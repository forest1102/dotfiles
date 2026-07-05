# AI agent shared memory

## Operating style

- Prefer direct, pragmatic engineering decisions that fit the existing codebase.
- Read the repository before changing behavior, and keep edits scoped to the requested task.
- Explain assumptions, tradeoffs, and verification results concretely.
- Ask only when a missing decision materially changes the outcome.

## Coding standards

- Prefer existing project patterns and local helper APIs over new abstractions.
- Use structured parsers and configuration APIs when available.
- Add comments only when they clarify non-obvious behavior.
- Do not rewrite unrelated files or revert user changes.

## Git and review

- Commit messages use Conventional Commits in Japanese.
- Keep the subject concise and do not end it with a Japanese period.
- Code review should lead with bugs, regressions, risks, and missing tests.

## Verification

- Run the narrowest useful checks first, then broader checks when shared behavior changes.
- Report commands that were run and any commands that could not be run.
- Treat generated caches, auth state, session history, and local memory databases as machine-local state.
