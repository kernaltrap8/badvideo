#!/usr/bin/env bash

# badvideo Copyright (C) 2024 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

VIDEO_INPUT="$1"
NUM_MP3_PASSES=10
NUM_MP4_PASSES=2
VIDEO_INPUT_NOEXT="${VIDEO_INPUT%.*}"
VIDEO_INPUT_CONVERTED="$PWD/work/${VIDEO_INPUT_NOEXT}_converted.mp4"
VIDEO_NO_AUDIO="$PWD/work/${VIDEO_INPUT_NOEXT}_no_audio.mp4"
OUTPUT_AAC="$PWD/work/${VIDEO_INPUT_NOEXT}_output.aac"
OUTPUT_MP3="$PWD/work/${VIDEO_INPUT_NOEXT}_compressed.mp3"
OUTPUT_MP4="$PWD/work/${VIDEO_INPUT_NOEXT}_compressed.mp4"
FINAL_MP4="$PWD/${VIDEO_INPUT_NOEXT}_final.mp4"

VERSION="2.0"
PREFIX="\033[37m[\033[0m\033[35m * \033[0m\033[37m]\033[0m"

# Argument checking

if [ "$1" == "-v" ] || [ "$1" == "--version" ]; then
	echo "badvideo v$VERSION"
	exit 0
fi

if [ "$#" -eq 0 ]; then
  echo -e "No arguments supplied.\nPlease supply the input filename."
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo -e "Incorrect number of arguments.\nUsage: $0 <input>"
  exit 1
fi

# Compression jobs

rm -rf work
mkdir -p work
echo -e "$VIDEO_INPUT_CONVERTED\n" "$VIDEO_NO_AUDIO\n" "$OUTPUT_AAC\n" "$OUTPUT_MP3\n" "$OUTPUT_MP4\n" "$FINAL_MP4\n"
echo -e "$PREFIX Converting input to workable format..."
sleep 1
ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT" -c:v copy -c:a aac -strict experimental "$VIDEO_INPUT_CONVERTED"
echo -e "$PREFIX Copying audio stream to external AAC..."
sleep 1
ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT_CONVERTED" -vn -acodec copy "$OUTPUT_AAC"
echo -e "$PREFIX Removing audio stream from video..."
sleep 1
ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT_CONVERTED" -an -c:v copy "$VIDEO_NO_AUDIO"
echo -e "$PREFIX Compressing audio stream..."
sleep 1
for (( i=1; i<=$NUM_MP3_PASSES; i++ ))
do
	OUTPUT_MP3="work/${VIDEO_INPUT_NOEXT}_${i}.mp3"
	ffmpeg -y -v quiet -stats -i "$OUTPUT_AAC" -c:a libmp3lame -crf 51 -b:a 8 -q 9 -preset veryfast "$OUTPUT_MP3"
	
	if [ $i -gt 1 ]; then
		rm "$OUTPUT_AAC"
	fi
	
	OUTPUT_AAC="$OUTPUT_MP3"
done
echo -e "$PREFIX Compressing video stream..."
sleep 1
for (( i=1; i<=$NUM_MP4_PASSES; i++ ))
do
	OUTPUT_MP4="work/${VIDEO_INPUT_NOEXT}_${i}.mp4"
	ffmpeg -y -v quiet -stats -i "$VIDEO_NO_AUDIO" -c:v libx264 -crf 51 -b:v 50 -preset veryfast "$OUTPUT_MP4"

	if [ $i -gt 1 ]; then
		rm "$VIDEO_NO_AUDIO"
	fi

	VIDEO_NO_AUDIO="$OUTPUT_MP4"
done
echo -e "$PREFIX Combining compressed streams..."
sleep 1
ffmpeg -y -v quiet -stats -i "$OUTPUT_MP4" -i "$OUTPUT_MP3" -c:v copy -c:a copy -preset veryfast "$FINAL_MP4"
echo -e "$PREFIX Removing work files..."
sleep 1
rm -f "$VIDEO_INPUT_CONVERTED" "${VIDEO_INPUT_NOEXT}_no_audio.mp4" "${VIDEO_INPUT_NOEXT}_output.aac" "$OUTPUT_MP3" "$OUTPUT_MP4"
