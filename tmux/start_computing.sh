#!/bin/zsh

# Start computing workspace tmux session with claude and all infrastructure projects

SESSION_NAME="computing"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for projects directory
    tmux new-session -d -s $SESSION_NAME -n "projects" -c "/Users/erikwestlund/code/projects" /bin/zsh
    
    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "/Users/erikwestlund/code/projects" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m
    
    # Create window for dotfiles (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "dotfiles" -c "/Users/erikwestlund/code/dotfiles" /bin/zsh
    
    # Create window for ha (window index 3)
    tmux new-window -t $SESSION_NAME:3 -n "ha" -c "/Users/erikwestlund/code/home-assistant" /bin/zsh
    
    # Create window for homelab (window index 4)
    tmux new-window -t $SESSION_NAME:4 -n "homelab" -c "/Users/erikwestlund/code/homelab" /bin/zsh
    
    # Create window for vscode (window index 5)
    tmux new-window -t $SESSION_NAME:5 -n "vscode" -c "/Users/erikwestlund/code/vscode" /bin/zsh
    
    # Create window for raycast (window index 6)
    tmux new-window -t $SESSION_NAME:6 -n "raycast" -c "/Users/erikwestlund/code/raycast" /bin/zsh
    
    # Go back to claude window (window index 1)
    tmux select-window -t $SESSION_NAME:1
fi

# Attach to session
tmux attach-session -t $SESSION_NAME