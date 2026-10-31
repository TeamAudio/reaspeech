## Legacy Docker images — migration notice

These images are for older, Docker-based versions of ReaSpeech (0.7.x and
earlier). Starting with ReaSpeech 1.0, Docker and the local web server are no
longer required: transcription runs through ReaSpeech Lib, installed alongside
ReaSpeech through ReaPack.

See the [ReaSpeech installation and migration instructions](https://github.com/TeamAudio/reaspeech#coming-from-the-docker-version).
After installing and testing the new version, switch your shortcuts and toolbar
buttons to the ReaPack-installed action, stop your old ReaSpeech container,
and disable its automatic startup. Your old downloaded script still requires
the Docker web service.

We will continue hosting these legacy images for a limited time, so please
plan to move to the new version. For the old setup instructions, see the
[0.7.3 documentation](https://github.com/TeamAudio/reaspeech/tree/v0.7.3/docs).
