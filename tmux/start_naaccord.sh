#!/bin/zsh

SESSION="na"
PROJECT_DIR="$HOME/code/naaccord"
NAATOOLS_DIR="$HOME/code/NAATools"

# Parse command line arguments
NAATOOLS_DEV=false
for arg in "$@"; do
    case $arg in
        --naatools-dev)
            NAATOOLS_DEV=true
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to wait for containers to be ready
wait_for_containers() {
    local max_attempts=30
    local attempt=1

    echo "Waiting for containers to be ready..."
    while [ $attempt -le $max_attempts ]; do
        # Check if web container is ready
        if nc -z localhost 8000 >/dev/null 2>&1 && nc -z localhost 8001 >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} Containers are ready (ports 8000, 8001)!"
            return 0
        fi

        printf "  Attempt %2d/%d: Containers not ready yet...\r" $attempt $max_attempts
        sleep 2
        attempt=$((attempt + 1))
    done
    echo ""
    echo "${YELLOW}⚠${NC} Warning: Containers may not have started properly"
    echo "  Check the docker window for errors"
    return 1
}

# Check if session already exists
if tmux has-session -t $SESSION 2>/dev/null; then
    echo "Session '$SESSION' already exists. Attaching to it..."
    tmux attach -t $SESSION
    exit 0
fi

echo "═══════════════════════════════════════════"
echo "NAACCORD Tmux Session Manager"
if [ "$NAATOOLS_DEV" = true ]; then
    echo "NAATools Dev Mode: ENABLED"
fi
echo "═══════════════════════════════════════════"
echo ""

if [ "$NAATOOLS_DEV" = true ]; then
    echo "${YELLOW}⚡ Local NAATools will be mounted from:${NC}"
    echo "  $NAATOOLS_DIR"
    echo ""
fi

# Start Docker services first
echo "Starting Docker services..."
cd "$PROJECT_DIR"
if [ "$NAATOOLS_DEV" = true ]; then
    if ! "$PROJECT_DIR/scripts/naaccord-docker.sh" start --env dev --naatools-dev; then
        echo ""
        echo "${RED}✗ Failed to start Docker services${NC}"
        exit 1
    fi
else
    if ! "$PROJECT_DIR/scripts/naaccord-docker.sh" start --env dev; then
        echo ""
        echo "${RED}✗ Failed to start Docker services${NC}"
        exit 1
    fi
fi

echo ""
echo "Docker services ready. Waiting a moment for full initialization..."
sleep 3
echo ""

# Wait for containers to be ready
wait_for_containers || {
    echo "${RED}✗${NC} Containers failed to start properly. You can still attach to the session and debug manually:"
    echo "  tmux attach -t $SESSION"
}

echo ""
echo "${GREEN}✓ All required Docker services are running${NC}"
echo ""
echo "Creating tmux session..."
echo ""

# Start tmux with zsh window (window 0)
tmux new-session -d -s $SESSION -n zsh -c "$PROJECT_DIR"

# Create Claude window (window 1)
tmux new-window -t $SESSION -n claude -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:cl" "claude" C-m

# Create Codex windows for different reasoning levels (windows 2-4)
tmux new-window -t $SESSION -n co-l -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:co-l" "codex --model gpt-5.1-codex -c model_reasoning_effort=\"low\"" C-m

tmux new-window -t $SESSION -n co-m -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:co-m" "codex --model gpt-5.1-codex -c model_reasoning_effort=\"medium\"" C-m

tmux new-window -t $SESSION -n co-h -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:co-h" "codex --model gpt-5.1-codex -c model_reasoning_effort=\"high\"" C-m

# Create Zai window (window 5)
tmux new-window -t $SESSION -n zai -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:zai" "zai" C-m

# Create Web container access window (window 6)
tmux new-window -t $SESSION -n web -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:web" "# Web container access - Django logs and shell access" C-m
tmux send-keys -t "${SESSION}:web" 'command docker logs -f --tail 50 naaccord-test-web 2>&1' C-m

# Create Services container access window (window 7)
tmux new-window -t $SESSION -n srv -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:srv" "# Services container access - Django logs and shell access" C-m
tmux send-keys -t "${SESSION}:srv" 'command docker logs -f --tail 50 naaccord-test-services 2>&1' C-m

# Create Celery monitoring window (window 8)
tmux new-window -t $SESSION -n clry -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:clry" "# Celery worker monitoring and Flower dashboard" C-m
tmux send-keys -t "${SESSION}:clry" "echo 'Celery worker logs:'" C-m
tmux send-keys -t "${SESSION}:clry" 'command docker logs -f --tail 50 naaccord-test-celery 2>&1' C-m

# Create NPM window (window 9)
tmux new-window -t $SESSION -n npm -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:npm" "npm run dev" C-m

# Create Docker monitoring window (window 10)
tmux new-window -t $SESSION -n dock -c "$PROJECT_DIR"
tmux send-keys -t "${SESSION}:dock" 'command docker compose logs -f --tail 50 2>&1' C-m

# Re-select zsh window (window 0)
tmux select-window -t "${SESSION}:zsh"

# Print success summary
echo ""
echo "═══════════════════════════════════════════"
echo "${GREEN}✓ Tmux session created successfully!${NC}"
echo "═══════════════════════════════════════════"
echo ""

echo "${GREEN}🐋 Containerized Development Environment:${NC}"
echo "  • ✅ All services running in Docker containers"
echo "  • ✅ Auto-reload enabled for code changes"
echo "  • ✅ PHI-compliant two-server architecture"
echo "  • ✅ Celery worker with Flower monitoring"
if [ "$NAATOOLS_DEV" = true ]; then
    echo "  • ${YELLOW}⚡ NAATools Dev Mode: Local changes reflected immediately${NC}"
fi
echo ""

echo "Tmux windows created:"
echo "  • 0: zsh          : Main shell (~/code/naaccord)"
echo "  • 1: cl           : Claude CLI"
echo "  • 2: co-l         : Codex CLI (low reasoning)"
echo "  • 3: co-m         : Codex CLI (medium reasoning)"
echo "  • 4: co-h         : Codex CLI (high reasoning)"
echo "  • 5: zai          : Zai CLI (Z.ai API)"
echo "  • 6: web          : Web container logs (port 8000)"
echo "  • 7: services     : Services container logs (port 8001)"
echo "  • 8: celery       : Celery worker logs and monitoring"
echo "  • 9: npm          : NPM dev server (port 3000)"
echo "  • 10: docker      : Docker compose logs (all containers)"
echo ""

echo "${GREEN}🔗 Service URLs:${NC}"
echo "  • Web Interface: http://localhost:8000"
echo "  • Services API: http://localhost:8001"
echo "  • Flower (Celery): http://localhost:5555"
echo "  • Vite Dev Server: http://localhost:3000"
echo ""

echo "${GREEN}🛠️ Container Access:${NC}"
echo "  • Web shell: docker exec -it naaccord-test-web bash"
echo "  • Services shell: docker exec -it naaccord-test-services bash"
echo "  • Django shell: docker exec -it naaccord-test-web python manage.py shell"
echo ""

echo "Attaching to session '$SESSION'..."
echo "═══════════════════════════════════════════"
echo ""

# Attach to session
tmux attach -t $SESSION