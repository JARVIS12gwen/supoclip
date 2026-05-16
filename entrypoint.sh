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
    # Pin to version 6 to avoid Prisma 7 breaking changes
    npx prisma@6.19.3 generate
    npx prisma@6.19.3 db push --accept-data-loss

fi

# Start Backend (FastAPI with Uvicorn)
echo "Starting backend (FastAPI)..."
cd /app/backend
export PYTHONPATH=$PYTHONPATH:/app/backend
# Use uvicorn to start the server so it listens on port 8000
/root/.local/bin/uv run uvicorn src.main:app --host 0.0.0.0 --port 8000 &

# Start Worker (Arq)
echo "Starting background worker (Arq)..."
/root/.local/bin/uv run python -m src.worker_main &

# Start Frontend (Standalone Next.js)
echo "Starting frontend (Next.js Standalone)..."
cd /app/frontend
export PORT=3107
export HOSTNAME="0.0.0.0"
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
