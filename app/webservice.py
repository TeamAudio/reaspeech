from os import path
from typing import Union, Annotated
import importlib.metadata
import logging
import os
import tempfile

from celery.result import AsyncResult
from fastapi import FastAPI, File, Query, Request, UploadFile, applications
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from whisper import tokenizer
import aiofiles

from .util.audio import load_audio
from .worker import transcribe as bg_transcribe

logging.basicConfig(format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s', level=logging.INFO, force=True)
logger = logging.getLogger(__name__)

ASR_ENGINE = os.getenv("ASR_ENGINE", "faster_whisper")

ASR_OPTIONS = frozenset([
    "task",
    "language",
    "initial_prompt",
    "encode",
    "output",
    "vad_filter",
    "word_timestamps",
    "model_name",
])

DEFAULT_MODEL_NAME = os.getenv("ASR_MODEL", "small")

LANGUAGE_CODES = sorted(list(tokenizer.LANGUAGES.keys()))

projectMetadata = importlib.metadata.metadata('reaspeech')
app = FastAPI(
    # docs_url=None,
    # redoc_url=None,
    title=projectMetadata['Name'].title().replace('-', ' '),
    description=projectMetadata['Summary'],
    version=projectMetadata['Version'],
    contact={
        "url": projectMetadata['Home-page']
    },
    swagger_ui_parameters={"defaultModelsExpandDepth": -1},
    license_info={
        "name": "MIT License",
        "url": projectMetadata['License']
    }
)

assets_path = os.getcwd() + "/swagger-ui-assets"
if path.exists(assets_path + "/swagger-ui.css") and path.exists(assets_path + "/swagger-ui-bundle.js"):
    app.mount("/assets", StaticFiles(directory=assets_path), name="static")


    def swagger_monkey_patch(*args, **kwargs):
        return get_swagger_ui_html(
            *args,
            **kwargs,
            swagger_favicon_url="",
            swagger_css_url="/assets/swagger-ui.css",
            swagger_js_url="/assets/swagger-ui-bundle.js",
        )


    applications.get_swagger_ui_html = swagger_monkey_patch


static_path = os.getcwd() + "/app/static"
app.mount("/static", StaticFiles(directory=static_path), name="static")

templates_path = os.getcwd() + "/app/templates"
templates = Jinja2Templates(directory=templates_path)

output_directory = os.environ.get("OUTPUT_DIRECTORY", os.getcwd() + "/app/output")
output_url_prefix = os.environ.get("OUTPUT_URL_PREFIX", "/output")
app.mount(output_url_prefix, StaticFiles(directory=output_directory), name="output")

@app.get("/", response_class=RedirectResponse, include_in_schema=False)
async def index():
    return "/reaspeech"

@app.get("/reaspeech", response_class=HTMLResponse, include_in_schema=False)
async def reaspeech(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/reascript", response_class=PlainTextResponse, include_in_schema=False)
async def reascript(request: Request, name: str, host: str):
    return templates.TemplateResponse("reascript.lua", {
            "request": request,
            "name": name,
            "host": host
        },
        media_type='application/x-lua',
        headers={
            'Content-Disposition': f'attachment; filename="{name}.lua"'
        }
    )

@app.post("/asr", tags=["Endpoints"])
async def asr(
    task: Union[str, None] = Query(default="transcribe", enum=["transcribe", "translate"]),
    language: Union[str, None] = Query(default=None, enum=LANGUAGE_CODES),
    initial_prompt: Union[str, None] = Query(default=None),
    audio_file: UploadFile = File(...),
    encode: bool = Query(default=True, description="Encode audio first through ffmpeg"),
    output: Union[str, None] = Query(default="txt", enum=["txt", "vtt", "srt", "tsv", "json"]),
    vad_filter: Annotated[bool | None, Query(
        description="Enable the voice activity detection (VAD) to filter out parts of the audio without speech",
        include_in_schema=(True if ASR_ENGINE == "faster_whisper" else False)
    )] = False,
    word_timestamps: bool = Query(default=False, description="Word level timestamps"),
    model_name: Union[str, None] = Query(default=None, description="Model name to use for transcription"),
    use_async: bool = Query(default=False, description="Use asynchronous processing")
):
    asr_options = {k: v for k, v in locals().items() if k in ASR_OPTIONS}
    async_str = " (async)" if use_async else ""
    logger.info(f"Transcribing{async_str} {audio_file.filename} with {asr_options}")

    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
        temp_file_path = temp_file.name

    async with aiofiles.open(temp_file_path, 'wb') as out_file:
        while content := await audio_file.read(1024 * 1024):  # Read in chunks of 1MB
            await out_file.write(content)

    transcriber = bg_transcribe.si(temp_file_path, audio_file.filename, asr_options)

    if use_async:
        job = transcriber.apply_async()
        return JSONResponse({"job_id": job.id})

    else:
        result = transcriber.apply().get()

        def reader():
            with open(result['output_path'], "r") as file:
                yield from file

        filename = audio_file.filename.encode('latin-1', 'ignore')
        return StreamingResponse(
            reader(),
            media_type="text/plain",
            headers={
                'Asr-Engine': ASR_ENGINE,
                'Content-Disposition': f'attachment; filename="{filename}.{output}"'
            })

@app.get("/jobs/{job_id}", tags=["Endpoints"])
async def job_status(job_id: str):
    job = AsyncResult(job_id)

    result = {
        "job_id": job_id,
        "job_status": job.status,
        "job_result": job.result
    }
    return JSONResponse(result)

@app.delete("/jobs/{job_id}", tags=["Endpoints"])
async def revoke_job(job_id: str):
    job = AsyncResult(job_id)
    job.revoke(terminate=True)

    result = {
        "job_id": job_id,
        "job_status": job.status
    }
    return JSONResponse(result)
