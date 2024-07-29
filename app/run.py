#!/usr/bin/env python

import os
import subprocess
import sys
import argparse

argmap = {
    '--redis-bin': {
        'default': 'redis-server',
        'help': 'Path to Redis server binary (default: %(default)s)' },
    '--celery-broker-url': {
        'default': 'redis://localhost:6379/0',
        'help': 'Celery broker URL (default: %(default)s)' },
    '--celery-result-backend-url': {
        'default': 'redis://localhost:6379/0',
        'help': 'Celery result backend URL (default: %(default)s)' },
    '--output-directory': {
        'default': 'app/output',
        'help': 'Output directory (default: %(default)s)' },
    '--output-url-prefix': {
        'default': '/output',
        'help': 'Output URL prefix (default: %(default)s)' },
    '--ffmpeg-bin': {
        'default': 'ffmpeg',
        'help': 'Path to ffmpeg binary (default: %(default)s)' },
    '--asr-engine': {
        'default': os.getenv('ASR_ENGINE', 'faster_whisper'),
        'help': 'ASR engine to use (default: %(default)s)' },
    '--asr-model': {
        'default': os.getenv('ASR_MODEL', 'small'),
        'help': 'ASR model to use (default: %(default)s)' },
    '--build-reascripts': {
        'action': 'store_true',
        'help': 'Build ReaScripts before starting' },
    '--enable-swagger-ui': {
        'action': 'store_true',
        'help': 'Enable automatic Swagger UI for API' },
}

parser = argparse.ArgumentParser()
for arg, kwargs in argmap.items():
    parser.add_argument(arg, **kwargs)

args = parser.parse_args()

os.environ['CELERY_BROKER_URL'] = args.celery_broker_url
os.environ['CELERY_RESULT_BACKEND'] = args.celery_result_backend_url
os.environ['OUTPUT_DIRECTORY'] = args.output_directory
os.environ['OUTPUT_URL_PREFIX'] = args.output_url_prefix
os.environ['FFMPEG_BIN'] = args.ffmpeg_bin
os.environ['ASR_ENGINE'] = args.asr_engine
os.environ['ASR_MODEL'] = args.asr_model

if args.build_reascripts:
    if os.system('cd reascripts/ReaSpeech && make') != 0:
        print('ReaScript build failed', file=sys.stderr)
        sys.exit(1)

if args.enable_swagger_ui:
    os.environ['ENABLE_SWAGGER_UI'] = '/docs'

processes = {}

# Start Redis
print('Starting database...', file=sys.stderr)
processes['redis'] = subprocess.Popen([args.redis_bin], stdout=subprocess.DEVNULL)

# Start Celery
print('Starting worker...', file=sys.stderr)
processes['celery'] = subprocess.Popen(['celery', '-A', 'app.worker.celery', 'worker', '--pool=solo', '--loglevel=info'])

# Start Gunicorn
print('Starting application...', file=sys.stderr)
processes['gunicorn'] = subprocess.Popen(['gunicorn', '--bind', '0.0.0.0:9000', '--workers', '1', '--timeout', '0', 'app.webservice:app', '-k', 'uvicorn.workers.UvicornWorker'])

# Wait for any process to exit
pid, waitstatus = os.wait()
exitcode = os.waitstatus_to_exitcode(waitstatus)
process_name = '<unknown>'
for name, p in processes.items():
    if p.pid == pid:
        process_name = name
        break
if exitcode < 0:
    print('Process', process_name, 'received signal', -exitcode, file=sys.stderr)
else:
    print('Process', process_name, 'exited with status', exitcode, file=sys.stderr)

# Terminate any child processes
print('Terminating child processes...', file=sys.stderr)
for name, p in processes.items():
    try:
        print('Terminating', name, file=sys.stderr)

        # kinda bass-ackwards, but poll() returns None if process is still running
        if not p.poll():
            p.terminate()
        else:
            print(name, "already exited", file=sys.stderr)
    except Exception as e:
        print(e, file=sys.stderr)

# Exit with status of process that exited
status = 1 if exitcode < 0 else exitcode
print('Exiting with status', status, file=sys.stderr)
sys.exit(status)
