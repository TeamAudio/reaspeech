from typing import List
import numpy as np

from pywhispercpp.model import Model as BaseModel
import _pywhispercpp as pw

class Word:
    def __init__(self, t0: int, t1: int, text: str, p: float):
        self.t0 = t0
        self.t1 = t1
        self.text = text
        self.p = p

    def __str__(self):
        return f"t0={self.t0}, t1={self.t1}, text={self.text}, p={self.p}"

    def __repr__(self):
        return str(self)

class Segment:
    def __init__(self, t0: int, t1: int, text: str, words: List[Word]):
        self.t0 = t0
        self.t1 = t1
        self.text = text
        self.words = words

    def __str__(self):
        return f"t0={self.t0}, t1={self.t1}, text={self.text}, words={self.words}"

    def __repr__(self):
        return str(self)

class Model(BaseModel):
    def _transcribe(self, audio: np.ndarray, n_processors: int = None):
        if n_processors:
            pw.whisper_full_parallel(self._ctx, self._params, audio, audio.size, n_processors)
        else:
            pw.whisper_full(self._ctx, self._params, audio, audio.size)
        n = pw.whisper_full_n_segments(self._ctx)
        res = Model._get_segments_with_words(self._ctx, 0, n)
        return res

    @staticmethod
    def _get_segments_with_words(ctx, start: int, end: int) -> List[Segment]:
        n = pw.whisper_full_n_segments(ctx)
        assert end <= n, f"{end} > {n}: `End` index must be less or equal than the total number of segments"
        res = []
        for i in range(start, end):
            t0 = pw.whisper_full_get_segment_t0(ctx, i)
            t1 = pw.whisper_full_get_segment_t1(ctx, i)
            text = pw.whisper_full_get_segment_text(ctx, i)
            token_n = pw.whisper_full_n_tokens(ctx, i)
            words = []
            for j in range(0, token_n):
                if pw.whisper_full_get_token_id(ctx, i, j) >= pw.whisper_token_eot(ctx):
                    continue
                token_data = pw.whisper_full_get_token_data(ctx, i, j)
                token_text = pw.whisper_full_get_token_text(ctx, i, j)
                token_p = pw.whisper_full_get_token_p(ctx, i, j)
                if words and not token_text.startswith(' '):
                    words[-1].t1 = token_data.t1
                    words[-1].text += token_text.strip()
                else:
                    word = Word(token_data.t0, token_data.t1, token_text.strip(), token_p)
                    words.append(word)
            res.append(Segment(t0, t1, text.strip(), words))
        return res
