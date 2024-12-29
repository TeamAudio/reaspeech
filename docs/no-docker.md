### Running Outside of Docker

ReaSpeech can be run without using Docker. You will probably need Python 3.10. Other versions of Python may work, but this is the version we currently standardize on. Some of ReaSpeech's dependencies can be sensitive to the Python version.

Once you have the desired Python version installed, follow the [instructions to install Poetry](https://python-poetry.org/docs/#installation). Poetry is used to maintain the package versions that ReaSpeech's Python environment requires.

With Poetry installed, you can run it to install the Python library dependencies:

```
poetry install
```

You will also need to install the Redis database server. Instructions are available [here](https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/).

You should now be able to start ReaSpeech's services by running:

```
# Start all services
poetry run python3.10 app/run.py

# Start all services except for Redis
poetry run python3.10 app/run.py --no-start-redis

# For usage instructions
poetry run python3.10 app/run.py --help
```

Alternatively, you can start the processes manually:

```
redis-server &
poetry run python3.10 celery -A app.worker.celery worker --pool=solo --loglevel=info &
poetry run python3.10 gunicorn --bind 0.0.0.0:9000 --workers 1 --timeout 0 app.webservice:app -k uvicorn.workers.UvicornWorker &
```

See the source code to app/run.py for details. This is the same script that the Docker container runs when it starts.
