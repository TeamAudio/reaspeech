--[[

  FuzzyWordMatcher.lua - match needle phrases against track transcripts

  Matching runs locally via TextNormalizer + FuzzyAligner; no backend
  service is involved. The async job interface consumed by MatchingEngine
  is preserved, but instead of polling a remote job, each is_ready() call
  performs one unit of work (preparing or matching one track), so matching
  cooperates with the UI frame loop that drives the polling interval.

  Prepared word streams are cached per track + transcript file, so only
  the first needle after a transcript change pays the preparation cost.

]]--

FuzzyWordMatcher = Polo {
  key = 'fuzzy_word',

  MAX_MATCHES_PER_TRACK = 25,

  -- Very short needles ("Yeah?") occur all over a session; require
  -- near-exact matches for them.
  SHORT_NEEDLE_TOKENS = 3,
  SHORT_NEEDLE_MIN_CONFIDENCE = 0.8,

  -- The long-shot rescue tier: a weak lead beats silent zero. Only
  -- runs when the normal pass finds nothing.
  LONG_SHOT_MIN_CONFIDENCE = 0.3,
  SHORT_NEEDLE_LONG_SHOT_MIN_CONFIDENCE = 0.5,
  LONG_SHOT_MAX_MATCHES = 3,
}

function FuzzyWordMatcher:init()
  Logging().init(self, 'FuzzyWordMatcher')

  assert(self.session_id, 'FuzzyWordMatcher: session_id is required')
  assert(self.workflow, 'FuzzyWordMatcher: workflow is required')

  self.async_status = 'idle'
  self.async_results = nil
  self.async_error_message = nil

  self._work_queue = {}
  self._suggestions = nil
  -- Injectable so the workflow can share one cache across matcher
  -- instances (a new matcher is built per generation run)
  self._stream_cache = self.stream_cache or {}

  self:log("Initialized FuzzyWordMatcher")
end

function FuzzyWordMatcher:name()
  return "Fuzzy Word Matcher"
end

-- Synchronous matching; also the core the async interface drives.
function FuzzyWordMatcher:match(needle)
  local tokens, options = self:_needle_tokens(needle)
  if #tokens == 0 then return {} end

  local suggestions = {}
  for _, audio_track in ipairs(self.workflow:audio_tracks()) do
    self:_match_track(tokens, options, audio_track, suggestions)
  end

  -- Long-shot rescue: when nothing clears the normal floor, offer the
  -- best weak alignments (marked) rather than silence
  if #suggestions == 0 then
    local rescue = self:_long_shot_options(options)
    for _, audio_track in ipairs(self.workflow:audio_tracks()) do
      self:_match_track(tokens, rescue, audio_track, suggestions)
    end
  end

  table.sort(suggestions, function(a, b) return a.confidence > b.confidence end)
  self:log("Generated " .. #suggestions .. " suggestions")
  return suggestions
end

-- Rescue-pass options: a lower floor and a tighter cap, results
-- marked long_shot for the UI. Short needles keep a higher rescue
-- floor - two tokens at 0.3 confidence is noise, not guidance.
function FuzzyWordMatcher:_long_shot_options(options)
  return {
    max_matches = self.LONG_SHOT_MAX_MATCHES,
    min_confidence = options.min_confidence
      and self.SHORT_NEEDLE_LONG_SHOT_MIN_CONFIDENCE
      or self.LONG_SHOT_MIN_CONFIDENCE,
    long_shot = true,
  }
end

-- ================================================================================
-- ASYNC JOB INTERFACE
-- ================================================================================

function FuzzyWordMatcher:start_async_generation(needle)
  if self.async_status == 'running' then
    self:log("Cannot start async generation - job already in progress")
    return false
  end

  local tokens, options = self:_needle_tokens(needle)
  if #tokens == 0 then
    self:log("Needle has no matchable words after normalization: " .. needle.content)
  end

  self.async_results = nil
  self.async_error_message = nil
  self._suggestions = {}
  self._work_queue = {}
  self._async_tokens = tokens
  self._async_options = options
  self._long_shot_pass = false

  if #tokens > 0 then
    for _, audio_track in ipairs(self.workflow:audio_tracks()) do
      table.insert(self._work_queue, {
        tokens = tokens,
        options = options,
        audio_track = audio_track,
      })
    end
  end

  self.async_status = 'running'
  self:log("Starting local matching for needle: " .. needle.content
    .. " (" .. #self._work_queue .. " tracks)")
  return true
end

-- Performs one unit of work (one track) per call; returns true once all
-- tracks have been matched or an error occurred.
function FuzzyWordMatcher:is_ready()
  if self.async_status ~= 'running' then
    return true
  end

  local work = table.remove(self._work_queue, 1)
  if work then
    local ok, err = pcall(function()
      self:_match_track(work.tokens, work.options, work.audio_track, self._suggestions)
    end)
    if not ok then
      self:log("ERROR: Matching failed: " .. tostring(err))
      self.async_status = 'error'
      self.async_error_message = "Matching failed: " .. tostring(err)
      return true
    end
  end

  if #self._work_queue == 0 then
    -- Long-shot rescue, same as the sync path: an empty first pass
    -- refills the queue once with the lowered floor
    if #self._suggestions == 0 and not self._long_shot_pass
      and self._async_tokens and #self._async_tokens > 0
    then
      self._long_shot_pass = true
      local rescue = self:_long_shot_options(self._async_options)
      for _, audio_track in ipairs(self.workflow:audio_tracks()) do
        table.insert(self._work_queue, {
          tokens = self._async_tokens,
          options = rescue,
          audio_track = audio_track,
        })
      end
      return false
    end

    table.sort(self._suggestions, function(a, b) return a.confidence > b.confidence end)
    self.async_results = self._suggestions
    self._suggestions = nil
    self.async_status = 'completed'
    self:log("Completed with " .. #self.async_results .. " suggestions")
    return true
  end

  return false
end

function FuzzyWordMatcher:get_results()
  if self.async_status == 'completed' then
    return self.async_results
  elseif self.async_status == 'error' then
    return nil, self.async_error_message
  else
    return nil, "Job not ready (status: " .. (self.async_status or 'uninitialized') .. ")"
  end
end

function FuzzyWordMatcher:has_error()
  return self.async_status == 'error'
end

function FuzzyWordMatcher:get_status()
  return self.async_status or 'idle'
end

function FuzzyWordMatcher:cancel()
  if self.async_status == 'running' then
    self:log("Cancelling matching job")
    self._work_queue = {}
    self._suggestions = nil
    self.async_status = 'idle'
    self.async_results = nil
    self.async_error_message = nil
    return true
  end
  return false
end

-- ================================================================================
-- MATCHING
-- ================================================================================

function FuzzyWordMatcher:_needle_tokens(needle)
  local text = TextNormalizer.strip_stage_directions(needle.content)
  local tokens = TextNormalizer.tokenize(text)

  local options = { max_matches = self.MAX_MATCHES_PER_TRACK }
  if #tokens <= self.SHORT_NEEDLE_TOKENS then
    options.min_confidence = self.SHORT_NEEDLE_MIN_CONFIDENCE
  end

  return tokens, options
end

function FuzzyWordMatcher:_match_track(tokens, options, audio_track, suggestions)
  local entry = self:_prepared_stream(audio_track)
  if not entry then return end

  for _, match in ipairs(FuzzyAligner.find_matches(tokens, entry.prepared, options)) do
    local first_word = entry.words[match.start_index]
    local last_word = entry.words[match.end_index]

    local matching_text_parts = {}
    for i = match.start_index, match.end_index do
      table.insert(matching_text_parts, entry.words[i].text)
    end

    table.insert(suggestions, {
      start_time = first_word.start_time,
      end_time = last_word.end_time,
      file = first_word.file,
      matching_text = table.concat(matching_text_parts, " "),
      track_guids = { audio_track.guid },
      confidence = match.confidence,
      matched_count = match.matched_count,
      match_type = "fuzzy",
      long_shot = options.long_shot or nil,
    })
  end
end

-- Load and prepare a track's transcript word stream, cached per track and
-- transcript file so repeated needles skip the import and tokenization.
function FuzzyWordMatcher:_prepared_stream(audio_track)
  local transcript_file = self:_transcript_file(audio_track)
  if not transcript_file then
    self:log("No transcript found for track: " .. audio_track.guid)
    return nil
  end

  local cache_key = audio_track.guid .. '\0' .. transcript_file
  local entry = self._stream_cache[cache_key]
  if entry then return entry end

  local transcript = TranscriptImporter:import(transcript_file)
  local words = self:create_word_stream_from_transcript(transcript)
  local texts = {}
  for i, word in ipairs(words) do
    texts[i] = word.text
  end

  entry = {
    words = words,
    prepared = FuzzyAligner.prepare_stream(texts),
  }
  self._stream_cache[cache_key] = entry
  self:log("Prepared word stream for track " .. audio_track.guid
    .. " (" .. #words .. " words)")
  return entry
end

function FuzzyWordMatcher:_transcript_file(audio_track)
  local track = self.workflow:audio_track(audio_track.guid)
  if not track or not track.metadata_layers then
    return nil
  end

  for _, layer in ipairs(track.metadata_layers) do
    if layer.key == TranscriptMetadataLayer.key then
      return layer.config.transcript_file
    end
  end
end

-- A `Transcript` instance provides some useful methods to create a word stream from the audio track metadata.
-- Assuming a `Transcript` instance `t`:
--   - `t:get_segments()` returns the flat list of segments as `TranscriptSegment` instances.
--   - `t:has_words()` returns true if the transcript segments have a `words` property, which is a collection of `TranscriptWord` instances.
-- Assuming a `TranscriptSegment` instance `s`: its JSON-derived fields
-- live in `s.data` ('start', 'end', 'text', 'file' - the source filename
-- sans extension), while `s.words` holds `TranscriptWord` instances and
-- `s.item` / `s.take` hold REAPER objects when available.
-- Assuming a `TranscriptWord` instance `w`:
--  - `w.word`: the word text.
--  - `w.start`: the start time of the word.
--  - `w.end_`: the end time of the word.
--  - `w.probability`: the probability of the word being correct.
-- TranscriptSegment keeps its JSON fields (file, text, start, end) in the
-- segment's `data` table; plain-table segments may carry them directly
local function segment_field(segment, key)
  if segment.data and segment.data[key] ~= nil then
    return segment.data[key]
  end
  return segment[key]
end

function FuzzyWordMatcher:create_word_stream_from_transcript(transcript)
  local word_stream = {}

  local has_words = transcript:has_words()
  for _, segment in ipairs(transcript:get_segments()) do
    local words = has_words and segment.words or self:create_words_from_segment_text(segment)
    local segment_file = segment_field(segment, 'file')

    for _, word in ipairs(words) do
      table.insert(word_stream, {
        text = word.word,
        start_time = word.start,
        end_time = word.end_,
        probability = word.probability,
        file = segment_file,
      })
    end
  end

  return word_stream
end

-- Create a collection of `TranscriptWord`s from the segment text, applying start/end times
-- that are proportional to each word's position in the segment text and the word's length.
function FuzzyWordMatcher:create_words_from_segment_text(segment)
  local segment_words = {}

  local segment_text = segment_field(segment, 'text') or ''
  local segment_start = segment_field(segment, 'start') or 0
  local segment_end = segment_field(segment, 'end') or segment.end_ or segment_start

  local words = segment_text:split(' ')
  local segment_duration = segment_end - segment_start
  local word_duration = segment_duration / #words
  for i, word_text in ipairs(words) do
    local start_time = segment_start + (i - 1) * word_duration
    local end_time = start_time + word_duration

    table.insert(segment_words, {
      word = word_text,
      start = start_time,
      end_ = end_time,
      probability = 1.0, -- High confidence for segments without words
    })
  end

  return segment_words
end
