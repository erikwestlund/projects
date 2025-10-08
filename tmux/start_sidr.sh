#!/bin/zsh

# Start SIDR workspace tmux session

SESSION_NAME="sidr"
PROJECT_DIR="$HOME/code/jh-sidr-pipeline"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for pipeline
    tmux new-session -d -s $SESSION_NAME -n "pipeline" -c "$HOME/code/jh-sidr-pipeline" /bin/zsh

    # Create Claude window in jh-sidr dir (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/jh-sidr" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create Zai window in jh-sidr dir (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "zai" -c "$HOME/code/jh-sidr" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "zai" C-m

    # Create new windows for jh-sidr-data and jh-sidr-data-restricted
    tmux new-window -t $SESSION_NAME:3 -n "data" -c "$HOME/code/jh-sidr-data" /bin/zsh
    tmux new-window -t $SESSION_NAME:4 -n "data-restricted" -c "$HOME/code/jh-sidr-data-restricted" /bin/zsh
    tmux new-window -t $SESSION_NAME:5 -n "tools" -c "$HOME/code/jh-sidr-tools" /bin/zsh

    # Create a window for Python REPL
    tmux new-window -t $SESSION_NAME:6 -n "python-repl" -c "$HOME/code/jh-sidr-pipeline" /bin/zsh
    tmux send-keys -t $SESSION_NAME:6 "source venv/bin/activate" C-m
    tmux send-keys -t $SESSION_NAME:6 "python" C-m

    # Create a window for example project
    tmux new-window -t $SESSION_NAME:7 -n "example" -c "$HOME/code/sidr-example-project" /bin/zsh

    # Create a window for R console in example project
    tmux new-window -t $SESSION_NAME:8 -n "example-R" -c "$HOME/code/sidr-example-project" /bin/zsh
    tmux send-keys -t $SESSION_NAME:8 "R" C-m

    # Activate virtual environment in the pipeline window
    tmux send-keys -t $SESSION_NAME:0 "source venv/bin/activate" C-m

    # Select the first window
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME