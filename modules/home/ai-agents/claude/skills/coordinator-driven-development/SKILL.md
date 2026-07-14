---
name: coordinator-driven-development
description: Use when coordinating execution of a plan or a well-scoped coding task in the current Claude Code session.
---

# Coordinator-Driven Development

**REQUIRED BACKGROUND:** superpowers:subagent-driven-development — this skill is that process with the roster pinned for Claude Code: the Sonnet Coordinator only writes instructions and relays results, launches Claude Code's built-in/default `Explore` subagent with Haiku, and delegates each small implementation task to a Haiku `executor` that owns the outcome. The executor normally implements directly but may launch bounded Haiku subagents for isolated exploration, diagnostics, or file-disjoint implementation when doing so reduces total token use. Read that skill for the full background (task briefs and status contracts), but this skill removes inherited per-step/per-task reviews and overrides any inherited instruction for the Coordinator to create or update report files, ledger files, commits, or other repository state. This skill also overrides who explores, who implements, how advice is requested, and when tasks may run concurrently.

**REQUIRED SUB-SKILL:** superpowers:dispatching-parallel-agents — use it to judge whether the plan's tasks are independent domains before dispatching more than one executor at a time (see "Parallel task dispatch" below).

**Coordinator contract:** The Coordinator produces only task briefs, agent prompts/messages, relayed decisions/findings, and progress updates. It never writes, edits, creates, deletes, formats, or stages repository files; never implements tests or production code; and never runs repository commands, tests, formatters, generators, migrations, commits, or pushes. Delegate implementation, repository mutations, helper selection, and final verification to a Haiku `executor`; delegate the final review to the reviewer. There is no exception for a one-line or "obvious" change.

**"The user is in a hurry" is never a reason to skip the final review or to commit on the user's behalf.** Urgency does not override the no-commit rule.

## Roster

| Role | Who | Model |
|---|---|---|
| Coordinator | you (this session) — writes briefs and instructions, dispatches/resumes agents, relays decisions/findings, and tracks progress in the conversation; never implements, reviews directly, runs repository commands, or changes the working tree/index | Sonnet |
| Built-in Explore | Claude Code's built-in/default `Explore` subagent, launched as `Agent`(subagent_type: "Explore", model: "haiku") — investigates the repository before the Coordinator prepares a self-contained task brief; do not define or dispatch a custom Explorer | Haiku |
| Executor (per task) | `Agent`(subagent_type: "executor") — one per small, self-contained implementation task; it owns integration, fixes, final verification, and the task outcome, and may launch bounded helpers for token-efficient side work | Haiku — pinned in the agent's own definition, no need to pass `model` |
| Executor helper (on demand) | Launched directly by the executor: built-in `Explore` with `model: "haiku"` for broad code search, or `general-purpose` with `model: "haiku"` for noisy diagnostics or an isolated file-disjoint implementation subtask; returns a concise report and never stages or commits | Haiku |
| Escalation advisor | `Agent`(subagent_type: "general-purpose", model: "opus") dispatched by the Coordinator only after an executor reports `NEEDS_ADVICE`; its prompt forbids editing or implementing | Opus (read-only) |
| Final reviewer | `Agent`(subagent_type: "general-purpose", model: "sonnet") dispatched by the Coordinator for the final whole-branch review | Sonnet |

## What this skill changes vs. plain subagent-driven-development

- **Implementation dispatch always targets `subagent_type: "executor"`.** The Coordinator makes each task small and self-contained before dispatch. Never dispatch a generic `general-purpose` implementer and never use repository-editing or shell tools yourself — the Haiku executor writes the tests and implementation, runs commands, applies fixes, and stages approved files directly
- **The executor owns the outcome but may launch token-saving helpers directly.** Quick targeted work and anything requiring shared implementation context stays in the executor. For isolated search/log/document analysis or a small file-disjoint implementation subtask, the executor may invoke a nested Haiku `Agent` when prompt/result overhead is lower than keeping the work in its own context. The executor integrates the result and performs final verification; helpers never stage or commit
- **Nested delegation is bounded by net token savings.** Use the smallest useful prompt and request a concise evidence-backed result without raw logs. Do not spawn a helper when startup/prompt/result overhead is likely to exceed the context saved, and do not let helpers recursively delegate again
- **Exploration uses Claude Code's built-in/default Explore subagent on Haiku.** When repository discovery is needed to make a task brief self-contained, the Coordinator dispatches `Agent`(subagent_type: "Explore", model: "haiku") before the executor. Do not replace it with a custom Explorer
- **There is no per-step or per-task reviewer.** Each executor implements every step in its task sequentially and reports **DONE** / **DONE_WITH_CONCERNS** once. The only review is the final whole-branch review
- **The final review uses Sonnet and `/code-review`.** Dispatch `Agent`(subagent_type: "general-purpose", model: "sonnet") with every task brief and instruct it to check whole-plan compliance and invoke Skill `code-review` scoped to `git diff HEAD`. Do not pass `--fix` — findings return to the owning Haiku executor; cross-task findings go to a new, scoped Haiku executor
- **Resume the executor with `SendMessage`, don't re-dispatch a fresh one.** Use it to relay advisor decisions, final-review findings, and final staging approval while preserving the executor's task context. **Fallback**, only if `SendMessage` is missing from this session (confirm via `ToolSearch` first): re-dispatch a fresh executor with the full task brief and accumulated decisions/findings
- **Parallel task dispatch is the default; steps within one task never parallelize.** Plan every task set expecting to dispatch all of them at once. Before dispatching, run the superpowers:dispatching-parallel-agents check: are the tasks' Files lists (from the plan's task template) disjoint from each other, with no task depending on an interface another hasn't finished yet? This is the normal case — [[linear-subtask-no-dependencies]]-style plans are written with no blockedBy precisely so every task can run at once. When the check passes, dispatch one `Agent`(subagent_type: "executor") per task **in the same response** — issuing them across separate responses runs them sequentially instead. Steps inside a single task stay strictly sequential (each builds on the last, all in the same executor's turn). Only fall back to sequential dispatch (or add `isolation: "worktree"` for extra safety) in the specific cases the check flags: tasks aren't file-disjoint, they'd race on the same test fixtures/DB state, or one task's steps need an interface another is still defining
- **Opus advice is coordinated, never nested.** When the executor reaches a genuine design ambiguity, it stops without guessing and returns `NEEDS_ADVICE` with the question and options. The Coordinator dispatches `Agent`(subagent_type: "general-purpose", model: "opus") with an analysis-only prompt, then resumes the same executor with the decision via `SendMessage`. The advisor never edits files
- **No commits — executor-owned staging replaces superpowers' commit-based review handoff.** This project forbids automatic `git commit`/`git push` (only an explicit user-invoked `/commit` may commit). superpowers:subagent-driven-development assumes the implementer commits per task and reviewers diff commit ranges (`scripts/review-package BASE HEAD`, ledger lines with `<base7>..<head7>`) — that machinery has nothing to diff against here. Use this instead:
  - The executor never commits. For any new file, it runs `git add -N <path>` (intent-to-add) so the final reviewer can see the full content before approval
  - Executors do not stage completed tasks before the final review
  - The final reviewer — never the Coordinator — inspects `git diff HEAD`, which captures all staged and unstaged work because no task commits
  - After the final review is clean, the Coordinator sends each executor the exact approved file list. Each executor stages only its own approved files and reports **STAGED**
  - At the very end, once every task is **STAGED**, tell the user it's ready and let them run `/commit` themselves. Do not commit on their behalf
- **Everything else is unchanged**: task brief contents and the DONE / DONE_WITH_CONCERNS / STAGED / NEEDS_CONTEXT / NEEDS_ADVICE / BLOCKED contract follow superpowers:subagent-driven-development except for the **STAGED** terminal state defined here. The final reviewer checks task-brief compliance and uses `/code-review` for quality; the Coordinator does neither review itself

## Execution and final review

0. Before dispatching anything, launch Claude Code's built-in/default `Explore` subagent as `Agent`(subagent_type: "Explore", model: "haiku") for required repository discovery, then split the plan into small, self-contained implementation tasks.

1. Prepare a self-contained task brief (steps, interfaces from other tasks, acceptance criteria).
2. After every brief exists, group file-disjoint tasks into independent domains per superpowers:dispatching-parallel-agents and dispatch their `Agent`(subagent_type: "executor") calls **in the same response**, with the matching brief in each prompt. Record each executor's agent id/name.
3. Each Haiku executor implements every step in its task sequentially with TDD, then reports **DONE** / **DONE_WITH_CONCERNS**. It normally works directly and does not stage the task yet.
4. Handle other statuses before continuing:
   - **NEEDS_ADVICE:** dispatch a read-only `Agent`(subagent_type: "general-purpose", model: "opus") for that exact decision, then `SendMessage` the conclusion to the same executor
   - **NEEDS_CONTEXT:** supply the missing brief context, using the built-in/default `Explore` subagent on Haiku if mechanical discovery can recover it; ask the user only when the missing decision cannot be derived safely
   - **BLOCKED:** resolve the reported blocker by adding context, reducing task size, or escalating to the user; never count it as complete
   - **DONE_WITH_CONCERNS:** accept it only when concerns are observations unrelated to correctness or scope; otherwise send the unresolved concern back for correction
5. Wait until every task is **DONE** or has an explicitly accepted **DONE_WITH_CONCERNS**. NEEDS_CONTEXT, NEEDS_ADVICE, and BLOCKED are never completion states.
6. Dispatch `Agent`(subagent_type: "general-purpose", model: "sonnet") for whole-plan compliance and Skill `code-review` scoped to `git diff HEAD`.
7. If the final reviewer finds issues, route each finding by its owning task/files:
    - Send task-local findings to that task's original Haiku executor with `SendMessage`; it fixes them directly and reports DONE again
    - For a cross-task integration finding with no single owner, create one new small, self-contained repair brief and dispatch a new Haiku `executor`; the Coordinator never implements it
    - Repeat the Sonnet whole-plan review after all fixes report DONE
8. Once the Sonnet final review is clean, send each executor its exact approved file list and instruct it to stage only those files and report **STAGED**.
9. Finish only when every executor has reported **STAGED**.

Ledger lines record files, not commits, and interleave naturally across concurrent tasks, e.g.:
```
Task 2: DONE (files: app/models/foo.rb, test/models/foo_test.rb — awaiting final review)
Task 3: DONE (files: app/services/bar_service.rb, test/services/bar_service_test.rb — awaiting final review)
Final review: clean
Task 2: STAGED
Task 3: STAGED
```

## Coordinator responsibilities

- Delegate repository investigation to Claude Code's built-in/default `Explore` subagent by launching `Agent`(subagent_type: "Explore", model: "haiku") before preparing a task brief when exploration is needed; never create a custom Explorer, and exploration never includes implementation
- Prepare small, self-contained task briefs that a Haiku executor can implement directly, each with its own Files list — the executor never inherits this session's context, so nothing can be implied
- When an executor reports NEEDS_ADVICE, ask a read-only Opus advisor and relay the decision back; never ask the executor to dispatch the advisor
- Before dispatching, check the plan's tasks for independence (superpowers:dispatching-parallel-agents) and dispatch every independent task's executor in one response
- Keep the progress ledger current at task granularity in the conversation so a compaction never causes re-dispatch of finished tasks; never edit a repository ledger or report file yourself
- Use only coordination operations: write instructions, dispatch/resume agents, relay their outputs, and report status. Do not use repository editing, shell, test, formatter, generator, migration, or Git mutation tools yourself

## Common Mistakes

| 間違い | 正しい形 |
|---|---|
| カスタムの Explorer エージェントを定義・起動する | Claude Code 組み込みのデフォルト `Explore` を `Agent`(subagent_type: "Explore", model: "haiku") で起動する |
| Coordinator が一行だけの修正、テスト、設定変更を自分で書く | 大小を問わず、リポジトリへの変更は必ず Haiku `executor` に指示する |
| Coordinator がテスト、formatter、generator、migration、`git add` を自分で実行する | 実行対象と受け入れ条件を executor に指示し、結果を報告させる。Coordinator はリポジトリコマンドを実行しない |
| executor が常にすべての探索・大量ログ・独立実装を自分のコンテキストへ読み込む | 分離可能な作業で総トークンが減る場合はHaiku helperを直接ネスト起動し、短い報告だけを受け取る |
| helper にタスク全体や共有ファイルの実装を丸投げする | executorが全体責任・統合・最終検証を持つ。helperへの実装委譲は明示したファイルだけの独立した小タスクに限定する |
| helperの起動コストを考えず細かい作業まで再委譲する | プロンプトと結果のオーバーヘッドより節約量が大きい場合だけネスト起動する |
| Sonnet を実装担当として使う | Sonnet は Coordinator と最終レビューの中継・統合に使い、実装は Haiku executor に委譲する |
| 汎用の general-purpose エージェントに実装タスクを投げる | タスクは `subagent_type: "executor"` に委譲し、その executor 自身が各ステップを直接実装する |
| ステップ再開のたびに新しい Agent を再ディスパッチする | `SendMessage(to: <executor>)` で同じ executor を再開する（コンテキストが保持される）。新規ディスパッチだと文脈を失う |
| タスクの独立性を確認せずに複数 executor を並列で投げる | superpowers:dispatching-parallel-agents で Files が重ならないか・未確定インターフェースへの依存がないかを先に確認する |
| 1つのタスク内の複数ステップを並列に投げる | ステップは常に逐次。並列化はタスク単位のみ |
| executor が最終レビュー前にタスクを stage する | 最終レビューまでは未stageのままにし、新規ファイルだけ `git add -N` で可視化する。最終承認後に指定ファイルだけを stage する |
| 複数タスクを別々のレスポンス（ターン）に分けてディスパッチしてしまう | 同一レスポンス内で複数の `Agent` 呼び出しを発行する（レスポンスを分けると逐次実行になる） |
| 複数タスクの diff を Coordinator 自身が読んで判断し、レビューエージェントを dispatch しない | レビューは必ず `Agent` 呼び出しで別のレビューエージェントに行わせる。Coordinator の目視確認では代替しない |
| レビューエージェントに `/code-review` を使わせず、自己流の観点で読ませる | レビューエージェントのプロンプトで Skill `code-review` を起動させる（品質面はこれが担当。要件適合は別途タスクブリーフと突き合わせて確認する） |
| 最終レビューのモデルを曖昧な effort 指定だけに任せる | 最終の全体レビューは `model: "sonnet"` を明示する |
| レビューエージェントに `--fix` を渡して直接修正させる | 修正は executor の仕事。findings は `SendMessage` で executor に渡して直させる |
| executor が Opus advisor を再帰的に呼ぶ | executor は NEEDS_ADVICE で止まり、Coordinator が読み取り専用 Opus advisor を起動して結論を中継する |
| `scripts/review-package BASE HEAD` をコミット前提でそのまま使う | commit は禁止。Sonnet final reviewer が `git diff HEAD` を確認し、承認後の staging は executor が行う |
| レビュー通過後に executor や Coordinator が commit してしまう | commit は一切しない。executor は承認済みファイルの staging だけを行い、最終レビュー通過後にユーザーへ `/commit` を促す |
| 「急いでいる」「プロセスに時間をかけたくない」という発言を理由に最終レビューを省略する | 急ぎでもSonnet final reviewerによる全体レビューは行う |
| ユーザーの「急いで」「細かいことは気にせず進めて」を、commit禁止やレビュー必須のルールを一時的に解除してよい合図だと解釈する | 「急いで」は作業の進め方についての要望であって、安全ルールの解除指示ではない。ルール自体を変えたいなら、それが本当にユーザーの意図か明示的に確認してから変える |
