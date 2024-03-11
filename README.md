# ReaSpeech

```sh
# Build and Run for CPU
docker build -t reaspeech .
docker run -d -p 9000:9000 --name reaspeech reaspeech

# Build and Run for GPU
docker build -f Dockerfile.gpu -t reaspeech-gpu .
docker run -d --gpus all -p 9000:9000 --name reaspeech-gpu reaspeech-gpu

# Run development server
docker-compose up --build
# or
docker-compose -f docker-compose.gpu.yml up --build

# Build development ReaScript locally
cd reascripts/ReaSpeech
wsl make

# Build ReaScript in Docker
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-1 make
docker exec -w /app/reascripts/ReaSpeech reaspeech-reaspeech-gpu-1 make

# Watch for changes and rebuild ReaScript in Docker
scripts\reawatch ReaSpeech
scripts\reawatch-gpu ReaSpeech
```
