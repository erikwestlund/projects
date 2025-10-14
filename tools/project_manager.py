#!/usr/bin/env python3
"""Project Manager CLI for personal repository maintenance tasks."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List

try:
    import click
except ModuleNotFoundError as exc:  # pragma: no cover - dependency guard
    raise SystemExit("The 'click' package is required. Install it with `pip install click`.") from exc

DEFAULT_CANONICAL_NAME = "CLAUDE.md"
DEFAULT_LEGACY_NAMES = ("AGENTS.md", "GEMINI.md")
GRAVEYARD_DIRNAME = ".llm-graveyard"
TMUX_DIR = Path.home() / "code" / "projects" / "tmux"
ALIASES_FILE = Path.home() / "code" / "dotfiles" / "config" / ".aliases"


class ProjectManagerError(click.ClickException):
    """Raised when a CLI operation encounters an unrecoverable error."""

    def __init__(self, message: str) -> None:
        super().__init__(message)


@dataclass
class SyncConfig:
    repo_path: Path
    canonical_name: str
    legacy_names: List[str]
    branch: str | None
    dry_run: bool


@dataclass
class TmuxWindow:
    name: str
    path: Path
    commands: List[str]


def run_git_command(repo: Path, args: List[str]) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise ProjectManagerError(
            f"git {' '.join(args)} failed with exit code {completed.returncode}: {completed.stderr.strip()}"
        )
    return completed


def ensure_git_repo(repo: Path) -> None:
    completed = run_git_command(repo, ["rev-parse", "--is-inside-work-tree"])
    if completed.stdout.strip() != "true":
        raise ProjectManagerError(f"{repo} is not a git work tree")


def ensure_clean_worktree(repo: Path) -> None:
    status = run_git_command(repo, ["status", "--porcelain"])
    if status.stdout.strip():
        raise ProjectManagerError(
            "Repository has uncommitted changes. Please commit or stash before running sync."
        )


def checkout_branch(repo: Path, branch: str, dry_run: bool) -> None:
    if dry_run:
        click.echo(f"[DRY-RUN] Would checkout branch '{branch}' in {repo}")
        return
    run_git_command(repo, ["checkout", branch])


def kebab_case_path(path: Path) -> str:
    """Convert a relative path to a kebab-cased filename while preserving suffix."""

    def to_kebab(value: str) -> str:
        cleaned = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-")
        return cleaned.lower() if cleaned else "segment"

    parts = [to_kebab(part) for part in path.parts[:-1]]
    stem = to_kebab(path.stem)
    pieces = [piece for piece in (*parts, stem) if piece]
    basename = "-".join(pieces) if pieces else "file"
    suffix = path.suffix.lower()
    return f"{basename}{suffix}"


def ensure_graveyard(repo: Path, dry_run: bool) -> Path:
    graveyard = repo / GRAVEYARD_DIRNAME
    if dry_run:
        click.echo(f"[DRY-RUN] Would ensure graveyard directory {graveyard}")
    else:
        graveyard.mkdir(parents=True, exist_ok=True)
    return graveyard


def ensure_gitignore(repo: Path, graveyard: Path, dry_run: bool) -> None:
    gitignore = repo / ".gitignore"
    entry = f"{graveyard.name}/"
    existing_text = ""
    if gitignore.exists():
        existing_text = gitignore.read_text(encoding="utf-8")
        existing_lines = [line.strip() for line in existing_text.splitlines()]
        if entry in existing_lines:
            return
    if dry_run:
        action = "append" if gitignore.exists() else "create"
        click.echo(f"[DRY-RUN] Would {action} {entry!r} to {gitignore}")
        return
    if gitignore.exists():
        with gitignore.open("a", encoding="utf-8") as handle:
            if existing_text and not existing_text.endswith("\n"):
                handle.write("\n")
            handle.write(f"{entry}\n")
    else:
        gitignore.write_text(f"{entry}\n", encoding="utf-8")


def gather_legacy_files(repo: Path, legacy_names: Iterable[str]) -> List[Path]:
    matches: List[Path] = []
    for legacy in legacy_names:
        for path in repo.rglob(legacy):
            if path.is_dir():
                continue
            rel_parts = path.relative_to(repo).parts
            if any(part in {".git", GRAVEYARD_DIRNAME} for part in rel_parts):
                continue
            matches.append(path)
    return matches


def backup_file(src: Path, graveyard: Path, dry_run: bool) -> Path:
    rel = src.relative_to(graveyard.parent)
    base_target = graveyard / kebab_case_path(rel)
    if base_target.exists():
        stem = base_target.stem
        suffix = base_target.suffix
        counter = 1
        while True:
            candidate = base_target.parent / f"{stem}-{counter}{suffix}"
            if not candidate.exists():
                base_target = candidate
                break
            counter += 1
    target = base_target
    if dry_run:
        click.echo(f"[DRY-RUN] Would backup {rel} to {target}")
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, target)
    return target


def promote_to_canonical(src: Path, canonical: Path, dry_run: bool) -> None:
    if dry_run:
        if canonical.exists():
            click.echo(f"[DRY-RUN] Would remove legacy file {src} (canonical already present)")
        else:
            click.echo(f"[DRY-RUN] Would rename {src} -> {canonical}")
        return

    if canonical.exists():
        if canonical.samefile(src):  # pragma: no cover - safety
            return
        src.unlink()
    else:
        canonical.parent.mkdir(parents=True, exist_ok=True)
        src.rename(canonical)


def process_legacy_files(config: SyncConfig) -> None:
    graveyard = ensure_graveyard(config.repo_path, config.dry_run)
    ensure_gitignore(config.repo_path, graveyard, config.dry_run)

    legacy_files = gather_legacy_files(config.repo_path, config.legacy_names)
    if not legacy_files:
        click.echo("No legacy files found. Nothing to do.")
        return

    for legacy_path in legacy_files:
        rel = legacy_path.relative_to(config.repo_path)
        canonical_path = legacy_path.with_name(config.canonical_name)
        click.echo(f"Processing {rel} -> {canonical_path.relative_to(config.repo_path)}")
        backup_file(legacy_path, graveyard, config.dry_run)

        if canonical_path.exists() and not config.dry_run:
            try:
                existing = canonical_path.read_bytes()
                legacy = legacy_path.read_bytes()
            except OSError as exc:  # pragma: no cover - filesystem errors
                raise ProjectManagerError(f"Failed to read files while comparing {rel}: {exc}") from exc
            if existing != legacy:
                click.echo(
                    f"Warning: canonical {canonical_path.relative_to(config.repo_path)} differs from legacy copy; keeping canonical."
                )
        promote_to_canonical(legacy_path, canonical_path, config.dry_run)


@click.group()
def cli() -> None:
    """Personal project maintenance helpers."""


@cli.group(name="llm:agents")
def llm_agents_group() -> None:
    """Manage LLM assistant documentation files."""


@llm_agents_group.command("sync")
@click.option(
    "repo",
    "repo_path",
    default=".",
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    help="Path to the git repository (default: current directory).",
)
@click.option(
    "--branch",
    default=None,
    help="Branch to checkout before syncing (requires clean worktree).",
)
@click.option(
    "--canonical",
    default=DEFAULT_CANONICAL_NAME,
    show_default=True,
    help="Canonical filename to retain.",
)
@click.option(
    "--legacy",
    "legacy_names",
    multiple=True,
    default=DEFAULT_LEGACY_NAMES,
    show_default=True,
    help="Legacy filenames to promote to the canonical name.",
)
@click.option("--dry-run", is_flag=True, help="Preview actions without modifying files.")
def sync_llm_agents(
    repo_path: Path,
    branch: str | None,
    canonical: str,
    legacy_names: tuple[str, ...],
    dry_run: bool,
) -> None:
    """Canonicalize legacy LLM assistant files within a repository."""

    repo = repo_path.expanduser().resolve()
    config = SyncConfig(
        repo_path=repo,
        canonical_name=canonical,
        legacy_names=list(dict.fromkeys(legacy_names)),
        branch=branch,
        dry_run=dry_run,
    )

    ensure_git_repo(config.repo_path)
    if config.branch:
        ensure_clean_worktree(config.repo_path)
        checkout_branch(config.repo_path, config.branch, config.dry_run)

    process_legacy_files(config)


def _escape_double_quotes(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _render_tmux_script(
    session_name: str,
    project_dir: Path,
    windows: List[TmuxWindow],
    ensure_python_venv: bool,
) -> str:
    project_dir_str = _escape_double_quotes(str(project_dir))
    lines: List[str] = [
        "#!/bin/zsh",
        "",
        f"SESSION_NAME=\"{session_name}\"",
        f"PROJECT_DIR=\"{project_dir_str}\"",
    ]

    if ensure_python_venv:
        lines.append('PYTHON_VENV="$PROJECT_DIR/.venv"')

    lines.extend(
        [
            "",
            "tmux has-session -t $SESSION_NAME 2>/dev/null",
            "",
            "if [ $? != 0 ]; then",
        ]
    )

    if ensure_python_venv:
        lines.extend(
            [
                "    if [ ! -d \"$PYTHON_VENV\" ]; then",
                "        echo \"Creating Python virtual environment at $PYTHON_VENV\"",
                "        python3 -m venv \"$PYTHON_VENV\"",
                "    fi",
                "",
            ]
        )

    lines.append('    tmux new-session -d -s $SESSION_NAME -n "main" -c "$PROJECT_DIR" /bin/zsh')

    for index, window in enumerate(windows, start=1):
        window_path = _escape_double_quotes(str(window.path))
        lines.append(
            f'    tmux new-window -t $SESSION_NAME:{index} -n "{window.name}" -c "{window_path}" /bin/zsh'
        )
        for command in window.commands:
            lines.append(f'    tmux send-keys -t $SESSION_NAME:{index} "{command}" C-m')
        if window.commands:
            lines.append("")

    if lines[-1] != "":
        lines.append("")

    lines.extend(["fi", "", "tmux attach -t $SESSION_NAME", ""])
    return "\n".join(lines)


def _write_script(path: Path, content: str, overwrite: bool) -> None:
    if path.exists() and not overwrite:
        raise ProjectManagerError(f"File already exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def _tmux_script_path(session_name: str) -> Path:
    return TMUX_DIR / f"start_{session_name}.sh"


def _prompt_tmux_windows(
    project_dir: Path,
    project_type: str | None,
) -> tuple[List[TmuxWindow], bool, str]:
    choices = ["data analysis", "laravel", "cli"]
    if project_type is None:
        detected_type = click.prompt(
            "Project type",
            type=click.Choice(choices, case_sensitive=False),
            default="cli",
        )
    else:
        detected_type = project_type
    detected_type = detected_type.lower()

    windows: List[TmuxWindow] = []
    include_claude = click.confirm("Include claude window?", default=True)
    include_codex = click.confirm("Include codex window?", default=True)
    include_zai = click.confirm("Include zai window?", default=True)

    if include_claude:
        windows.append(TmuxWindow(name="claude", path=project_dir, commands=["claude"]))
    if include_codex:
        windows.append(TmuxWindow(name="codex", path=project_dir, commands=["codex"]))
    if include_zai:
        windows.append(TmuxWindow(name="zai", path=project_dir, commands=["zai"]))

    ensure_python_venv = False

    if detected_type == "data analysis":
        use_r = click.confirm("Include R tooling?", default=True)
        use_python = click.confirm("Include Python tooling (create virtualenv)?", default=False)

        if use_r and click.confirm("Add R REPL window?", default=True):
            windows.append(TmuxWindow(name="r", path=project_dir, commands=["R"]))

        if use_python:
            ensure_python_venv = True
            if click.confirm("Add Python REPL window?", default=True):
                windows.append(
                    TmuxWindow(
                        name="python",
                        path=project_dir,
                        commands=['source "$PYTHON_VENV/bin/activate"', "python3"],
                    )
                )

    elif detected_type == "laravel":
        if click.confirm("Add Laravel Tinker window?", default=True):
            windows.append(TmuxWindow(name="tinker", path=project_dir, commands=["php artisan tinker"]))
        if click.confirm("Add Laravel Horizon window?", default=True):
            windows.append(TmuxWindow(name="horizon", path=project_dir, commands=["php artisan horizon"]))
        if click.confirm("Add npm dev window?", default=True):
            windows.append(TmuxWindow(name="npm", path=project_dir, commands=["npm run dev"]))

    return windows, ensure_python_venv, detected_type


@cli.group()
def tmux() -> None:
    """Manage tmux project scripts."""


@tmux.command("scaffold")
@click.option("--session", "session_name", default=None, help="Tmux session name (e.g. computing).")
@click.option(
    "--type",
    "project_type",
    type=click.Choice(["data analysis", "laravel", "cli"], case_sensitive=False),
    default=None,
    help="Project type to scaffold.",
)
@click.option("--project-dir", type=click.Path(path_type=Path), default=None, help="Root directory for the project.")
@click.option("--output", type=click.Path(path_type=Path), default=None, help="Custom output path for the script.")
@click.option("--force", is_flag=True, help="Overwrite existing script if present.")
def tmux_scaffold(
    session_name: str | None,
    project_type: str | None,
    project_dir: Path | None,
    output: Path | None,
    force: bool,
) -> None:
    """Interactively scaffold a tmux start script in the projects directory."""

    if session_name is None:
        session_name = click.prompt("Session name", type=str)
    session_name = session_name.strip()
    if not session_name:
        raise ProjectManagerError("Session name cannot be empty.")

    default_dir = project_dir or (Path.home() / "code" / session_name)
    project_dir = click.prompt(
        "Project directory",
        default=str(default_dir),
        type=click.Path(path_type=Path),
    )
    project_dir = project_dir.expanduser().resolve()

    windows, ensure_python_venv, _ = _prompt_tmux_windows(project_dir, project_type)

    script_path = output or _tmux_script_path(session_name)
    script_path = script_path.expanduser().resolve()

    content = _render_tmux_script(session_name, project_dir, windows, ensure_python_venv)
    _write_script(script_path, content, overwrite=force)

    click.echo(f"Created tmux script at {script_path}")


def _parse_project_dir(script_text: str) -> Path | None:
    for line in script_text.splitlines():
        if line.startswith("PROJECT_DIR="):
            value = line.split("=", 1)[1].strip().strip('"')
            expanded = os.path.expandvars(value)
            return Path(expanded).expanduser().resolve()
    return None


def _next_window_index(script_text: str) -> int:
    matches = list(re.finditer(r":(\d+)\b", script_text))
    indices = [int(match.group(1)) for match in matches]
    return (max(indices) + 1) if indices else 1


def _insert_before_final_fi(script_text: str, snippet: str) -> str:
    lines = script_text.splitlines()
    insert_at = None
    for idx, line in enumerate(lines):
        if line.strip() == "fi":
            if any("tmux attach" in rest for rest in lines[idx + 1 :]):
                insert_at = idx
    if insert_at is None:
        raise ProjectManagerError("Could not find insertion point in script.")
    new_lines = lines[:insert_at] + snippet.splitlines() + lines[insert_at:]
    return "\n".join(new_lines) + ("\n" if script_text.endswith("\n") else "")


@tmux.command("add-tab")
@click.option("--session", "session_name", required=True, help="Session name matching the script filename.")
@click.option("--name", "tab_name", required=True, help="Name for the new tmux window.")
@click.option("--path", "tab_path", type=click.Path(path_type=Path), default=None, help="Working directory for the tab.")
@click.option("--script", "script_path", type=click.Path(path_type=Path), default=None, help="Explicit path to the tmux start script.")
def tmux_add_tab(
    session_name: str,
    tab_name: str,
    tab_path: Path | None,
    script_path: Path | None,
) -> None:
    """Add an additional window to an existing tmux start script."""

    path = script_path.expanduser().resolve() if script_path else _tmux_script_path(session_name)
    if not path.exists():
        raise ProjectManagerError(f"Script not found: {path}")

    text = path.read_text(encoding="utf-8")
    project_dir = _parse_project_dir(text)
    if project_dir is None:
        raise ProjectManagerError("Could not determine PROJECT_DIR from script.")

    target_dir = (tab_path or project_dir).expanduser().resolve()
    next_index = _next_window_index(text)

    snippet_lines = [
        f'    tmux new-window -t $SESSION_NAME:{next_index} -n "{tab_name}" -c "{_escape_double_quotes(str(target_dir))}" /bin/zsh'
    ]
    snippet = "\n" + "\n".join(snippet_lines) + "\n"

    updated_text = _insert_before_final_fi(text, snippet)
    path.write_text(updated_text, encoding="utf-8")
    click.echo(f"Added window '{tab_name}' (index {next_index}) to {path}")


def _alias_token(session_name: str) -> str:
    token = session_name.replace("-", "_").replace(" ", "_")
    token = re.sub(r"[^A-Za-z0-9_]", "", token)
    if not token:
        token = "project"
    if token[0].isdigit():
        token = f"p{token}"
    return token


def _path_with_tilde(path: Path) -> str:
    try:
        relative = path.resolve().relative_to(Path.home())
        return f"~/{relative.as_posix()}"
    except ValueError:
        return str(path)


def _ensure_aliases_for_session(session_name: str, script_path: Path) -> None:
    alias_file = ALIASES_FILE
    alias_file.parent.mkdir(parents=True, exist_ok=True)
    if not alias_file.exists():
        alias_file.write_text("", encoding="utf-8")

    content = alias_file.read_text(encoding="utf-8")
    existing_lines = set(content.splitlines())

    token = _alias_token(session_name)
    script_alias = f'alias tm{token}="{_path_with_tilde(script_path)}"'
    attach_alias = f'alias tma{token}="tmux attach -t {session_name}"'

    additions = [line for line in (script_alias, attach_alias) if line not in existing_lines]
    if not additions:
        return

    with alias_file.open("a", encoding="utf-8") as handle:
        if content and not content.endswith("\n"):
            handle.write("\n")
        handle.write("\n".join(additions) + "\n")


@cli.command("new")
@click.argument("directory")
def new_project(directory: str) -> None:
    """Create a project skeleton under $HOME and scaffold tmux + aliases."""

    base_dir = click.prompt("Base directory under home", default="code")
    base_path = (Path.home() / base_dir).expanduser().resolve()

    relative_path = Path(directory)
    project_path = (base_path / relative_path).expanduser().resolve()
    project_path.mkdir(parents=True, exist_ok=True)

    is_empty = not any(project_path.iterdir())
    git_dir = project_path / ".git"
    if is_empty and not git_dir.exists():
        result = subprocess.run(
            ["git", "init"],
            cwd=str(project_path),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise ProjectManagerError(f"git init failed: {result.stderr.strip()}")
        click.echo(f"Initialized git repository in {project_path}")

    default_session = relative_path.name.replace("-", "_") or "project"
    session_name = click.prompt("Tmux session name", default=default_session).strip()
    if not session_name:
        raise ProjectManagerError("Tmux session name cannot be empty.")

    windows, ensure_python_venv, _ = _prompt_tmux_windows(project_path, None)
    script_path = _tmux_script_path(session_name).expanduser().resolve()

    overwrite = True
    if script_path.exists():
        overwrite = click.confirm(f"{script_path} exists. Overwrite?", default=False)
        if not overwrite:
            raise ProjectManagerError("Aborted: tmux script already exists.")

    content = _render_tmux_script(session_name, project_path, windows, ensure_python_venv)
    _write_script(script_path, content, overwrite=overwrite)
    click.echo(f"Created tmux script at {script_path}")

    _ensure_aliases_for_session(session_name, script_path)
    click.echo("Updated shell aliases for tmux session.")

    click.echo(f"Project directory ready at {project_path}")


def main() -> None:
    cli(prog_name="project-manager")


if __name__ == "__main__":
    main()
