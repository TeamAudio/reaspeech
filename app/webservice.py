import importlib.metadata
import logging
import os
from os import path
from tempfile import NamedTemporaryFile
from typing import Union, Annotated

from celery.result import AsyncResult

from fastapi import FastAPI, File, Query, Request, UploadFile, applications
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import (HTMLResponse, JSONResponse, PlainTextResponse,
                               RedirectResponse, StreamingResponse)
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from whisper import tokenizer

from .util.audio import load_audio
from .worker import transcribe as bg_transcribe

logging.basicConfig(format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s', level=logging.INFO, force=True)
logger = logging.getLogger(__name__)

ASR_ENGINE = os.getenv("ASR_ENGINE", "faster_whisper")
if ASR_ENGINE == "faster_whisper":
    from .faster_whisper.core import load_model, language_detection, transcribe as whisper_transcribe
else:
    from .openai_whisper.core import load_model, language_detection, transcribe as whisper_transcribe

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
    model_name: Union[str, None] = Query(default=None, description="Model name to use for transcription")
):
    model_name = model_name or DEFAULT_MODEL_NAME
    asr_options = {k: v for k, v in locals().items() if k in ASR_OPTIONS}
    logger.info(f"Transcribing {audio_file.filename} with {asr_options}")

    logger.info(f"Loading model {model_name}")
    load_model(model_name)

    result = whisper_transcribe(load_audio(audio_file.file, encode), asr_options, output)
    filename = audio_file.filename.encode('latin-1', 'ignore')
    return StreamingResponse(
        result,
        media_type="text/plain",
        headers={
            'Asr-Engine': ASR_ENGINE,
            'Content-Disposition': f'attachment; filename="{filename}.{output}"'
        })


@app.post("/asr_async", tags=["Endpoints"])
async def asr_async(
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
    model_name: Union[str, None] = Query(default=None, description="Model name to use for transcription")
):
    model_name = model_name or DEFAULT_MODEL_NAME
    asr_options = {k: v for k, v in locals().items() if k in ASR_OPTIONS}
    logger.info(f"Transcribing (async) {audio_file.filename} with {asr_options}")

    source_file = NamedTemporaryFile(delete=False)
    source_file.write(audio_file.file.read())
    source_file.close()

    job = bg_transcribe.apply_async((source_file.name, audio_file.filename, asr_options))
    return JSONResponse({"job_id": job.id})


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

@app.post("/detect-language", tags=["Endpoints"])
async def detect_language(
        audio_file: UploadFile = File(...),
        encode: bool = Query(default=True, description="Encode audio first through ffmpeg")
):
    detected_lang_code = language_detection(load_audio(audio_file.file, encode))
    return {"detected_language": tokenizer.LANGUAGES[detected_lang_code], "language_code": detected_lang_code}
