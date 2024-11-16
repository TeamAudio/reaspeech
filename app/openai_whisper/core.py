# MIT License
#
# Copyright (c) 2022 Ahmet Oner & Besim Alibegovic
# Portions Copyright (c) 2024 Team Audio
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
from io import StringIO
from threading import Lock
from typing import BinaryIO, Union

import torch
import whisper
from whisper.utils import ResultWriter, WriteTXT, WriteSRT, WriteVTT, WriteTSV, WriteJSON
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

        if torch.cuda.is_available():
            model = whisper.load_model(next_model_name, download_root=model_path).cuda()
        else:
            model = whisper.load_model(next_model_name, download_root=model_path)

        model_name = next_model_name

        return model


def transcribe(audio, asr_options, output):
    options_dict = {k: v for k, v in asr_options.items() if k in ASR_ENGINE_OPTIONS}

    with model_lock:
        result = model.transcribe(audio, **options_dict)

    output_file = StringIO()
    write_result(result, output_file, output)
    output_file.seek(0)

    return output_file


def language_detection(audio):
    # load audio and pad/trim it to fit 30 seconds
    audio = whisper.pad_or_trim(audio)

    # make log-Mel spectrogram and move to the same device as the model
    mel = whisper.log_mel_spectrogram(audio).to(model.device)

    # detect the spoken language
    with model_lock:
        _, probs = model.detect_language(mel)
    detected_lang_code = max(probs, key=probs.get)

    return detected_lang_code


def write_result(
        result: dict, file: BinaryIO, output: Union[str, None]
):
    options = {
        'max_line_width': 1000,
        'max_line_count': 10,
        'highlight_words': False
    }
    if output == "srt":
        WriteSRT(ResultWriter).write_result(result, file=file, options=options)
    elif output == "vtt":
        WriteVTT(ResultWriter).write_result(result, file=file, options=options)
    elif output == "tsv":
        WriteTSV(ResultWriter).write_result(result, file=file, options=options)
    elif output == "json":
        WriteJSON(ResultWriter).write_result(result, file=file, options=options)
    elif output == "txt":
        WriteTXT(ResultWriter).write_result(result, file=file, options=options)
    else:
        return 'Please select an output method!'
