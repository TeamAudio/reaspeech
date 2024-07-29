--[[

  TranscriptWord.lua - Transcript segment word with a start/end

]]--

TranscriptWord = Polo {}

function TranscriptWord:init()
  assert(self.word, 'missing word')
  assert(self.start, 'missing start')
  assert(self.end_, 'missing end_')
  assert(self.probability, 'missing probability')
end

function TranscriptWord:copy()
  return TranscriptWord.new {
    word = self.word,
    start = self.start,
    end_ = self.end_,
    probability = self.probability,
  }
end

function TranscriptWord:score()
  return self.probability
end

function TranscriptWord:to_table()
  return {
    word = self.word,
    start = self.start,
    ['end'] = self.end_,
    probability = self.probability,
  }
end

function TranscriptWord:select_in_timeline(offset)
  offset = offset or 0
  local start = self.start + offset
  local end_ = self.end_ + offset
  reaper.GetSet_LoopTimeRange(true, true, start, end_, false)
end
