#!/usr/bin/env python

import argparse
import os
import signal
import subprocess
import sys
import time

argmap = {
    '--celery-broker-url': {
        'default': 'sqla+sqlite:///celery.sqlite',
        'help': 'Celery broker URL (default: %(default)s)' },
    '--celery-result-backend-url': {
        'default': 'db+sqlite:///results.sqlite',
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
        'const': 'publish5.4',
        'nargs': '?',
        'help': 'Build ReaScripts before starting. Optional value specifies target (default: %(const)s)' },
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
    print('Building ReaScripts...', file=sys.stderr)
    if os.system(f'cd reascripts/ReaSpeech && make {args.build_reascripts}') != 0:
        print('ReaScript build failed', file=sys.stderr)
        sys.exit(1)

if args.enable_swagger_ui:
    os.environ['ENABLE_SWAGGER_UI'] = '/docs'

shutdown_requested = False

def signal_handler(signum, frame):
    global shutdown_requested
    print('\nShutdown requested...', file=sys.stderr)
    shutdown_requested = True

# Set up signal handlers before starting processes
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

processes = {}

# Start Celery
print('Starting worker...', file=sys.stderr)
processes['celery'] = \
    subprocess.Popen([
        'celery',
        '-A', 'app.worker.celery',
        'worker',
        '--pool=solo',
        '--loglevel=info'
    ], start_new_session=True)

# Start Gunicorn
print('Starting application...', file=sys.stderr)
processes['gunicorn'] = \
    subprocess.Popen([
        'gunicorn',
        '--bind', '0.0.0.0:9000',
        '--workers', '1',
        '--timeout', '0',
        'app.webservice:app',
        '-k', 'uvicorn.workers.UvicornWorker'
    ], start_new_session=True)

exitcode = 0
process_name = '<unknown>'

while not shutdown_requested:
    try:
        pid, waitstatus = os.waitpid(-1, os.WNOHANG)
    except ChildProcessError:
        break
    if pid == 0:  # No process has exited
        time.sleep(0.1)
        continue

    exitcode = os.waitstatus_to_exitcode(waitstatus)
    for name, p in processes.items():
        if p.pid == pid:
            process_name = name
            break

    if exitcode < 0:
        print('Process', process_name, 'received signal', -exitcode, file=sys.stderr)
    else:
        print('Process', process_name, 'exited with status', exitcode, file=sys.stderr)
    shutdown_requested = True

# Graceful shutdown sequence
print('Initiating graceful shutdown...', file=sys.stderr)
for name, p in reversed(list(processes.items())):
    if name == process_name:
        continue
    try:
        print(f'Terminating {name}...', file=sys.stderr)
        p.terminate()
        try:
            p.wait(timeout=5)  # Give each process 5 seconds to shut down
        except subprocess.TimeoutExpired:
            print(f'Force killing {name}...', file=sys.stderr)
            p.kill()
    except Exception as e:
        print(f'Error shutting down {name}: {e}', file=sys.stderr)

# Exit with status of process that exited
status = 1 if exitcode < 0 else exitcode
print('Exiting with status', status, file=sys.stderr)
sys.exit(status)
