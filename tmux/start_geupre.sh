#!/bin/zsh

SESSION_NAME="geupre"
PROJECT_DIR="$HOME/code/geu-preregistration"

tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION_NAME -n "main" -c "$PROJECT_DIR" /bin/zsh
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/geu-preregistration" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    tmux new-window -t $SESSION_NAME:2 -n "codex" -c "$HOME/code/geu-preregistration" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex" C-m

    tmux new-window -t $SESSION_NAME:3 -n "R" -c "$HOME/code/geu-preregistration" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "R" C-m

fi

tmux attach -t $SESSION_NAME
