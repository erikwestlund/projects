#!/bin/zsh

# Start Pequod Page development tmux session

SESSION_NAME="pequod-page"
PROJECT_DIR="$HOME/code/pequod.page"

# Kill existing session if it exists and wait for cleanup
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Start tmux with shell window (index 0)
tmux new-session -d -s $SESSION_NAME -n zsh -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Tinker window (index 2)
tmux new-window -t $SESSION_NAME:2 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "php artisan tinker" C-m

# Create Horizon window (index 3)
tmux new-window -t $SESSION_NAME:3 -n horizon -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "php artisan horizon" C-m

# Re-select shell window and attach
tmux select-window -t $SESSION_NAME:0
tmux attach-session -t $SESSION_NAME
