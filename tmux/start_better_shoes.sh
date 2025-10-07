#!/bin/zsh

# Start Better Shoes development tmux session

SESSION_NAME="bs"
PROJECT_DIR="$HOME/code/better-shoes"

# IDE Configuration - Set your preferred IDE command
# Options: "cursor", "code", "phpstorm", "webstorm", "positron", etc.
IDE_COMMAND="phpstorm"  # Change this to your preferred IDE

# Kill existing session if it exists and wait for cleanup
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Start tmux with shell window (index 0)
tmux new-session -d -s $SESSION_NAME -n shell -c "$PROJECT_DIR" /bin/zsh

# Create Claude window for AI assistant (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex window for AI assistant (index 2)
tmux new-window -t $SESSION_NAME:2 -n codex -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex" C-m

# Create Horizon window for queue processing (index 3)
tmux new-window -t $SESSION_NAME:3 -n horizon -c "$PROJECT_DIR" /bin/zsh
# Note: Horizon daemon not auto-started - run manually with: php artisan horizon

# Create NPM window for frontend development (index 4)
tmux new-window -t $SESSION_NAME:4 -n npm -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "npm run dev" C-m

# Create Tinker window for database interaction (index 5)
tmux new-window -t $SESSION_NAME:5 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "php artisan tinker" C-m

# Create Docker window (index 6)
tmux new-window -t $SESSION_NAME:6 -n docker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "$HOME/code/projects/docker/better-shoes.sh start" C-m

# Create Log window for monitoring logs (index 7)
tmux new-window -t $SESSION_NAME:7 -n logs -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:7 "tail -n 1000 -f storage/logs/laravel.log" C-m

# Create Framework window (index 8)
tmux new-window -t $SESSION_NAME:8 -n framework -c "$HOME/code/framework" /bin/zsh

# Create IDE window (index 9)
# This window is for launching your preferred IDE
# Note: The IDE will open in a separate window/app, not in tmux
tmux new-window -t $SESSION_NAME:9 -n ide -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:9 "echo '💡 IDE Launcher - Press Enter to open $IDE_COMMAND'" C-m
tmux send-keys -t $SESSION_NAME:9 "echo 'Project: $PROJECT_DIR'" C-m
tmux send-keys -t $SESSION_NAME:9 "echo ''" C-m
tmux send-keys -t $SESSION_NAME:9 "echo 'Run: $IDE_COMMAND .'" C-m

# Re-select shell window and attach
tmux select-window -t $SESSION_NAME:0
tmux attach-session -t $SESSION_NAME