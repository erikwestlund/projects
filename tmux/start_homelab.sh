#!/bin/zsh

# Start homelab infrastructure tmux session

SESSION_NAME="homelab"
PROJECT_DIR="$HOME/code/homelab"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window (0) named "homelab" in homelab directory
    tmux new-session -d -s $SESSION_NAME -n "homelab" -c "$HOME/code/homelab" /bin/zsh

    # Create second window (1) named "cl" and start claude
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/homelab" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create Codex windows for different reasoning levels (indexes 2-4)
    tmux new-window -t $SESSION_NAME:2 -n "co-l" -c "$HOME/code/homelab" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"low\"" C-m

    tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$HOME/code/homelab" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"medium\"" C-m

    tmux new-window -t $SESSION_NAME:4 -n "co-h" -c "$HOME/code/homelab" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"high\"" C-m

    # Create dotfiles window (index 5) in dotfiles directory
    tmux new-window -t $SESSION_NAME:5 -n "dotfiles" -c "$HOME/code/dotfiles" /bin/zsh

    # Create home-assistant window (index 6) in home-assistant directory
    tmux new-window -t $SESSION_NAME:6 -n "home-assistant" -c "$HOME/code/home-assistant" /bin/zsh

    # Select first window
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME