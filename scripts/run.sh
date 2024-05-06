#!/bin/bash

export CELERY_BROKER_URL=redis://localhost:6379/0
export CELERY_RESULT_BACKEND=redis://localhost:6379/0
export OUTPUT_DIRECTORY=/app/app/output
export OUTPUT_URL_PREFIX=/output

# Start Redis
echo Starting database...
redis-server &

# Start Celery
echo Starting workers...
celery -A app.worker.celery worker -P solo --loglevel=info &

# Start Gunicorn
echo Starting application...
gunicorn --bind 0.0.0.0:9000 --workers 1 --timeout 0 app.webservice:app -k uvicorn.workers.UvicornWorker &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
