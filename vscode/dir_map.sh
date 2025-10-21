#!/usr/bin/env bash
# ============================================================================
# Directory Mapping for VS Code Task Generator
# ============================================================================
# Maps project keys (derived from tmux script names) to actual directory paths
#
# Usage: This file is sourced by tools/gen_tasks.sh
#
# Format: DIR_MAP[key]="/absolute/path/to/project"
#
# Only add entries here when the default convention ($CODE/<key>) doesn't work
# Default: key "foo" maps to $HOME/code/foo
# ============================================================================

declare -A DIR_MAP=(
  # Tmux script uses underscores, directory uses hyphens/dots
  [better_shoes]="$HOME/code/better-shoes"
  [pequod_page]="$HOME/code/pequod.page"

  # a2omop and a2cps_to_omop both point to same project
  [a2omop]="$HOME/code/a2cps-ehr-to-omop"
  [a2cps_to_omop]="$HOME/code/a2cps-ehr-to-omop"

  # Add more mappings as needed
  # [example_key]="$HOME/code/example-project"
)
