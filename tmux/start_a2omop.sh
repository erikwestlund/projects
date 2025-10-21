#!/bin/zsh

SESSION_NAME="a2omop"
PROJECT_DIR="$HOME/code/a2cps-ehr-to-omop"

tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION_NAME -n "main" -c "$PROJECT_DIR" /bin/zsh
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/a2cps-ehr-to-omop" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    tmux new-window -t $SESSION_NAME:2 -n "codex" -c "$HOME/code/a2cps-ehr-to-omop" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex" C-m

    tmux new-window -t $SESSION_NAME:3 -n "zai" -c "$HOME/code/a2cps-ehr-to-omop" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "zai" C-m

    tmux new-window -t $SESSION_NAME:4 -n "R" -c "$HOME/code/a2cps-ehr-to-omop" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "R" C-m

fi

tmux attach -t $SESSION_NAME
