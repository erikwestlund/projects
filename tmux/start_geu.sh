#!/bin/zsh

# Start GEU Support tmux session

SESSION_NAME="geu"
PROJECT_DIR="$HOME/code/geu-irr-support"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex window (window 2)
tmux new-window -t $SESSION_NAME:2 -n "codex" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex" C-m

# Create R console window (window 3)
tmux new-window -t $SESSION_NAME:3 -n "R" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "R" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME