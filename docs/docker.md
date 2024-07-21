## Docker Usage

### Install Docker

The copypasta below requires that you've already got [Docker](https://www.docker.com/) installed, providing path-reachable command-line tools (`docker` and `docker-compose`). You can download Docker [here](https://www.docker.com/products/docker-desktop/).

### Build and Run

Based on your environment (do you have a compatible GPU?), choose the appropriate "build and run" block below.


```sh
# Build and Run for CPU
docker build -t reaspeech .
docker run -d -p 9000:9000 --name reaspeech reaspeech

# Build and Run for CPU (Development)
docker-compose up --build

# Build and Run for GPU
docker build -f Dockerfile.gpu -t reaspeech-gpu .
docker run -d --gpus all -p 9000:9000 --name reaspeech-gpu reaspeech-gpu

# Build and Run for GPU (Development)
docker-compose -f docker-compose.gpu.yml up --build
```
