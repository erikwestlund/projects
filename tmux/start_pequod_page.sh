#!/bin/zsh

# Start Pequod Page development tmux session

SESSION_NAME="pequod-page"
PROJECT_DIR="$HOME/code/pequod.page"

# IDE Configuration
IDE_COMMAND="phpstorm"

# Kill existing session if it exists and wait for cleanup
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Start tmux with shell window (index 0)
tmux new-session -d -s $SESSION_NAME -n zsh -c "$PROJECT_DIR" /bin/zsh

# Create Claude window (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex window (index 2)
tmux new-window -t $SESSION_NAME:2 -n codex -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex" C-m

# Create Tinker window (index 3)
tmux new-window -t $SESSION_NAME:3 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "php artisan tinker" C-m

# Create Horizon window (index 4)
tmux new-window -t $SESSION_NAME:4 -n horizon -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "php artisan horizon" C-m

# Create NPM window (index 5)
tmux new-window -t $SESSION_NAME:5 -n npm -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "npm run dev" C-m

# Create IDE window (index 6)
tmux new-window -t $SESSION_NAME:6 -n ide -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "echo '💡 IDE Launcher - Press Enter to open $IDE_COMMAND'" C-m
tmux send-keys -t $SESSION_NAME:6 "echo 'Project: $PROJECT_DIR'" C-m
tmux send-keys -t $SESSION_NAME:6 "echo ''" C-m
tmux send-keys -t $SESSION_NAME:6 "echo 'Run: $IDE_COMMAND .'" C-m

# Re-select shell window and attach
tmux select-window -t $SESSION_NAME:0
tmux attach-session -t $SESSION_NAME
