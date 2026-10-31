# ReaSpeech

![Lint & Test](https://github.com/TeamAudio/reaspeech/actions/workflows/check-reascripts.yml/badge.svg)

### Painless speech-to-text transcription inside REAPER

ReaSpeech is a ReaScript interface for transcribing REAPER media items. It
builds a searchable, project-marker-based transcript while keeping REAPER
responsive during recognition. Find that perfect take, jump to a spoken phrase,
or give your scrubbing finger a well-earned break.

![ReaSpeech screenshot](docs/assets/img/reaspeech-screenshot.png)

## Requirements

- REAPER
- [ReaImGui](https://github.com/cfillion/reaimgui) 0.10 or newer
- ReaSpeech Lib installed in REAPER's `UserPlugins` directory

## Install

Add the Team Audio repository to ReaPack:

    https://github.com/TeamAudio/reascripts/raw/main/index.xml

Install **ReaSpeech** and one **ReaSpeech Lib** backend from ReaPack, then run
ReaSpeech from REAPER's Actions window. The script is self-contained; its only
runtime dependencies are ReaImGui and ReaSpeech Lib.

Select one or more media items and click **Transcribe Selected Items**.
Recognition runs asynchronously, with progress and cancellation available in
the existing ReaSpeech interface.

## Coming from the Docker version?

Starting with ReaSpeech 1.0, transcription runs through ReaSpeech Lib instead of
the Docker-hosted web service. Docker and the local web server are no longer
required. Install ReaSpeech and a ReaSpeech Lib backend through ReaPack using
the instructions above; your existing Docker container is not used by this
version.

If you still need an older Docker-based version, the legacy images remain on
[Docker Hub](https://hub.docker.com/r/techaudiodoc/reaspeech). We will continue
hosting them for a limited time, so please plan to move to the new version.
The old setup instructions are preserved in the
[0.5.0 documentation](https://github.com/TeamAudio/reaspeech/tree/v0.5.0/docs).

## Get involved

Found a bug, have a question, or want to help? Visit the
[issue tracker](https://github.com/TeamAudio/reaspeech/issues), read our
[contribution guidelines](docs/CONTRIBUTING.md), or see
[Development](docs/development.md) to build and test ReaSpeech.

## Credits

### ReaSpeech team

- [Dave Benjamin](https://github.com/ramen)
- [Jason Nanna](https://github.com/smrl)
- [Kyle Vande Slunt](https://github.com/kvande-standingwave)
- [Michael DeFreitas](https://github.com/mikeylove)
- [Roel Sanchez](https://github.com/roelsan)

### Open source projects

- [ReaSpeech Lib](https://github.com/TeamAudio/reaspeech-lib) provides the
  transcription engine.
- [ReaImGui](https://github.com/cfillion/reaimgui) by Christian Fillion powers
  the user interface.
- [OpenMoji](https://openmoji.org) provides the emoji icons, licensed under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- [json.lua](https://github.com/rxi/json.lua) by rxi handles JSON, and
  [LuaUnit](https://github.com/bluebird75/luaunit) supports our tests.

Our earlier Docker-based versions built on
[Whisper ASR Webservice](https://github.com/ahmetoner/whisper-asr-webservice)
and [Faster Whisper](https://github.com/SYSTRAN/faster-whisper). Thank you to
their contributors for helping ReaSpeech get its start.

## License

ReaSpeech is distributed under the GNU General Public License v3.0. See
[LICENSE](LICENSE). Third-party components retain their own licenses; the
earlier web service included code derived from the MIT-licensed Whisper ASR
Webservice project.
