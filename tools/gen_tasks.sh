#!/usr/bin/env zsh
# ============================================================================
# VS Code Tasks Generator for tmux Launchers
# ============================================================================
# Scans ~/code/projects/tmux/start_*.sh scripts and generates VS Code tasks.json
# files that auto-run the tmux launcher when the project folder opens.
#
# - Writes tasks to ~/code/projects/vscode/tasks/<key>.tasks.json
# - Copies to each project's .vscode/tasks.json
# - Adds .vscode/tasks.json to .git/info/exclude (local gitignore)
# - Idempotent: can be re-run safely
#
# Usage: ./tools/gen_tasks.sh
# ============================================================================

set -euo pipefail

# Configuration
CODE="${CODE:-$HOME/code}"
TMUX_DIR="$HOME/code/projects/tmux"
TASKS_DIR="$HOME/code/projects/vscode/tasks"
DIR_MAP_FILE="$HOME/code/projects/vscode/dir_map.sh"

# Source directory mapping if it exists
declare -A DIR_MAP
if [[ -f "$DIR_MAP_FILE" ]]; then
    source "$DIR_MAP_FILE"
fi

# Create tasks directory
mkdir -p "$TASKS_DIR"

# Track stats
processed=0
skipped=0
errors=0

echo "================================================================"
echo "VS Code Tasks Generator"
echo "================================================================"
echo ""

# Process each tmux launcher script
for script in "$TMUX_DIR"/start_*.sh; do
    # Skip if no scripts found
    [[ ! -f "$script" ]] && continue

    # Extract project key from filename
    filename="${script##*/}"
    key="${filename#start_}"
    key="${key%.sh}"

    # Determine project directory
    if [[ -n "${DIR_MAP[$key]:-}" ]]; then
        proj_dir="${DIR_MAP[$key]}"
    else
        proj_dir="$CODE/$key"
    fi

    # Check if project directory exists
    if [[ ! -d "$proj_dir" ]]; then
        echo "⚠️  SKIP: $key (directory not found: $proj_dir)"
        skipped=$((skipped + 1))
        continue
    fi

    # Check if project has a git repo
    if [[ ! -d "$proj_dir/.git" ]]; then
        echo "⚠️  SKIP: $key (not a git repository: $proj_dir)"
        skipped=$((skipped + 1))
        continue
    fi

    # Ensure .vscode directory exists
    mkdir -p "$proj_dir/.vscode"

    # Build tasks.json content
    tasks_json=$(cat <<EOF
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Run tmux launcher",
      "type": "shell",
      "command": "\${env:HOME}/code/projects/tmux/start_${key}.sh",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "focus": false
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ]
}
EOF
)

    # Write to tasks repository
    task_file="$TASKS_DIR/${key}.tasks.json"
    echo "$tasks_json" > "$task_file"

    # Copy to project's .vscode directory
    cp "$task_file" "$proj_dir/.vscode/tasks.json"

    # Add to .git/info/exclude if not already present
    exclude_file="$proj_dir/.git/info/exclude"
    exclude_entry=".vscode/tasks.json"

    # Create exclude file if it doesn't exist
    touch "$exclude_file"

    # Add entry if not already present (idempotent)
    if ! grep -Fxq "$exclude_entry" "$exclude_file" 2>/dev/null; then
        echo "$exclude_entry" >> "$exclude_file"
    fi

    # Also add to project's .gitignore (so it's never committed to app repos)
    gitignore_file="$proj_dir/.gitignore"
    if [[ -f "$gitignore_file" ]]; then
        # Add entry if not already present (idempotent)
        if ! grep -Fxq "$exclude_entry" "$gitignore_file" 2>/dev/null; then
            echo "" >> "$gitignore_file"
            echo "# Auto-generated VS Code tasks (managed by ~/code/projects/tools/gen_tasks.sh)" >> "$gitignore_file"
            echo "$exclude_entry" >> "$gitignore_file"
        fi
    fi

    echo "✅ $key → $proj_dir/.vscode/tasks.json"
    processed=$((processed + 1))
done

# Summary
echo ""
echo "================================================================"
echo "Summary"
echo "================================================================"
echo "Processed: $processed"
echo "Skipped:   $skipped"
echo "Errors:    $errors"
echo ""
echo "Task files written to: $TASKS_DIR"
echo ""
