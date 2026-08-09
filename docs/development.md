# Development

The application is maintained as readable Lua modules under
`reascripts/ReaSpeech/source`. The release artifact is one self-contained
`reascripts/ReaSpeech/build/ReaSpeech.lua` file.

## Requirements

- Lua 5.3 and 5.4 for the test suite
- LuaCheck for linting
- Make and standard command-line file utilities
- REAPER with ReaImGui 0.10 or newer
- ReaSpeech Lib installed in REAPER's `UserPlugins` directory

## Build and test

From `reascripts/ReaSpeech`, run:

```sh
make lint
make test
make build
```

`make build` concatenates the header, bundled JSON implementation, embedded
images, application modules, version, and entry point into
`build/ReaSpeech.lua`. The `build` directory is ignored by Git.

## Publishing

The release bundle is published through the Team Audio ReaPack repository. By
default that repository is expected at `../reascripts` relative to this one.

First validate the bundle and destination repository without changing either:

    make -C reascripts/ReaSpeech publish-check

To publish, ensure both repositories are on `main` with clean working trees,
then run:

    make -C reascripts/ReaSpeech publish

This builds `build/ReaSpeech.lua`, copies it to `ReaSpeech/ReaSpeech.lua` in the
ReaPack repository, commits the package, runs `reapack-index` to commit the
updated index, and pushes the ReaPack repository. Override the destination with
`REASCRIPTS_DIR=/path/to/reascripts` when needed.
The result is plain Lua and runs on both Lua versions supported by REAPER.

The tests use a mocked REAPER API and can be run without launching REAPER.
For interactive testing, rebuild `build/ReaSpeech.lua`, add that file to
REAPER's Actions window, and run it.

## Architecture

`ReaSpeechWorker` translates the UI's existing queued requests into
`ReaSpeech_Start`, polls events using `ReaSpeech_Poll`, and forwards completed
segments into the existing transcript editor. Cancellation calls
`ReaSpeech_Cancel`.

The UI intentionally exposes only capabilities currently provided by
ReaSpeech Lib. Additional recognition options can be enabled when the
extension adds support for them.
