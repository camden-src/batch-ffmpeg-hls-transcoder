# HLS Audio Transcode

Audio transcoding workflow for converting source audio files to HLS (HTTP Live Streaming) format using containerized ffmpeg.

## Container Environment

This is a standalone containerized workflow that does not rely on git repository structure. The launcher script prompts for host directories to mount as `/staged` and `/processed` in the container.

## Transcoding Workflow

Audio files are transcoded to HLS format using a containerized ffmpeg workflow.

```
hls-audio-transcode/
├── Containerfile              # Alpine + ffmpeg container
├── launch-transcode.sh     # Container orchestration with directory prompts
└── generate-hls.sh         # Transcoding script (runs inside container)
```

### Usage

```bash
# Launch transcoder - you will be prompted for host directories
./launch-transcode.sh

# Force rebuild container if needed
./launch-transcode.sh --force-rebuild
```

The launcher will prompt you for:
1. **Staged directory** - Host path containing input audio files (WAV, FLAC, MP3, etc.)
2. **Processed directory** - Host path where transcoded HLS output will be written

**Directory prompts support tab-completion** for easy navigation.

**Permissions:** Ensure both directories are readable, writable, and executable by your user (uid 1000). The container runs as `developer` user with `--userns=keep-id` mapping.

### Track Naming Convention

Source files should use **kebab-case** naming (lowercase words separated by hyphens):

```
creeping-insolence.wav      -> creeping-insolence/
rude-introduction.wav       -> rude-introduction/
my-new-track.wav            -> my-new-track/
```

The filename becomes the track directory identifier in the output structure.

### Container Mounts

- `/staged` - Input directory (read-write)
- `/processed` - Output directory (read-write)

### Output

Each file is transcoded to 3 bitrate tiers (64k, 128k, 192k AAC) with adaptive bitrate master playlist:

```
/processed/{track-name}/
├── master.m3u8      # Adaptive bitrate playlist
├── 64k/stream.m3u8  # Low bandwidth
├── 128k/stream.m3u8 # Medium bandwidth
└── 192k/stream.m3u8 # High bandwidth
```

Example output structure:

```
/processed/
  creeping-insolence/
    master.m3u8
    64k/stream.m3u8
    128k/stream.m3u8
    192k/stream.m3u8
  rude-introduction/
    master.m3u8
    64k/stream.m3u8
    128k/stream.m3u8
    192k/stream.m3u8
```

## Container Standards

This transcoder follows the project's containerized workflow standards:

- **Base Image:** Alpine Linux with ffmpeg
- **User:** developer (uid 1000, gid 1000)
- **Execution Pattern:** One-shot batch processing
- **Mount:** `/workspace` for git repository access

See /workspace/CLAUDE.md for complete container standards and patterns.

## Code Style

- Minimal comments; code should be self-documenting
- Shell scripts output tool stdout only; no echo instrumentation unless tool provides no output
