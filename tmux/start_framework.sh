#!/bin/zsh

# Start Framework tmux session

SESSION_NAME="fw"
PROJECT_DIR="$HOME/code/framework"
PROJECT_SHELL_DIR="$HOME/code/framework-project"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex windows for different reasoning levels (windows 2-4)
tmux new-window -t $SESSION_NAME:2 -n "co-l" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION_NAME:4 -n "co-h" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "codex --full-auto --model gpt-5-codex -c model_reasoning_effort=\"high\"" C-m

# Create Zai window (window 5)
tmux new-window -t $SESSION_NAME:5 -n "zai" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "zai" C-m

# Create R console window (window 6)
tmux new-window -t $SESSION_NAME:6 -n "R" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "R" C-m

# Create framework project shell (window 7)
tmux new-window -t $SESSION_NAME:7 -n "fw-proj" -c "$PROJECT_SHELL_DIR" /bin/zsh

# Create GUI R backend window (window 8) - Auto-reloads on R file changes
tmux new-window -t $SESSION_NAME:8 -n "gui-r" -c "$PROJECT_DIR/gui-dev" /bin/zsh
tmux send-keys -t $SESSION_NAME:8 "lsof -ti :8080 | xargs kill 2>/dev/null; npm run dev:server" C-m

# Create GUI Vite dev server window (window 9) - Hot reload for UI
tmux new-window -t $SESSION_NAME:9 -n "gui-ui" -c "$PROJECT_DIR/gui-dev" /bin/zsh
tmux send-keys -t $SESSION_NAME:9 "npm run dev" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME