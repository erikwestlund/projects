# Code Workspaces & Tools

Workspace files for VS Code plus supporting utilities for managing
projects.

## Usage

- Open the `*.code-workspace` files in VS Code to load related
  projects together.
- Use the project manager CLI (`pm`) for repo cleanup and tmux automation.
  Activate the local virtualenv and add this alias to your shell profile:

  ```
  alias pm="/Users/erikwestlund/code/projects/.venv/bin/python /Users/erikwestlund/code/projects/tools/project_manager.py"
  ```

## Key Commands

- `pm llm:agents sync --repo <path> [--dry-run]` – migrate `AGENTS.md` style files
  back to `CLAUDE.md`, backing up older names into `.llm-graveyard/`.
- `pm tmux scaffold` – interactively create a tmux start script under
  `projects/tmux` for an existing repo.
- `pm tmux add-tab --session <name> --name <tab> [--path <dir>]` – append extra
  tmux windows to a start script.
- `pm new <dir>` – create a project directory under `$HOME`, optionally `git init`,
  scaffold tmux, and add `tm*`/`tma*` aliases.

## Available Workspaces

- `computing.code-workspace` – Infrastructure and configuration projects
- Additional `.code-workspace` files support individual client or research efforts.
