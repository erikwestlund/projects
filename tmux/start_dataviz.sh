#!/bin/zsh

# Start Data Visualization course tmux session

SESSION_NAME="dvc"
PROJECT_DIR="$HOME/code/data-viz-summer-25"

# IDE Configuration
IDE_COMMAND="positron"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Clean up any existing Quarto temporary files
rm -rf $HOME/code/data-viz-summer-25/lectures/.quarto
rm -rf $HOME/code/data-viz-summer-25/lectures/_freeze
rm -rf $HOME/code/data-viz-summer-25/lectures/site_libs
rm -rf $HOME/code/data-viz-summer-25/lectures/_site

# Create a new tmux session
tmux new-session -d -s $SESSION_NAME -n "shell" -c "$HOME/code/data-viz-summer-25" /bin/zsh

# Setup main window with venv
tmux send-keys -t $SESSION_NAME:0 "source venv/bin/activate" C-m
tmux send-keys -t $SESSION_NAME:0 "clear" C-m

# Create R window
tmux new-window -t $SESSION_NAME:1 -n "R" -c "$HOME/code/data-viz-summer-25" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "R" C-m

# Create Python window
tmux new-window -t $SESSION_NAME:2 -n "Python" -c "$HOME/code/data-viz-summer-25" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "source venv/bin/activate" C-m
tmux send-keys -t $SESSION_NAME:2 "python3" C-m

# Create Quarto preview window
tmux new-window -t $SESSION_NAME:3 -n "Quarto" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "quarto preview lectures/day_\$(cat .active_preview)/day_\$(cat .active_preview)_lecture.qmd --output-dir _site/day\$(cat .active_preview)" C-m

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