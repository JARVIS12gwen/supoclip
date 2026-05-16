#!/bin/bash
set -e

echo "===== Application Startup at $(date) ====="

# Start Redis
echo "Starting redis-server..."
redis-server --daemonize yes
sleep 1

# Start Nginx
echo "Starting nginx..."
service nginx start

# Sync Database (Frontend)
echo "Synchronizing database schema..."
cd /app/frontend
if [ -z "$DATABASE_URL" ]; then
    echo "WARNING: DATABASE_URL is not set. Skipping DB sync."
else
    # Run prisma generate again just in case it's needed for the engine path
    npx prisma generate
    npx prisma db push --accept-data-loss
fi

# Start Backend
echo "Starting backend (FastAPI)..."
cd /app/backend
export PYTHONPATH=$PYTHONPATH:/app/backend
/root/.local/bin/uv run python -m src.main &

# Start Worker
echo "Starting background worker (Arq)..."
/root/.local/bin/uv run python -m src.worker_main &

# Start Frontend (Standalone Next.js)
echo "Starting frontend (Next.js Standalone)..."
cd /app/frontend
export PORT=3107
if [ -f "server.js" ]; then
    node server.js &
else
    echo "ERROR: server.js not found in /app/frontend. Attempting npm start..."
    npm start -- --port 3107 &
fi

# Wait for all processes to finish
echo "All processes started. Waiting..."
wait -n

# Exit with status of process that exited first
exit $?
