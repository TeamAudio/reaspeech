# Development

We expect that roughly 96.7533% of users will have their needs met with things
as they are, but for that remaining 3.2467% here's how you can make changes
and rebuild.

## Design Philosophy

Programming with Lua inside of REAPER - while generally fluid and intuitive,
once you understand the model that ReaScript provides - can be tricky and
littered with gotchas that can (and have) left even the most seasoned
developers in a somewhat-comatose state of crisis, only emitting a faint but
discernible existential wail.

ReaSpeech code is written to mostly respect the top-level namespace and
environment of the running Lua interpreter. Use of globals is limited to the
variables `app` (the single instance of `ReaSpeechUI`) and `ctx` (the ImGui
context) - both instantiated in `ReaSpeechMain.lua`.

"Building" the script for distribution consists of concatenating a specified
collection of Lua source files (everything in `source` and from a common
library), so any code should be written to not assume that any symbols or
objects (variables, tables or "classes") are available on the initial parse
(see `source/Theme.lua` for an example of how ReaScript-aware code is written
but deferred). By doing things this way, we avoid confusion as to the loading
behavior of Lua modules within REAPER, at the expense of defining these
symbols up-front and independently of any other code.

## Using Docker Compose

The most straightforward way to work on ReaSpeech is to use Docker Compose.
This will set up the development environment for you and allow you to make
changes to the code without having to worry about dependencies. It is also
possible to run ReaSpeech without Docker, but this requires setting up the
environment manually. Both methods are described below.

To build and run the ReaSpeech Docker image using Docker Compose, run the
following command:

### CPU

```sh
docker compose up --build
```

### GPU

If you have a compatible NVIDIA GPU and would like to run the GPU version of
the ReaSpeech Docker image using Docker Compose, you can use the following
command:

```sh
docker compose -f docker-compose.gpu.yml up --build
```

This will build the Docker image and run it in a container. You can access the
ReaSpeech web interface at [http://localhost:9000](http://localhost:9000).

You can leave off the `--build` flag if you have already built the image and
just want to run the container.

To stop the Docker container, press `Ctrl+C` in the terminal where Docker
Compose is running.

### Filesystem Mounting

When running the ReaSpeech Docker image with Docker Compose, the "app" directory
is mounted as a volume in the container. This allows you to make changes to the
ReaSpeech code and see the changes reflected in the container without having to
rebuild the image.

## Building ReaScripts

The ReaSpeech UI and related code are in a set of Lua files in the "reascripts"
directory. If you have the necessary dependencies (see the Makefile for details),
you can build the ReaScripts by running:

```sh
cd reascripts/ReaSpeech
make
```

You can also build the ReaScripts by running the `make` command within the
container created by Docker Compose:

```sh
# CPU version
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-1 make
# GPU version
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-gpu-1 make
```

### Automatic Rebuilding

If you would like the ReaScripts to be automatically rebuilt whenever you make
changes to the Lua files, you can run the following command:

```sh
# CPU version
scripts/reawatch ReaSpeech
# GPU version
scripts/reawatch-gpu ReaSpeech
```

### Build-Free ReaScript Development

A "ReaSpeechDev.lua" file is provided in the "reascripts/ReaSpeech" directory.
This file loads all of the Lua source files directly each time it runs,
enabling you to make changes to the Lua files and see the changes reflected in
REAPER without having to rebuild the ReaScripts. To use this file, add it as
an action in REAPER.

## Web Service Development

The ReaSpeech web service is written in Python using the FastAPI framework. If
you make changes to the web service code, you will need to restart the web
service for the changes to take effect. You can do this by stopping the Docker
container and running `docker compose up` again. You can also restart the
container by clicking the "Restart" button in the Docker Desktop interface.

## Environment Variables

You can customize the behavior of the ReaSpeech Docker image by setting
environment variables when running the container. Here are the available
environment variables and their default values:

- `ASR_ENGINE`: The ASR engine to use. Options are `faster_whisper` (default)
  and `openai_whisper`.

To set an environment variable when running the Docker container, use the `-e`
flag followed by the variable name and value. For example, to use the
`openai_whisper` engine, you would run:

```sh
docker run -d -p 9000:9000 -e ASR_ENGINE=openai_whisper techaudiodoc/reaspeech:latest
```

When using Docker Compose, you can set environment variables in the
`docker-compose.yml` or `docker-compose.gpu.yml` file. For example:

```yaml
services:
  reaspeech:
    environment:
      - ASR_ENGINE=openai_whisper
```

## Filesystem Permissions

When running the ReaSpeech Docker image with Docker Compose, the "app" directory
is mounted as a volume in the container. This allows you to make changes to the
ReaSpeech code and see the changes reflected in the container without having to
rebuild the image. However, the permissions on the mounted volume may not match
the permissions in the container, which can cause issues when running the
ReaSpeech service.

To fix this issue, you can use the `SERVICE_UID` and `SERVICE_GID` Dockerfile
arguments. By default, the service runs as the `service` user with
UID 1001 and GID 1001. If you need to change these values, you can set the
`SERVICE_UID` and `SERVICE_GID` environment variables in the
`docker-compose.yml` or `docker-compose.gpu.yml` file. For example:

```yaml
services:
  reaspeech:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - SERVICE_UID=1000
        - SERVICE_GID=1000
```

## Restart Behavior

By default, the ReaSpeech Docker container will restart automatically if it
crashes or is stopped. This behavior can be customized using the `--restart`
flag when running the container. The available options are:

- `no`: Do not restart the container if it stops or crashes.
- `always`: Always restart the container if it stops or crashes.
- `on-failure`: Restart the container only if it stops with a non-zero exit
  code.
- `unless-stopped`: Always restart the container unless it is explicitly
  stopped.

To set the restart behavior when running the Docker container, use the
`--restart` flag followed by the desired option. For example, to always restart
the container, you would run:

```sh
docker run -d -p 9000:9000 --restart always techaudiodoc/reaspeech:latest
```

When using Docker Compose, you can set the restart behavior in the
`docker-compose.yml` or `docker-compose.gpu.yml` file. For example:

```yaml
services:
  reaspeech:
    restart: always
```

## Running Without Docker

If you prefer not to use Docker, you can set up the ReaSpeech environment
manually. Please see [Running Outside of Docker](no-docker.md) for instructions.
