# Docker Usage

## Overview

ReaSpeech uses a Docker image to streamline the use of Whisper from REAPER by
packaging up most of its software dependencies into a service. This means you
can run ReaSpeech on any platform that supports Docker without having to
install a bunch of software on your local machine. This image needs to be
running in order for ReaSpeech to work.

The Docker image is a virtual environment containing all needed software
dependencies, and if you have a graphics card that supports CUDA
(recent NVIDIA GPUs), you can benefit from increased processing speed.
All of the processing is done locally on your computer with no internet
requirements beyond the initial setup.

## Quick Start

The fastest way to get up and running with ReaSpeech is to use the search
feature in Docker Desktop:

* Type "techaudiodoc/reaspeech" into the search box
* Ensure that the "latest" tag is selected, and click "Run"
* Open "Optional settings" and enter "9000" for the "Host port"
* Click "Run" to start the container

Note that this will run the CPU version. To use the GPU version, you will have
to use the command line. See the following instructions for details.

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
docker run -d -p 9000:9000 --name reaspeech techaudiodoc/reaspeech:latest
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
docker run -d --gpus all -p 9000:9000 --name reaspeech-gpu techaudiodoc/reaspeech:latest-gpu
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

## Updating the Docker Image

### CPU

To update the Docker image to the latest version, you can pull the latest
version from Docker Hub and run it in a new container. First, stop and remove
the existing container:

```sh
docker stop reaspeech
docker rm reaspeech
```

Then, pull the latest version of the image and run it in a new container:

```sh
docker pull techaudiodoc/reaspeech:latest
docker run -d -p 9000:9000 --name techaudiodoc/reaspeech:latest
```

This will download the latest version of the `reaspeech` image from Docker Hub
and run it in a new container.

### GPU

To update the GPU version of the Docker image, you can follow the same steps as
above, but use the `reaspeech-gpu` image instead:

```sh
docker stop reaspeech-gpu
docker rm reaspeech-gpu
docker pull techaudiodoc/reaspeech:latest-gpu
docker run -d --gpus all -p 9000:9000 --name reaspeech-gpu techaudiodoc/reaspeech:latest-gpu
```

This will download the latest version of the `reaspeech-gpu` image from Docker
Hub and run it in a new container.

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
