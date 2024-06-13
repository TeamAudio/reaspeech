FROM swaggerapi/swagger-ui:v4.18.2 AS swagger-ui
FROM python:3.10-slim

ARG UID=1001
ARG GID=1001

ENV POETRY_VENV=/app/.venv

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qq update \
    && apt-get -qq install --no-install-recommends \
    lua5.3 \
    lua5.4 \
    lua-check \
    fswatch \
    make \
    cargo \
    ffmpeg \
    redis \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv $POETRY_VENV \
    && $POETRY_VENV/bin/pip install -U pip setuptools \
    && $POETRY_VENV/bin/pip install poetry==1.6.1

ENV PATH="${PATH}:${POETRY_VENV}/bin"

WORKDIR /app

COPY . /app
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui.css swagger-ui-assets/swagger-ui.css
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui-bundle.js swagger-ui-assets/swagger-ui-bundle.js

RUN poetry config virtualenvs.in-project true
RUN poetry install && rm -rf /root/.cache/pypoetry

WORKDIR /app/reascripts/ReaSpeech
RUN make publish
WORKDIR /app
RUN rm -rf reascripts

RUN groupadd -g $GID service || true
RUN useradd -u $UID -g $GID -d /app -s /usr/sbin/nologin service || true
RUN chown -R service:service .
USER service

ENTRYPOINT ["python3", "app/run.py"]

EXPOSE 9000
