"""
FastAPI endpoints for script matching functionality
"""

import logging
import tempfile
import aiofiles

from fastapi import APIRouter, File, Query, UploadFile
from fastapi.responses import JSONResponse

from ..worker import parse_spreadsheet_task

logger = logging.getLogger(__name__)

router = APIRouter()

TASK_EXPIRATION_SECONDS = 30

@router.post("/parse_spreadsheet")
async def parse_spreadsheet(
    spreadsheet: UploadFile = File(...),
    use_async: bool = Query(default=False, description="Use asynchronous processing")
):
    """
    Parse an uploaded spreadsheet into per-sheet cell data plus row style
    info. Synchronous by default; use_async returns a job_id to poll,
    following the ASR pattern.
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
