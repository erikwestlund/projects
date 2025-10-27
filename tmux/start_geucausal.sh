#!/bin/zsh

SESSION_NAME="geucausal"
PROJECT_DIR="$HOME/code/geu-causal-presentation"

tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION_NAME -n "main" -c "$PROJECT_DIR" /bin/zsh
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/geu-causal-presentation" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    tmux new-window -t $SESSION_NAME:2 -n "co-l" -c "$HOME/code/geu-causal-presentation" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"low\"" C-m

    tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$HOME/code/geu-causal-presentation" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"medium\"" C-m

    tmux new-window -t $SESSION_NAME:4 -n "co-h" -c "$HOME/code/geu-causal-presentation" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"high\"" C-m

    tmux new-window -t $SESSION_NAME:5 -n "R" -c "$HOME/code/geu-causal-presentation" /bin/zsh
    tmux send-keys -t $SESSION_NAME:5 "R" C-m

fi

tmux attach -t $SESSION_NAME
