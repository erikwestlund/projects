#!/bin/zsh

# Start NORC American Health Survey tmux session

SESSION_NAME="norc"
PROJECT_DIR="$HOME/code/norc-american-health-survey"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for zsh
    tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$PROJECT_DIR" /bin/zsh

    # Create window for claude (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:1 "claude" C-m

    # Create Codex windows for different models (windows 2-5)
    tmux new-window -t $SESSION_NAME:2 -n "co-mini" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "codex --model gpt-5.1-codex-mini -c model_reasoning_effort=\"low\"" C-m

    tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

    tmux new-window -t $SESSION_NAME:4 -n "co-max" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "codex --model gpt-5.1-codex-max -c model_reasoning_effort=\"high\"" C-m

    tmux new-window -t $SESSION_NAME:5 -n "co-gpt" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:5 "codex --model gpt-5.1 -c model_reasoning_effort=\"high\"" C-m

    # Create window for R (window index 6)
    tmux new-window -t $SESSION_NAME:6 -n "R" -c "$PROJECT_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:6 "R" C-m

    # Go back to zsh window (window index 0)
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME