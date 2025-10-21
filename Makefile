# ============================================================================
# Makefile for ~/code/projects management
# ============================================================================

.PHONY: help tasks

# Default target - show help
help:
	@echo "================================================================"
	@echo "~/code/projects - Available Commands"
	@echo "================================================================"
	@echo ""
	@echo "  make tasks     Generate VS Code tasks.json files for all tmux launchers"
	@echo "  make help      Show this help message"
	@echo ""
	@echo "Details:"
	@echo "  - tasks: Scans tmux/start_*.sh scripts and creates VS Code auto-run tasks"
	@echo "  - Output: vscode/tasks/*.tasks.json + .vscode/tasks.json in each project"
	@echo ""

# Generate VS Code tasks for all tmux launchers
tasks:
	@./tools/gen_tasks.sh
