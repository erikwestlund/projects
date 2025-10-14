# Project Manager CLI

`project_manager.py` provides a Click-based command line interface for personal
repo maintenance tasks. The initial `llm:agents` command streamlines conversion
of assistant documentation files so that `CLAUDE.md` remains canonical while
`AGENTS.md` and other variants get backed up.

## Installation

Install Click inside the workspace virtualenv (located at `/Users/erikwestlund/code/projects/.venv`):

```
/Users/erikwestlund/code/projects/.venv/bin/pip install click
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
  --legacy AGENTS.md GEMINI.md \
  --dry-run
```

Remove `--dry-run` to actually promote the files. The command:

- Ensures `.llm-graveyard/` exists, ignoring it via `.gitignore`.
- Backs up each legacy file into the graveyard using kebab-cased path names.
- Promotes or retains the canonical `CLAUDE.md` (configurable with `--canonical`).
- Optionally checks out a branch (`--branch main`) after verifying a clean tree.

Additional legacy names can be supplied with repeated `--legacy` options.

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
