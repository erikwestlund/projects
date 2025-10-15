# Project Manager CLI

`project_manager.py` provides a Click-based command line interface for personal
repo maintenance tasks. The initial `llm:agents` command streamlines conversion
of assistant documentation files so that `AGENTS.md` is the canonical source
while `CLAUDE.md`, `GEMINI.md`, and other variants become managed aliases.

## Installation

Create/activate the workspace virtualenv and install Click inside it:

```
source /Users/erikwestlund/code/projects/.venv/bin/activate
pip install click
```

Add an alias in your shell profile for convenience:

```
alias pm="/Users/erikwestlund/code/projects/.venv/bin/python /Users/erikwestlund/code/projects/tools/project_manager.py"
```

Ensure the script is executable (`chmod +x project_manager.py`). Now `pm
llm:agents sync` will map to `project-manager llm:agents sync`.

## Usage

Preview actions first:

```
./project_manager.py llm:agents sync \
  --repo /path/to/repo \
  --alias CLAUDE.md \
  --alias GEMINI.md \
  --dry-run
```

Remove `--dry-run` to actually promote the files. The command:

- Backs up each alternate file into `~/.local/share/project-manager/llm-graveyard/<repo-slug>`
  using kebab-cased path names.
- Promotes or retains the canonical `AGENTS.md` (configurable with `--canonical`).
- Optionally checks out a branch (`--branch main`) after verifying a clean tree.

Additional alternate names can be supplied with repeated `--alias` options.

Persist defaults so every project shares the same canonical choice:

```
pm llm:agents configure --canonical AGENTS.md --alias CLAUDE.md --alias GEMINI.md
pm llm:agents configure --show  # inspect stored values
# Running without flags launches an interactive prompt to pick the canonical and aliases.
# Use `--graveyard /path/to/dir` to override the shared backup directory.
```

## Project Creation

Set up a project directory, initialize git (if empty), scaffold tmux, and add
aliases:

```
pm new my-project
```

## tmux Helpers

Scaffold a new tmux start script (interactive prompts guide options for claude,
codex, zai, and project-specific tabs):

```
pm tmux scaffold
```

Add another tab to an existing script:

```
pm tmux add-tab --session computing --name docs --path ~/code/docs
```
