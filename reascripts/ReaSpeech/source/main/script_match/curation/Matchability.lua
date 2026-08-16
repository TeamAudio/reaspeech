--[[

  Matchability.lua - intrinsic matchability classes for needles

  A needle's content predicts how matching will go before any roll:
  a bracketed direction ("[Shrieks.]") strips to nothing and text
  matching is structurally hopeless; a one-or-two-word line only
  matches at high confidence. Classes mirror the matcher's own view
  (same stage-direction stripping, same tokenizer, same short
  threshold), so a class is a prediction of matcher behavior, not a
  separate opinion.

  Computed at needle generation; the diagnosis layer consults it
  first (an intrinsic class explains an empty roll without needing
  evidence).

]]--

Matchability = {}

function Matchability.classify(content)
  local text = TextNormalizer.strip_stage_directions(content or '')
  local tokens = TextNormalizer.tokenize(text)

  if #tokens == 0 then
    return {
      class = 'non_verbal',
      reason = 'Non-verbal direction: nothing for text matching to find',
    }
  end

  if #tokens <= FuzzyWordMatcher.SHORT_NEEDLE_TOKENS then
    return {
      class = 'short',
      reason = ('Only %d word%s: matches must clear a higher confidence bar')
        :format(#tokens, #tokens == 1 and '' or 's'),
    }
  end

  return { class = 'text' }
end
