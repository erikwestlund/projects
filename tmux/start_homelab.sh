#!/bin/zsh

# Start homelab infrastructure tmux session

SESSION_NAME="homelab"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window (0) named "homelab" in homelab directory
    tmux new-session -d -s $SESSION_NAME -n "homelab" -c "$HOME/code/homelab" /bin/zsh
    
    # Create second window (1) named "claude" and start claude
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/homelab" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m
    
    # Create third window (2) named "dotfiles" in dotfiles directory
    tmux new-window -t $SESSION_NAME:2 -n "dotfiles" -c "$HOME/code/dotfiles" /bin/zsh
    
    # Create fourth window (3) named "home-assistant" in home-assistant directory
    tmux new-window -t $SESSION_NAME:3 -n "home-assistant" -c "$HOME/code/home-assistant" /bin/zsh
    
    # Select first window
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME