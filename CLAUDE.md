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

# Dedicate CPU cores (OCI-standard resource controls)
./launch-transcode.sh --cpus 4                    # Limit to 4 CPUs
./launch-transcode.sh --cpuset-cpus 0-3           # Pin to cores 0-3
./launch-transcode.sh --cpuset-cpus 0,2,4,6       # Pin to specific cores (e.g., even cores)

# Combine options
./launch-transcode.sh --force-rebuild --cpus 8
```

The launcher will prompt you for:
1. **Staged directory** - Host path containing input audio files (WAV, FLAC, MP3, etc.)
2. **Processed directory** - Host path where transcoded HLS output will be written

**Directory prompts support tab-completion** for easy navigation.

**Permissions:** Ensure both directories are readable, writable, and executable by your user (uid 1000). The container runs as `developer` user with `--userns=keep-id` mapping.

**CPU Resource Controls (OCI-Standard):**

- `--cpus N` - Limit container to N CPUs (fractional values supported, e.g., 2.5)
- `--cpuset-cpus X-Y` - Pin container to specific CPU cores (e.g., 0-3 for cores 0 through 3)
- `--cpuset-cpus X,Y,Z` - Pin to non-contiguous cores (e.g., 0,2,4,6 for even cores only)

These options use Linux cgroups and follow OCI runtime spec standards. Useful for:
- **Dedicated performance** - Pin to specific cores for consistent transcoding speed
- **System stability** - Limit CPU usage to prevent transcoder from overwhelming host
- **NUMA optimization** - Pin to cores on specific NUMA nodes for memory locality

### Track Naming Convention

Source files should use **kebab-case** naming (lowercase words separated by hyphens):

```
creeping-insolence.wav      -> creeping-insolence/
rude-introduction.wav       -> rude-introduction/
my-new-track.wav            -> my-new-track/
```

The filename becomes the track directory identifier in the output structure.

**Track Short Name Generation:**

The transcoder automatically generates a display-friendly track name from the filename:
- Filename (without extension) → Hyphens replaced with spaces → Title Cased
- `creeping-insolence.wav` → `"Creeping Insolence"`
- `rude-introduction.wav` → `"Rude Introduction"`
- `my-new-track.wav` → `"My New Track"`

This `track-short-name` is embedded in the HLS master playlist and optimized for UI display (fits ~300px at 12pt font). Frontend components can use this for compact track listings without needing to process filenames.

### Metadata Requirements

All source audio files **must** have the following metadata tags:

- **artist** - Track artist name
- **title** - Track title

The transcoder validates these tags before processing. Files missing required metadata will be rejected with an error message.

Optional metadata tags (extracted if present, otherwise empty):

- **venue** - Recording venue name
- **date** - Recording date (recommended format: YYYY-MM-DD)

During transcoding, the following metadata is automatically added:

- **publisher** - "Noise2Signal LLC"
- **copyright** - "Copyright {YEAR} Noise2Signal LLC" (current year inferred)

All existing metadata from the source file is preserved in the transcoded output.

**Setting Metadata on Source Files:**

```bash
# WAV files - use ffmpeg to add metadata
ffmpeg -i input.wav -metadata artist="Artist Name" -metadata title="Track Title" -metadata venue="Venue Name" -metadata date="2025-06-15" output.wav

# FLAC files - use metaflac
metaflac --set-tag="ARTIST=Artist Name" --set-tag="TITLE=Track Title" --set-tag="VENUE=Venue Name" --set-tag="DATE=2025-06-15" input.flac
```

### HLS Metadata Tags

The transcoder embeds canonical track metadata in the master playlist using RFC 8216 `EXT-X-SESSION-DATA` tags. This allows frontend components (hls.js) to query track information directly from the HLS manifest without maintaining separate metadata representations.

**Embedded Metadata Fields:**

- `com.noise2signal-llc.track-short-name` - Display name derived from filename (auto-generated, e.g., "Creeping Insolence")
- `com.noise2signal-llc.artist` - Track artist (extracted from source)
- `com.noise2signal-llc.title` - Track title (extracted from source)
- `com.noise2signal-llc.duration` - Track duration in seconds (extracted from source)
- `com.noise2signal-llc.venue` - Recording venue (extracted from source, empty if not present)
- `com.noise2signal-llc.date` - Recording date (extracted from source, empty if not present)
- `com.noise2signal-llc.publisher` - "Noise2Signal LLC" (auto-generated)
- `com.noise2signal-llc.copyright` - "Copyright {YEAR} Noise2Signal LLC" (auto-generated)

**Master Playlist Example:**

```m3u8
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.track-short-name",VALUE="Creeping Insolence"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.artist",VALUE="Artist Name"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.title",VALUE="Track Title"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.duration",VALUE="247.5"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.venue",VALUE="The Venue Name"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.date",VALUE="2025-06-15"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.publisher",VALUE="Noise2Signal LLC"
#EXT-X-SESSION-DATA:DATA-ID="com.noise2signal-llc.copyright",VALUE="Copyright 2026 Noise2Signal LLC"
#EXT-X-STREAM-INF:BANDWIDTH=64000,CODECS="mp4a.40.34"
64k/stream.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.34"
128k/stream.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=192000,CODECS="mp4a.40.34"
192k/stream.m3u8
```

**Frontend Access Pattern:**

Frontend components can access session data directly from the parsed master playlist, eliminating the need for separate metadata APIs or databases.

**Note:** HLS metadata tags are distinct from TS segment metadata. This implementation provides playlist-level metadata for frontend consumption. Future TS segment metadata injection (for portable copyright attribution within media files) will use separate tooling subject to different licensing requirements.

### Container Mounts

- `/staged` - Input directory (read-write)
- `/processed` - Output directory (read-write)

### Output

Each file is transcoded to 3 bitrate tiers (64k, 128k, 192k MP3) with adaptive bitrate master playlist:

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

## Performance

The transcoder uses ffmpeg parallelization for optimal speed:

- **Single-pass decoding** - Input file decoded once, not three times
- **Parallel encoding** - All three bitrates (64k, 128k, 192k) encoded simultaneously
- **Multi-threading** - ffmpeg auto-detects CPU cores (`-threads 0`)

This approach is significantly faster than sequential encoding, especially for longer audio files.

**CPU Resource Allocation:**

For maximum performance, dedicate CPU cores to the container using `--cpus` or `--cpuset-cpus`. Example:

```bash
# Dedicate 8 cores for faster transcoding
./launch-transcode.sh --cpus 8

# Pin to high-performance cores (check with lscpu)
./launch-transcode.sh --cpuset-cpus 0-7
```

Recommended: Allocate at least 4 cores for optimal parallel encoding performance.

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
