#!/bin/zsh

# Start DR (Diabetic Retinopathy) tmux session

SESSION_NAME="dr"
PACKAGE_DIR="$HOME/code/ohdsi-dr-screening"
VIZ_DIR="$HOME/code/cai-gde-2025-retina-tp"

# Check if session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
    # Create new session with first window for package (dr-screening)
    tmux new-session -d -s $SESSION_NAME -n "package" -c "$PACKAGE_DIR" /bin/zsh

    # Create window for viz (window index 1)
    tmux new-window -t $SESSION_NAME:1 -n "viz" -c "$VIZ_DIR" /bin/zsh

    # Create window for claude-package (window index 2)
    tmux new-window -t $SESSION_NAME:2 -n "claude-package" -c "$PACKAGE_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:2 "claude" C-m

    # Create window for codex-package (window index 3)
    tmux new-window -t $SESSION_NAME:3 -n "codex-package" -c "$PACKAGE_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:3 "codex" C-m

    # Create window for claude-viz (window index 4)
    tmux new-window -t $SESSION_NAME:4 -n "claude-viz" -c "$VIZ_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:4 "claude" C-m

    # Create window for codex-viz (window index 5)
    tmux new-window -t $SESSION_NAME:5 -n "codex-viz" -c "$VIZ_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:5 "codex" C-m

    # Create window for R (window index 6)
    tmux new-window -t $SESSION_NAME:6 -n "R" -c "$PACKAGE_DIR" /bin/zsh
    tmux send-keys -t $SESSION_NAME:6 "R" C-m

    # Go back to package window (window index 0)
    tmux select-window -t $SESSION_NAME:0
fi

# Attach to session
tmux attach-session -t $SESSION_NAME