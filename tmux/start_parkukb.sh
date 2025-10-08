#!/bin/zsh

# Start UK Biobank Parkinson's analysis tmux session

SESSION_NAME="park"
PROJECT_DIR="$HOME/code/parkukb"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for shell
    tmux new-session -d -s $SESSION_NAME -n "shell" -c "$HOME/code/parkukb" /bin/zsh
    tmux send-keys -t $SESSION_NAME:0 "source venv/bin/activate" C-m

    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/parkukb" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create window for zai (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "zai" -c "$HOME/code/parkukb" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "zai" C-m

    # Create window for python (window index 3)
    tmux new-window -t $SESSION_NAME:3 -n "python" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "python3" C-m

    # Select the first window
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME