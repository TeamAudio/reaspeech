Changelog
=========

[1.0.0] (2026-08-09)
--------------------

### Changed

- Replaced the Docker, PyTorch, curl, and web-service stack with ReaSpeech Lib
- Distributed ReaSpeech as a single Lua script through ReaPack
- Added asynchronous progress reporting and cancellation through ReaSpeech Lib
- Simplified installation and development setup

[0.5.0] (2025-01-16)
--------------------

### Changed

- Configurable font size
- Improved export interface
- Added support for whisper.cpp ASR engine
- Better external process handling
- Removed dependency on Redis
- Usability and reliability improvements

[0.4.2] (2024-12-05)
--------------------

### Changed

- Optimized table rendering for large transcripts
- Added help tooltips for ASR options

### Fixed

- ImGui_Context errors preventing startup
- Redundant progress updates with faster-whisper

[0.4.1] (2024-11-22)
--------------------

### Changed

- Added Import Transcript feature
- Added Turbo model
- Upgraded faster-whisper to 1.1.0
- Upgraded openai-whisper to 20240930
- Upgraded various Python dependencies

[0.4.0] (2024-11-06)
--------------------

### Changed

- Added Create Markers dialog
- Added Take Marker creation
- Added persistence for speech recognition settings
