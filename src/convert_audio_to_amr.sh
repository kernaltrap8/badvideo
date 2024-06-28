#!/usr/bin/env bash

./badvideo.sh $1

echo -e "WARNING: you WILL need an AMR encoder to use this script!"

INPUT_MP4="$1"
BASE_NAME="${INPUT_MP4%.*}"
OUTPUT_MP3="${BASE_NAME}.mp3"
OUTPUT_MP3_CONVERTED="${BASE_NAME}_converted.mp3"
OUTPUT_AMR="${BASE_NAME}.amr"

echo -e "Extracting audio from file..."
ffmpeg "$INPUT_MP4" -q:a 0 -map a "$OUTPUT_MP3"
echo -e "Converting to AMR format..."
ffmpeg "$OUTPUT_MP3" -acodec amr_nb -ar 8000 -ac 1 "$OUTPUT_AMR"
echo -e "Converting to a workable format..."
ffmpeg -i "$OUTPUT_AMR" -c:a libmp3lame "$OUTPUT_MP3_CONVERTED"
echo -e "Combining streams..."
ffmpeg -i "$INPUT_NAME" -i "$OUTPUT_MP3_CONVERTED" -c:v copy -c:a aac "${BASE_NAME}_amr.mp4"
