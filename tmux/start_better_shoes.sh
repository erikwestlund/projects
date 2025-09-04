#!/bin/zsh

# Start Better Shoes development tmux session

SESSION_NAME="bs"
PROJECT_DIR="$HOME/code/better-shoes"

# Kill existing session if it exists and wait for cleanup
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Start tmux with shell window (index 0)
tmux new-session -d -s $SESSION_NAME -n shell -c "$PROJECT_DIR" /bin/zsh

# Create Claude window for AI assistant (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t "$SESSION_NAME:claude" "claude" C-m

# Create Horizon window for queue processing (index 2)
tmux new-window -t $SESSION_NAME:2 -n horizon -c "$PROJECT_DIR" /bin/zsh
# Note: Horizon daemon not auto-started - run manually with: php artisan horizon

# Create NPM window for frontend development (index 3)
tmux new-window -t $SESSION_NAME:3 -n npm -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t "$SESSION_NAME:npm" "npm run dev" C-m

# Create MCP window for Model Context Protocol server (index 4)
tmux new-window -t $SESSION_NAME:4 -n mcp -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t "$SESSION_NAME:mcp" "php artisan mcp:serve" C-m

# Create Tinker window for database interaction (index 5)
tmux new-window -t $SESSION_NAME:5 -n tinker -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t "$SESSION_NAME:tinker" "php artisan tinker" C-m

# Create Log window for monitoring logs (index 6)
tmux new-window -t $SESSION_NAME:6 -n logs -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t "$SESSION_NAME:logs" "tail -n 1000 -f storage/logs/laravel.log" C-m

# Re-select shell window and attach
tmux select-window -t "$SESSION_NAME:shell"
tmux attach-session -t $SESSION_NAME