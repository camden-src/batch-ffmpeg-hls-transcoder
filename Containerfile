# HLS Transcoder Container
FROM alpine:3.21

RUN apk add --no-cache ffmpeg

RUN addgroup -g 1000 developer && adduser -u 1000 -G developer -D developer

USER developer
WORKDIR /workspace

ENTRYPOINT ["/workspace/generate-hls.sh"]
