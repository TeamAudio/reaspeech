import logging
import os

from celery import Celery
from typing import Union, Callable
from whisper import tokenizer
import tqdm

from .util.audio import load_audio

logging.basicConfig(format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s', level=logging.INFO, force=True)
logger = logging.getLogger(__name__)

# monkeypatch tqdm to fool whisper's `transcribe` function
class _TQDM(tqdm.tqdm):
    _tqdm = tqdm.tqdm
    progress_function = None

    def __init__(self, *argv, total=0, unit="", **kwargs):
        logger.debug(f"Creating TQDM with total={total}, unit={unit}")
        self._total = total
        self._unit = unit
        self._progress = 0
        self.progress_function = _TQDM.progress_function or None
        super().__init__(*argv, **kwargs)

    def set_progress_function(progress_function: Callable[[str, int, int], None]):
        logger.debug(f"Setting progress function to {progress_function}")
        _TQDM.progress_function = progress_function

    def update(self, progress):
        logger.debug(f"Updating TQDM with progress={progress}")
        self._progress += progress
        if self.progress_function is not None:
            self.progress_function(self._unit, self._total, self._progress)
        else:
            _TQDM._tqdm.update(self, progress)

tqdm.tqdm = _TQDM

ASR_ENGINE = os.getenv("ASR_ENGINE", "faster_whisper")
if ASR_ENGINE == "faster_whisper":
    from .faster_whisper import core as asr_engine
elif ASR_ENGINE == "whisper_cpp":
    from .whisper_cpp import core as asr_engine
else:
    from .openai_whisper import core as asr_engine

LANGUAGE_CODES = sorted(list(tokenizer.LANGUAGES.keys()))

DEFAULT_MODEL_NAME = os.getenv("ASR_MODEL", "small")

STATES = {
    'loading_model': 'LOADING_MODEL',
    'encoding': 'ENCODING',
    'transcribing': 'TRANSCRIBING',
    'detecting_language': 'DETECTING_LANGUAGE',
}
celery = Celery(__name__)
celery.conf.broker_connection_retry_on_startup = True
celery.conf.broker_url = os.environ.get("CELERY_BROKER_URL", "sqla+sqlite:///celery.sqlite")
celery.conf.result_backend = os.environ.get("CELERY_RESULT_BACKEND", "db+sqlite:///results.sqlite")
celery.conf.worker_hijack_root_logger = False
celery.conf.worker_redirect_stdouts_level = "DEBUG"

@celery.task(name="transcribe", bind=True)
def transcribe(
    self,
    audio_file_path: str,
    original_filename: str,
    asr_options: dict,
):
    logger.info(f"Transcribing {audio_file_path} with {asr_options}")
    output_format = asr_options["output"]

    with open(audio_file_path, "rb") as audio_file:
        model_name = asr_options.get("model_name") or DEFAULT_MODEL_NAME
        logger.info(f"Loading model {model_name}")
        self.update_state(state=STATES["loading_model"], meta={"progress": {"units": "models", "total": 1, "current": 0}})
        _TQDM.set_progress_function(update_progress(self, STATES["loading_model"]))
        try:
            asr_engine.load_model(model_name)
        finally:
            _TQDM.set_progress_function(None)

        logger.info(f"Loading audio from {audio_file_path}")
        self.update_state(state=STATES["encoding"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
        audio_data = load_audio(audio_file, asr_options.get("encode", False))

        logger.info(f"Transcribing audio")
        self.update_state(state=STATES["transcribing"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
        _TQDM.set_progress_function(update_progress(self, STATES["transcribing"]))
        try:
            result = asr_engine.transcribe(audio_data, asr_options, output_format)
        finally:
            _TQDM.set_progress_function(None)

    logger.info(f"Transcription complete")

    os.remove(audio_file_path)

    filename = f"{self.request.id}.{output_format}"
    output_directory = get_output_path(self.request.id)
    output_path = f"{output_directory}/{filename}"

    logger.info(f"Writing result to {output_path}")

    if not os.path.exists(output_directory):
        os.makedirs(output_directory)

    with open(output_path, "w") as f:
        f.write(result.read())

    url_path = f"{get_output_url_path(transcribe.request.id)}/{filename}"

    return {
        "output_filename": filename,
        "output_path": output_path,
        "url_path": url_path,
    }

@celery.task(name="detect_language", bind=True)
def detect_language(self, audio_file_path: str, encode: bool):
    logger.info(f"Detecting language of {audio_file_path}")

    with open(audio_file_path, "rb") as audio_file:
        model_name = DEFAULT_MODEL_NAME
        logger.info(f"Loading model {model_name}")
        self.update_state(state=STATES["loading_model"], meta={"progress": {"units": "models", "total": 1, "current": 0}})
        asr_engine.load_model(model_name)

        logger.info(f"Loading audio from {audio_file_path}")
        self.update_state(state=STATES["encoding"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
        audio_data = load_audio(audio_file, encode)

        logger.info(f"Detecting audio language")
        self.update_state(state=STATES["detecting_language"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
        result = asr_engine.language_detection(audio_data)

    os.remove(audio_file_path)

    logger.info(f"Returning result in job state")

    result_object = { "language_code": result }

    return {
        "result": result_object
    }

def get_output_path(job_id: str):
    return os.environ.get("OUTPUT_DIRECTORY", os.getcwd() + "/app/output") + "/" + job_id

def get_output_url_path(job_id: str):
    return os.environ.get("OUTPUT_URL_PREFIX", "/output") + "/" + job_id

def update_progress(context, state):
    def do_update(units, total, current):
        logger.debug(f"Updating progress with units={units}, total={total}, current={current}")
        context.update_state(
            state=state,
            meta={"progress": {"units": units, "total": total, "current": current}}
        )
    return do_update
