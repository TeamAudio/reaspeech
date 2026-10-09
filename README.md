# ReaSpeech

ReaSpeech is a ReaScript interface for transcribing REAPER media items. It
builds a searchable, project-marker-based transcript while keeping REAPER
responsive during recognition.

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

## Development

See [Development](docs/development.md).

## License

ReaSpeech is distributed under the GNU General Public License v3.0. See
[LICENSE](LICENSE).
