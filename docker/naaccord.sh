#!/bin/zsh

PROJECT_DIR="$HOME/code/naaccord"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to wait for a service to be ready
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for $service to be ready on port $port..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost $port >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} $service is ready!"
            return 0
        fi
        printf "  Attempt %2d/%d: %s not ready yet...\r" $attempt $max_attempts "$service"
        sleep 2
        attempt=$((attempt + 1))
    done
    echo ""
    echo "${RED}✗${NC} Error: $service failed to start after $max_attempts attempts"
    return 1
}


# Function to check if services are already running
check_services_status() {
    local all_running=true
    
    echo "Checking service status..."
    echo "-------------------------------------------"
    
    # Check each service
    if nc -z localhost 3306 >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} MariaDB is running (port 3306)"
    else
        echo "${RED}✗${NC} MariaDB is not running"
        all_running=false
    fi
    
    if nc -z localhost 6379 >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} Redis is running (port 6379)"
    else
        echo "${RED}✗${NC} Redis is not running"
        all_running=false
    fi
    
    if nc -z localhost 9000 >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} MinIO is running (port 9000)"
    else
        echo "${RED}✗${NC} MinIO is not running"
        all_running=false
    fi
    
    if nc -z localhost 5555 >/dev/null 2>&1; then
        echo "${GREEN}✓${NC} Flower is running (port 5555)"
    else
        echo "${RED}✗${NC} Flower is not running"
        all_running=false
    fi
    
    echo "-------------------------------------------"
    
    if $all_running; then
        return 0
    else
        return 1
    fi
}

# Main script
echo "═══════════════════════════════════════════"
echo "NAACCORD Docker Services Manager"
echo "═══════════════════════════════════════════"
echo ""

# Parse command line arguments
case "${1:-start}" in
    start)
        # Check if services are already running
        if check_services_status >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} Services are already running"
            check_services_status
            echo ""
            echo "${GREEN}✓ All services ready!${NC}"
            exit 0
        fi
        
        echo "Starting Docker services in $PROJECT_DIR..."
        echo ""
        
        # Start Docker Compose (using -f with full path)
        docker compose -f "$PROJECT_DIR/docker-compose.dev.yml" --project-directory "$PROJECT_DIR" up -d --remove-orphans
        
        echo ""
        echo "Services started. Waiting 2 seconds for initialization..."
        sleep 2
        
        echo ""
        echo "═══════════════════════════════════════════"
        echo "${GREEN}✓ Docker services started successfully!${NC}"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "Services running:"
        echo "  • MariaDB : localhost:3306"
        echo "  • Redis   : localhost:6379"
        echo "  • Flower  : localhost:5555"
        echo ""
        echo "You can now run 'tmna' to start the tmux session"
        ;;
        
    stop)
        echo "Stopping Docker services in $PROJECT_DIR..."
        docker compose -f "$PROJECT_DIR/docker-compose.dev.yml" --project-directory "$PROJECT_DIR" down
        echo "${GREEN}✓${NC} Docker services stopped"
        ;;
        
    restart)
        $0 stop
        echo ""
        sleep 2
        $0 start
        ;;
        
    status)
        check_services_status
        echo ""
        
        # Also show Docker containers
        echo "Docker containers:"
        echo "-------------------------------------------"
        docker ps --filter "label=com.docker.compose.project=naaccord" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
        
    logs)
        docker compose -f "$PROJECT_DIR/docker-compose.dev.yml" --project-directory "$PROJECT_DIR" logs -f
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all Docker services"
        echo "  stop    - Stop all Docker services"
        echo "  restart - Restart all Docker services"
        echo "  status  - Check status of services"
        echo "  logs    - Show and follow Docker logs"
        exit 1
        ;;
esac