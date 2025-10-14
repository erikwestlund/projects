#!/bin/zsh

# Start GEU IRR support tmux session with zsh, claude, and R

SESSION_NAME="geu-irr"
PROJECT_DIR="$HOME/code/geu-irr-support"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for zsh
    tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create window for codex (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "codex" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex" C-m

    # Create window for R (window index 3)
    tmux new-window -t $SESSION_NAME:3 -n "R" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "R" C-m

    # Go back to claude window (window index 1)
    tmux select-window -t $SESSION_NAME:1
fi

# Attach to session
tmux attach-session -t $SESSION_NAME