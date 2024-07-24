# Docker Usage

## Overview

ReaSpeech uses a Docker image to streamline the use of Whisper from REAPER by
packaging up most of the software dependencies into a service. This means you
can run ReaSpeech on any platform that supports Docker without having to
install a bunch of software on your local machine. This image needs to be
running in order for ReaSpeech to work.

The Docker image is a virtual environment containing all needed software
dependencies, and if you have a graphics card that supports CUDA
(recent NVIDIA GPUs), you can benefit from increased processing speed.
All of the processing is done locally on your computer with no internet
requirements beyond the initial setup.

## GPU Support

If you have a compatible NVIDIA GPU, you can use the `reaspeech-gpu` image to
take advantage of GPU acceleration. This can significantly speed up the
transcription process. If you don't have a compatible GPU, you can still use
the `reaspeech` image, which will run on your CPU.

## Running the Docker Image

To run the Docker image, you'll need to have Docker installed on your machine.
You can download Docker [here](https://www.docker.com/products/docker-desktop/).

### CPU

To run the CPU version of the Docker image, use the following command:

```sh
docker run -d -p 9000:9000 techaudiodoc/reaspeech:latest
```

This will download the latest version of the `reaspeech` image from Docker Hub
and run it in a container. The `-d` flag tells Docker to run the container in
detached mode, so it will continue running in the background. The `-p 9000:9000`
flag tells Docker to map port 9000 on your local machine to port 9000 in the
container, so you can access the ReaSpeech web interface at
[http://localhost:9000](http://localhost:9000).

### GPU

GPU support is **optional**, but will enable faster processing using your
graphics card. It is currently limited to NVIDIA cards that support CUDA, a
platform which allows you to use the processing power of your GPU for general
computing tasks such as the ASR model. GPU support is currently working on
Windows and Linux, but not yet available on Mac.

For GPU support on Windows, you may need to:

1. Install the latest [NVIDIA driver](https://www.nvidia.com/Download/index.aspx)
2. Install [CUDA Toolkit 12.2 or later](https://developer.nvidia.com/cuda-downloads?target_os=Windows&target_arch=x86_64&target_version=11&target_type=exe_local)
3. Ensure virtualization is enabled in your BIOS and in Windows features:
   [Windows 10](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) / [Windows 11](https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-11-pcs-c5578302-6e43-4b4b-a449-8ced115f58e1)
4. Set up [Docker with WSL2](https://docs.docker.com/desktop/windows/wsl/)

If you have a compatible NVIDIA GPU, you can run the GPU version of the Docker
image using the following command:

```sh
docker run -d --gpus all -p 9000:9000 techaudiodoc/reaspeech:latest-gpu
```

This will download the latest version of the `reaspeech-gpu` image from Docker
Hub and run it in a container. The `--gpus all` flag tells Docker to give the
container access to all GPUs on your machine. The `-p 9000:9000` flag maps port
9000 on your local machine to port 9000 in the container, so you can access the
ReaSpeech web interface at [http://localhost:9000](http://localhost:9000).

## Setting up the ReaSpeech script

Once the Docker container is running, you'll need to set up the ReaSpeech script
in REAPER to communicate with the Docker container. Click the "9000:9000" link
in the Docker Desktop interface or navigate to
[http://localhost:9000](http://localhost:9000).
You should see a web page that explains how to install and run ReaSpeech.
The ReaSpeech script can be downloaded from this page.
Before running the script, you will need to follow the instructions to ensure
that ReaPack and ReaImGui are installed in REAPER.

## Stopping the Docker Container

To stop the Docker container, you'll need to know the container ID. You can get
a list of running containers and their IDs by running:

```sh
docker ps
```

This will show you a list of running containers, along with their IDs, names,
and other information. Find the ID of the ReaSpeech container you want to stop,
and then run:

```sh
docker stop <container_id>
```

Replace `<container_id>` with the ID of the container you want to stop. This
will stop the container, but it will still be on your machine. To remove the
container completely, run:

```sh
docker rm <container_id>
```

This will remove the container from your machine.

## Updating the Docker Image

To update the Docker image to the latest version, you can pull the latest
version from Docker Hub and run it in a new container. First, stop and remove
the existing container:

```sh
docker stop <container_id>
docker rm <container_id>
```

Then pull the latest version of the image and run it in a new container:

```sh
docker pull techaudiodoc/reaspeech:latest
docker run -d -p 9000:9000 techaudiodoc/reaspeech:latest
```

This will download the latest version of the `reaspeech` image from Docker Hub
and run it in a new container.

## Troubleshooting

If you're having trouble running the Docker image, here are a few things to
check:

- Make sure Docker is installed and running on your machine.
- Make sure you're using the correct command to run the Docker image.
- Check the Docker logs for the container to see if there are any error
  messages.
- If you're using the GPU version of the Docker image, make sure you have a
  compatible NVIDIA GPU and that the NVIDIA container toolkit is installed on
  your machine.

If you're still having trouble, feel free to reach out to the ReaSpeech team
for help.

## Using Docker Compose

If you would like to develop ReaSpeech or run it in a more controlled
environment, you can use [Docker Compose](https://docs.docker.com/compose/) to
manage the Docker containers.

### CPU

To build and run the CPU version of the ReaSpeech Docker image using Docker
Compose, run the following command:

```sh
docker-compose up --build
```

### GPU

If you have a compatible NVIDIA GPU and would like to run the GPU version of
the ReaSpeech Docker image using Docker Compose, you can use the following
command:

```sh
docker-compose -f docker-compose.gpu.yml up --build
```

This will build the GPU version of the Docker image and run it in a container.
You can access the ReaSpeech web interface at
[http://localhost:9000](http://localhost:9000).

To stop the Docker container, press `Ctrl+C` in the terminal where Docker
Compose is running.

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
`SERVICE_UID` and `SERVICE_GID` environment variables when running the Docker
container. For example:

```sh
docker run -d -p 9000:9000 -e SERVICE_USER=app -e SERVICE_UID=1000 -e SERVICE_GID=1000 techaudiodoc/reaspeech:latest
```

When using Docker Compose, you can set these environment variables in the
`docker-compose.yml` or `docker-compose.gpu.yml` file. For example:

```yaml
services:
  reaspeech:
    environment:
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
