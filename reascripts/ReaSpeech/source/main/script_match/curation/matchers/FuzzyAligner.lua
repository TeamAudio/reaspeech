--[[

  FuzzyAligner.lua - fuzzy alignment of a needle phrase against a word stream

  Finds occurrences of a needle (a normalized token sequence, typically a
  script line) inside a stream of words (typically a transcript), tolerating
  word substitutions, inserted filler words, and dropped words.

  Strategy:
    1. Anchor: pick the rarest needle tokens that occur in the stream index
       and only examine windows around their occurrences, so cost scales
       with anchor frequency rather than stream length.
    2. Align: run a semi-global alignment (needle consumed fully, stream
       consumed freely at the edges) over each window. Word pairs score by
       character-level similarity; interior gaps are penalized.

  Confidence is the alignment score divided by the needle length, so an
  exact full match scores 1.0 and degrades with each substitution or gap.

  Pure module: depends only on TextNormalizer, safe outside REAPER.

]]--

FuzzyAligner = {
  DEFAULT_OPTIONS = {
    min_confidence = 0.5,       -- discard matches scoring below this
    similarity_threshold = 0.6, -- minimum word similarity to count as a substitution
    insertion_penalty = 0.25,   -- extra stream word inside a match
    deletion_penalty = 0.4,     -- needle word absent from the stream
    max_anchors = 3,            -- rare needle tokens used to seed windows
    band_slack = 3,             -- extra stream positions around each window
    max_windows = 500,          -- alignment budget per needle
    max_matches = math.huge,    -- cap on returned matches (short needles can
                                -- occur hundreds of times in a long stream)
  },
}

-- Tokenize a stream of raw words and build a token -> positions index.
-- Each token remembers the index of the source word it came from, so
-- matches can be mapped back to word-stream entries (and their timings).
function FuzzyAligner.prepare_stream(words)
  local tokens = {}
  local index = {}

  for source_index, word in ipairs(words) do
    for _, token in ipairs(TextNormalizer.tokenize(word)) do
      table.insert(tokens, { token = token, source_index = source_index })
      local positions = index[token]
      if not positions then
        positions = {}
        index[token] = positions
      end
      table.insert(positions, #tokens)
    end
  end

  return { tokens = tokens, index = index }
end

function FuzzyAligner.levenshtein(a, b)
  local la, lb = #a, #b
  if la == 0 then return lb end
  if lb == 0 then return la end

  local previous_row = {}
  for j = 0, lb do
    previous_row[j] = j
  end

  for i = 1, la do
    local current_row = { [0] = i }
    local a_byte = a:byte(i)
    for j = 1, lb do
      local substitution_cost = (a_byte == b:byte(j)) and 0 or 1
      local best = previous_row[j - 1] + substitution_cost
      local deletion = previous_row[j] + 1
      local insertion = current_row[j - 1] + 1
      if deletion < best then best = deletion end
      if insertion < best then best = insertion end
      current_row[j] = best
    end
    previous_row = current_row
  end

  return previous_row[lb]
end

-- Character-level similarity between two tokens in [0, 1].
function FuzzyAligner.similarity(a, b)
  if a == b then return 1.0 end
  local max_len = #a > #b and #a or #b
  if max_len == 0 then return 0.0 end
  return 1.0 - FuzzyAligner.levenshtein(a, b) / max_len
end

-- Find occurrences of needle_tokens in a prepared stream. Returns matches
-- sorted by descending confidence:
--   {
--     start_index = <source index of first matched stream word>,
--     end_index = <source index of last matched stream word>,
--     confidence = <0..1>,
--     matched_count = <needle tokens matched>,
--   }
function FuzzyAligner.find_matches(needle_tokens, stream, options)
  options = FuzzyAligner._merge_options(options)

  local n = #needle_tokens
  if n == 0 or #stream.tokens == 0 then return {} end

  local windows = FuzzyAligner._candidate_windows(needle_tokens, stream, options)

  local similarity_memo = {}
  local matches = {}
  for _, window in ipairs(windows) do
    FuzzyAligner._align_all(needle_tokens, stream, window, options, similarity_memo, matches)
  end

  return FuzzyAligner._deduplicate(matches, options.max_matches)
end

-- Collect every qualifying occurrence within a window: align, then
-- recursively re-align the stretches left and right of the matched span.
-- Back-to-back takes of the same line land in one window and would
-- otherwise collapse to a single match.
function FuzzyAligner._align_all(needle_tokens, stream, window, options, similarity_memo, out)
  if window.first > window.last then return end

  local match = FuzzyAligner._align(needle_tokens, stream, window, options, similarity_memo)
  if not match or match.confidence < options.min_confidence then return end

  table.insert(out, match)
  FuzzyAligner._align_all(needle_tokens, stream,
    { first = window.first, last = match.first_token - 1 },
    options, similarity_memo, out)
  FuzzyAligner._align_all(needle_tokens, stream,
    { first = match.last_token + 1, last = window.last },
    options, similarity_memo, out)
end

function FuzzyAligner._merge_options(options)
  local merged = {}
  for key, value in pairs(FuzzyAligner.DEFAULT_OPTIONS) do
    merged[key] = value
  end
  for key, value in pairs(options or {}) do
    merged[key] = value
  end
  return merged
end

-- Seed alignment windows around occurrences of the rarest needle tokens.
function FuzzyAligner._candidate_windows(needle_tokens, stream, options)
  local anchors = {}
  local seen_tokens = {}
  for needle_index, token in ipairs(needle_tokens) do
    local positions = stream.index[token]
    if positions and not seen_tokens[token] then
      seen_tokens[token] = true
      table.insert(anchors, {
        needle_index = needle_index,
        positions = positions,
        frequency = #positions,
      })
    end
  end
  table.sort(anchors, function(a, b) return a.frequency < b.frequency end)

  local n = #needle_tokens
  local token_count = #stream.tokens
  local windows = {}
  local seen_starts = {}
  for anchor_rank, anchor in ipairs(anchors) do
    if anchor_rank > options.max_anchors then break end
    for _, position in ipairs(anchor.positions) do
      if #windows >= options.max_windows then return windows end
      local first = position - (anchor.needle_index - 1) - options.band_slack
      if first < 1 then first = 1 end
      local last = first + n - 1 + 2 * options.band_slack
      if last > token_count then last = token_count end
      if not seen_starts[first] then
        seen_starts[first] = true
        table.insert(windows, { first = first, last = last })
      end
    end
  end

  return windows
end

-- Semi-global alignment of the full needle against one stream window.
-- Leading and trailing unmatched stream tokens are free; interior gaps
-- and unmatched needle tokens are penalized.
function FuzzyAligner._align(needle_tokens, stream, window, options, similarity_memo)
  local tokens = stream.tokens
  local n = #needle_tokens
  local m = window.last - window.first + 1

  local function pair_similarity(needle_index, window_index)
    local needle_token = needle_tokens[needle_index]
    local stream_token = tokens[window.first + window_index - 1].token
    local key = needle_token .. '\0' .. stream_token
    local memoized = similarity_memo[key]
    if not memoized then
      memoized = FuzzyAligner.similarity(needle_token, stream_token)
      similarity_memo[key] = memoized
    end
    return memoized
  end

  -- Each cell tracks the score plus enough provenance to recover the
  -- matched span without a backtrace: first/last matched token position,
  -- matched token count.
  local previous_row = {}
  for j = 0, m do
    previous_row[j] = { score = 0, matched = 0 }
  end

  for i = 1, n do
    local current_row = {
      [0] = { score = previous_row[0].score - options.deletion_penalty, matched = 0 },
    }
    for j = 1, m do
      -- Needle token i unmatched (deletion from the stream's perspective)
      local up = previous_row[j]
      local best = {
        score = up.score - options.deletion_penalty,
        matched = up.matched,
        first = up.first,
        last = up.last,
      }

      -- Extra stream token inside the match (insertion)
      local left = current_row[j - 1]
      local left_score = left.score - options.insertion_penalty
      if left_score > best.score then
        best = {
          score = left_score,
          matched = left.matched,
          first = left.first,
          last = left.last,
        }
      end

      -- Needle token i matched to stream token j
      local sim = pair_similarity(i, j)
      if sim >= options.similarity_threshold then
        local diagonal = previous_row[j - 1]
        local diagonal_score = diagonal.score + sim
        if diagonal_score >= best.score then
          local position = window.first + j - 1
          best = {
            score = diagonal_score,
            matched = diagonal.matched + 1,
            first = diagonal.first or position,
            last = position,
          }
        end
      end

      current_row[j] = best
    end
    previous_row = current_row
  end

  local best_cell = nil
  for j = 0, m do
    local cell = previous_row[j]
    if cell.matched > 0 and (not best_cell or cell.score > best_cell.score) then
      best_cell = cell
    end
  end
  if not best_cell then return nil end

  local confidence = best_cell.score / n
  if confidence < 0 then confidence = 0 end
  if confidence > 1 then confidence = 1 end

  return {
    start_index = tokens[best_cell.first].source_index,
    end_index = tokens[best_cell.last].source_index,
    first_token = best_cell.first,
    last_token = best_cell.last,
    confidence = confidence,
    matched_count = best_cell.matched,
  }
end

-- Windows seeded by different anchors can rediscover the same occurrence;
-- keep only the best-scoring match for any overlapping token span.
function FuzzyAligner._deduplicate(matches, max_matches)
  table.sort(matches, function(a, b) return a.confidence > b.confidence end)

  local kept = {}
  for _, match in ipairs(matches) do
    if #kept >= max_matches then break end
    local overlaps = false
    for _, existing in ipairs(kept) do
      local first = match.first_token > existing.first_token
        and match.first_token or existing.first_token
      local last = match.last_token < existing.last_token
        and match.last_token or existing.last_token
      if last >= first then
        overlaps = true
        break
      end
    end
    if not overlaps then
      table.insert(kept, match)
    end
  end

  return kept
end
