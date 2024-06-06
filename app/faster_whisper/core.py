import os
from io import StringIO
from threading import Lock
from typing import Union, BinaryIO

import torch
import tqdm
import whisper
from faster_whisper import WhisperModel

from .utils import ResultWriter, WriteTXT, WriteSRT, WriteVTT, WriteTSV, WriteJSON

ASR_ENGINE_OPTIONS = frozenset([
    "task",
    "language",
    "initial_prompt",
    "vad_filter",
    "word_timestamps",
])

model_name = os.getenv("ASR_MODEL", "small")
model_path = os.getenv("ASR_MODEL_PATH", os.path.join(os.path.expanduser("~"), ".cache", "whisper"))

model_lock = Lock()

model = None
def load_model(next_model_name: str):
    with model_lock:
        global model_name, model

        if model and next_model_name == model_name:
            return model

        model_name = next_model_name

        if torch.cuda.is_available():
            model = WhisperModel(model_size_or_path=model_name, device="cuda", compute_type="float32", download_root=model_path)
        else:
            model = WhisperModel(model_size_or_path=model_name, device="cpu", compute_type="int8", download_root=model_path)

        return model


def transcribe(audio, asr_options, output):
    options_dict = {k: v for k, v in asr_options.items() if k in ASR_ENGINE_OPTIONS}

    with model_lock:
        segments = []
        text = ""
        segment_generator, info = model.transcribe(audio, beam_size=5, **options_dict)
        with tqdm.tqdm(total=round(info.duration), unit='sec') as tqdm_pbar:
            for segment in segment_generator:
                segment_dict = segment._asdict()
                if segment.words:
                    segment_dict["words"] = [word._asdict() for word in segment.words]
                segments.append(segment_dict)
                text = text + segment.text
                tqdm_pbar.update(segment.end - segment.start)
        result = {
            "language": options_dict.get("language", info.language),
            "segments": segments,
            "text": text
        }

    output_file = StringIO()
    write_result(result, output_file, output)
    output_file.seek(0)

    return output_file


def language_detection(audio):
    # load audio and pad/trim it to fit 30 seconds
    audio = whisper.pad_or_trim(audio)

    # detect the spoken language
    with model_lock:
        segments, info = model.transcribe(audio, beam_size=5)
        detected_lang_code = info.language

    return detected_lang_code


def write_result(
        result: dict, file: BinaryIO, output: Union[str, None]
):
    if output == "srt":
        WriteSRT(ResultWriter).write_result(result, file=file)
    elif output == "vtt":
        WriteVTT(ResultWriter).write_result(result, file=file)
    elif output == "tsv":
        WriteTSV(ResultWriter).write_result(result, file=file)
    elif output == "json":
        WriteJSON(ResultWriter).write_result(result, file=file)
    elif output == "txt":
        WriteTXT(ResultWriter).write_result(result, file=file)
    else:
        return 'Please select an output method!'
