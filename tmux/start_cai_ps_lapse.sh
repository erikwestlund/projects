#!/bin/zsh

SESSION="cai"
PROJECT_DIR="$HOME/code/cai-ps-lapse"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if session already exists
if tmux has-session -t $SESSION 2>/dev/null; then
    echo "Session '$SESSION' already exists. Attaching to it..."
    tmux attach -t $SESSION
    exit 0
fi

echo "═══════════════════════════════════════════"
echo "CAI PS Lapse Tmux Session Manager"
echo "═══════════════════════════════════════════"
echo ""

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "${RED}✗${NC} Project directory not found: $PROJECT_DIR"
    echo "Please ensure the project exists at the specified location."
    exit 1
fi

echo "Creating tmux session '$SESSION'..."
echo ""

# Start tmux with zsh window (this becomes window 0)
tmux new-session -d -s $SESSION -n zsh -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:zsh" "cd \"$PROJECT_DIR\"" C-m
tmux send-keys -t "${SESSION}:zsh" "clear" C-m

# Create Claude window
tmux new-window -t $SESSION -n claude -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:claude" "cd \"$PROJECT_DIR\"" C-m
tmux send-keys -t "${SESSION}:claude" "claude" C-m

# Create R window
tmux new-window -t $SESSION -n R -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:R" "cd \"$PROJECT_DIR\"" C-m
tmux send-keys -t "${SESSION}:R" "R" C-m

# Re-select zsh window
tmux select-window -t "${SESSION}:zsh"

# Print success summary
echo "═══════════════════════════════════════════"
echo "${GREEN}✓ Tmux session created successfully!${NC}"
echo "═══════════════════════════════════════════"
echo ""
echo "Tmux windows created:"
echo "  • zsh    : Shell (window 0)"
echo "  • claude : Claude CLI (window 1)"
echo "  • R      : R console (window 2)"
echo ""
echo "Useful tmux commands:"
echo "  • Switch windows: Ctrl-b [0-2]"
echo "  • Next window: Ctrl-b n"
echo "  • Previous window: Ctrl-b p"
echo "  • Detach: Ctrl-b d"
echo ""
echo "Attaching to session '$SESSION'..."
echo "═══════════════════════════════════════════"
echo ""

# Attach to session
tmux attach -t $SESSION