import logging
import os

from celery import Celery
from typing import Union, Callable
from whisper import tokenizer
import tqdm

from .util.audio import load_audio

# monkeypatch tqdm to fool whisper's `transcribe` function
class _TQDM(tqdm.tqdm):
    _tqdm = tqdm.tqdm
    progress_function = None

    def __init__(self, *argv, total=0, unit="", **kwargs):
        logging.info(f"Creating TQDM with total={total}, unit={unit}")
        self._total = total
        self._unit = unit
        self._progress = 0
        self.progress_function = _TQDM.progress_function or None
        super().__init__(*argv, **kwargs)

    def set_progress_function(progress_function: Callable[[str, int, int], None]):
        logging.info(f"Setting progress function to {progress_function}")
        _TQDM.progress_function = progress_function

    def update(self, progress):
        logging.info(f"Updating TQDM with progress={progress}")
        self._progress += progress
        if self.progress_function is not None:
            self.progress_function(self._unit, self._total, self._progress)
        else:
            _TQDM._tqdm.update(self, progress)

tqdm.tqdm = _TQDM

ASR_ENGINE = os.getenv("ASR_ENGINE", "faster_whisper")
if ASR_ENGINE == "faster_whisper":
    from .faster_whisper.core import load_model, transcribe as whisper_transcribe
else:
    from .openai_whisper.core import load_model, transcribe as whisper_transcribe

LANGUAGE_CODES = sorted(list(tokenizer.LANGUAGES.keys()))

DEFAULT_MODEL_NAME = os.getenv("ASR_MODEL", "small")

STATES = {
    'loading_model': 'LOADING_MODEL',
    'encoding': 'ENCODING',
    'transcribing': 'TRANSCRIBING',
}
celery = Celery(__name__)
celery.conf.broker_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379")
celery.conf.result_backend = os.environ.get("CELERY_RESULT_BACKEND", "redis://localhost:6379")

@celery.task(name="transcribe", bind=True)
def transcribe(
    self,
    language: Union[str, None],
    initial_prompt: Union[str, None],
    audio_file_path: str,
    original_filename: str,
    encode: Union[bool, None],
    output_format: Union[str, None],
    vad_filter: Union[bool, None],
    word_timestamps: Union[bool, None],
    model_name: str = DEFAULT_MODEL_NAME
):
    logging.info(f"Transcribing {audio_file_path} with language={language}, initial_prompt={initial_prompt}, encode={encode}, output_format={output_format}, vad_filter={vad_filter}, word_timestamps={word_timestamps}")

    with open(audio_file_path, "rb") as audio_file:
        _TQDM.set_progress_function(update_progress(self))

        try:
            logging.info(f"Loading model {model_name}")
            self.update_state(state=STATES["loading_model"], meta={"progress": {"units": "models", "total": 1, "current": 0}})
            load_model(model_name)

            logging.info(f"Loading audio from {audio_file_path}")
            self.update_state(state=STATES["encoding"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
            audio_data = load_audio(audio_file, encode)

            logging.info(f"Transcribing audio")
            self.update_state(state=STATES["transcribing"], meta={"progress": {"units": "files", "total": 1, "current": 0}})
            result = whisper_transcribe(audio_data, "transcribe", language, initial_prompt, vad_filter, word_timestamps, output_format)
        finally:
            _TQDM.set_progress_function(None)

    logging.info(f"Transcription complete")

    os.remove(audio_file_path)

    filename = f"{original_filename.encode('latin-1', 'ignore').decode()}.{output_format}"
    output_directory = get_output_path(self.request.id)
    output_path = f"{output_directory}/{filename}"

    logging.info(f"Writing result to {output_path}")

    if not os.path.exists(output_directory):
        os.makedirs(output_directory)

    with open(output_path, "w") as f:
        f.write(result.read())

    url = f"{get_output_url_path(transcribe.request.id)}/{filename}"

    logging.info(f"Result written to {output_path}, URL: {url}")

    return {
        "url": url
    }

def get_output_path(job_id: str):
    return os.environ.get("OUTPUT_DIRECTORY", os.getcwd() + "/app/output") + "/" + job_id

def get_output_url_path(job_id: str):
    return os.environ.get("OUTPUT_URL_PREFIX", "/output") + "/" + job_id

def update_progress(context):
    def do_update(units, total, current):
        logging.info(f"Updating progress with units={units}, total={total}, current={current}")
        context.update_state(
            state=STATES["transcribing"],
            meta={"progress": {"units": units, "total": total, "current": current}}
        )
    return do_update
