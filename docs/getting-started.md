# Getting Started with ReaSpeech

Welcome to the ReaSpeech setup guide! Ours is a simple goal: get you driving off the lot in a shiny, new ReaSpeech! Ideally, that means utilizing your GPU for the fastest transcription possible, but we're not gonna leave CPU-sers out in the cold here.

Choose the path your adventure follows by clicking each link to get pointed in the right direction based on your platform and GPU status. Scrolling around the document is only going to lead to heartache and misery. Once you receive your prize, you can just follow that link right in this tab - you won't need to get started anymore, you'll be well on your way.

You are a beautiful, unique snowflake and we're gonna make you glisten!

## Choose Your Platform

REAPER is great, right? Windows, Mac, Linux, it doesn't matter! What's your flavor?

1. [Windows](#windows)
2. [Mac](#mac)
3. [Linux](#linux)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
# Getting Started with ReaSpeech ...again

Oh, hello! Really didn't expect you back here, but always happy to see that million dollar smile! Same rules - scrolling spoils the fun; click your way through for maximum joy!

## Choose Your Platform

REAPER is great, right? Windows, Mac, Linux, it doesn't matter! What's your flavor?

1. [Windows](#windows)
2. [Mac](#mac)
3. [Linux](#linux)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## Windows

### Do you have a CUDA-capable NVIDIA GPU?

Transcription is much faster using a GPU, but support is limited to NVIDIA GPUs with CUDA support.

1. [Yes](#🎉-your-prize-is-our-docker-with-gpu-guide-🥳)
2. [No](#🎉-your-prize-is-our-docker-guide-🥳)
3. [What's a CUDA? What are you talking about? Where am I?](#whats-a-cuda)

[Start Over, or "did I say Windows? I meant uhhh...Mac...or Linux"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## Mac

### What type of Mac do you have?

A few years back, Apple decided to mix things up again in announcing their departure from Intel as a core platform in favor of their own chips.

Who knows if that was the right call, but they apparently couldn't even at least do us the courtesy of calling to see how that might affect our writing installation documentation for a product that we wouldn't concieve of until years later. Kinda rude, but we've moved past that mostly.

What was the question? Oh...yeah, what kind of Mac are you on?

1. [Intel Mac](#intel-mac)
2. [Apple Silicon](#one-more-note-about-apple-silicon)

[Start Over, or "did I say Mac? I meant uhhh...Windows...or Linux"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
#### Intel Mac

It's up to you whether or not to use Docker. Are you comfortable managing your own development environment and tools? You might appreciate running ReaSpeech directly - especially if you want to contribute some code yourself! Unfortunately, GPU support is off the table for the foreseeable future.

1. [Use Docker - "This is all new to me!" or "I'm mostly transcribing anyway."](#🎉-your-prize-is-our-docker-guide-🥳)
2. [No Docker - "I enjoy command lines" or "I'm interested in extending ReaSpeech"](#one-more-note-about-no-docker-mac)
3. [I lied, I'm actually on Apple Silicon but had a nostalgic hankering for a simpler time](#one-more-note-about-apple-silicon)

[Start Over, or "I thought I was ready to think different, but I was wrong"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## Linux

### Do you have a CUDA-capable NVIDIA GPU?

Transcription is much faster using a GPU, but support is limited to NVIDIA GPUs with CUDA support.

1. [Yes](#linux-with-gpu-support)
2. [No](#linux-without-gpu-support)
3. [What's a CUDA? What are you talking about? Where am I?](#whats-a-cuda)

[Start Over, or "did I say Linux? I meant uhhh...Windows...or Mac"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
#### Linux with GPU Support

To run ReaSpeech on Linux with a CUDA-capable NVIDIA GPU, Docker is optional.

1. [Use Docker - "This is all new to me!" or "I'm mostly transcribing anyway."](#🎉-your-prize-is-our-docker-with-gpu-guide-🥳)
2. [No Docker - "I enjoy command lines" or "I'm interested in extending ReaSpeech"](#🎉-your-prize-is-our-no-docker-guide-🥳)

[Start Over, or "I was just curious what all this 'Linux' business was all about"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
#### Linux without GPU Support

The choice here is mostly about your comfort level with the command-line.

1. [Use Docker - "This is all new to me!" or "I'm mostly transcribing anyway."](#🎉-your-prize-is-our-docker-guide-🥳)
2. [No Docker - "I enjoy command lines" or "I'm interested in extending ReaSpeech"](#🎉-your-prize-is-our-no-docker-guide-🥳)

[Start Over, or "I was just curious what all this 'Linux' business was all about"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
### What's a CUDA?

CUDA is a development layer provided by NVIDIA that works on top of their GPU devices. It's a requirement to enjoy GPU-accelerated transcription. [See if your device is listed here](https://developer.nvidia.com/cuda-gpus).

1. Sweet, my device is supported! I'm...
    - [...on Windows.](#🎉-your-prize-is-our-docker-with-gpu-guide-🥳)
    - [...on Linux.](#linux-with-gpu-support)
2. Dang, I don't see my device on that list, and I'm...
    - [...on Windows](#🎉-your-prize-is-our-docker-guide-🥳)
    - [...on Linux](#linux-without-gpu-support)

[Start Over, or "That was scary, I think I need to click around a few more times before I'm ready"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
### One more note about no-Docker Mac...

You'll probably want to use the `openai-whisper` engine. There are some as-of-yet unresolved library conflicts that cause the `faster-whisper` engine to crash in some environments.

[Click here to claim your prize!](#🎉-your-prize-is-our-no-docker-guide-🥳)

[Start Over, or "I thought I was ready to think different, but I was wrong"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
### One more note about Apple Silicon...

There are some technical details that currently prevent dockerized services from using your GPU. That means the buy-in for GPU-accelerated transcription is a bit more command-line effort. It's super worth it though, we promise!

When you're getting set up, be sure to choose the `whisper_cpp` engine. It's the one that provides GPU support. Don't worry, we'll mention it again when this comes up.

1. [I still think I'd prefer to use Docker, but acknowledge that means CPU-only.](#🎉-your-prize-is-our-docker-guide-🥳)
2. [I'm ready to claim my prize!](#🎉-your-prize-is-our-no-docker-guide-🥳)

[Start Over, or "I thought I was ready to think different, but I was wrong"](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## 🎉 Your prize is our Docker (with GPU) guide! 🥳

You'll want to check out the [Docker-based installation guide](docker.md). When you're following along, you'll be choosing the options that deal with the image `reaspeech-gpu`. Safe bet that you're going to need to install the [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads) if you haven't already, but you can sit and quietly panic about that in the background for the moment.

Thanks for playing! Excelsior!
[Click here to play again](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## 🎉 Your prize is our Docker guide! 🥳

You'll want to check out the [Docker-based installation guide](docker.md). When you're following along, you'll be choosing the options that deal with the image `reaspeech`.

Thank you for playing! Excelsior!
[Click here to play again](#getting-started-with-reaspeech-again)

---

```





















  THIS SPACE INTENTIONALLY LEFT BLANK





















```
## 🎉 Your prize is our No-Docker guide! 🥳

Check out the [No-Docker installation guide](no-docker.md). There's a bit more to do to set things up, but in the end it's pretty simple too.

Thank you for playing! Excelsior!
[Click here to play again](#getting-started-with-reaspeech-again)

---

```











































  THIS SPACE INTENTIONALLY LEFT BLANK


































(👋)
```
