# HLS Audio Transcode

Audio transcoding workflow for converting source audio files to HLS (HTTP Live Streaming) format using containerized ffmpeg.

## Overview

This is a containerized audio transcoding system that converts source audio files (WAV, FLAC, MP3, etc.) into HLS format with adaptive bitrate streaming. The workflow uses ffmpeg to generate three quality tiers (64k, 128k, 192k MP3) with HLS playlists.

**Owner:** Noise2Signal LLC

## Quick Start

```bash
./launch-transcode.sh
```

You'll be prompted for:
- **Staged directory**: Host path containing input audio files
- **Processed directory**: Host path for transcoded HLS output

See [CLAUDE.md](CLAUDE.md) for detailed usage and configuration.

## License and Compliance

### This Project

The wrapper scripts and container configuration in this repository are licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Noise2Signal LLC

### FFmpeg (LGPL 2.1+)

This project uses **FFmpeg** as an external binary for audio transcoding. FFmpeg is licensed under the GNU Lesser General Public License (LGPL) version 2.1 or later.

**Important:** This project executes ffmpeg as a separate process (not linked as a library), which means:
- The wrapper code remains under MIT License
- FFmpeg retains its LGPL 2.1+ license
- No license conflict exists between MIT and LGPL

#### FFmpeg Source Code Access

As required by LGPL, the complete source code for ffmpeg is available:

- Official releases: https://ffmpeg.org/download.html
- Alpine package sources: https://git.alpinelinux.org/aports/
- Container version check: `podman run --rm alpine:3.21 sh -c "apk add ffmpeg && ffmpeg -version"`

See [NOTICE](NOTICE) for complete third-party software information.

#### Patent Considerations

This transcoder uses **MP3 (MPEG-1 Audio Layer III)** as the output codec. The MP3 patents have expired worldwide:
- US patents expired in 2017
- European patents expired in 2012

MP3 encoding via libmp3lame is now patent-free and safe for commercial use.

## Requirements

- Podman or Docker
- Source audio files with required metadata (artist, title)

## Documentation

- [CLAUDE.md](CLAUDE.md) - Complete usage guide and technical documentation
- [LICENSE](LICENSE) - MIT License for this project's code
- [NOTICE](NOTICE) - Third-party software notices (FFmpeg)

## Contributing

When contributing, ensure all code follows the existing patterns:
- Minimal comments; self-documenting code
- Shell scripts output tool stdout only
- No echo instrumentation unless tools provide no output
