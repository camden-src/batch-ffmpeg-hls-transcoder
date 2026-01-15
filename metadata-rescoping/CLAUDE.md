# Audio Metadata Verification Tool

Interactive metadata verification and amendment tool for WAV source files. Ensures required ID3 metadata tags are present before HLS transcoding.

## Problem Scope

The HLS transcoding workflow (`hls-audio-transcode`) requires source audio files to have complete metadata:

**Required fields:**
- `artist` - Track artist name
- `title` - Track title

**Optional fields:**
- `venue` - Recording venue name
- `date` - Recording date (recommended: YYYY-MM-DD)

**Auto-generated fields (added during transcode):**
- `publisher` - "Noise2Signal LLC"
- `copyright` - "Copyright {YEAR} Noise2Signal LLC"

**Challenges:**
1. DAW export workflows may not populate all required metadata fields
2. Batch processing fails when metadata is incomplete
3. Manual metadata verification is error-prone
4. ffmpeg requires file copy + rewrite for metadata updates (not in-place)

**Scope Boundary:**
- This tool **only** audits and amends source WAV files before transcoding
- HLS manifest metadata embedding happens during transcode (`generate-hls.sh`)
- TS segment metadata injection (ID3v2 frames in transport stream) is **out of scope** - requires separate Bento4/GPL tooling in dedicated repository

**Key Design Shift:**
- **Original approach:** Fix missing metadata fields only
- **New approach:** Audit ALL files, allow review/edit/approval of any metadata field (comprehensive pre-transcode verification)

## Proposed Solution

Interactive Python-based metadata audit tool that:

1. Scans directory for WAV files
2. Reads existing ID3 metadata from ALL files (not just incomplete ones)
3. Presents each file for review, edit, and approval
4. Allows amendment of any metadata field (required or optional)
5. Continues on error, generates final report with failure traces
6. Writes metadata back to source files

**Workflow Position:**
```
DAW Export → Metadata Verification → HLS Transcode → HLS Manifest (with embedded metadata)
             ^^^^^^^^^^^^^^^^^^^^
             (this tool)
```

## Container Design

**Approach:** Python container with ID3 tag library

```
metadata-rescoping/
├── Containerfile          # Alpine + Python + mutagen
├── orchestrate.sh         # Orchestrates verify + transcode workflow
├── launch-verify.sh       # Verify container launcher (called by orchestrate.sh)
└── verify-metadata.py     # Interactive audit script
```

**Python ID3 Library:** `mutagen` - Pure Python, lightweight, handles WAV ID3 tags, actively maintained

**Container Base Image Options:**
1. `python:3.12-alpine` - Minimal footprint (~50MB)
2. `python:3.12-slim` - Debian-based, more compatible (~120MB)

**Recommendation:** `python:3.12-alpine` unless binary dependencies cause issues

## Workflow Design

### Interactive Audit Flow

**Audit Mode (Default):** Reviews ALL staged WAV files regardless of metadata completeness

```
1. Scan /staged directory for *.wav files
2. For each file:
   a. Extract existing metadata (or show [missing]/[empty] for unset fields)
   b. Display current state
   c. Prompt to edit each field (required + optional)
   d. Allow user to keep existing, modify, or clear fields
   e. Confirm changes before writing
   f. On write error: log failure, continue to next file
3. Final report: successful updates + failures with trace info
```

**Prompt Design:**

```
File: creeping-insolence.wav (1 of 12)

Current metadata:
  artist: "The Artist Name"
  title: "Creeping Insolence"
  venue: [empty]
  date: [empty]

Edit fields? [y/N]: y

  artist ["The Artist Name"]: _
  title ["Creeping Insolence"]: _
  venue [empty]: The Venue
  date [empty] (YYYY-MM-DD): 2025-06-15

Apply changes? [y/N]: y
✓ Metadata updated

---
[Next file...]
```

**Continue-on-Error:** Tool processes all files even if individual writes fail. Final report shows:
```
Metadata Audit Complete
  12 files scanned
  10 files updated successfully
  2 files failed:
    - broken-file.wav: [mutagen.MutagenError] File corrupted or unsupported format
    - readonly-file.wav: [PermissionError] Permission denied writing to file
```

### Container Mounts

- `/staged` - Input/output directory (read-write, same as HLS transcode)
- Source files modified in-place (metadata-only update)

### Execution Pattern

**Orchestrated Workflow:** Single script manages both containers sequentially

```bash
# Orchestration script prompts for directories, runs verify + transcode
./orchestrate.sh
```

**Workflow Steps:**

1. Prompt for `/staged` and `/processed` host directory paths
2. Launch verify container with `/staged` mount
3. User reviews/edits metadata for all WAV files
4. Verify container exits with final report
5. **Approval prompt:** "Proceed to HLS transcode? [y/N]"
   - User may want to add/remove audio files before transcoding
   - User can inspect verify report and decide to abort
6. If approved, launch transcode container with `/staged` + `/processed` mounts
7. HLS transcode completes, final output in `/processed`

**Standalone Execution:** Verify and transcode containers can still be run independently if needed

```bash
# Run verify only
./launch-verify.sh

# Run transcode only (assumes metadata already validated)
cd ../hls-audio-transcode
./launch-transcode.sh
```

## Technical Considerations

### WAV ID3 Tag Format

**Supported Source Format:** WAV files only (industry standard for uncompressed lossless audio, supports 32-bit float dynamics)

WAV files support ID3v2 tags embedded in `id3 ` chunk or `LIST-INFO` chunk:
- **ID3v2.3** - Standard MP3-style tags (mutagen: `.id3` property) - SELECTED for maximum compatibility
- **RIFF INFO** - Native WAV metadata (mutagen: `.tags` property)

**Tag Format Decision:** ID3v2.3 (not 2.4)
- Near-universal hardware/software support
- Industry standard for professional DAWs and broadcast tools
- ID3v2.4's improvements (UTF-8, better storage efficiency) do not outweigh compatibility risks

**Implementation:** Write both ID3v2.3 and RIFF INFO for maximum compatibility with ffmpeg and downstream tools.

### Metadata Preservation During ffmpeg Transcode

Current `generate-hls.sh` uses `-map_metadata 0` to preserve source metadata. Metadata flows through transcode workflow:

1. Source WAV ID3v2.3 tags (set by this tool) → ffmpeg metadata extraction
2. Metadata embedded in HLS master playlist as RFC 8216 `EXT-X-SESSION-DATA` tags
3. Frontend (hls.js) queries metadata from master playlist

**TS Segment Metadata (Out of Scope):**

ID3v2 frames within MPEG-TS segments are **not** handled by this workflow. Embedding portable copyright/attribution metadata directly in TS segments requires:
- Bento4 tooling (mp4fragment, mp4dash with ID3 injection)
- GPL licensing constraints
- Separate repository/workflow

**Current Implementation:** Metadata available in HLS master playlist only (sufficient for frontend display). Portable TS segment metadata deferred to future Bento4-based tooling.

### In-Place Modification vs. Copy-Rewrite

**ffmpeg approach (rejected):** Requires temp file, full decode/encode cycle
```bash
ffmpeg -i input.wav -metadata artist="Artist" temp.wav
mv temp.wav input.wav
```

**Python mutagen approach (preferred):** Direct tag manipulation, no re-encoding
```python
from mutagen.wave import WAVE
audio = WAVE('input.wav')
audio['artist'] = 'Artist Name'
audio.save()  # Writes tag chunks only, preserves audio data
```

**Performance:** Mutagen updates metadata chunks without touching audio stream - significantly faster and safer.

## Design Decisions

1. **ID3 Tag Format:** ID3v2.3 (industry standard, maximum compatibility)

2. **Audit Mode:** Review ALL staged WAV files, allow editing any field (not just missing fields)

3. **Validation Rules:** OPEN QUESTION - deferred for further consideration
   - Date format validation (YYYY-MM-DD strict, or flexible parsing like "June 2025")?
   - Artist/title length limits (max characters)?
   - Character encoding constraints (UTF-8 only, or allow ISO-8859-1)?
   - Sanitization rules (strip leading/trailing whitespace, normalize case)?

4. **Error Handling:** Continue-on-error approach with final failure report and trace info

5. **Integration:** Orchestration script (`orchestrate.sh`) runs verify container, prompts for approval, then runs transcode container

6. **TS Segment Metadata:** Out of scope - separate Bento4/GPL repository for portable TS metadata injection

7. **Source Format Support:** WAV files only (industry standard for uncompressed lossless, 32-bit float support)

## Additional Open Questions

1. **Dry-Run Mode:** Preview metadata changes without writing files?

2. **Skip/Abort Options:** Allow user to skip individual files during audit, or abort entire process?

3. **Default Values:** Pre-populate empty fields with intelligent defaults (e.g., derive title from filename)?

4. **User Experience:**
   - Terminal UI library (`prompt_toolkit`, `rich`) for better formatting/colors?
   - Or simple `input()` prompts sufficient?

5. **Progress Indication:** Show "File N of M" during audit for large batches?

## Next Steps

1. **Validate approach** - Review this design, decide on open questions
2. **Prototype Python script** - Test mutagen library with sample WAV files
3. **Build container** - Create Containerfile with Python + dependencies
4. **Implement launcher** - Directory prompt, mount logic, container orchestration
5. **Test workflow** - Verify metadata persists through HLS transcode
6. **Document integration** - Update main `/workspace/CLAUDE.md` with verification step

## Container Standards Alignment

This tool follows project containerized workflow standards:

- **Base Image:** Alpine Linux with Python
- **User:** developer (uid 1000, gid 1000)
- **Execution Pattern:** One-shot interactive batch processing
- **Mount:** `/staged` for source audio files (read-write)
- **No git dependency:** Standalone tool, directory-based workflow

Consistent with `hls-audio-transcode` design patterns.
