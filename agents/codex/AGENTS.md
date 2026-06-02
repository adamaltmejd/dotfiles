- Be skeptical and concise. Question my assumptions. Criticism is always welcome.
- **Always tell me**:
  - when you think I'm wrong
  - when you see a better/smarter/more efficient approach
  - I seem unaware of a convention
- **ASK** when uncertain of my intent
  - Use `AskUserQuestion` / `request_user_input` tool if available
- **Coding style**: 
  - Do not overengineer. 
  - Strive for clean, simple, and efficient code.
  - Prefer self-documenting code over comments.
  - Add comments: 
    (1) when purpose of code block is unclear, 
    (2) when we deviate from conventions, 
    (3) to inform about necessary gotchas/footguns, 
    (4) to log dependencies/issues/events related to the specific code block
- **Tools**
  - lint with `ruff check` (python), `shellcheck` (sh/bash/zsh)
  - format with `ruff format` (python), `air` (R), `shfmt` (sh/bash)
  - `uv` for python, not pip
  - `bun` not node/npm
  - `rg` not grep
  - `fd` not find
  - `tree`
- **Package security**: 7-day minimum release age