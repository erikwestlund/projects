#!/bin/zsh

# Start Presentations tmux session

SESSION_NAME="presentations"
PROJECT_DIR="$HOME/code/presentations"

# IDE Configuration
IDE_COMMAND="positron"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$HOME/code/presentations" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create R console window (window 2)
tmux new-window -t $SESSION_NAME:2 -n "R" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "R" C-m

# Create Python console window (window 3)
tmux new-window -t $SESSION_NAME:3 -n "Python" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "python3" C-m

# Create IDE window (window 4)
tmux new-window -t $SESSION_NAME:4 -n "ide" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "echo '💡 IDE Launcher - Press Enter to open $IDE_COMMAND'" C-m
tmux send-keys -t $SESSION_NAME:4 "echo 'Project: $PROJECT_DIR'" C-m
tmux send-keys -t $SESSION_NAME:4 "echo ''" C-m
tmux send-keys -t $SESSION_NAME:4 "echo 'Run: $IDE_COMMAND .'" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME