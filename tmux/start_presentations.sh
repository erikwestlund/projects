#!/bin/zsh

# Start Presentations tmux session

SESSION_NAME="presentations"
PROJECT_DIR="$HOME/code/presentations"

# Kill any existing tmux session with the same name
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Create a new tmux session with window 0 as zsh
tmux new-session -d -s $SESSION_NAME -n "zsh" -c "$HOME/code/presentations" /bin/zsh

# Create Claude window (window 1)
tmux new-window -t $SESSION_NAME:1 -n "claude" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:1 "claude" C-m

# Create Codex windows for different reasoning levels (windows 2-4)
tmux new-window -t $SESSION_NAME:2 -n "co-l" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:2 "codex --model gpt-5.1-codex -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION_NAME:3 -n "co-m" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:3 "codex --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION_NAME:4 -n "co-h" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:4 "codex --model gpt-5.1-codex -c model_reasoning_effort=\"high\"" C-m

# Create R console window (window 5)
tmux new-window -t $SESSION_NAME:5 -n "R" -c "$HOME/code/presentations" /bin/zsh
tmux send-keys -t $SESSION_NAME:5 "R" C-m

# Create Python console window (window 6)
tmux new-window -t $SESSION_NAME:6 -n "Python" -c "$PROJECT_DIR" /bin/zsh
tmux send-keys -t $SESSION_NAME:6 "python3" C-m

# Select the first window
tmux select-window -t $SESSION_NAME:0

# Attach to the session
tmux attach-session -t $SESSION_NAME