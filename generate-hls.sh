#!/bin/sh

# HLS Transcoder
#
# Expects:
#   /staged - Input directory containing audio files
#   /processed - Output directory for transcoded HLS content

STAGED_ROOT="/staged"
OUTPUT_ROOT="/processed"

normalize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

transcode_file() {
    input_file="$1"

    [ -f "$input_file" ] || return 1

    filename=$(basename "$input_file")
    name="${filename%.*}"
    name=$(normalize_name "$name")

    track_dir="${OUTPUT_ROOT}/${name}"

    mkdir -p "${track_dir}/64k" "${track_dir}/128k" "${track_dir}/192k"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 64k -ac 2 -ar 44100 \
        -f hls -hls_time 10 -hls_list_size 0 \
        -hls_segment_filename "${track_dir}/64k/seg_%03d.ts" \
        "${track_dir}/64k/stream.m3u8"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 128k -ac 2 -ar 44100 \
        -f hls -hls_time 10 -hls_list_size 0 \
        -hls_segment_filename "${track_dir}/128k/seg_%03d.ts" \
        "${track_dir}/128k/stream.m3u8"

    ffmpeg -y -i "$input_file" \
        -codec:a libmp3lame -b:a 192k -ac 2 -ar 44100 \
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
