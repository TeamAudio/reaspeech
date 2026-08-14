"""
FastAPI endpoints for script matching functionality
"""

import logging
import tempfile
from typing import Dict, Any, Union, List
import aiofiles

from fastapi import APIRouter, File, Query, UploadFile
from fastapi.responses import JSONResponse
from celery.result import AsyncResult

from ..worker import fuzzy_match, parse_spreadsheet_task

logger = logging.getLogger(__name__)

router = APIRouter()

TASK_EXPIRATION_SECONDS = 30

@router.post("/match")
async def match_script_to_audio(
    needle: Dict[str, Any],
    audio_tracks: List[Dict[str, Any]], 
    matching_options: Dict[str, Any] = None,
    use_async: bool = Query(default=True, description="Use asynchronous processing")
):
    """
    Match script text against audio transcripts using fuzzy matching.
    
    This endpoint follows the same pattern as the ASR endpoint:
    - Async mode returns job_id for polling
    - Sync mode returns results directly
    
    Accepts structured JSON data prepared by the Lua frontend.
    """
    
    # Validate required data
    if not needle or not needle.get('content'):
        return JSONResponse(
            status_code=400,
            content={"error": "needle with content is required"}
        )
    
    if not audio_tracks:
        return JSONResponse(
            status_code=400,
            content={"error": "audio_tracks are required"}
        )
    
    # STEP7_DEBUG: Log incoming request structure for validation
    logger.info(f"STEP7_DEBUG: Incoming request - needle: {needle.get('content', 'NO_CONTENT')}")
    logger.info(f"STEP7_DEBUG: Audio tracks count: {len(audio_tracks)}")
    for i, track in enumerate(audio_tracks):
        track_keys = list(track.keys())
        has_word_stream = 'word_stream' in track
        has_word_index = 'word_index' in track
        logger.debug(f"STEP7_DEBUG: Track {i} - keys: {track_keys}, word_stream: {has_word_stream}, word_index: {has_word_index}")
        if has_word_stream and isinstance(track['word_stream'], list):
            logger.debug(f"STEP7_DEBUG: Track {i} word_stream length: {len(track['word_stream'])}")
        if has_word_index and isinstance(track['word_index'], dict):
            logger.debug(f"STEP7_DEBUG: Track {i} word_index keys: {len(track['word_index'])}")
    
    # Validate that audio tracks have required pre-processed data
    for i, track in enumerate(audio_tracks):
        if not track.get('word_stream'):
            return JSONResponse(
                status_code=400,
                content={"error": f"Audio track {i} missing required 'word_stream' field"}
            )
        if not track.get('word_index'):
            return JSONResponse(
                status_code=400,
                content={"error": f"Audio track {i} missing required 'word_index' field"}
            )
    
    # Extract options with defaults
    options = matching_options or {}
    options.setdefault('max_suggestions', 10)
    options.setdefault('confidence_threshold', 0.1)
    
    needle_text = needle['content']
    logger.info(f"Script matching request: '{needle_text}' (async={use_async})")
    
    # Pass structured data to the fuzzy_match task
    matcher = fuzzy_match.si(needle, audio_tracks, options)
    
    if use_async:
        job = matcher.apply_async(expires=TASK_EXPIRATION_SECONDS)
        return JSONResponse({"job_id": job.id})
    else:
        # Synchronous execution
        result = matcher.apply().get()
        return JSONResponse(result)


@router.post("/parse_spreadsheet")
async def parse_spreadsheet_async(
    spreadsheet: UploadFile = File(...),
    use_async: bool = Query(default=False, description="Use asynchronous processing")
):
    """
    Parse uploaded spreadsheet file - async version of the existing endpoint.
    
    This provides both sync and async options, following the ASR pattern.
    Could eventually replace the sync version in the main webservice.
    """
    
    # Save uploaded file
    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
        temp_file_path = temp_file.name

    async with aiofiles.open(temp_file_path, 'wb') as out_file:
        while content := await spreadsheet.read(1024 * 1024):
            await out_file.write(content)
    
    logger.info(f"Processing spreadsheet: {spreadsheet.filename} (async={use_async})")
    
    parser = parse_spreadsheet_task.si(temp_file_path, spreadsheet.filename)
    
    if use_async:
        job = parser.apply_async(expires=TASK_EXPIRATION_SECONDS)
        return JSONResponse({"job_id": job.id})
    else:
        # Synchronous execution
        result = parser.apply().get()
        return JSONResponse(result)


@router.get("/info")
async def script_match_info():
    """
    Get information about available script matching capabilities.
    Similar to /asr_info endpoint.
    """
    return JSONResponse({
        "algorithms": ["exact", "fuzzy"],  # Could be expanded
        "options": [
            "max_suggestions",
            "confidence_threshold",
            "match_algorithms"
        ],
        "version": "1.0"
    })
