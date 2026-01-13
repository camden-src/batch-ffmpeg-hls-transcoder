#!/bin/sh

# HLS Transcoder
#
# Expects:
#   /staged - Input directory containing audio files
#   /processed - Output directory for transcoded HLS content

STAGED_ROOT="/staged"
OUTPUT_ROOT="/processed"
PUBLISHER="Noise2Signal LLC"
COPYRIGHT_YEAR=$(date +%Y)

normalize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

validate_metadata() {
    input_file="$1"

    artist=$(ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$input_file")
    title=$(ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$input_file")

    if [ -z "$artist" ] || [ -z "$title" ]; then
        echo "Error: Missing required metadata in $(basename "$input_file")" >&2
        [ -z "$artist" ] && echo "  - Missing: artist" >&2
        [ -z "$title" ] && echo "  - Missing: title" >&2
        return 1
    fi

    return 0
}

transcode_file() {
    input_file="$1"

    [ -f "$input_file" ] || return 1

    validate_metadata "$input_file" || return 1

    filename=$(basename "$input_file")
    name="${filename%.*}"
    name=$(normalize_name "$name")

    track_dir="${OUTPUT_ROOT}/${name}"

    mkdir -p "${track_dir}/64k" "${track_dir}/128k" "${track_dir}/192k"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 64k -ac 2 -ar 44100 \
        -map_metadata 0 \
        -metadata publisher="$PUBLISHER" \
        -metadata copyright="Copyright $COPYRIGHT_YEAR $PUBLISHER" \
        -f hls -hls_time 10 -hls_list_size 0 \
        -hls_segment_filename "${track_dir}/64k/seg_%03d.ts" \
        "${track_dir}/64k/stream.m3u8"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 128k -ac 2 -ar 44100 \
        -map_metadata 0 \
        -metadata publisher="$PUBLISHER" \
        -metadata copyright="Copyright $COPYRIGHT_YEAR $PUBLISHER" \
        -f hls -hls_time 10 -hls_list_size 0 \
        -hls_segment_filename "${track_dir}/128k/seg_%03d.ts" \
        "${track_dir}/128k/stream.m3u8"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 192k -ac 2 -ar 44100 \
        -map_metadata 0 \
        -metadata publisher="$PUBLISHER" \
        -metadata copyright="Copyright $COPYRIGHT_YEAR $PUBLISHER" \
        -f hls -hls_time 10 -hls_list_size 0 \
        -hls_segment_filename "${track_dir}/192k/seg_%03d.ts" \
        "${track_dir}/192k/stream.m3u8"

    cat > "${track_dir}/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=64000,CODECS="mp4a.40.34"
64k/stream.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.34"
128k/stream.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=192000,CODECS="mp4a.40.34"
192k/stream.m3u8
EOF
}

for input_file in "$STAGED_ROOT"/*; do
    [ -f "$input_file" ] || continue
    transcode_file "$input_file"
done
