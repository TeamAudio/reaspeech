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
        self._total = total
        self._unit = unit
        self._progress = 0
        self.progress_function = _TQDM.progress_function or None
        super().__init__(*argv, **kwargs)

    def set_progress_function(progress_function: Callable[[str, int, int], None]):
        _TQDM.progress_function = progress_function

    def update(self, progress):
        self._progress += progress
        if self.progress_function is not None:
            self.progress_function(self._unit, self._total, self._progress)
        else:
            _TQDM._tqdm.update(self, progress)

tqdm.tqdm = _TQDM

ASR_ENGINE = os.getenv("ASR_ENGINE", "faster_whisper")
if ASR_ENGINE == "faster_whisper":
    from .faster_whisper.core import transcribe as whisper_transcribe
else:
    from .openai_whisper.core import transcribe as whisper_transcribe

LANGUAGE_CODES = sorted(list(tokenizer.LANGUAGES.keys()))

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
    word_timestamps: Union[bool, None]
):
    self.update_state(state="ENCODING", meta={"units": "files", "total": 1, "current": 0})
    audio_file = open(audio_file_path, "rb")

    _TQDM.set_progress_function(update_progress(self))
    result = whisper_transcribe(load_audio(audio_file, encode), "transcribe", language, initial_prompt, vad_filter, word_timestamps, output_format)
    _TQDM.set_progress_function(None)
    audio_file.close()
    os.remove(audio_file_path)

    filename = f"{original_filename.encode('latin-1', 'ignore').decode()}.{output_format}"
    output_directory = get_output_path(self.request.id)
    output_path = f"{output_directory}/{filename}"

    if not os.path.exists(output_directory):
        os.makedirs(output_directory)

    f = open(output_path, "w")
    f.write(result.read())
    f.close()

    url = f"{get_output_url_path(transcribe.request.id)}/{filename}"

    return {
        "url": url
    }

def get_output_path(job_id: str):
    return os.environ.get("OUTPUT_DIRECTORY", os.getcwd() + "/app/output") + "/" + job_id

def get_output_url_path(job_id: str):
    return os.environ.get("OUTPUT_URL", "/output") + "/" + job_id

def update_progress(context):
    return lambda units, total, current: context.update_state(state="TRANSCRIBING", meta={"units": units, "total": total, "current": current})