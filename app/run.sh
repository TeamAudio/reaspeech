#!/bin/bash

# Start Redis
echo Starting Redis...
redis-server &

# Start application
echo Starting Gunicorn...
gunicorn --bind 0.0.0.0:9000 --workers 1 --timeout 0 app.webservice:app -k uvicorn.workers.UvicornWorker &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
