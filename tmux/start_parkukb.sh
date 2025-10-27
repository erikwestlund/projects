#!/bin/zsh

# Start UK Biobank Parkinson's analysis tmux session

SESSION_NAME="park"
PROJECT_DIR="$HOME/code/parkukb_v2"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for shell
    tmux new-session -d -s $SESSION_NAME -n "shell" -c "$HOME/code/parkukb_v2" /bin/zsh
    tmux send-keys -t $SESSION_NAME:0 "source .venv/bin/activate" C-m

    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/parkukb_v2" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create Codex windows for different reasoning levels (windows 2-4)
    tmux new-window -t $SESSION_NAME:2 -n "co-l" -c "$HOME/code/parkukb_v2" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex --model gpt-5-codex -c model_reasoning_effort=\"low\"" C-m

    tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$HOME/code/parkukb_v2" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex --model gpt-5-codex -c model_reasoning_effort=\"medium\"" C-m

    tmux new-window -t $SESSION_NAME:4 -n "co-h" -c "$HOME/code/parkukb_v2" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "codex --model gpt-5-codex -c model_reasoning_effort=\"high\"" C-m

    # Create window for python (window index 5)
    tmux new-window -t $SESSION_NAME:5 -n "python" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:5 "python3" C-m

    # Create new session with first window for shell
    tmux new-session -d -s $SESSION_NAME -n "shell" -c "$HOME/code/parkukb" /bin/zsh
    tmux send-keys -t $SESSION_NAME:0 "source .venv/bin/activate" C-m

    # Select the first window
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME