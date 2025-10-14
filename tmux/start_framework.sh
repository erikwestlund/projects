#!/bin/zsh

# Start Framework tmux session

SESSION_NAME="fw"
PROJECT_DIR="$HOME/code/framework"
PROJECT_SHELL_DIR="$HOME/code/framework-project"

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

# Create Zai window (window 3)
tmux new-window -t $SESSION_NAME:3 -n "zai" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "zai" C-m

# Create R console window (window 4)
tmux new-window -t $SESSION_NAME:4 -n "R" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "R" C-m

# Create framework project shell (window 5)
tmux new-window -t $SESSION_NAME:5 -n "fw-proj" -c "$PROJECT_SHELL_DIR" /bin/zsh

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME