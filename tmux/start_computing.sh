#!/bin/zsh

# Start computing workspace tmux session with claude and all infrastructure projects

SESSION_NAME="computing"
PROJECT_DIR="$HOME/code/projects"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for projects directory
    tmux new-session -d -s $SESSION_NAME -n "proj" -c "$HOME/code/projects" /bin/zsh

    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/projects" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create window for codex medium reasoning (window index 3)
    tmux new-window -t $SESSION_NAME:2 -n "co-m" -c "$HOME/code/projects" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

    # Create window for codex max model (window index 4)
    tmux new-window -t $SESSION_NAME:3 -n "co-max" -c "$HOME/code/projects" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5.1-codex-max -c model_reasoning_effort=\"high\"" C-m

    # Create window for codex gpt model (window index 5)
    tmux new-window -t $SESSION_NAME:4 -n "co-gpt" -c "$HOME/code/projects" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5.1 -c model_reasoning_effort=\"high\"" C-m

    # Create window for dotfiles (window index 7)
    tmux new-window -t $SESSION_NAME:5 -n "dotfiles" -c "$HOME/code/dotfiles" /bin/zsh

    # Create window for ha (window index 8)
    tmux new-window -t $SESSION_NAME:6 -n "ha" -c "$HOME/code/home-assistant" /bin/zsh

    # Create window for homelab (window index 9)
    tmux new-window -t $SESSION_NAME:7 -n "homelab" -c "$HOME/code/homelab" /bin/zsh

    # Create window for vscode (window index 10)
    tmux new-window -t $SESSION_NAME:8 -n "vs" -c "$HOME/code/vscode" /bin/zsh

    # Create window for raycast (window index 11)
    tmux new-window -t $SESSION_NAME:9 -n "ray" -c "$HOME/code/raycast" /bin/zsh

    # Go back to claude window (window index 1)
    tmux select-window -t $SESSION_NAME:1
fi

# Attach to session
tmux attach-session -t $SESSION_NAME