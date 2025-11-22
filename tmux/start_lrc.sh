#!/bin/zsh

# Start LetsRun development tmux session

SESSION_NAME="lrc"
PROJECT_DIR="$HOME/code/letsrun"

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

# Create Tinker window (index 5)
tmux new-window -t $SESSION_NAME:5 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "php artisan tinker" C-m

# Create NPM window (index 6) - load NVM and switch to Node 13, but don't start npm
tmux new-window -t $SESSION_NAME:6 -n npm -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"/opt/homebrew/opt/nvm/nvm.sh\" ] && \\. \"/opt/homebrew/opt/nvm/nvm.sh\" && nvm use 13" C-m

# Re-select shell window and attach
tmux select-window -t $SESSION_NAME:0
tmux attach-session -t $SESSION_NAME
