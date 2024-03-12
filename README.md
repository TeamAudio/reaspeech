# ReaSpeech

### Painless speech-to-transcript inside of REAPER
ReaSpeech is a REAScript frontend that will take your project's media items and run them through a docker-hosted whisper backend, building a searchable, project-marker based index of the resulting transcription. That's right - not only do you reap (zing!) the benefits of a staff of transcribers, but you get to add "familiar with Docker" to your resume.


### CPU or GPU-based transcriptions
If you have a compatible GPU (requirements list?), ReaSpeech can use it!

## Usage

### Install Docker

The copypasta below requires that you've already got [Docker](https://www.docker.com/) installed, providing path-reachable command-line tools (`docker` and `docker-compose`). You can download Docker [here](https://www.docker.com/products/docker-desktop/).

### Build and Run

Based on your environment (do you have a compatible GPU?), choose the appropriate "build and run" block below.


```sh
# Build and Run for CPU
docker build -t reaspeech .
docker run -d -p 9000:9000 --name reaspeech reaspeech
docker-compose up --build

# Build and Run for GPU
docker build -f Dockerfile.gpu -t reaspeech-gpu .
docker run -d --gpus all -p 9000:9000 --name reaspeech-gpu reaspeech-gpu
docker-compose -f docker-compose.gpu.yml up --build
```

## Development

We expect that roughly 96.7533% of users will have their needs met with things as they are, but for that remaining 3.2467% here's how you can make changes and rebuild.

### Design Philosophy

Programming with Lua inside of REAPER - while generally fluid and intuitive, once you understand the model that REAScript provides - can be tricky and littered with gotchas that can (and have) left even the most seasoned developers in a somewhat-comatose state of crisis, only emitting a faint but discernible existential wail.

ReaSpeech code is written to mostly respect the top-level namespace and environment of the running Lua interpreter. Use of globals is limited to the variables `app` (the single instance of `ReaSpeechUI`) and `ctx` (the ImGui context) - both instantiated in `ReaSpeechMain.lua`.

"Building" the script for distribution consists of concatenating a specified collection of lua source files (everything in `Source` and from a common library), so any code should be written to not assume that any symbols or objects (variables, tables or "classes") are available on the initial parse (see `Source/Theme.lua` for an example of how REAScript-aware code is written but deferred). By doing things this way, we avoid confusion as to the loading behavior of Lua modules within REAPER, at the expense of defining these symbols up-front and independently of any other code. The exception to this is in development mode - noted below (inside of the `UI Changes` section).

### UI Changes

Provided is a script (`Source/ReaSpeechDev.lua`) that can be added to REAPER without a running instance of Docker (and thus Whisper). This is useful for making changes to the UI or other facets of the script without having to do a full rebuild or any kind of recomposing of the docker image. Check inside for lines that can be uncommented to provide mock response data useful for look & feel UI development.

### Generic Changes

Once you've made your changes to files inside of `Source` and feel confident in your usage testing via the `ReaSpeechDev.lua` script, you can rebuild your distributable version of the code with the appropriate commands below.

```
# Build development ReaScript locally

# Windows
cd reascripts/ReaSpeech
wsl make

# Linux/MacOS
cd reascripts
make

# Build ReaScript in Docker
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-1 make
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-gpu-1 make
```

### Automatic Rebuilding

A watcher script is provided in case you'd prefer to operate exclusively in dockerland. Changes made inside of `Source` will trigger an automatic rebuild (you will need to re-run your script inside of REAPER). Choose the appropriate command below, based on your choice of CPU or GPU-based transcription.

```
# Watch for changes and rebuild ReaScript in Docker
scripts\reawatch ReaSpeech
scripts\reawatch-gpu ReaSpeech
```

# Credits
