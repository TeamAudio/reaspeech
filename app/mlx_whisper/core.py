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
from typing import BinaryIO
from huggingface_hub import snapshot_download
import json
import mlx_whisper
from .constants import ASR_ENGINE_OPTIONS

model_name = os.getenv("ASR_MODEL", "mlx-community/whisper-medium-mlx")
model_path = os.getenv("ASR_MODEL_PATH", os.path.join(os.path.expanduser("~"), ".cache", "whisper"))

model_lock = Lock()

model = None
def load_model(next_model_name: str):
    with model_lock:
        global model_name, model

        if model and next_model_name == model_name:
            return model

        model = snapshot_download(next_model_name, cache_dir=model_path)

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

def write_result(result: dict, file: BinaryIO, output):
  if output == "json":
    json.dump(result, file)
  else:
    return 'Please select an output method!'
