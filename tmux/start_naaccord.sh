#!/bin/zsh

SESSION="na"
PROJECT_DIR="$HOME/code/naaccord"
NAATOOLS_DIR="$HOME/code/NAATools"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Function to wait for Django to be ready
wait_for_django() {
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for Django to start..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost 8000 >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} Django is ready on port 8000!"
            return 0
        fi
        
        # Check if Django crashed (look for error messages in the window)
        if [ $attempt -gt 3 ]; then
            if tmux capture-pane -t "${SESSION}:django" -p | grep -q "Error\|Traceback\|SyntaxError\|NameError\|ImportError"; then
                echo ""
                echo "${RED}✗${NC} Django crashed with an error!"
                echo "  Check the django window for details"
                return 1
            fi
        fi
        
        printf "  Attempt %2d/%d: Django not ready yet...\r" $attempt $max_attempts
        sleep 2
        attempt=$((attempt + 1))
    done
    echo ""
    echo "${YELLOW}⚠${NC} Warning: Django may not have started properly"
    echo "  Check the django window for errors"
    return 1
}

# Function to check and clear port if needed
ensure_port_available() {
    local port=$1
    local service=$2
    
    if lsof -i :$port >/dev/null 2>&1; then
        echo "${YELLOW}⚠${NC} Port $port is in use. Attempting to clear it..."
        lsof -ti :$port | xargs kill -9 2>/dev/null
        sleep 1
        if lsof -i :$port >/dev/null 2>&1; then
            echo "${RED}✗${NC} Failed to clear port $port"
            return 1
        else
            echo "${GREEN}✓${NC} Port $port cleared successfully"
            return 0
        fi
    fi
    return 0
}

# Check if session already exists
if tmux has-session -t $SESSION 2>/dev/null; then
    echo "Session '$SESSION' already exists. Attaching to it..."
    tmux attach -t $SESSION
    exit 0
fi

echo "═══════════════════════════════════════════"
echo "NAACCORD Tmux Session Manager"
echo "═══════════════════════════════════════════"
echo ""

# Start Docker services first
echo "Starting Docker services..."
if ! "$HOME/code/projects/docker/naaccord.sh" start; then
    echo ""
    echo "${RED}✗ Failed to start Docker services${NC}"
    exit 1
fi

echo ""
echo "Docker services ready. Waiting a moment for full initialization..."
sleep 3
echo ""

echo ""
echo "${GREEN}✓ All required Docker services are running${NC}"
echo ""
echo "Creating tmux session..."
echo ""

# Start tmux with shell window (this becomes window 0)
tmux new-session -d -s $SESSION -n shell_depot -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:shell_depot" "source venv/bin/activate" C-m

# Create Claude window
tmux new-window -t $SESSION -n claude -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:claude" "claude" C-m

# Create NAATools shell window
tmux new-window -t $SESSION -n shell_naatools -c "$NAATOOLS_DIR"
tmux send-keys -t "${SESSION}:shell_naatools" "cd \"$NAATOOLS_DIR\"" C-m

# Ensure ports are available for Django servers
ensure_port_available 8000 "Django Web"
ensure_port_available 8001 "Django Services"

# Create Django Web Server window (streams to services)
tmux new-window -t $SESSION -n django -c "$PROJECT_DIR"

# Set Django environment and start web server (streaming mode)
echo "Starting Django web server (streaming mode)..."
tmux send-keys -t "${SESSION}:django" "source venv/bin/activate" C-m
sleep 1
tmux send-keys -t "${SESSION}:django" "export DJANGO_SETTINGS_MODULE=depot.settings" C-m
tmux send-keys -t "${SESSION}:django" "export SERVER_ROLE=web" C-m
tmux send-keys -t "${SESSION}:django" "export INTERNAL_API_KEY=dev-streaming-key-123" C-m
sleep 1
tmux send-keys -t "${SESSION}:django" "python manage.py runserver 0.0.0.0:8000" C-m

# Wait for Django web server to be ready
wait_for_django || {
    echo "${RED}✗${NC} Django web server failed to start. Showing last 10 lines from Django window:"
    tmux capture-pane -t "${SESSION}:django" -p | tail -10
    echo ""
    echo "You can still attach to the session and debug manually:"
    echo "  tmux attach -t $SESSION"
}

# Create Django Services Server window (handles file storage)
tmux new-window -t $SESSION -n services -c "$PROJECT_DIR"

# Set Django environment and start services server
echo "Starting Django services server (file storage)..."
tmux send-keys -t "${SESSION}:services" "source venv/bin/activate" C-m
sleep 1
tmux send-keys -t "${SESSION}:services" "export DJANGO_SETTINGS_MODULE=depot.settings" C-m
tmux send-keys -t "${SESSION}:services" "export SERVER_ROLE=services" C-m
tmux send-keys -t "${SESSION}:services" "export INTERNAL_API_KEY=dev-streaming-key-123" C-m
sleep 1
tmux send-keys -t "${SESSION}:services" "python manage.py runserver 0.0.0.0:8001" C-m

# Wait a moment for services server to start
echo "Waiting for services server to start..."
sleep 3

# Create Celery window
tmux new-window -t $SESSION -n celery -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:celery" "source venv/bin/activate && celery -A depot worker -l info" C-m

# Create NPM window
tmux new-window -t $SESSION -n npm -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:npm" "npm run dev" C-m

# Create R windows
tmux new-window -t $SESSION -n r_depot -c "$PROJECT_DIR/depot"
tmux send-keys -t "${SESSION}:r_depot" "cd \"$PROJECT_DIR/depot\" && R" C-m

tmux new-window -t $SESSION -n r_naatools -c "$NAATOOLS_DIR"
tmux send-keys -t "${SESSION}:r_naatools" "cd \"$NAATOOLS_DIR\" && R" C-m

# Create Docker monitoring window (optional - shows docker compose logs)
tmux new-window -t $SESSION -n docker -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:docker" "docker compose -f docker-compose.dev.yml logs -f" C-m

# Re-select shell window
tmux select-window -t "${SESSION}:shell_depot"

# Print success summary
echo ""
echo "═══════════════════════════════════════════"
echo "${GREEN}✓ Tmux session created successfully!${NC}"
echo "═══════════════════════════════════════════"
echo ""
echo "Tmux windows created:"
echo "  • shell_depot    : Main shell (activated venv)"
echo "  • claude         : Claude CLI"
echo "  • shell_naatools : NAATools shell"
echo "  • django         : Django web server (port 8000, streaming mode)"
echo "  • services       : Django services server (port 8001, file storage)"
echo "  • celery         : Celery worker"
echo "  • npm            : NPM dev server"
echo "  • r_depot        : R console (depot)"
echo "  • r_naatools     : R console (NAATools)"
echo "  • docker         : Docker compose logs"
echo ""
echo "Attaching to session '$SESSION'..."
echo "═══════════════════════════════════════════"
echo ""

# Attach to session
tmux attach -t $SESSION