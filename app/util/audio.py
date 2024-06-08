import os
from typing import BinaryIO

import ffmpeg
import numpy as np

SAMPLE_RATE = 16000

FFMPEG_BIN = os.getenv("FFMPEG_BIN", "ffmpeg")

def load_audio(file: BinaryIO, encode=True, sr: int = SAMPLE_RATE):
    """
    Open an audio file object and read as mono waveform, resampling as necessary.
    Modified from https://github.com/openai/whisper/blob/main/whisper/audio.py to accept a file object
    Parameters
    ----------
    file: BinaryIO
        The audio file like object
    encode: Boolean
        If true, encode audio stream to WAV before sending to whisper
    sr: int
        The sample rate to resample the audio if necessary
    Returns
    -------
    A NumPy array containing the audio waveform, in float32 dtype.
    """
    if encode:
        try:
            # This launches a subprocess to decode audio while down-mixing and resampling as necessary.
            # Requires the ffmpeg CLI and `ffmpeg-python` package to be installed.
            out, _ = (
                ffmpeg.input("pipe:", threads=0)
                .output("-", format="s16le", acodec="pcm_s16le", ac=1, ar=sr)
                .run(cmd=FFMPEG_BIN, capture_stdout=True, capture_stderr=True, input=file.read())
            )
        except ffmpeg.Error as e:
            raise RuntimeError(f"Failed to load audio: {e.stderr.decode()}") from e
    else:
        out = file.read()

    try:
        return np.frombuffer(out, np.int16).flatten().astype(np.float32) / 32768.0
    except Exception as e:
        # TODO: Unsupported file formats can raise the following exception:
        # ValueError: buffer size must be a multiple of element size
        # This should be made more robust.
        raise RuntimeError("Failed to load audio") from e
