from io import StringIO
from threading import Lock
from typing import BinaryIO
import json
import os

from huggingface_hub import snapshot_download
import mlx_whisper

from .constants import ASR_ENGINE_OPTIONS

model_name = os.getenv("ASR_MODEL", "small")
model_path = os.getenv("ASR_MODEL_PATH", os.path.join(os.path.expanduser("~"), ".cache", "whisper"))

model_lock = Lock()

model = None
def load_model(next_model_name: str):
    with model_lock:
        global model_name, model

        if model and next_model_name == model_name:
            return model

        model = snapshot_download(f"mlx-community/whisper-{next_model_name}-mlx", cache_dir=model_path)

        model_name = next_model_name

        return model


def transcribe(audio, asr_options, output):
    options_dict = {k: v for k, v in asr_options.items() if k in ASR_ENGINE_OPTIONS}

    with model_lock:
        result = mlx_whisper.transcribe(audio, path_or_hf_repo=model, **options_dict)

    output_file = StringIO()
    write_result(result, output_file, output)
    output_file.seek(0)

    return output_file


def language_detection(_audio):
    raise NotImplementedError("language detection not implemented for mlx-whisper")


def write_result(result: dict, file: BinaryIO, output):
    if output == "json":
        json.dump(result, file)
    else:
        return 'Please select an output method!'
