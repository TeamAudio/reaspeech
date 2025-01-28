### Running Outside of Docker

ReaSpeech can be run without using Docker. You will probably need Python 3.10. Other versions of Python may work, but this is the version we currently standardize on. Some of ReaSpeech's dependencies can be sensitive to the Python version.

Once you have the desired Python version installed, follow the [instructions to install Poetry](https://python-poetry.org/docs/#installation). Poetry is used to maintain the package versions that ReaSpeech's Python environment requires.

With Poetry installed, you can run it to install the Python library dependencies:

```
poetry install
```

You should now be able to start ReaSpeech's services by running:

```
# Start all services
poetry run python3.10 app/run.py

# For usage instructions
poetry run python3.10 app/run.py --help
```

Alternatively, you can start the processes manually:

```
poetry run python3.10 celery -A app.worker.celery worker --pool=solo --loglevel=info &
poetry run python3.10 gunicorn --bind 0.0.0.0:9000 --workers 1 --timeout 0 app.webservice:app -k uvicorn.workers.UvicornWorker &
```

See the source code to app/run.py for details. This is the same script that the Docker container runs when it starts.

### Apple Silicon GPU

The whisper.cpp engine can do GPU-accelerated transcription on Apple Silicon (M1-M4, etc.) GPUs. Support for these GPUs requires running ReaSpeech outside of Docker. The following instructions should help you get started:

```
Install Xcode Command Line Tools (if necessary)
xcode-select --install

Install Homebrew (if necessary)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Install Lua and Python
brew install lua@5.4 python@3.10 ffmpeg

Install Poetry
curl -sSL https://install.python-poetry.org | python3.10 -

Clone the repo
git clone https://github.com/TeamAudio/reaspeech.git

Install the Python dependencies
cd reaspeech
poetry install

Run the ReaSpeech service
ASR_ENGINE=whisper_cpp poetry run python3.10 app/run.py --build-reascripts
```

Please note that there are a few limitations to running the whisper.cpp ASR engine:

1. whisper.cpp timestamps are less accurate than openai-whisper or faster-whisper
2. Word-level timestamps, in particular, can be progressively less accurate within a segment
3. Not all features of the openai-whisper or faster-whisper engines are supported

That said, enabling GPU support can significantly speed up transcription times. If you have an Apple Silicon GPU, we recommend giving it a try.