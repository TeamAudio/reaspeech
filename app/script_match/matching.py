"""
Core fuzzy matching algorithms for script-to-audio matching.
This is a Python port/enhancement of the Lua FuzzyWordMatcher.
"""

import logging
import re
from typing import List, Dict, Any, Callable, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class MatchSuggestion:
    """A single match suggestion with metadata"""
    start_time: float
    end_time: float
    matching_text: str
    track_guids: List[str]
    confidence: float
    match_type: str
    metadata: Dict[str, Any] = None

class FuzzyMatcher:
    """
    Enhanced fuzzy matching engine with Python text processing libraries.
    Implements the same algorithm as the Lua version but with better tools.
    """
    
    def __init__(
        self, 
        confidence_threshold: float = 0.1,
        progress_callback: Optional[Callable[[int, int], None]] = None
    ):
        self.confidence_threshold = confidence_threshold
        self.progress_callback = progress_callback
        
    def match(self, needle: Dict[str, Any], audio_tracks: List[Dict[str, Any]]) -> List[MatchSuggestion]:
        """
        Main matching function - expects pre-processed word streams from Lua side
        
        Args:
            needle: Dictionary containing script content and metadata 
            audio_tracks: List of audio track objects with PRE-PROCESSED word streams
            
        Returns:
            List of match suggestions sorted by confidence
        """
        needle_text = needle.get('content', '')
        logger.info(f"Matching needle: '{needle_text}'")
        
        # Expect word streams to be pre-processed by Lua FuzzyWordMatcher
        word_streams = self._extract_word_streams(audio_tracks)
        needle_words = self._create_needle_word_stream(needle_text)
        
        if not word_streams or not needle_words:
            return []
            
        suggestions = []
        found_full_match = False
        
        # Try matching starting from each word position (same as Lua logic)
        for needle_start_index in range(len(needle_words)):
            if found_full_match and needle_start_index > 0:
                logger.debug("Skipping shorter needle subsets - already found full match")
                break
                
            needle_subset = needle_words[needle_start_index:]
            
            # Find locations of first word in subset
            first_word = needle_subset[0]
            start_locations = self._find_word_locations_indexed(word_streams, first_word)
            
            # Try to match complete needle subset from each location
            for location in start_locations:
                match_result = self._apply_exact_match(needle_subset, location)
                if match_result:
                    # Apply confidence penalty for partial matches
                    confidence_penalty = needle_start_index * 0.1
                    match_result.confidence = max(0, match_result.confidence - confidence_penalty)
                    suggestions.append(match_result)
                    
                    if needle_start_index == 0:
                        found_full_match = True
        
        # Sort by confidence (highest first)
        suggestions.sort(key=lambda s: s.confidence, reverse=True)
        
        logger.info(f"Generated {len(suggestions)} suggestions")
        return suggestions
    
    def _extract_word_streams(self, audio_tracks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Extract pre-processed word streams from audio tracks (prepared by Lua side)"""
        word_streams = []
        
        # STEP7_DEBUG: Log incoming audio track structure for validation
        logger.info(f"STEP7_DEBUG: Processing {len(audio_tracks)} audio tracks")
        for i, audio_track in enumerate(audio_tracks):
            logger.debug(f"STEP7_DEBUG: Audio track {i} keys: {list(audio_track.keys())}")
            if audio_track.get('word_stream'):
                logger.debug(f"STEP7_DEBUG: Track {i} has word_stream with {len(audio_track['word_stream'])} words")
            if audio_track.get('word_index'):
                logger.debug(f"STEP7_DEBUG: Track {i} has word_index with {len(audio_track['word_index'])} indexed words")
        
        for i, audio_track in enumerate(audio_tracks):
            if self.progress_callback:
                self.progress_callback(i, len(audio_tracks))
                
            # Expect word streams to be pre-processed by Lua FuzzyWordMatcher
            word_stream = audio_track.get('word_stream')
            word_index = audio_track.get('word_index')
            
            if word_stream and word_index:
                word_streams.append({
                    'track_guid': audio_track.get('guid'),
                    'word_stream': word_stream,
                    'word_index': word_index
                })
            else:
                logger.warning(f"Audio track {audio_track.get('guid')} missing pre-processed word_stream or word_index")
        
        return word_streams
    
    def _create_needle_word_stream(self, needle_text: str) -> List[Dict[str, Any]]:
        """Create word stream from needle text"""
        words = needle_text.strip().split()
        return [{'text': word, 'probability': 1.0} for word in words if word]
    
    def _normalize_word(self, word_text: str) -> str:
        """Normalize word for matching (same as Lua version, but extensible)"""
        normalized = word_text.lower()
        
        # Future enhancements:
        # - Remove punctuation: normalized = re.sub(r'[^\w\s]', '', normalized)
        # - Handle contractions
        # - Unicode normalization
        
        return normalized
    
    def _find_word_locations_indexed(
        self, 
        word_streams: List[Dict[str, Any]], 
        needle_word: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Find all locations of a word using indexes"""
        locations = []
        normalized_needle = self._normalize_word(needle_word['text'])
        
        for word_stream in word_streams:
            index = word_stream['word_index']
            matches = index.get(normalized_needle, [])
            
            # STEP7_DEBUG: Log word index lookup details
            logger.debug(f"STEP7_DEBUG: Looking for '{normalized_needle}' in track {word_stream.get('track_guid', 'unknown')}")
            logger.debug(f"STEP7_DEBUG: Found {len(matches)} matches")
            
            for match in matches:
                # Validate expected structure
                if not isinstance(match, dict) or 'word_data' not in match or 'word_index' not in match:
                    logger.warning(f"STEP7_DEBUG: Invalid match structure: {match}")
                    continue
                    
                word = match['word_data']
                locations.append({
                    'text': word['text'],
                    'track_guid': word_stream['track_guid'],
                    'word_stream': word_stream,
                    'word_index': match['word_index'],
                    'start_time': word.get('start_time'),
                    'end_time': word.get('end_time'),
                    'metadata': word.get('segment_metadata', {})
                })
        
        return locations
    
    def _apply_exact_match(
        self, 
        needle_subset: List[Dict[str, Any]], 
        start_location: Dict[str, Any]
    ) -> Optional[MatchSuggestion]:
        """Apply exact matching for needle subset starting at location"""
        # Extract word stream array from the word_stream object
        word_stream_obj = start_location['word_stream']
        word_stream_array = word_stream_obj['word_stream']  # This is the actual array of words
        start_index_lua = start_location['word_index']  # This is 1-based from Lua
        start_index = start_index_lua - 1  # Convert to 0-based for Python
        
        # STEP7_DEBUG: Log matching attempt details
        logger.debug(f"STEP7_DEBUG: Attempting exact match at Lua index {start_index_lua} (Python index {start_index}) for {len(needle_subset)} words")
        logger.debug(f"STEP7_DEBUG: Word stream has {len(word_stream_array)} words")
        
        # Check if we have enough words remaining
        if start_index + len(needle_subset) > len(word_stream_array):
            return None
            
        matched_words = []
        total_confidence = 0
        
        # Try to match each word sequentially
        for i, needle_word in enumerate(needle_subset):
            stream_index = start_index + i
            stream_word = word_stream_array[stream_index]
            
            # Exact match using normalized comparison
            needle_normalized = self._normalize_word(needle_word['text'])
            stream_normalized = self._normalize_word(stream_word['text'])
            
            if needle_normalized == stream_normalized:
                matched_words.append(stream_word)
                total_confidence += stream_word.get('probability', 1.0)
            else:
                # Sequence broken
                return None
        
        # Calculate average confidence
        avg_confidence = total_confidence / len(matched_words) if matched_words else 0
        
        # Build suggestion
        first_word = matched_words[0]
        last_word = matched_words[-1]
        
        matching_text = ' '.join(word['text'] for word in matched_words)
        
        return MatchSuggestion(
            start_time=first_word.get('start_time', 0),
            end_time=last_word.get('end_time', 0),
            matching_text=matching_text,
            track_guids=[start_location['track_guid']],
            confidence=avg_confidence,
            match_type='exact',
            metadata={
                'word_count': len(matched_words),
                'segment_metadata': first_word.get('segment_metadata', {})
            }
        )
