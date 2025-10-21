#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--repo PATH] [--dry-run] [--help]

Synchronize LLM assistant context files so that the chosen canonical tool
remains the single source of truth. Non-canonical files receive a generated
warning header and copy of the canonical content. Backups of overwritten files
are stored under ~/.local/share/project-manager/llm-graveyard/.
USAGE
}

REPO="$(pwd)"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo)
      REPO="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$REPO" ]]; then
  echo "Repository directory not found: $REPO" >&2
  exit 1
fi

REPO="$(cd "$REPO" && pwd)"
CONFIG_FILE="$REPO/.canonical-llm-context"
TOOLS=("claude" "codex" "copilot")
EXTRA_FILES=("AGENTS.md")

file_for_tool() {
  case "$1" in
    claude) echo "CLAUDE.md" ;;
    codex) echo "CODEX.md" ;;
    copilot) echo "COPILOT.md" ;;
    *) return 1 ;;
  esac
}

slug_repo() {
  local path="$1"
  path="${path#/}"
  path="${path//\//-}"
  path=$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')
  path=$(printf '%s' "$path" | sed 's/[^a-z0-9-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')
  [[ -z "$path" ]] && path="repo"
  printf '%s' "$path"
}

relative_path() {
  local abs="$1"
  if [[ "$abs" == "$REPO" ]]; then
    printf '.'
    return
  fi
  local rel="${abs#$REPO/}"
  printf '%s' "$rel"
}

prompt_canonical() {
  local choice
  echo "Select canonical LLM context:" >&2
  select choice in "${TOOLS[@]}"; do
    if [[ -n "$choice" ]]; then
      printf '%s' "$choice"
      return 0
    fi
  done
  return 1
}

canonical_tool=""
if [[ -f "$CONFIG_FILE" ]]; then
  canonical_tool=$(tr '[:upper:]' '[:lower:]' < "$CONFIG_FILE" | tr -d ' \t\r')
fi

is_valid=0
for tool in "${TOOLS[@]}"; do
  if [[ "$canonical_tool" == "$tool" ]]; then
    is_valid=1
    break
  fi
done

if [[ $is_valid -ne 1 ]]; then
  canonical_tool=""
fi

if [[ -z "$canonical_tool" ]]; then
  if [[ -t 0 ]]; then
    canonical_tool=$(prompt_canonical) || exit 1
    echo "Selected canonical context: $canonical_tool"
    printf '%s\n' "$canonical_tool" > "$CONFIG_FILE"
    echo "SYNCED_FILE: $(relative_path "$CONFIG_FILE")"
  else
    echo "Error: canonical context not configured. Run llm-sync interactively first." >&2
    exit 1
  fi
else
  stored=$(tr '[:upper:]' '[:lower:]' < "$CONFIG_FILE" | tr -d ' \t\r')
  if [[ "$stored" != "$canonical_tool" ]]; then
    printf '%s\n' "$canonical_tool" > "$CONFIG_FILE"
    echo "SYNCED_FILE: $(relative_path "$CONFIG_FILE")"
  fi
fi

canonical_file=$(file_for_tool "$canonical_tool" || echo "")
if [[ -z "$canonical_file" ]]; then
  echo "Unsupported canonical tool: $canonical_tool" >&2
  exit 1
fi

canonical_path="$REPO/$canonical_file"
if [[ ! -f "$canonical_path" ]]; then
  echo "Canonical file not found: $canonical_file" >&2
  exit 1
fi

GRAVEYARD_ROOT="${LLM_GRAVEYARD_ROOT:-$HOME/.local/share/project-manager/llm-graveyard}"
GRAVEYARD_DIR="$GRAVEYARD_ROOT/$(slug_repo "$REPO")"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[DRY-RUN] Would ensure graveyard directory $GRAVEYARD_DIR"
else
  mkdir -p "$GRAVEYARD_DIR"
fi

timestamp=$(date -u "+%Y-%m-%d %H:%M:%SZ")
timestamp_slug=$(date -u "+%Y%m%dT%H%M%SZ")
warning="<!-- DO NOT EDIT. Generated from ${canonical_file} on ${timestamp} -->"

remove_generated_header() {
  local file="$1"
  local rel="$(relative_path "$file")"
  if [[ ! -f "$file" ]]; then
    return
  fi
  local first_line
  IFS= read -r first_line < "$file" || true
  if [[ "$first_line" == "<!-- DO NOT EDIT."* ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY-RUN] Would remove generated header from $rel"
      return
    fi
    local tmp
    tmp=$(mktemp)
    tail -n +2 "$file" > "$tmp" || true
    if [[ -s "$tmp" ]]; then
      IFS= read -r maybe_blank < "$tmp" || true
      if [[ -z "$maybe_blank" ]]; then
        tail -n +2 "$tmp" > "$tmp.strip" || true
        if [[ -s "$tmp.strip" ]]; then
          mv "$tmp.strip" "$tmp"
        else
          : > "$tmp"
        fi
      fi
    fi
    mv "$tmp" "$file"
    echo "SYNCED_FILE: $rel"
  fi
}

backup_alias_file() {
  local src="$1"
  [[ ! -f "$src" ]] && return
  local rel="$(relative_path "$src")"
  local base="${rel##*/}"
  local ext="${base##*.}"
  local slug=$(printf '%s' "$rel" | tr '[:upper:]' '[:lower:]')
  slug=$(printf '%s' "$slug" | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')
  [[ -z "$slug" ]] && slug="file"
  local dest="$GRAVEYARD_DIR/${slug}-${timestamp_slug}"
  if [[ "$ext" != "$base" ]]; then
    dest="${dest}.${ext}"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] Would backup $rel to $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  fi
}

relative_targets=()
for tool in "${TOOLS[@]}"; do
  file=$(file_for_tool "$tool") || continue
  relative_targets+=("$file")
done
relative_targets+=("${EXTRA_FILES[@]}")

clean_targets=()
for file in "${relative_targets[@]}"; do
  [[ -z "$file" ]] && continue
  duplicate=0
  for existing in "${clean_targets[@]}"; do
    if [[ "$existing" == "$file" ]]; then
      duplicate=1
      break
    fi
  done
  [[ $duplicate -eq 1 ]] && continue
  clean_targets+=("$file")
done

remove_generated_header "$canonical_path"
canonical_content=$(cat "$canonical_path")

for target in "${clean_targets[@]}"; do
  if [[ "$target" == "$canonical_file" ]]; then
    continue
  fi
  target_path="$REPO/$target"
  target_rel="$(relative_path "$target_path")"
  tmp=$(mktemp)
  {
    printf '%s\n\n' "$warning"
    printf '%s\n' "$canonical_content"
  } > "$tmp"

  if [[ -f "$target_path" ]]; then
    if cmp -s "$tmp" "$target_path"; then
      rm -f "$tmp"
      continue
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] Would update $target_rel"
    rm -f "$tmp"
  else
    if [[ -f "$target_path" ]]; then
      backup_alias_file "$target_path"
    fi
    mkdir -p "$(dirname "$target_path")"
    mv "$tmp" "$target_path"
    echo "SYNCED_FILE: $target_rel"
  fi
done

exit 0
