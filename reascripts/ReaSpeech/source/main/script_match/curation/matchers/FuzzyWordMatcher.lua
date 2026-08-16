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

  -- The gap-inference tier searches ONLY a script-order-derived
  -- window, and that evidence buys a floor below the long-shot tier's
  -- (at the rescue floor the tier would be dead code - long-shot
  -- already searched everywhere at 0.3)
  GAP_MIN_CONFIDENCE = 0.1,
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
-- context (optional): { gap_window = { track_guid, start_time,
-- end_time } } - script-order evidence for a straggler's location.
function FuzzyWordMatcher:match(needle, context)
  self:_snapshot_claims(needle)

  local tokens, options = self:_needle_tokens(needle)
  if #tokens == 0 then
    -- Nothing speakable: a direction-only line. Whisper LEXICALIZES
    -- non-verbals, so hunt the interjections instead.
    return self:_vocalization_matches(needle)
  end

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

  -- Gap-inference tier: still nothing, but script order says the line
  -- lives in a specific window - search just there, below the rescue
  -- floor (the window evidence buys it), marked timeline-reasoned
  if #suggestions == 0 and context and context.gap_window then
    local window = context.gap_window
    local gap_options = {
      max_matches = self.LONG_SHOT_MAX_MATCHES,
      min_confidence = self.GAP_MIN_CONFIDENCE,
      long_shot = true,
      window = window,
      gap_inferred = true,
    }
    for _, audio_track in ipairs(self.workflow:audio_tracks()) do
      if audio_track.guid == window.track_guid then
        self:_match_track(tokens, gap_options, audio_track, suggestions)
      end
    end
  end

  table.sort(suggestions, function(a, b) return a.confidence > b.confidence end)
  self:log("Generated " .. #suggestions .. " suggestions")
  return suggestions
end

-- ================================================================================
-- SPAN EXCLUSION
-- ================================================================================

-- One consistent view of claimed territory per matching run: spans
-- other needles' ACCEPTED takes own are off the table (a duplicated
-- script line gets steered to its OTHER occurrence - the point of the
-- compounding mechanic). Graceful no-op when the workflow double has
-- no claims service.
function FuzzyWordMatcher:_snapshot_claims(needle)
  self._active_claims = self.workflow.get_claimed_spans
    and self.workflow:get_claimed_spans():by_track() or nil
  self._claiming_needle_guid = needle and needle.guid or nil
end

-- Majority overlap with a foreign claim disqualifies a candidate;
-- a needle's own claims never block its re-roll
function FuzzyWordMatcher:_claimed_by_other(track_guid, start_time, end_time)
  local claims = self._active_claims and self._active_claims[track_guid]
  if not claims then return false end

  local duration = math.max(end_time - start_time, 0.001)
  for _, claim in ipairs(claims) do
    if claim.needle_guid ~= self._claiming_needle_guid then
      local overlap = math.min(end_time, claim.end_time)
        - math.max(start_time, claim.start_time)
      if overlap > duration * 0.5 then
        return true
      end
    end
  end
  return false
end

-- ================================================================================
-- VOCALIZATION PASS
-- ================================================================================

-- Whisper LEXICALIZES non-verbals: a scream lands in the transcript
-- as "ah!"/"aah!", a grunt sometimes as the literal word "grunts"
-- (both observed in reference data). Direction words map to small
-- interjection vocabularies; hits offer at a fixed low confidence,
-- marked vocalization + long_shot, capped per track. KNOWN CAVEAT:
-- the literal direction words also match a director TRACK saying
-- them as direction - the low confidence and marking leave that to
-- the human ear.
FuzzyWordMatcher.VOCALIZATION_CONFIDENCE = 0.35
FuzzyWordMatcher.VOCALIZATION_MAX_PER_TRACK = 3

FuzzyWordMatcher.VOCALIZATIONS = {
  scream = { 'ah', 'aah', 'aaah', 'ahh', 'agh', 'argh' },
  shriek = { 'ah', 'aah', 'aaah', 'ahh', 'agh', 'argh' },
  shout = { 'hey', 'ah', 'ahh' },
  yell = { 'hey', 'ah', 'ahh' },
  gasp = { 'ah', 'huh', 'oh', 'ohh' },
  grunt = { 'ugh', 'uh', 'hmm', 'mm', 'hmph' },
  groan = { 'ugh', 'ohh', 'oh', 'aww' },
  sigh = { 'ah', 'ahh', 'whew', 'phew', 'hah' },
  laugh = { 'ha', 'haha', 'heh', 'hehe', 'hah' },
  chuckle = { 'heh', 'ha', 'hmm' },
  cough = { 'ahem', 'ugh' },
  cry = { 'oh', 'ohh', 'ah', 'no' },
  sob = { 'oh', 'ohh', 'ah' },
  pain = { 'ow', 'ouch', 'agh', 'ah' },
  hurt = { 'ow', 'ouch', 'agh' },
  effort = { 'ugh', 'hup', 'huh', 'ha' },
  breathe = { 'whew', 'phew', 'hah' },
  pant = { 'hah', 'huh', 'whew' },
}

-- Tokens inside the needle's bracketed directions
function FuzzyWordMatcher:_direction_tokens(content)
  local directions = {}
  for _, pattern in ipairs({ '%[(.-)%]', '{(.-)}', '%((.-)%)' }) do
    for inner in (content or ''):gmatch(pattern) do
      for _, token in ipairs(TextNormalizer.tokenize(inner)) do
        table.insert(directions, token)
      end
    end
  end
  return directions
end

-- The sounds worth hunting for this needle: each direction word's
-- interjection vocabulary (stemmed: screams/screaming -> scream)
-- plus the direction words themselves (literal lexicalization)
function FuzzyWordMatcher:_vocalization_vocabulary(content)
  local vocabulary = {}
  for _, token in ipairs(self:_direction_tokens(content)) do
    vocabulary[token] = true
    -- Parenthesized: gsub's second return would corrupt the list
    for _, stem in ipairs({ token, (token:gsub('ing$', '')), (token:gsub('ed$', '')), (token:gsub('s$', '')) }) do
      for _, sound in ipairs(FuzzyWordMatcher.VOCALIZATIONS[stem] or {}) do
        vocabulary[sound] = true
      end
    end
  end
  return vocabulary
end

function FuzzyWordMatcher:_vocalization_matches(needle)
  local vocabulary = self:_vocalization_vocabulary(needle.content)
  if not next(vocabulary) then return {} end

  local suggestions = {}
  for _, audio_track in ipairs(self.workflow:audio_tracks()) do
    local entry = self:_prepared_stream(audio_track)
    if entry then
      local track_hits = 0
      for _, word in ipairs(entry.words) do
        if track_hits >= FuzzyWordMatcher.VOCALIZATION_MAX_PER_TRACK then break end
        local token = TextNormalizer.tokenize(word.text)[1]
        if token and vocabulary[token]
          and not self:_claimed_by_other(audio_track.guid, word.start_time, word.end_time) then
          track_hits = track_hits + 1
          table.insert(suggestions, {
            start_time = word.start_time,
            end_time = word.end_time,
            file = word.file,
            matching_text = word.text,
            track_guids = { audio_track.guid },
            confidence = FuzzyWordMatcher.VOCALIZATION_CONFIDENCE,
            matched_count = 1,
            match_type = 'vocalization',
            long_shot = true,
          })
        end
      end
    end
  end

  self:log(('Vocalization pass: %d hit(s)'):format(#suggestions))
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

  self:_snapshot_claims(needle)

  local tokens, options = self:_needle_tokens(needle)
  if #tokens == 0 then
    self:log("Needle has no matchable words after normalization: " .. needle.content)
  end

  self.async_results = nil
  self.async_error_message = nil
  -- Direction-only needles take the vocalization pass up front (a
  -- cheap linear scan); the empty work queue then completes with
  -- these as the results. The token guard on the long-shot refill
  -- keeps the rescue pass out of it.
  self._suggestions = #tokens == 0 and self:_vocalization_matches(needle) or {}
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

    local in_window = not options.window
      or (first_word.start_time >= options.window.start_time
        and last_word.end_time <= options.window.end_time)

    if in_window
      and not self:_claimed_by_other(audio_track.guid, first_word.start_time, last_word.end_time) then
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
        gap_inferred = options.gap_inferred or nil,
      })
    end
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
  entry = self:_prepare_transcript(transcript)
  self._stream_cache[cache_key] = entry
  self:log("Prepared word stream for track " .. audio_track.guid
    .. " (" .. #entry.words .. " words)")
  return entry
end

function FuzzyWordMatcher:_prepare_transcript(transcript)
  local words = self:create_word_stream_from_transcript(transcript)
  local texts = {}
  for i, word in ipairs(words) do
    texts[i] = word.text
  end

  return {
    words = words,
    prepared = FuzzyAligner.prepare_stream(texts),
  }
end

-- Diagnosis probe: search an arbitrary transcript FILE (typically one
-- discovered in the project folder but not linked to any track) for
-- the needle. Mirrors real matching - normal floor first, long-shot
-- fallback - and returns the best hit { confidence, long_shot } or
-- nil. Streams cache alongside the track streams.
function FuzzyWordMatcher:probe_transcript_file(needle, transcript_file)
  local tokens, options = self:_needle_tokens(needle)
  if #tokens == 0 then return nil end

  local cache_key = '\0probe\0' .. transcript_file
  local entry = self._stream_cache[cache_key]
  if not entry then
    local transcript = TranscriptImporter:import(transcript_file)
    if not transcript then return nil end
    entry = self:_prepare_transcript(transcript)
    self._stream_cache[cache_key] = entry
  end

  local best
  local function consider(matches, long_shot)
    for _, match in ipairs(matches) do
      if not best or match.confidence > best.confidence then
        best = { confidence = match.confidence, long_shot = long_shot or nil }
      end
    end
  end

  consider(FuzzyAligner.find_matches(tokens, entry.prepared, options), false)
  if not best then
    consider(FuzzyAligner.find_matches(tokens, entry.prepared, self:_long_shot_options(options)), true)
  end

  return best
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
