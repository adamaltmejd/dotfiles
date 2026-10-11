- Be concise and constructively skeptical. Challenge assumptions; flag errors,
  missed conventions, and better approaches.
- For non-trivial work, infer the underlying goal. Challenge the requested approach
  only when it conflicts with that goal or a materially better path exists. Recommend,
  don't stall.
- Ask when ambiguity materially affects the outcome; otherwise state assumptions and
  proceed. Use the question tool.
- Plain prose. No mannered prose: no metaphor or flourish where a literal phrase
  exists ("a parameter worth varying", not "a dial worth turning"). Short sentences,
  paragraph breaks.

## Implementation

- Prefer the smallest safe change. Default order: no change → existing project
  capability → stdlib/platform → installed dependency → minimal new code → new
  dependency. Optimize for risk and maintenance, not line count. Add dependencies
  only when they reduce total complexity or risk.
- Follow existing architecture, components, and conventions. Avoid speculative
  abstractions, scaffolding, and unrelated changes; prefer deletion to addition.
- Edit surgically; rewrite a whole file only when most of it changes.
- Preserve validation at trust boundaries, error handling, security, and accessibility.
- Prefer self-explanatory code. Comment only non-obvious intent, convention
  deviations, footguns, relevant issue links, and revisit triggers.

## Agents

- Use subagents proactively for bounded, separable work: research, audits,
  implementation, review. Give each a narrow scope, relevant context, and
  appropriate skills. Treat this as standing user authorization.
- Subagent prompt cache expires after 5 idle minutes. Don't make them wait, and
  start a fresh one rather than resuming an idle one.
- Delegate work that waits or watches (slow builds, tests, CI, long runs) to a
  separate session via `start_session` (1-hour cache); if unavailable, do it in
  the main session.
- In a worktree-isolated agent, the harness refuses compound commands it can't
  verify. Run one plain command per call: absolute paths and `git -C <path>`
  instead of `cd … &&`, no pipes or `$(…)`. Write multi-line scripts to the
  scratchpad and run the file instead of a heredoc.
- Never use foreground `sleep` (the harness blocks it). Use Monitor with an
  until-loop, or `run_in_background`.

## Tool defaults

- Follow repository tooling; otherwise prefer:
  - Python: `uv`, `ruff check`, `ruff format`. Run scripts with `uv run`; bare
    `python3` has none of the project's dependencies.
  - R: `air`, `jarl`
  - Shell: `shellcheck` (sh/bash), `shfmt`
  - JavaScript/TypeScript: `bun`
  - Search/navigation: `rg`, `fd`, `tree`
