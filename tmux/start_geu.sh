#!/bin/zsh

# Start GEU Support tmux session

SESSION_NAME="geu"
PROJECT_DIR="$HOME/code/geu-irr-support"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex windows for different models (windows 2-5)
tmux new-window -t $SESSION_NAME:2 -n "co-mini" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5.1-codex-mini -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION_NAME:4 -n "co-max" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5.1-codex-max -c model_reasoning_effort=\"high\"" C-m

tmux new-window -t $SESSION_NAME:5 -n "co-gpt" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "codex --full-auto --model gpt-5.1 -c model_reasoning_effort=\"high\"" C-m

# Create R console window (window 6)
tmux new-window -t $SESSION_NAME:6 -n "R" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "R" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME