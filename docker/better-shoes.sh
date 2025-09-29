#!/bin/zsh

PROJECT_DIR="$HOME/code/better-shoes"

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
    if docker ps | grep -q better-shoes-postgres; then
        echo "${GREEN}✓${NC} PostgreSQL is running (container)"
    else
        echo "${RED}✗${NC} PostgreSQL is not running"
        all_running=false
    fi

    if docker ps | grep -q better-shoes-redis; then
        echo "${GREEN}✓${NC} Redis is running (container)"
    else
        echo "${RED}✗${NC} Redis is not running"
        all_running=false
    fi

    if docker ps | grep -q better-shoes-r-executor; then
        echo "${GREEN}✓${NC} R Executor is running (container)"
    else
        echo "${RED}✗${NC} R Executor is not running"
        all_running=false
    fi

    echo "-------------------------------------------"

    if $all_running; then
        return 0
    else
        return 1
    fi
}

# Function to backup Herd database if needed
backup_herd_db() {
    if nc -z localhost 5432 >/dev/null 2>&1; then
        echo "Detected Herd PostgreSQL running on port 5432"

        # Check if database exists
        if PGPASSWORD="" psql -h 127.0.0.1 -p 5432 -U root -d better_shoes -c "\dt" >/dev/null 2>&1; then
            mkdir -p "$PROJECT_DIR/storage/app/dumps"
            local backup_file="$PROJECT_DIR/storage/app/dumps/herd_backup_$(date +%Y%m%d_%H%M%S).sql"

            echo "Creating backup of Herd database..."
            PGPASSWORD="" pg_dump -h 127.0.0.1 -p 5432 -U root -d better_shoes \
                --no-owner --no-acl --clean --if-exists > "$backup_file"
            echo "${GREEN}✓${NC} Database backed up to: $(basename $backup_file)"
            return 0
        fi
    fi
    return 1
}

# Main script
echo "═══════════════════════════════════════════"
echo "Better Shoes Docker Services Manager"
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

        echo "Starting Docker services for Better Shoes..."
        echo ""

        # Backup Herd database if it exists
        if backup_herd_db; then
            echo ""
        fi

        # Update .env for containerized services
        cd "$PROJECT_DIR"

        # Backup .env if changing
        if ! grep -q "^DB_PORT=5433" .env; then
            cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

            # Update database port for containerized PostgreSQL
            sed -i '' 's/^DB_HOST=.*/DB_HOST=127.0.0.1/' .env
            sed -i '' 's/^DB_PORT=.*/DB_PORT=5433/' .env

            # Update Redis port for containerized Redis
            sed -i '' 's/^REDIS_HOST=.*/REDIS_HOST=127.0.0.1/' .env
            sed -i '' 's/^REDIS_PORT=.*/REDIS_PORT=6380/' .env

            echo "${GREEN}✓${NC} Updated .env for containerized services"
        fi

        # Start Docker Compose with dev overlay for ARM64 images
        docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres redis r-executor

        echo ""
        echo "Services started. Waiting for initialization..."

        # Wait for PostgreSQL to be ready
        wait_for_service "PostgreSQL" 5433

        # Restore database if backup exists
        local latest_dump=$(ls -t "$PROJECT_DIR/storage/app/dumps"/*.sql 2>/dev/null | head -1)
        if [ -n "$latest_dump" ] && docker exec better-shoes-postgres pg_isready -U root >/dev/null 2>&1; then
            echo "Restoring database from backup..."
            docker exec -i better-shoes-postgres psql -U root -d better_shoes < "$latest_dump"
            echo "${GREEN}✓${NC} Database restored"
        fi

        echo ""
        echo "═══════════════════════════════════════════"
        echo "${GREEN}✓ Docker services started successfully!${NC}"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "Services running:"
        echo "  • PostgreSQL : localhost:5433 (containerized)"
        echo "  • Redis      : localhost:6380 (containerized)"
        echo "  • R Executor : better-shoes-r-executor"
        echo ""
        echo "Database connection:"
        echo "  Host: 127.0.0.1"
        echo "  Port: 5433"
        echo "  Database: better_shoes"
        echo "  User: root"
        echo ""
        ;;

    stop)
        echo "Stopping Docker services..."
        cd "$PROJECT_DIR"
        docker compose -f docker-compose.yml -f docker-compose.dev.yml down
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
        docker ps --filter "name=better-shoes" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;

    logs)
        cd "$PROJECT_DIR"
        docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
        ;;

    shell)
        # Connect to R executor container
        docker exec -it better-shoes-r-executor bash
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|logs|shell}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all Docker services"
        echo "  stop    - Stop all Docker services"
        echo "  restart - Restart all Docker services"
        echo "  status  - Check status of services"
        echo "  logs    - Show and follow Docker logs"
        echo "  shell   - Open shell in R executor container"
        exit 1
        ;;
esac