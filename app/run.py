#!/usr/bin/env python

import os
import subprocess
import sys

os.environ['CELERY_BROKER_URL'] = 'redis://localhost:6379/0'
os.environ['CELERY_RESULT_BACKEND'] = 'redis://localhost:6379/0'
os.environ['OUTPUT_DIRECTORY'] = '/app/app/output'
os.environ['OUTPUT_URL_PREFIX'] = '/output'

# Start Redis
print('Starting database...', file=sys.stderr)
subprocess.Popen(['redis-server'])

# Start Celery
print('Starting workers...', file=sys.stderr)
subprocess.Popen(['celery', '-A', 'app.worker.celery', 'worker', '--pool=solo', '--loglevel=info'])

# Start Gunicorn
print('Starting application...', file=sys.stderr)
subprocess.Popen(['gunicorn', '--bind', '0.0.0.0:9000', '--workers', '1', '--timeout', '0', 'app.webservice:app', '-k', 'uvicorn.workers.UvicornWorker'])

# Wait for any process to exit
status = os.WEXITSTATUS(os.wait()[1])
print('Process exited with status', status, file=sys.stderr)

# Terminate any child processes
print('Terminating child processes...', file=sys.stderr)
os.system('pkill -P %d' % os.getpid())

# Exit with status of process that exited
print('Exiting with status', status, file=sys.stderr)
sys.exit(status)
