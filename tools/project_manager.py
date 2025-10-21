#!/usr/bin/env python3
"""Project Manager CLI for personal repository maintenance tasks."""
from __future__ import annotations

import json
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

DEFAULT_CANONICAL_NAME = "AGENTS.md"
DEFAULT_ALIAS_NAMES = ("CLAUDE.md", "CODEX.md", "COPILOT.md", "GEMINI.md", "AGENTS.md")
GRAVEYARD_DIRNAME = ".llm-graveyard"
DEFAULT_GRAVEYARD_ROOT = Path.home() / ".local" / "share" / "project-manager" / "llm-graveyard"
TMUX_DIR = Path.home() / "code" / "projects" / "tmux"
ALIASES_FILE = Path.home() / "code" / "dotfiles" / "config" / ".aliases"
CONFIG_PATH = Path.home() / ".config" / "project-manager" / "settings.json"
LLM_SYNC_SCRIPT = Path(__file__).resolve().parent / "llm-sync.sh"
HOOK_SIGNATURE = "# llm-sync hook installed by project-manager"


class ProjectManagerError(click.ClickException):
    """Raised when a CLI operation encounters an unrecoverable error."""

    def __init__(self, message: str) -> None:
        super().__init__(message)


@dataclass
class SyncConfig:
    repo_path: Path
    canonical_name: str
    alias_names: List[str]
    branch: str | None
    dry_run: bool
    graveyard_path: Path


@dataclass
class TmuxWindow:
    name: str
    path: Path
    commands: List[str]


def _load_settings() -> dict:
    if not CONFIG_PATH.exists():
        return {}
    try:
        with CONFIG_PATH.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}


def _save_settings(settings: dict) -> None:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CONFIG_PATH.open("w", encoding="utf-8") as handle:
        json.dump(settings, handle, indent=2, sort_keys=True)


def _llm_settings() -> dict:
    settings = _load_settings()
    llm_settings = settings.setdefault("llm_agents", {})
    return settings, llm_settings


def _slugify_path(path: Path) -> str:
    normalized = path.expanduser().resolve()
    parts = [p for p in normalized.parts if p not in {"", os.sep}]
    slug = "-".join(
        re.sub(r"[^A-Za-z0-9]+", "-", part).strip("-").lower() or "segment"
        for part in parts
    )
    return slug or "repo"


def _ensure_llm_sync_script() -> Path:
    script_path = LLM_SYNC_SCRIPT.resolve()
    if not script_path.exists():
        raise ProjectManagerError(f"llm-sync script not found at {script_path}")
    if not os.access(script_path, os.X_OK):
        raise ProjectManagerError(
            f"llm-sync script is not executable: {script_path}"
        )
    return script_path


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


def ensure_graveyard(path: Path, dry_run: bool) -> Path:
    if dry_run:
        click.echo(f"[DRY-RUN] Would ensure graveyard directory {path}")
    else:
        path.mkdir(parents=True, exist_ok=True)
    return path


def ensure_gitignore(repo: Path, graveyard: Path, dry_run: bool) -> None:
    try:
        relative_path = graveyard.relative_to(repo)
    except ValueError:
        return

    gitignore = repo / ".gitignore"
    entry = f"{relative_path.as_posix()}/"
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


def _gather_named_files(repo: Path, names: Iterable[str]) -> List[Path]:
    matches: List[Path] = []
    unique_names = list(dict.fromkeys(names))
    for name in unique_names:
        for path in repo.rglob(name):
            if path.is_dir():
                continue
            rel_parts = path.relative_to(repo).parts
            if any(part in {".git", GRAVEYARD_DIRNAME} for part in rel_parts):
                continue
            matches.append(path)
    return matches


def gather_alias_files(repo: Path, alias_names: Iterable[str]) -> List[Path]:
    return _gather_named_files(repo, alias_names)


def gather_canonical_files(repo: Path, canonical_name: str) -> List[Path]:
    return _gather_named_files(repo, [canonical_name])


def backup_file(src: Path, graveyard: Path, repo_path: Path, dry_run: bool) -> Path:
    rel = src.relative_to(repo_path)
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
            click.echo(f"[DRY-RUN] Would remove alternate file {src} (canonical already present)")
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


def _ensure_alias_symlink(
    alias_path: Path,
    canonical_path: Path,
    graveyard: Path,
    config: SyncConfig,
) -> int:
    if alias_path == canonical_path or not canonical_path.exists():
        return 0

    rel_alias = alias_path.relative_to(config.repo_path)
    rel_canonical = canonical_path.relative_to(config.repo_path)
    desired_target = os.path.relpath(canonical_path, alias_path.parent)

    performed = 0

    if alias_path.exists() or alias_path.is_symlink():
        if alias_path.is_symlink():
            current_target = alias_path.resolve(strict=False)
            if current_target.exists() and current_target.resolve() == canonical_path.resolve():
                return 0
            if config.dry_run:
                click.echo(f"[DRY-RUN] Would update symlink {rel_alias} -> {rel_canonical}")
            else:
                alias_path.unlink()
            performed += 1
        else:
            backup_file(alias_path, graveyard, config.repo_path, config.dry_run)
            if config.dry_run:
                click.echo(f"[DRY-RUN] Would replace {rel_alias} with symlink to {rel_canonical}")
            else:
                alias_path.unlink()
            performed += 1

    if config.dry_run:
        click.echo(f"[DRY-RUN] Would create symlink {rel_alias} -> {rel_canonical}")
    else:
        alias_path.symlink_to(desired_target)
    performed += 1
    return performed


def _ensure_canonical_is_regular(canonical_path: Path, config: SyncConfig) -> int:
    if not canonical_path.exists() or not canonical_path.is_symlink():
        return 0

    rel_canonical = canonical_path.relative_to(config.repo_path)
    if config.dry_run:
        click.echo(f"[DRY-RUN] Would replace symlink canonical {rel_canonical} with regular file")
        return 1

    data = canonical_path.read_bytes()
    canonical_path.unlink()
    canonical_path.write_bytes(data)
    return 1


def process_alias_files(config: SyncConfig) -> int:
    graveyard = ensure_graveyard(config.graveyard_path, config.dry_run)
    ensure_gitignore(config.repo_path, graveyard, config.dry_run)

    alias_files = gather_alias_files(config.repo_path, config.alias_names)
    canonical_files = gather_canonical_files(config.repo_path, config.canonical_name)
    canonical_set = {path for path in canonical_files}

    processed = 0

    for canonical_path in list(canonical_set):
        processed += _ensure_canonical_is_regular(canonical_path, config)

    for alias_path in alias_files:
        canonical_path = alias_path.with_name(config.canonical_name)
        if not alias_path.exists() or alias_path.is_symlink():
            continue
        if canonical_path.exists():
            continue

        rel_alias = alias_path.relative_to(config.repo_path)
        rel_canonical = canonical_path.relative_to(config.repo_path)
        backup_file(alias_path, graveyard, config.repo_path, config.dry_run)
        if config.dry_run:
            click.echo(f"[DRY-RUN] Would promote {rel_alias} -> {rel_canonical}")
        else:
            canonical_path.parent.mkdir(parents=True, exist_ok=True)
            alias_path.rename(canonical_path)
        canonical_set.add(canonical_path)
        processed += 1

    canonical_set.update(
        path for path in gather_canonical_files(config.repo_path, config.canonical_name)
    )

    for canonical_path in list(canonical_set):
        processed += _ensure_canonical_is_regular(canonical_path, config)

    if not canonical_set and not alias_files:
        click.echo("No canonical or alternate assistant files found. Nothing to do.")
        return processed

    unique_alias_names = list(dict.fromkeys(config.alias_names))

    for canonical_path in canonical_set:
        if not canonical_path.exists():
            continue
        for alias_name in unique_alias_names:
            if alias_name == config.canonical_name:
                continue
            alias_path = canonical_path.with_name(alias_name)
            processed += _ensure_alias_symlink(alias_path, canonical_path, graveyard, config)

    return processed

@click.group()
def cli() -> None:
    """Personal project maintenance helpers."""


@cli.group(name="llm:agents")
def llm_agents_group() -> None:
    """Manage LLM assistant documentation files."""


@llm_agents_group.command("sync")
@click.option(
    "--repo",
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
    default=None,
    help="Canonical filename to retain (defaults to stored preference).",
)
@click.option(
    "--alias",
    "alias_names",
    multiple=True,
    help="Alternate filenames to promote to the canonical name (repeat option).",
)
@click.option("--dry-run", is_flag=True, help="Preview actions without modifying files.")
def sync_llm_agents(
    repo_path: Path,
    branch: str | None,
    canonical: str,
    alias_names: tuple[str, ...],
    dry_run: bool,
) -> None:
    """Canonicalize assistant documentation files within a repository."""

    settings, llm_settings = _llm_settings()
    effective_canonical = canonical or llm_settings.get("canonical", DEFAULT_CANONICAL_NAME)
    if alias_names:
        effective_aliases = list(dict.fromkeys(alias_names))
    else:
        stored_aliases = llm_settings.get("aliases")
        if stored_aliases is None:
            stored_aliases = llm_settings.get("legacy")
        effective_aliases = list(stored_aliases) if stored_aliases else list(DEFAULT_ALIAS_NAMES)

    effective_aliases = [name for name in effective_aliases if name != effective_canonical]
    if "AGENTS.md" not in effective_aliases and effective_canonical != "AGENTS.md":
        effective_aliases.append("AGENTS.md")

    repo = repo_path.expanduser().resolve()
    graveyard_root = Path(
        llm_settings.get("graveyard_root", str(DEFAULT_GRAVEYARD_ROOT))
    ).expanduser()
    graveyard_path = graveyard_root / _slugify_path(repo)

    base_config = SyncConfig(
        repo_path=repo,
        canonical_name=effective_canonical,
        alias_names=effective_aliases,
        branch=branch,
        dry_run=dry_run,
        graveyard_path=graveyard_path,
    )

    ensure_git_repo(base_config.repo_path)
    if base_config.branch:
        ensure_clean_worktree(base_config.repo_path)
        checkout_branch(base_config.repo_path, base_config.branch, dry_run)

    if dry_run:
        process_alias_files(base_config)
        return

    preview_config = SyncConfig(
        repo_path=base_config.repo_path,
        canonical_name=base_config.canonical_name,
        alias_names=base_config.alias_names,
        branch=base_config.branch,
        dry_run=True,
        graveyard_path=base_config.graveyard_path,
    )
    click.echo("Preview (no changes made):")
    preview_count = process_alias_files(preview_config)
    if preview_count == 0:
        return

    if not click.confirm("Apply these changes?", default=True):
        click.echo("Aborted without making changes.")
        return

    apply_config = SyncConfig(
        repo_path=base_config.repo_path,
        canonical_name=base_config.canonical_name,
        alias_names=base_config.alias_names,
        branch=base_config.branch,
        dry_run=False,
        graveyard_path=base_config.graveyard_path,
    )
    click.echo("Applying changes...")
    process_alias_files(apply_config)


@llm_agents_group.command("install-hook")
@click.option(
    "--repo",
    "repo_path",
    default=".",
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    help="Repository where the hook should be installed.",
)
@click.option("--force", is_flag=True, help="Overwrite an existing pre-commit hook.")
def install_llm_hook(repo_path: Path, force: bool) -> None:
    """Install a pre-commit hook that runs llm-sync.sh before commits."""

    repo = repo_path.expanduser().resolve()
    ensure_git_repo(repo)
    git_dir = repo / ".git"
    if not git_dir.exists():
        raise ProjectManagerError(
            f"{repo} does not appear to be a git repository (missing .git directory)"
        )

    hooks_dir = git_dir / "hooks"
    hook_path = hooks_dir / "pre-commit"
    hooks_dir.mkdir(parents=True, exist_ok=True)

    script_path = _ensure_llm_sync_script()

    if hook_path.exists():
        existing = hook_path.read_text(encoding="utf-8")
        if HOOK_SIGNATURE not in existing and not force:
            raise ProjectManagerError(
                "A pre-commit hook already exists and was not installed by project-manager. "
                "Use --force to overwrite it."
            )

    hook_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        HOOK_SIGNATURE,
        f'SCRIPT_PATH="{script_path}"',
        'REPO_ROOT="$(git rev-parse --show-toplevel)"',
        'if [ ! -x "$SCRIPT_PATH" ]; then',
        '  echo "llm-sync: missing script at $SCRIPT_PATH" >&2',
        '  exit 1',
        'fi',
        'output="$("$SCRIPT_PATH" --repo "$REPO_ROOT")"',
        'status=$?',
        'printf "%s\n" "$output"',
        'if [ $status -ne 0 ]; then',
        '  exit $status',
        'fi',
        'while IFS= read -r line; do',
        '  case "$line" in',
        '    "SYNCED_FILE:"*)',
        '      file="${line#SYNCED_FILE: }"',
        '      if [ -n "$file" ]; then',
        '        git -C "$REPO_ROOT" add "$file"',
        '      fi',
        '      ;;',
        '  esac',
        'done <<< "$output"',
        "",
    ]
    hook_path.write_text("\n".join(hook_lines) + "\n", encoding="utf-8")
    hook_path.chmod(0o755)
    click.echo(f"Installed pre-commit hook at {hook_path}")




@llm_agents_group.command("remove-hook")
@click.option(
    "--repo",
    "repo_path",
    default=".",
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    help="Repository where the hook should be removed.",
)
@click.option("--force", is_flag=True, help="Remove the hook even if it was not installed by project-manager.")
def remove_llm_hook(repo_path: Path, force: bool) -> None:
    """Remove the llm-sync pre-commit hook if present."""

    repo = repo_path.expanduser().resolve()
    ensure_git_repo(repo)
    hooks_dir = repo / ".git" / "hooks"
    hook_path = hooks_dir / "pre-commit"

    if not hook_path.exists():
        click.echo("No pre-commit hook found; nothing to remove.")
        return

    content = hook_path.read_text(encoding="utf-8")
    if HOOK_SIGNATURE not in content and not force:
        raise ProjectManagerError(
            "Existing pre-commit hook was not installed by project-manager. Use --force to remove it."
        )

    hook_path.unlink()
    click.echo(f"Removed pre-commit hook at {hook_path}")


@llm_agents_group.command("configure")
@click.option(
    "--canonical",
    default=None,
    help="Set the canonical filename to use by default.",
)
@click.option(
    "--alias",
    "alias_names",
    multiple=True,
    help="Set alternate filenames (repeat option).",
)
@click.option(
    "--graveyard",
    "graveyard_root",
    type=click.Path(path_type=Path),
    help="Set backup directory root (default stored globally).",
)
@click.option("--show", is_flag=True, help="Display current settings without modifying them.")
def configure_llm_agents(
    canonical: str | None,
    alias_names: tuple[str, ...],
    graveyard_root: Path | None,
    show: bool,
) -> None:
    """Persist LLM file preferences used by sync across repositories."""

    settings, llm_settings = _llm_settings()

    current_graveyard_root = Path(
        llm_settings.get("graveyard_root", str(DEFAULT_GRAVEYARD_ROOT))
    ).expanduser()

    current_canonical = llm_settings.get("canonical", DEFAULT_CANONICAL_NAME)
    current_aliases = llm_settings.get("aliases")
    if current_aliases is None:
        legacy_aliases = llm_settings.get("legacy")
        current_aliases = list(legacy_aliases) if legacy_aliases else list(DEFAULT_ALIAS_NAMES)

    if graveyard_root is not None:
        graveyard_root = graveyard_root.expanduser()

    if show:
        click.echo("Current LLM settings:")
        click.echo(f"  canonical: {current_canonical}")
        click.echo(f"  aliases  : {', '.join(current_aliases)}")
        click.echo(f"  graveyard: {current_graveyard_root}")
        return

    if canonical is None and not alias_names and graveyard_root is None:
        click.echo("Current LLM settings:")
        click.echo(f"  canonical: {current_canonical}")
        click.echo(f"  aliases  : {', '.join(current_aliases)}")
        click.echo(f"  graveyard: {current_graveyard_root}")

        choices = list(dict.fromkeys([current_canonical, *current_aliases]))
        if not choices:
            choices = [current_canonical]

        canonical = click.prompt(
            "Choose canonical filename",
            default=current_canonical,
        ).strip() or current_canonical

        default_aliases = [name for name in choices if name != canonical]
        alias_input = click.prompt(
            "Alternate filenames (comma-separated)",
            default=", ".join(default_aliases),
        ).strip()
        alias_names = tuple(
            part.strip()
            for part in alias_input.split(",")
            if part.strip()
        )
        if not alias_names and default_aliases:
            alias_names = tuple(default_aliases)

        prompt_graveyard = click.prompt(
            "Backup storage directory",
            default=str(current_graveyard_root),
        ).strip()
        graveyard_root = Path(prompt_graveyard).expanduser() if prompt_graveyard else current_graveyard_root

    if graveyard_root is None:
        graveyard_root = current_graveyard_root

    updated = False
    if canonical:
        llm_settings["canonical"] = canonical
        updated = True
    if alias_names:
        llm_settings["aliases"] = list(dict.fromkeys(alias_names))
        llm_settings.pop("legacy", None)
        updated = True

    if graveyard_root != current_graveyard_root:
        llm_settings["graveyard_root"] = str(graveyard_root)
        updated = True

    if not updated:
        click.echo("No changes provided. Use --canonical and/or --alias to update settings.")
        return

    _save_settings(settings)
    click.echo("Preferences saved. Future syncs will use these defaults.")


def _escape_double_quotes(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _render_tmux_script(
    session_name: str,
    project_dir: Path,
    windows: List[TmuxWindow],
    ensure_python_venv: bool,
) -> str:
    project_dir_str = _escape_double_quotes(_homeify_path(project_dir))
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
        window_path = _escape_double_quotes(_homeify_path(window.path))
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
    choices = ["data", "laravel", "cli"]
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

    if detected_type == "data":
        use_r = click.confirm("Include R tooling?", default=True)
        use_python = click.confirm("Include Python tooling (create virtualenv)?", default=False)

        if use_r and click.confirm("Add R REPL window?", default=True):
            windows.append(TmuxWindow(name="R", path=project_dir, commands=["R"]))

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
    type=click.Choice(["data", "laravel", "cli"], case_sensitive=False),
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

    default_dir = project_dir or Path.cwd()
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

    token = _alias_token(session_name)
    alias_added = _ensure_aliases_for_session(session_name, script_path)
    if alias_added:
        click.echo(
            f"Registered aliases tm{token} and tma{token} in {ALIASES_FILE}"
        )
        click.echo(
            "Reminder: reload your shell (e.g. run your dotfiles bootstrap) so the new aliases are available."
        )
    else:
        click.echo(
            f"Aliases tm{token} and tma{token} already present in {ALIASES_FILE}"
        )


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
        f'    tmux new-window -t $SESSION_NAME:{next_index} -n "{tab_name}" -c "{_escape_double_quotes(_homeify_path(target_dir))}" /bin/zsh'
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


def _homeify_path(path: Path) -> str:
    home = Path.home().resolve()
    try:
        relative = path.resolve().relative_to(home)
        return f"$HOME/{relative.as_posix()}"
    except ValueError:
        return str(path)


def _path_with_tilde(path: Path) -> str:
    return _homeify_path(path)


def _ensure_aliases_for_session(session_name: str, script_path: Path) -> bool:
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
        return False

    with alias_file.open("a", encoding="utf-8") as handle:
        if content and not content.endswith("\n"):
            handle.write("\n")
        handle.write("\n".join(additions) + "\n")
    return True


@cli.command("new")
@click.argument("directory")
@click.option("--dry-run", is_flag=True, help="Preview actions without applying changes.")
def new_project(directory: str, dry_run: bool) -> None:
    """Create a project skeleton under $HOME and scaffold tmux + aliases."""

    base_dir = click.prompt("Base directory under home", default="code")
    base_path = (Path.home() / base_dir).expanduser().resolve()

    relative_path = Path(directory)
    project_path = (base_path / relative_path).expanduser().resolve()
    click.echo(f"Project directory: {project_path}")
    if dry_run:
        click.echo("[DRY-RUN] Would create project directory if missing")
    else:
        project_path.mkdir(parents=True, exist_ok=True)

    is_empty = not any(project_path.iterdir())
    git_dir = project_path / ".git"
    if is_empty and not git_dir.exists():
        click.echo("[INFO] Directory empty; eligible for git init")
        result = subprocess.run(
            ["git", "init"],
            cwd=str(project_path),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if dry_run:
            click.echo("[DRY-RUN] Would run git init")
        else:
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
        if dry_run:
            click.echo(f"[DRY-RUN] Would {'overwrite' if overwrite else 'skip overwriting'} existing script")
            if not overwrite:
                return
        elif not overwrite:
            raise ProjectManagerError("Aborted: tmux script already exists.")

    content = _render_tmux_script(session_name, project_path, windows, ensure_python_venv)
    if dry_run:
        click.echo(f"[DRY-RUN] Would write tmux script to {script_path}")
    else:
        _write_script(script_path, content, overwrite=overwrite)
        click.echo(f"Created tmux script at {script_path}")

    if dry_run:
        click.echo("[DRY-RUN] Would update shell aliases")
    else:
        token = _alias_token(session_name)
        alias_added = _ensure_aliases_for_session(session_name, script_path)
        if alias_added:
            click.echo(
                f"Registered aliases tm{token} and tma{token} in {ALIASES_FILE}"
            )
            click.echo(
                "Reminder: reload your shell (e.g. run your dotfiles bootstrap) so the new aliases are available."
            )
        else:
            click.echo(
                f"Aliases tm{token} and tma{token} already present in {ALIASES_FILE}"
            )

    if dry_run:
        click.echo("Dry-run complete. Re-run without --dry-run to apply changes.")
    else:
        click.echo(f"Project directory ready at {project_path}")


@cli.command("workspace")
@click.option(
    "--name",
    default=None,
    help="Workspace filename stem (defaults to current directory name).",
)
@click.option(
    "--projects-root",
    default=str(Path.home() / "code" / "projects"),
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    help="Directory where workspace files live (defaults to ~/code/projects).",
)
@click.option(
    "--folder",
    "folders",
    multiple=True,
    type=click.Path(path_type=Path),
    help="Additional folders to include (repeatable). Defaults to current directory.",
)
@click.option("--force", is_flag=True, help="Overwrite existing workspace file if present.")
def scaffold_workspace(
    name: str | None,
    projects_root: Path,
    folders: tuple[Path, ...],
    force: bool,
) -> None:
    """Generate a VS Code / Positron workspace file under the projects directory."""

    root = projects_root.expanduser().resolve()
    if name is None:
        name = Path.cwd().stem
    name = name.strip()
    if not name:
        raise ProjectManagerError("Workspace name cannot be empty.")

    workspace_path = root / f"{name}.code-workspace"
    if workspace_path.exists() and not force:
        raise ProjectManagerError(
            f"Workspace file already exists at {workspace_path}. Use --force to overwrite."
        )

    if folders:
        folder_paths = [path.expanduser().resolve() for path in folders]
    else:
        folder_paths = [Path.cwd().resolve()]

    def relative_to_workspace(path: Path) -> str:
        rel = os.path.relpath(path, start=workspace_path.parent)
        return Path(rel).as_posix()

    folder_entries = [
        {"path": relative_to_workspace(folder_path)} for folder_path in folder_paths
    ]

    payload = {
        "folders": folder_entries,
        "settings": {},
    }

    workspace_path.parent.mkdir(parents=True, exist_ok=True)
    with workspace_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")

    click.echo(f"Created workspace at {workspace_path}")
    click.echo("Folders:")
    for entry in folder_entries:
        click.echo(f"  - {entry['path']}")


def main() -> None:
    cli(prog_name="project-manager")


if __name__ == "__main__":
    main()
