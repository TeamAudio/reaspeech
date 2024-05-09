#!/usr/bin/env python

import os
import subprocess
import sys
import argparse

argmap = {
    '--redis-bin': {
        'default': 'redis-server',
        'help': 'Path to Redis server binary' },
    '--celery-broker-url': {
        'default': 'redis://localhost:6379/0',
        'help': 'Celery broker URL' },
    '--celery-result-backend-url': {
        'default': 'redis://localhost:6379/0',
        'help': 'Celery result backend URL' },
    '--output-directory': {
        'default': '/app/app/output',
        'help': 'Output directory' },
    '--output-url-prefix': {
        'default': '/output',
        'help': 'Output URL prefix' },
    '--ffmpeg-bin': {
        'default': 'ffmpeg',
        'help': 'Path to ffmpeg binary' },
    '--asr-engine': {
        'default': os.getenv('ASR_ENGINE', 'faster_whisper'),
        'help': 'ASR engine to use' },
    '--asr-model': {
        'default': os.getenv('ASR_MODEL', 'small'),
        'help': 'ASR model to use' },
}

parser = argparse.ArgumentParser()
for arg, kwargs in argmap.items():
    parser.add_argument(arg, **kwargs)

args = parser.parse_args()

if args.help:
    parser.print_help()
    sys.exit(0)

os.environ['CELERY_BROKER_URL'] = args.celery_broker_url
os.environ['CELERY_RESULT_BACKEND'] = args.celery_result_backend_url
os.environ['OUTPUT_DIRECTORY'] = args.output_directory
os.environ['OUTPUT_URL_PREFIX'] = args.output_url_prefix
os.environ['FFMPEG_BIN'] = args.ffmpeg_bin
os.environ['ASR_ENGINE'] = args.asr_engine
os.environ['ASR_MODEL'] = args.asr_model

# Start Redis
print('Starting database...', file=sys.stderr)
subprocess.Popen([args.redis_bin])

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
