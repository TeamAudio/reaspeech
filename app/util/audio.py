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

from typing import BinaryIO, Union
import os

import ffmpeg
import numpy as np

SAMPLE_RATE = 16000

FFMPEG_BIN = os.getenv("FFMPEG_BIN", "ffmpeg")

def load_audio(file: Union[BinaryIO, str], encode=True, sr: int = SAMPLE_RATE):
    """
    Open an audio file object or file path and read as mono waveform, resampling as necessary.
    Modified from https://github.com/openai/whisper/blob/main/whisper/audio.py to accept a file object or file path.
    Parameters
    ----------
    file: Union[BinaryIO, str]
        The audio file like object or file path
    encode: Boolean
        If true, encode audio stream to WAV before sending to whisper
    sr: int
        The sample rate to resample the audio if necessary
    Returns
    -------
    A NumPy array containing the audio waveform, in float32 dtype.
    """
    is_path = isinstance(file, str)
    if encode:
        input_source = file if is_path else "pipe:"
        pipe_input = None if is_path else file.read()
        try:
            # This launches a subprocess to decode audio while down-mixing and resampling as necessary.
            # Requires the ffmpeg CLI and `ffmpeg-python` package to be installed.
            out, _ = (
                ffmpeg.input(input_source, threads=0)
                .output("-", format="s16le", acodec="pcm_s16le", ac=1, ar=sr)
                .run(cmd=FFMPEG_BIN, capture_stdout=True, capture_stderr=True, input=pipe_input)
            )
        except ffmpeg.Error as e:
            raise RuntimeError(f"Failed to load audio: {e.stderr.decode()}") from e
    elif is_path:
        with open(file, 'rb') as f:
            out = f.read()
    else:
        out = file.read()

    try:
        return np.frombuffer(out, np.int16).flatten().astype(np.float32) / 32768.0
    except Exception as e:
        # TODO: Unsupported file formats can raise the following exception:
        # ValueError: buffer size must be a multiple of element size
        # This should be made more robust.
        raise RuntimeError("Failed to load audio") from e
