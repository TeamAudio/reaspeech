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

Publishing a GitHub release builds `ReaSpeech.lua` from its tag and attaches it
as a downloadable asset through `.github/workflows/release-assets.yml`. This
also runs for prereleases. To retry an upload, run that workflow manually with
the existing release tag; it replaces the asset with a fresh build of that tag.

Publishing a full GitHub release also triggers two workflows, following the XY Pad
release pipeline:

- `.github/workflows/reapack-publish.yml` builds the Lua bundle, copies it to
  `ReaSpeech/ReaSpeech.lua` in `TeamAudio/reascripts`, commits the package and
  updated ReaPack index, and opens a PR for review.
- `.github/workflows/release.yml` opens a PR in `TeamAudio/techaudio-web` with
  the release notes and announcement through its shared publish-release action.

Drafts and prereleases do not publish to ReaPack or the website. Promoting a prerelease to a full release
does publish. Both workflows also support manual runs; use the ReaPack workflow's
`tag` input to retry a release and its optional `source_ref` to test a fix without
moving the tag. The website workflow supports rerunning corrected release notes.

Configure `REASCRIPTS_PUBLISH_TOKEN` with permission to push branches and open
PRs in `TeamAudio/reascripts`, and `PUBLISH_RELEASE_SERVICE_TOKEN` for the website
publishing action. The optional `LATEST_RELEASE_URL` repository variable overrides
the website's release link. Merge the generated PRs after reviewing them.

### Local publishing

The release bundle is published through the Team Audio ReaPack repository. By
default that repository is expected at `../reascripts` relative to this one.

Stage the generated package in the ReaPack checkout and inspect the printed
diff:

    make -C reascripts/ReaSpeech publish

This does not commit or push anything. Restore the staged package after review,
ensure the ReaPack repository is clean, then create the release commits with:

    make -C reascripts/ReaSpeech publish-release

This builds `build/ReaSpeech.lua`, copies it to `ReaSpeech/ReaSpeech.lua` in the
ReaPack repository, commits the package, runs `reapack-index` to commit the
updated index, and leaves both commits for review. Push the ReaPack repository
manually to publish. Override the destination with
`REASCRIPTS_DIR=/path/to/reascripts` when needed.
The result is plain Lua and runs on both Lua versions supported by REAPER.

The tests use a mocked REAPER API and can be run without launching REAPER.
For interactive testing, rebuild `build/ReaSpeech.lua`, add that file to
REAPER's Actions window, and run it.

## Architecture

`ReaSpeechWorker` translates the UI's existing queued requests into
`ReaSpeech_StartEx` with JSON options, polls events using `ReaSpeech_Poll`,
and forwards completed segments into the existing transcript editor.
Cancellation calls `ReaSpeech_Cancel` and keeps polling until a terminal event
arrives.

The UI intentionally exposes only capabilities currently provided by
ReaSpeech Lib. Additional recognition options can be enabled when the
extension adds support for them.
