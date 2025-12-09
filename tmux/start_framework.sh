#!/bin/zsh

# Start Framework tmux session

SESSION_NAME="fw"
PROJECT_DIR="$HOME/code/framework"
SITE_DIR="$HOME/code/framework-site"
PROJECT_SHELL_DIR="$HOME/code/framework-project"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create site windows (windows 2-3)
tmux new-window -t $SESSION_NAME:2 -n "site" -c "$SITE_DIR" /bin/zsh

tmux new-window -t $SESSION_NAME:3 -n "site-cl" -c "$SITE_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "claude" C-m

# Create Codex windows for different models (windows 4-6)
tmux new-window -t $SESSION_NAME:4 -n "co-mini" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5.1-codex-mini -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION_NAME:5 -n "co-m" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "codex --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION_NAME:6 -n "co-max" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "codex --full-auto --model gpt-5.1-codex-max -c model_reasoning_effort=\"high\"" C-m

tmux new-window -t $SESSION_NAME:7 -n "co-gpt" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:7 "codex --full-auto --model gpt-5.1 -c model_reasoning_effort=\"high\"" C-m

tmux new-window -t $SESSION_NAME:8 -n "gui-srv" -c "$PROJECT_DIR/gui-dev" /bin/zsh
tmux send-keys -t $SESSION_NAME:8 "lsof -ti :8080 | xargs kill 2>/dev/null; npm run dev:server" C-m

tmux new-window -t $SESSION_NAME:9 -n "gui-npm" -c "$PROJECT_DIR/gui-dev" /bin/zsh
tmux send-keys -t $SESSION_NAME:9 "npm run dev" C-m

tmux new-window -t $SESSION_NAME:10 -n "site-npm" -c "$SITE_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:10 "npm run dev" C-m

tmux new-window -t $SESSION_NAME:11 -n "R" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:11 "R" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME