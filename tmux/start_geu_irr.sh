#!/bin/zsh

# Start GEU IRR support tmux session with zsh, claude, and R

SESSION_NAME="geu-irr"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for zsh
    tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$HOME/code/geu-irr-support" /bin/zsh
    
    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/geu-irr-support" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m
    
    # Create window for R (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "R" -c "$HOME/code/geu-irr-support" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "R" C-m
    
    # Go back to claude window (window index 1)
    tmux select-window -t $SESSION_NAME:1
fi

# Attach to session
tmux attach-session -t $SESSION_NAME