#!/bin/bash

# Start Nginx
service nginx start

# Start Backend
cd /app/backend
/root/.local/bin/uv run python -m app.main &

# Start Worker
/root/.local/bin/uv run python -m arq app.worker.WorkerSettings &

# Start Frontend
cd /app/frontend
npm start &

# Wait for all processes to finish
wait -n

# Exit with status of process that exited first
exit $?
