#!/bin/zsh

# Meta Tmux Helper Functions
# These functions help manage projects in the meta tmux session

# Color codes for project highlighting
declare -A PROJECT_COLORS=(
    [0]="colour39"   # Bright blue
    [1]="colour46"   # Bright green
    [2]="colour214"  # Orange
    [3]="colour201"  # Pink
    [4]="colour226"  # Yellow
    [5]="colour51"   # Cyan
    [6]="colour198"  # Magenta
    [7]="colour47"   # Lime
    [8]="colour208"  # Dark orange
    [9]="colour135"  # Purple
)

# Map of project names to their start scripts
declare -A PROJECT_SCRIPTS=(
    ["better-shoes"]="$HOME/code/projects/tmux/start_better_shoes.sh"
    ["bs"]="$HOME/code/projects/tmux/start_better_shoes.sh"
    ["naaccord"]="$HOME/code/projects/tmux/start_naaccord.sh"
    ["na"]="$HOME/code/projects/tmux/start_naaccord.sh"
    ["sidr"]="$HOME/code/projects/tmux/start_sidr.sh"
    ["computing"]="$HOME/code/projects/tmux/start_computing.sh"
    ["comp"]="$HOME/code/projects/tmux/start_computing.sh"
    ["homelab"]="$HOME/code/projects/tmux/start_homelab.sh"
    ["presentations"]="$HOME/code/projects/tmux/start_presentations.sh"
    ["pres"]="$HOME/code/projects/tmux/start_presentations.sh"
    ["pequod"]="$HOME/code/projects/tmux/start_pequod_page.sh"
    ["peq"]="$HOME/code/projects/tmux/start_pequod_page.sh"
    ["dataviz"]="$HOME/code/projects/tmux/start_dataviz.sh"
    ["dvc"]="$HOME/code/projects/tmux/start_dataviz.sh"
)

# Track project windows
PROJECTS_FILE="$HOME/.tmux_meta_projects"
touch "$PROJECTS_FILE"

# Add a project to the meta session
tmadd() {
    if [ -z "$1" ]; then
        echo "Usage: tmadd <project-name>"
        echo "Example: tmadd better-shoes"
        return 1
    fi

    local project_name="$1"
    local script="${PROJECT_SCRIPTS[$project_name]}"

    if [ -z "$script" ]; then
        echo "❌ Unknown project: $project_name"
        echo "Run 'tmlist' to see available projects"
        return 1
    fi

    if [ ! -f "$script" ]; then
        echo "❌ Script not found: $script"
        return 1
    fi

    # Get the project session name from the script
    local session_name=$(grep "SESSION_NAME=" "$script" | head -1 | cut -d'"' -f2)

    if [ -z "$session_name" ]; then
        echo "❌ Could not determine session name from script"
        return 1
    fi

    # Check if project is already running
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✅ Project '$project_name' is already running (session: $session_name)"
        echo "   Linking to right pane..."

        # Link the existing session to the right pane
        tmux kill-pane -t meta:0.1 2>/dev/null
        tmux split-window -t meta:0 -h -p 70 -c "$HOME"
        tmux send-keys -t meta:0.1 "tmux attach -t $session_name" C-m
        return 0
    fi

    echo "🚀 Starting project: $project_name (session: $session_name)"

    # Start the project session in detached mode
    bash "$script" &
    sleep 2

    # Check if session was created
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ Failed to start project session"
        return 1
    fi

    # Get project index for coloring
    local project_index=$(cat "$PROJECTS_FILE" | wc -l | xargs)
    local color="${PROJECT_COLORS[$((project_index % 10))]}"

    # Save project info
    echo "$project_name:$session_name:$color" >> "$PROJECTS_FILE"

    # Link the session to the right pane
    tmux kill-pane -t meta:0.1 2>/dev/null
    tmux split-window -t meta:0 -h -p 70 -c "$HOME"
    tmux send-keys -t meta:0.1 "tmux attach -t $session_name" C-m

    # Update pane colors
    tmux select-pane -t meta:0.1 -P "bg=default,fg=$color"

    echo "✅ Project added! Use Cmd+Shift+[ / Cmd+Shift+] to navigate"
    echo "   Or use: tmswitch $project_name"
}

# Switch to a different project
tmswitch() {
    if [ -z "$1" ]; then
        echo "Usage: tmswitch <project-name>"
        return 1
    fi

    local project_name="$1"
    local script="${PROJECT_SCRIPTS[$project_name]}"

    if [ -z "$script" ]; then
        echo "❌ Unknown project: $project_name"
        return 1
    fi

    local session_name=$(grep "SESSION_NAME=" "$script" | head -1 | cut -d'"' -f2)

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ Project not running. Start it with: tmadd $project_name"
        return 1
    fi

    # Switch the right pane to the project session
    tmux kill-pane -t meta:0.1 2>/dev/null
    tmux split-window -t meta:0 -h -p 70 -c "$HOME"
    tmux send-keys -t meta:0.1 "tmux attach -t $session_name" C-m

    echo "✅ Switched to: $project_name"
}

# List available projects
tmlist() {
    echo "📋 Available projects:"
    echo ""

    # Group by category
    echo "Work Projects:"
    echo "  naaccord, na      - NA Accord project"
    echo "  sidr              - SIDR project"
    echo ""

    echo "Personal Projects:"
    echo "  better-shoes, bs  - Better Shoes"
    echo "  pequod, peq       - Pequod Page"
    echo "  dataviz, dvc      - Data Visualization"
    echo ""

    echo "Infrastructure:"
    echo "  computing, comp   - Computing workspace"
    echo "  homelab           - Homelab infrastructure"
    echo ""

    echo "Other:"
    echo "  presentations, pres - Presentations workspace"
    echo ""

    echo "Running projects:"
    if [ -s "$PROJECTS_FILE" ]; then
        cat "$PROJECTS_FILE" | while IFS=: read -r name session color; do
            if tmux has-session -t "$session" 2>/dev/null; then
                echo "  ✅ $name (session: $session)"
            fi
        done
    else
        echo "  (none)"
    fi
}

# Show help
tmhelp() {
    echo "🎯 Meta Tmux Commands:"
    echo ""
    echo "Project Management:"
    echo "  tmadd <project>      - Add/start a project"
    echo "  tmswitch <project>   - Switch to a running project"
    echo "  tmlist               - List available projects"
    echo "  tmstop <project>     - Stop a project"
    echo "  tmactive             - Show active projects"
    echo ""
    echo "Navigation:"
    echo "  Cmd+Shift+[ / ]      - Switch between projects"
    echo "  Shift+[ / ]          - Navigate tabs within project"
    echo "  Ctrl+<number>        - Jump to specific tab"
    echo "  Ctrl+b [             - Switch to previous window in left sidebar"
    echo "  Ctrl+b ]             - Switch to next window in left sidebar"
    echo ""
    echo "Examples:"
    echo "  tmadd better-shoes   - Start Better Shoes project"
    echo "  tmadd na             - Start NA Accord project"
    echo "  tmswitch bs          - Switch to Better Shoes"
    echo ""
}

# Show active projects
tmactive() {
    echo "🟢 Active projects:"
    if [ -s "$PROJECTS_FILE" ]; then
        cat "$PROJECTS_FILE" | while IFS=: read -r name session color; do
            if tmux has-session -t "$session" 2>/dev/null; then
                echo "  • $name (session: $session)"
            fi
        done
    else
        echo "  (none running)"
    fi
}

# Stop a project
tmstop() {
    if [ -z "$1" ]; then
        echo "Usage: tmstop <project-name>"
        return 1
    fi

    local project_name="$1"
    local script="${PROJECT_SCRIPTS[$project_name]}"

    if [ -z "$script" ]; then
        echo "❌ Unknown project: $project_name"
        return 1
    fi

    local session_name=$(grep "SESSION_NAME=" "$script" | head -1 | cut -d'"' -f2)

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ Project not running: $project_name"
        return 1
    fi

    tmux kill-session -t "$session_name"
    echo "✅ Stopped project: $project_name"

    # Remove from projects file
    sed -i.bak "/^$project_name:/d" "$PROJECTS_FILE"
    rm -f "$PROJECTS_FILE.bak"
}

# Clean up stopped projects from tracking file
tmclean() {
    if [ ! -s "$PROJECTS_FILE" ]; then
        echo "No projects to clean"
        return 0
    fi

    local temp_file=$(mktemp)
    cat "$PROJECTS_FILE" | while IFS=: read -r name session color; do
        if tmux has-session -t "$session" 2>/dev/null; then
            echo "$name:$session:$color" >> "$temp_file"
        fi
    done

    mv "$temp_file" "$PROJECTS_FILE"
    echo "✅ Cleaned up project tracking"
}

# Export functions
export -f tmadd tmswitch tmlist tmhelp tmactive tmstop tmclean
