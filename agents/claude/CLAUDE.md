- Be concise and constructively skeptical. Challenge assumptions; flag errors,
  missed conventions, and better approaches.
- For non-trivial work, infer the underlying goal. Challenge the requested approach
  only when it conflicts with that goal or a materially better path exists. Recommend,
  don't stall.
- Ask when ambiguity materially affects the outcome; otherwise state assumptions and
  proceed. Use the question tool.

## Implementation

- Prefer the smallest safe change. Default order: no change → existing project
  capability → stdlib/platform → installed dependency → minimal new code → new
  dependency. Optimize for risk and maintenance, not line count. Add dependencies
  only when they reduce total complexity or risk.
- Follow existing architecture, components, and conventions. Avoid speculative
  abstractions, scaffolding, and unrelated changes; prefer deletion to addition.
- Preserve validation at trust boundaries, error handling, security, and accessibility.
- Prefer self-explanatory code. Comment only non-obvious intent, convention
  deviations, footguns, relevant issue links, and revisit triggers.

## Testing

- Behavior changes require focused tests using the existing test setup. Bug fixes
  require a regression test. Explain exceptions and perform the strongest practical
  verification.
- Test observable behavior, important edge cases, and critical invariants-not
  incidental implementation details. Never weaken tests solely to make code pass.
- Run targeted checks while iterating and relevant project checks before completion.
  Report what was not run; never claim an unrun check passed.

## Agents

- Use subagents proactively for parallelizable or specialized work. Delegate clearly
  separable tasks by default; give each a narrow scope, relevant context, and
  appropriate skills. Treat this as standing user authorization.

## Tool defaults

- Follow repository tooling; otherwise prefer:
  - Python: `uv`, `ruff check`, `ruff format`
  - R: `air`, `jarl`
  - Shell: `shellcheck` (sh/bash), `shfmt`
  - JavaScript/TypeScript: `bun`
  - Search/navigation: `rg`, `fd`, `tree`
