---
name: coordinator-driven-development
description: Use when implementing a plan or a well-scoped coding task in this session as the Coordinator, before writing any implementation code yourself.
---

# Coordinator-Driven Development

**REQUIRED BACKGROUND:** superpowers:subagent-driven-development — this skill is that process with the roster pinned: every implementation task goes to the `executor` custom agent, never to you (the Coordinator) directly, and the escalation-to-a-stronger-advisor step is built into the executor itself. Read that skill for the full background (task briefs, report files, ledger, review method) — this skill overrides who implements, at what granularity review happens, what happens when they're unsure, and when tasks may run concurrently.

**REQUIRED SUB-SKILL:** superpowers:dispatching-parallel-agents — use it to judge whether the plan's tasks are independent domains before dispatching more than one executor at a time (see "Parallel task dispatch" below).

**"The user is in a hurry" is never a reason to skip a step-level review or to commit on the user's behalf.** If time pressure is real, the fix is coarser task/step granularity (fewer, bigger review checkpoints) decided up front in the task brief — not skipping checkpoints that already exist, and not treating urgency as implicit permission to override the no-commit rule.

## Roster

| Role | Who | Model |
|---|---|---|
| Coordinator | you (this session) | inherits session model |
| Executor (per task) | `Agent`(subagent_type: "executor") — one per independent task, dispatched concurrently (same response) when tasks are file-disjoint per superpowers:dispatching-parallel-agents | Sonnet 5 — pinned in the agent's own definition, no need to pass `model` |
| Step implementer | the executor itself dispatches a fresh subagent per step of its task (`Agent`(subagent_type: "general-purpose" or recursively "executor")) | Sonnet 5 |
| Escalation advisor | the executor (or a step implementer) calls `Agent`(model: "fable") when a design judgment call has more than one reasonable answer | Fable 5 |
| Step / final reviewer | `Agent`(subagent_type: "general-purpose") dispatched by the Coordinator, instructed to invoke Skill `code-review` for the bug/cleanup pass — one per ready task, dispatched concurrently (same response) when more than one task is ready for review at once | varies (effort level scales with diff size, see below) |

## What this skill changes vs. plain subagent-driven-development

- **Implementer dispatch always targets `subagent_type: "executor"`.** Never dispatch a generic `general-purpose` agent for a whole task, and never edit source files yourself mid-plan — if you're about to open Edit on a source file, stop, that's the executor's job
- **The executor decomposes its task into steps and delegates each one, instead of implementing inline.** It dispatches a fresh subagent per step (mirroring "fresh subagent per task" one level deeper) rather than writing all the task's steps itself in one continuous turn
- **Review granularity is per step, not per task.** After every step except the task's last one, the executor pauses and reports **STEP_DONE**, ending its turn. You (the Coordinator) — not the executor — dispatch the reviewer for that step's diff; review dispatch is never something the executor does to itself
- **The reviewer's bug/cleanup pass is the `/code-review` skill, not an ad-hoc read-through.** Dispatch an `Agent` whose prompt tells it to (a) check spec compliance against the task brief (did it build what was asked, nothing more, per superpowers:subagent-driven-development's review method) and (b) invoke Skill `code-review` scoped to the step's diff/files. Effort scales with what's being reviewed: `low` or `medium` for a single step's diff, `high` or `xhigh` for the final whole-branch review (mirrors subagent-driven-development's Model Selection: the final review is the one review worth spending the most on). Do not pass `--fix` — findings get routed back to the executor via `SendMessage` and fixed there, never applied by the reviewer directly
- **Resume the paused executor with `SendMessage`, don't re-dispatch a fresh one.** Verified 2026-07-08: `SendMessage(to: <executor's agent id/name>, message: ...)` resumes a paused executor with full prior context intact (it remembered step 1's files and continued step 2 without re-explanation). Re-dispatching a brand-new `Agent` call instead would lose that context and force you to re-paste everything. **Fallback**, only if `SendMessage` is missing from this session (confirm via `ToolSearch` first — it has intermittently been absent in past sessions): re-dispatch a fresh executor for the remaining steps, pasting the accumulated step decisions/diffs so far into the prompt
- **Independent tasks dispatch in parallel; steps within one task never do.** subagent-driven-development's Red Flags forbid parallel implementer dispatch to guard against conflicting edits on a shared tree — but per superpowers:dispatching-parallel-agents, concurrent dispatch on a shared tree is safe and expected when each task's Files list (from the plan's task template) is disjoint from every other concurrently-running task's Files list, and neither depends on an interface the other hasn't finished yet. When the plan's tasks meet that bar (this is the normal case — [[linear-subtask-no-dependencies]]-style plans are written with no blockedBy precisely so every task can run at once), dispatch one `Agent`(subagent_type: "executor") per task **in the same response** — issuing them across separate responses runs them sequentially instead. Steps inside a single task stay strictly sequential (each builds on the last, all in the same executor's turn). Fall back to sequential (or add `isolation: "worktree"` for extra safety) only when you can't confirm the tasks are file-disjoint, when they'd race on the same test fixtures/DB state, or when one task's steps need an interface the other is still defining
- **The Fable escalation happens inside the executor's own turn.** The executor (or its step implementer) decides on its own when a decision is genuinely ambiguous and calls Fable itself; you don't relay this. It shows up in the STEP_DONE / DONE report as "Consulted Fable on: ... → conclusion: ...". Read it — a pattern of frequent escalations on a plan usually means the plan under-specified something and needs a fix, not just repeated advisor calls
- **No commits — working-tree diffs and staging replace superpowers' commit-based review handoff.** This project forbids automatic `git commit`/`git push` (only an explicit user-invoked `/commit` may commit). superpowers:subagent-driven-development assumes the implementer commits per task and reviewers diff commit ranges (`scripts/review-package BASE HEAD`, ledger lines with `<base7>..<head7>`) — that machinery has nothing to diff against here. Use this instead:
  - The executor and its step implementers never commit. For any new file, they run `git add -N <path>` (intent-to-add) so it shows up in `git diff` with full content, without staging it
  - **With only one task in flight:** after a step's review is clean, the Coordinator runs `git add -A` to stage it, and the per-step review package is a plain `git diff` (unstaged changes = exactly the current step's delta, since prior steps are already staged)
  - **With more than one task in flight (parallel dispatch):** `git add -A` and bare `git diff` are both wrong — they'd sweep up or show every other in-flight task's unreviewed changes too. Scope everything to the reporting task's own Files list instead: review package = `git diff -- <task's files>`, and after that review is clean, stage with `git add -- <task's files>` (never `-A`)
  - Final whole-branch review package = `git diff <ORIG_HEAD>` where `ORIG_HEAD` is `git rev-parse HEAD` recorded once before Task 1 — this captures everything (staged + unstaged) accumulated across all tasks and steps, replacing `scripts/review-package MERGE_BASE HEAD`. Run it only once every task has reached its terminal status, parallel or not
  - At the very end, once the final whole-branch review is clean, everything is staged in the working tree — tell the user it's ready and let them run `/commit` themselves. Do not commit on their behalf
- **Everything else is unchanged**: task brief contents and the STEP_DONE / DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED contract follow superpowers:subagent-driven-development. The spec-compliance half of its review method stays as-is; the quality half is now `/code-review` specifically, not a free-form read-through

## The step-level review loop

0. Before dispatching anything, group the plan's tasks into independent domains per superpowers:dispatching-parallel-agents (disjoint files, no unresolved cross-task interface). Dispatch every task in an independent group's `Agent`(subagent_type: "executor") calls **in the same response** — that's what makes them run concurrently. Record each one's agent id/name; you'll juggle several in parallel.

For each task (whether it's running alone or alongside others):

1. Prepare a self-contained task brief (steps, interfaces from other tasks, acceptance criteria).
2. The executor dispatches a step implementer, then reports **STEP_DONE** and pauses.
3. Dispatch a reviewer — an `Agent` call, never your own read-through — for that step: spec compliance against the task brief, plus Skill `code-review` (effort `low`/`medium`) scoped to `git diff` (solo) or `git diff -- <this task's files>` (parallel). If more than one parallel task is already sitting at STEP_DONE waiting for review, dispatch a reviewer for each of them **in the same response** instead of working through them one at a time.
4. **Clean:** stage it (`git add -A` solo, `git add -- <this task's files>` if parallel), then `SendMessage(to: <this executor>, message: "step N approved, proceed")`.
5. **Issues found:** `SendMessage(to: <this executor>, message: "<findings>, please fix step N")`. The executor dispatches a fix implementer and reports STEP_DONE again — go back to step 3.
6. Repeat 2–5 until the executor's report is a task-level status instead of STEP_DONE (its last step). Review and stage that final step the same way, then treat the task as complete
7. Update the progress ledger. STEP_DONE reports from parallel tasks can arrive in any order — don't wait for the others to also reach a checkpoint before reviewing one that's ready. If several are already waiting when you check, batch their reviewer dispatches into one response (step 3); if they trickle in one at a time, review each as it lands rather than queuing it
8. Once every task in the plan has reached its terminal status, dispatch the final whole-branch review: spec compliance against the whole plan, plus Skill `code-review` (effort `high` or `xhigh`) scoped to `git diff <ORIG_HEAD>`

Ledger lines record files, not commits, and interleave naturally across concurrent tasks, e.g.:
```
Task 2 / Step 1: complete (files: app/models/foo.rb, spec/models/foo_spec.rb — staged, review clean)
Task 3 / Step 1: complete (files: app/services/bar_service.rb, spec/services/bar_service_spec.rb — staged, review clean)
Task 2 / Step 2: complete (files: app/models/foo.rb — staged, review clean)
Task 3: all steps complete
Task 2: all steps complete
```

## Coordinator responsibilities

- Prepare self-contained task briefs, each with its own Files list — the executor never inherits this session's context, so nothing here can be implied, and disjoint Files lists are what makes parallel dispatch safe
- Before dispatching, check the plan's tasks for independence (superpowers:dispatching-parallel-agents) and dispatch every independent task's executor in one response; review and resume each one at every STEP_DONE, not just once at the task's end
- Keep the progress ledger current at step granularity so a compaction never causes re-dispatch of finished steps
- **Plan mode approval (`ExitPlanMode` accepted) is itself the signal to start implementation.** Once the user approves the plan, dispatch the first executor without waiting for a separate "実装して" — no extra confirmation round-trip. This does not apply to a Linear ticket's implementation plan (superpowers-adjacent `linear-task-planner` skill): there, Plan-mode approval only means "post this to Linear," because the real approver is a human supervisor reviewing the ticket afterward — implementation still waits for an explicit instruction in that flow

## Common Mistakes

| 間違い | 正しい形 |
|---|---|
| Coordinator が自分で実装コードを書く | 実装は必ず `executor` に委譲する |
| 汎用の general-purpose エージェントにタスク全体を投げる | タスクは `subagent_type: "executor"` に委譲する（ステップごとの委譲は executor 自身が行う） |
| executor が全ステップをまとめて実装してから一度だけ報告してくる | 各ステップで STEP_DONE 停止・Coordinator レビューを挟む設計になっているか確認する。まとめて報告してきたらやり直させる |
| executor の STEP_DONE 後、Coordinator がレビューせずそのまま次へ進める指示を送る | 必ずレビューを起動してから `SendMessage` で再開する。レビューを起動するのは Coordinator の役目であって executor の自己判断ではない |
| ステップ再開のたびに新しい Agent を再ディスパッチする | `SendMessage(to: <executor>)` で同じ executor を再開する（コンテキストが保持される）。新規ディスパッチだと文脈を失う |
| タスクの独立性を確認せずに複数 executor を並列で投げる | superpowers:dispatching-parallel-agents で Files が重ならないか・未確定インターフェースへの依存がないかを先に確認する |
| 1つのタスク内の複数ステップを並列に投げる | ステップは常に逐次。並列化はタスク単位のみ |
| 並列実行中に `git add -A` や素の `git diff` を使う | 他タスクの未レビュー差分を巻き込む。`git diff -- <ファイル一覧>` / `git add -- <ファイル一覧>` でこのタスクのファイルだけに絞る |
| 複数タスクを別々のレスポンス（ターン）に分けてディスパッチしてしまう | 同一レスポンス内で複数の `Agent` 呼び出しを発行する（レスポンスを分けると逐次実行になる） |
| 複数タスクの diff を Coordinator 自身が読んで判断し、レビューエージェントを dispatch しない | レビューは必ず `Agent` 呼び出しで別のレビューエージェントに行わせる。Coordinator の目視確認では代替しない |
| レビューエージェントに `/code-review` を使わせず、自己流の観点で読ませる | レビューエージェントのプロンプトで Skill `code-review` を起動させる（品質面はこれが担当。spec compliance は別途タスクブリーフと突き合わせて確認する） |
| ステップ単位のレビューにも `high`/`xhigh` の重い effort を使う | ステップ単位は `low`/`medium` で十分。`high`/`xhigh` は最終の全体レビューだけに使う |
| レビューエージェントに `--fix` を渡して直接修正させる | 修正は executor の仕事。findings は `SendMessage` で executor に渡して直させる |
| 複数タスクが同時に STEP_DONE でレビュー待ちなのに、レビューエージェントを1件ずつ順番に dispatch する | 同時に待っているものは同一レスポンスでまとめてレビューエージェントを並列 dispatch する |
| Coordinator が Fable への相談を代行・仲介する | 相談は executor（またはそのステップ実装先）自身が行う。Coordinator は報告に含まれる相談内容を読むだけ |
| Plan承認後も追加の「実装して」を待って手が止まる | Plan mode 承認（ExitPlanMode）がそのまま実装開始の合図。承認され次第、最初の executor を dispatch する |
| Linear チケットの実装計画の承認も「実装開始の合図」として扱ってしまう | linear-task-planner の承認ゲートは対象外（上長レビュー前提のため）。あちらは引き続き明示指示を待つ |
| `scripts/review-package BASE HEAD` をコミット前提でそのまま使う | commit は禁止。`git diff`（ステップ単位）／`git diff ORIG_HEAD`（最終レビュー）＋ staging で代替する |
| レビュー通過後に executor や Coordinator が commit してしまう | commit は一切しない。最終レビュー通過後、ユーザーに `/commit` を促すだけ |
| 「急いでいる」「プロセスに時間をかけたくない」という発言を理由にステップレビューをまとめる・省略する | 急ぎなら task brief 側でステップ・タスクの粒度を粗くする（チェックポイントの数を減らす）。既にあるチェックポイントを飛ばさない |
| ユーザーの「急いで」「細かいことは気にせず進めて」を、commit禁止やレビュー必須のルールを一時的に解除してよい合図だと解釈する | 「急いで」は作業の進め方についての要望であって、安全ルールの解除指示ではない。ルール自体を変えたいなら、それが本当にユーザーの意図か明示的に確認してから変える |
