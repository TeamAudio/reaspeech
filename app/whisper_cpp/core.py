import logging
import os
from io import StringIO
from threading import Lock
from typing import Union, BinaryIO

from pywhispercpp.model import Model

import json
from .constants import ASR_ENGINE_OPTIONS

logging.basicConfig(format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s', level=logging.INFO, force=True)
logger = logging.getLogger(__name__)

model_name = os.getenv("ASR_MODEL", "small")
model_path = os.getenv("ASR_MODEL_PATH", os.path.join(os.path.expanduser("~"), ".cache", "whisper"))

model_lock = Lock()

model = None
def load_model(next_model_name: str):
    with model_lock:
        global model_name, model

        if model and next_model_name == model_name:
            return model

        model = Model(next_model_name, models_dir=model_path)

        model_name = next_model_name

        return model


def build_options(asr_options):
    options_dict = {
        'language': asr_options.get('language'),
        'translate': asr_options.get('task', '') == 'translate',
        'token_timestamps': asr_options.get('split_on_word', False),
    }
    if asr_options.get('initial_prompt'):
        options_dict['initial_prompt'] = asr_options['initial_prompt']
    if asr_options.get('split_on_word'):
        options_dict['max_len'] = 1
        options_dict['split_on_word'] = True
    return options_dict


def transcribe(audio, asr_options, output):
    options_dict = build_options(asr_options)
    logger.info(f"whisper.cpp options: {options_dict}")

    with model_lock:
        segments = []
        text = ""
        segment_generator = model.transcribe(audio, **options_dict)
        for segment in segment_generator:
            segment_dict = {
                "start": float(segment.t0) / 100.0,
                "end": float(segment.t1) / 100.0,
                "text": segment.text,
            }
            segments.append(segment_dict)
            text = text + segment.text
        result = {
            "language": options_dict.get("language"),
            "segments": segments,
            "text": text
        }

    output_file = StringIO()
    write_result(result, output_file, output)
    output_file.seek(0)

    return output_file


# def language_detection(audio):
    # load audio and pad/trim it to fit 30 seconds
    # audio = whisper.pad_or_trim(audio)

    # detect the spoken language
    # with model_lock:
        # segments, info = model.transcribe(audio, beam_size=5)
        # detected_lang_code = info.language

    # return detected_lang_code


def write_result(
        result: dict, file: BinaryIO, output: Union[str, None]
):
    if output == "json":
        json.dump(result, file)
    else:
        return 'Please select an output method!'
