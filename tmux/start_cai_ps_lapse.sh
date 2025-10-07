#!/bin/zsh

# Start CAI PS Lapse tmux session

SESSION_NAME="cai"
PROJECT_DIR="$HOME/code/cai-ps-lapse"

# IDE Configuration
IDE_COMMAND="positron"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for zsh
    tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh
    
    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m
    
    # Create window for R (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "R" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "R" C-m

    # Create IDE window (index 3)
    tmux new-window -t $SESSION_NAME:3 -n "ide" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "echo '💡 IDE Launcher - Press Enter to open $IDE_COMMAND'" C-m
    tmux send-keys -t $SESSION_NAME:3 "echo 'Project: $PROJECT_DIR'" C-m
    tmux send-keys -t $SESSION_NAME:3 "echo ''" C-m
    tmux send-keys -t $SESSION_NAME:3 "echo 'Run: $IDE_COMMAND .'" C-m

    # Go back to zsh window (window index 0)
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME