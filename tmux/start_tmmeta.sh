#!/bin/zsh

# Start Meta Tmux Session - A workspace manager with sidebar and project area

SESSION_NAME="meta"
CONTROL_DIR="$HOME/code/scratch"

# Kill existing session if it exists
tmux kill-session -t $SESSION_NAME 2>/dev/null
sleep 0.5

# Create main session with control window
tmux new-session -d -s $SESSION_NAME -n control -c "$CONTROL_DIR"

# Split into left (30%) and right (70%) panes
tmux split-window -t $SESSION_NAME:0 -h -p 70 -c "$CONTROL_DIR"

# Left pane (0): Control terminal with helper functions
tmux select-pane -t $SESSION_NAME:0.0
tmux send-keys -t $SESSION_NAME:0.0 "source $HOME/code/projects/tmux/meta_helpers.sh" C-m
tmux send-keys -t $SESSION_NAME:0.0 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '🚀 Meta Tmux Session Started'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo ''" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo 'Helper commands available:'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '  tmadd <project>  - Add a project to the right pane'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '  tmlist           - List available projects'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '  tmhelp           - Show all commands'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo ''" C-m

# Right pane (1): Empty initially, will display projects
tmux select-pane -t $SESSION_NAME:0.1
tmux send-keys -t $SESSION_NAME:0.1 "clear" C-m

# Set pane titles
tmux select-pane -t $SESSION_NAME:0.0 -T "Control"
tmux select-pane -t $SESSION_NAME:0.1 -T "Projects"

# Create Claude window (index 1)
tmux new-window -t $SESSION_NAME:1 -n claude -c "$CONTROL_DIR"
tmux split-window -t $SESSION_NAME:1 -h -p 70 -c "$CONTROL_DIR"
tmux select-pane -t $SESSION_NAME:1.0
tmux send-keys -t $SESSION_NAME:1.0 "claude" C-m
tmux select-pane -t $SESSION_NAME:1.0 -T "Claude"
tmux select-pane -t $SESSION_NAME:1.1 -T "Projects"

# Create Codex window (index 2)
tmux new-window -t $SESSION_NAME:2 -n codex -c "$CONTROL_DIR"
tmux split-window -t $SESSION_NAME:2 -h -p 70 -c "$CONTROL_DIR"
tmux select-pane -t $SESSION_NAME:2.0
tmux send-keys -t $SESSION_NAME:2.0 "codex" C-m
tmux select-pane -t $SESSION_NAME:2.0 -T "Codex"
tmux select-pane -t $SESSION_NAME:2.1 -T "Projects"

# Store project colors for later use
tmux set-environment -t $SESSION_NAME PROJECT_INDEX 0

# Return to control window and attach
tmux select-window -t $SESSION_NAME:0
tmux select-pane -t $SESSION_NAME:0.0
tmux attach-session -t $SESSION_NAME
