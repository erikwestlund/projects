#!/bin/zsh

PROJECT_DIR="$HOME/code/naaccord"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════"
echo "Django Startup Diagnostics"
echo "═══════════════════════════════════════════"
echo ""

# Change to project directory
cd "$PROJECT_DIR" || {
    echo "${RED}✗${NC} Failed to change to project directory: $PROJECT_DIR"
    exit 1
}

# Check if venv exists
echo "1. Checking Python virtual environment..."
echo "-------------------------------------------"
if [ -d "venv" ]; then
    echo "${GREEN}✓${NC} Virtual environment exists"
    source venv/bin/activate
    echo "${GREEN}✓${NC} Virtual environment activated"
    echo "   Python: $(which python)"
    echo "   Version: $(python --version)"
else
    echo "${RED}✗${NC} Virtual environment not found!"
    exit 1
fi
echo ""

# Check if Django is installed
echo "2. Checking Django installation..."
echo "-------------------------------------------"
if python -c "import django; print(f'Django version: {django.get_version()}')" 2>/dev/null; then
    echo "${GREEN}✓${NC} Django is installed"
    python -c "import django; print(f'   Version: {django.get_version()}')"
else
    echo "${RED}✗${NC} Django is not installed!"
    echo "   Try: pip install -r requirements.txt"
    exit 1
fi
echo ""

# Check database connectivity
echo "3. Testing database connection..."
echo "-------------------------------------------"
echo "Attempting to connect to MariaDB..."

# First check if MariaDB is reachable
if nc -z localhost 3306 >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} MariaDB port 3306 is open"
else
    echo "${RED}✗${NC} MariaDB port 3306 is not reachable"
    exit 1
fi

# Try to import Django settings and test DB connection
echo "Testing Django database configuration..."
python << 'EOF'
import os
import sys
import django
from django.conf import settings

try:
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'depot.settings')
    django.setup()
    
    from django.db import connection
    
    # Try to connect
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        if result[0] == 1:
            print("✓ Django can connect to database")
            print(f"   Database: {connection.settings_dict['NAME']}")
            print(f"   Host: {connection.settings_dict['HOST']}")
            print(f"   Port: {connection.settings_dict['PORT']}")
            
except Exception as e:
    print(f"✗ Database connection failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo "${RED}✗${NC} Django database connection test failed"
    echo ""
    echo "Checking environment variables..."
    echo "   DATABASE_URL: ${DATABASE_URL:-Not set}"
    echo "   DJANGO_SETTINGS_MODULE: ${DJANGO_SETTINGS_MODULE:-Not set}"
    exit 1
fi
echo ""

# Check Redis connectivity
echo "4. Testing Redis connection..."
echo "-------------------------------------------"
if nc -z localhost 6379 >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} Redis port 6379 is open"
    
    # Test Redis with Django cache
    python << 'EOF'
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'depot.settings')
django.setup()

try:
    from django.core.cache import cache
    cache.set('test_key', 'test_value', 30)
    value = cache.get('test_key')
    if value == 'test_value':
        print("✓ Django can connect to Redis cache")
    else:
        print("⚠ Redis connection works but cache test failed")
except Exception as e:
    print(f"⚠ Redis cache test failed: {e}")
EOF
else
    echo "${RED}✗${NC} Redis port 6379 is not reachable"
fi
echo ""

# Check for migrations
echo "5. Checking database migrations..."
echo "-------------------------------------------"
python manage.py showmigrations --plan | head -20
MIGRATION_STATUS=$?
if [ $MIGRATION_STATUS -eq 0 ]; then
    echo "${GREEN}✓${NC} Can check migration status"
    
    # Check for unapplied migrations
    UNAPPLIED=$(python manage.py showmigrations --plan | grep -c "\[ \]")
    if [ $UNAPPLIED -gt 0 ]; then
        echo "${YELLOW}⚠${NC} There are $UNAPPLIED unapplied migrations"
        echo "   Run: python manage.py migrate"
    else
        echo "${GREEN}✓${NC} All migrations appear to be applied"
    fi
else
    echo "${RED}✗${NC} Cannot check migration status"
fi
echo ""

# Check if port 8000 is available
echo "6. Checking port availability..."
echo "-------------------------------------------"
if lsof -i :8000 >/dev/null 2>&1; then
    echo "${YELLOW}⚠${NC} Port 8000 is already in use:"
    lsof -i :8000 | grep LISTEN
    echo "   Kill the process or use a different port"
else
    echo "${GREEN}✓${NC} Port 8000 is available"
fi
echo ""

# Try to start Django
echo "7. Attempting to start Django server..."
echo "-------------------------------------------"
echo "Starting Django in test mode (will timeout after 10 seconds)..."
echo ""

# Start Django in background and capture output
timeout 10 python manage.py runserver 0.0.0.0:8000 2>&1 | tee /tmp/django_startup.log &
DJANGO_PID=$!

# Wait a bit for Django to start
sleep 3

# Check if Django is responding
if nc -z localhost 8000 >/dev/null 2>&1; then
    echo ""
    echo "${GREEN}✓${NC} Django server started successfully!"
    
    # Try to fetch the homepage
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ | grep -q "200\|301\|302"; then
        echo "${GREEN}✓${NC} Django is responding to HTTP requests"
    else
        echo "${YELLOW}⚠${NC} Django is running but not responding as expected"
    fi
else
    echo ""
    echo "${RED}✗${NC} Django failed to start on port 8000"
    echo ""
    echo "Last 20 lines of startup log:"
    echo "-------------------------------------------"
    tail -20 /tmp/django_startup.log
fi

# Kill the test Django process
kill $DJANGO_PID 2>/dev/null
wait $DJANGO_PID 2>/dev/null

echo ""
echo "═══════════════════════════════════════════"
echo "Diagnostics Complete"
echo "═══════════════════════════════════════════"
echo ""
echo "If Django failed to start, check:"
echo "  1. The startup log above for errors"
echo "  2. Your config/settings/local.py file"
echo "  3. Environment variables in .env file"
echo "  4. Database credentials and permissions"
echo ""