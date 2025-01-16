# Getting Started with ReaSpeech

Welcome to the ReaSpeech setup guide. Follow the steps below to get started based on your platform and GPU status.

## Choose Your Platform

1. [Windows](#windows)
2. [Mac](#mac)
3. [Linux](#linux)

## Windows

### Do you have a CUDA-capable NVIDIA GPU?

1. [Yes](#windows-with-gpu-support)
2. [No](#windows-without-gpu-support)

#### Windows with GPU Support

You'll want to check out the [Docker-based installation guide](docker.md). When you're following along, you'll be choosing the options that deal with the image `reaspeech-gpu`.

#### Windows without GPU Support

You'll want to check out the [Docker-based installation guide](docker.md). When you're following along, you'll be choosing the options that deal with the image `reaspeech`.

## Mac

### What type of Mac do you have?

1. [Intel Mac](#intel-mac)
2. [Apple Silicon](#apple-silicon)

#### Intel Mac

It's up to you whether or not to use Docker. Are you comfortable managing your own development environment and tools? You might appreciate running ReaSpeech directly - especially if you want to contribute some code yourself!

1. [Use Docker - "This is all new to me!" or "I'm mostly transcribing anyway."](#intel-mac-docker)
2. [No Docker - "I enjoy command lines" or "I'm interested in extending ReaSpeech"](#intel-mac-no-docker)

##### Intel Mac (Docker)

To run ReaSpeech on an Intel Mac, use Docker with the image name `reaspeech`. [Installation instructions are here.](docker.md)

##### Intel Mac (No Docker)

To run ReaSpeech on an Intel Mac without Docker, [check out our No Docker guide](no-docker.md). Make sure to use the OpenAI Whisper engine (`openai-whisper`).

#### Apple Silicon

There are some technical details that currently prevent dockerized services from using your GPU. That means the buy-in for GPU-accelerated transcription is a bit more command-line effort. It's super worth it though, we promise!

[Follow the No Docker guide](no-docker.md), and be sure to choose the `whisper_cpp` engine. It's the one that provides GPU support.

## Linux

### Do you have a CUDA-capable NVIDIA GPU?

1. [Yes](#linux-with-gpu-support)
2. [No](#linux-without-gpu-support)

#### Linux with GPU Support

To run ReaSpeech on Linux with a CUDA-capable NVIDIA GPU, Docker is optional. You might need to install some CUDA tools? Maybe. That's at least a Windows thing, need to follow up.

If you'd like to keep it simple, then [yeah, Docker is a decent option](docker.md). Make sure to use the `reaspeech-gpu` image. 

If you want to run ReaSpeech yourself, follow [this guide instead](no-docker.md).

#### Linux without GPU Support

[If Docker seems simpler to you, follow this guide.](docker.md)

If you'd prefer to run ReaSpeech yourself, [follow our No Docker guide](no-docker.md).