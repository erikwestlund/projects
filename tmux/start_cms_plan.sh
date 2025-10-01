#!/bin/zsh

# Start CMS Plan tmux session

SESSION_NAME="cms-plan"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$HOME/code/cms-plan" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/cms-plan" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME
