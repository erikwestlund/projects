#!/bin/zsh

# Start Pequod Page development tmux session

SESSION_NAME="pequod-page"
PROJECT_DIR="$HOME/code/pequod.page"

# Kill existing session if it exists and wait for cleanup
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Start tmux with shell window (index 0)
tmux new-session -d -s $SESSION_NAME -n zsh -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex windows for different models (indexes 2-4)
tmux new-window -t $SESSION_NAME:2 -n co-l -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5.1-codex -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION_NAME:3 -n co-m -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION_NAME:4 -n co-h -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5.1-codex -c model_reasoning_effort=\"high\"" C-m

# Create Zai window (index 5)
tmux new-window -t $SESSION_NAME:5 -n zai -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "zai" C-m

# Create Tinker window (index 6)
tmux new-window -t $SESSION_NAME:6 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "php artisan tinker" C-m

# Create Horizon window (index 7)
tmux new-window -t $SESSION_NAME:7 -n horizon -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:7 "php artisan horizon" C-m

# Create NPM window (index 8)
tmux new-window -t $SESSION_NAME:8 -n npm -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:8 "npm run dev" C-m

# Re-select shell window and attach
tmux select-window -t $SESSION_NAME:0
tmux attach-session -t $SESSION_NAME
