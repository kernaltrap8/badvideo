#!/usr/bin/env bash

# badvideo Copyright (C) 2024 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

VERSION="3.7"
NUM_MP3_PASSES_DEFAULT=10
NUM_MP4_PASSES_DEFAULT=2
MP3_RATE_DEFAULT="20k"
MP4_RATE_DEFAULT="50k"
DATE=$(date +'%d-%m-%y')
DISABLE_DELETE=1
PREFIX="\033[37m[\033[0m\033[35m * \033[0m\033[37m]\033[0m"
WARNING_PREFIX="\033[37m[\033[0m\033[31m * \033[0m\033[37m]\033[0m"
DEBUG_PREFIX="\033[37m[\033[0m\033[32m DEBUG \033[0m\033[37m]\033[0m"
PASS_PREFIX="\033[37m[\033[0m\033[32m ! \033[0m\033[37m]\033[0m"
EXIT_PREFIX="\033[37m[\033[0m\033[31m ! \033[0m\033[37m]\033[0m"

# Argument checking
if [ "$#" -eq 0 ]; then
  echo -e "No arguments supplied.\nPlease supply at least the input filename.\nUsage: $0 <input> [mp3_passes] [mp4_passes] [mp3_rate] [mp4_rate]"
  exit 1
fi

if [[ "$1" == "-v" ]] || [[ "$1" == "--version" ]]; then
  echo -e "badvideo v$VERSION\nThis program is licensed under the BSD-3-Clause license.\nThe license document can be viewed here: https://opensource.org/license/bsd-3-clause"
  exit 0
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo -e "Tip! You can also specify the passes to do and the bitrates!\nExample: $0 filename.mp4 5 5 20k 100k\nThis will set the mp3 passes to 5, the mp4 passes to 5, the mp3 bitrate to 20, and mp4 bitrate to 100."
  exit 0
fi

if [[ "$1" == "-d" ]] || [[ "$1" == "--disable-delete" ]]; then
  DISABLE_DELETE=0
  shift
fi

cleanup() {
	if [[ "$DISABLE_DELETE" -eq 1 ]]; then
	  echo -e "$WARNING_PREFIX Removing work files..."
	  sleep 1
	  rm -rf "$WORK_DIR"
	fi
	printf "$EXIT_PREFIX Exiting.\n"
	exit 1
}

trap cleanup SIGINT

VIDEO_INPUT="$1"

if [[ "$VIDEO_INPUT" != *.mp4 ]]; then
	echo "$WARNING_PREFIX Only MP4 files are supported."
	exit 1
fi

if [ "$#" -ge 2 ]; then
   NUM_MP3_PASSES="$2"
else
   NUM_MP3_PASSES="$NUM_MP3_PASSES_DEFAULT"
fi
	
if [ "$#" -ge 3 ]; then
  NUM_MP4_PASSES="$3"
else
  NUM_MP4_PASSES="$NUM_MP4_PASSES_DEFAULT"
fi
	
if [ "$#" -ge 4 ]; then
  MP3_RATE="$4"
else
  MP3_RATE="$MP3_RATE_DEFAULT"
fi
	
if [ "$#" -ge 5 ]; then
  MP4_RATE="$5"
else
  MP4_RATE="$MP4_RATE_DEFAULT"
fi

# Function to check if bitrate ends with 'k' or 'K'
check_bitrate_format() {
    local rate="$1"
    if [[ "$rate" =~ ^[0-9]+[kK]$ ]]; then
        return 0  # Valid bitrate format
    else
        return 1  # Invalid bitrate format
    fi
}

# Ensure NUM_MP3_PASSES and NUM_MP4_PASSES are valid integers
if ! [[ "$NUM_MP3_PASSES" =~ ^[0-9]+$ ]]; then
  echo "Error: NUM_MP3_PASSES must be an integer."
  exit 1
fi

if ! [[ "$NUM_MP4_PASSES" =~ ^[0-9]+$ ]]; then
  echo "Error: NUM_MP4_PASSES must be an integer."
  exit 1
fi

# Check MP3_RATE format
if ! check_bitrate_format "$MP3_RATE"; then
    echo "Error: MP3 bitrate must end with 'k' or 'K'. Example: 128k"
    exit 1
fi

# Check MP4_RATE format
if ! check_bitrate_format "$MP4_RATE"; then
    echo "Error: MP4 bitrate must end with 'k' or 'K'. Example: 500k"
    exit 1
fi

# Variable setup
INPUT_DIR=$(dirname "$VIDEO_INPUT")
INPUT_FILENAME=$(basename "$VIDEO_INPUT")
VIDEO_INPUT_NOEXT="${INPUT_FILENAME%.*}"

# Construct paths for output files
if [[ "$INPUT_DIR" == "." ]]; then
    WORK_DIR="./work_$DATE/"
else
    WORK_DIR="${INPUT_DIR}/work_$DATE/"
fi

# Define full paths for output files using WORK_DIR
VIDEO_INPUT_CONVERTED="${WORK_DIR}${VIDEO_INPUT_NOEXT}_converted.mp4"
VIDEO_NO_AUDIO="${WORK_DIR}${VIDEO_INPUT_NOEXT}_no_audio.mp4"
OUTPUT_AAC="${WORK_DIR}${VIDEO_INPUT_NOEXT}_output.aac"
OUTPUT_MP3="${WORK_DIR}${VIDEO_INPUT_NOEXT}_compressed.opus"
OUTPUT_MP4="${WORK_DIR}${VIDEO_INPUT_NOEXT}_compressed.mp4"
FINAL_MP4="./${VIDEO_INPUT_NOEXT}_final.mp4"

# Remove existing output the tool may have made
rm -f "$FINAL_MP4"
# Ensure the work directory exists
mkdir -p "$WORK_DIR"

# Compression jobs
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
  OUTPUT_MP3="${WORK_DIR}${VIDEO_INPUT_NOEXT}_${i}.opus"
  printf "$PASS_PREFIX Pass: ${i}\n"
  ffmpeg -y -v quiet -stats -i "$OUTPUT_AAC" -c:a libopus -ac 1 -ar 16000 -b:a "$MP3_RATE" -vbr constrained "$OUTPUT_MP3"
  if [ $i -gt 1 ]; then
    rm "$OUTPUT_AAC"
  fi
  OUTPUT_AAC="$OUTPUT_MP3"
done
echo -e "$PREFIX Compressing video stream..."
sleep 1
for (( i=1; i<=$NUM_MP4_PASSES; i++ ))
do
  OUTPUT_MP4="${WORK_DIR}${VIDEO_INPUT_NOEXT}_${i}.mp4"
  printf "$PASS_PREFIX Pass: ${i}\n"
  ffmpeg -y -v quiet -stats -i "$VIDEO_NO_AUDIO" -c:v libx264 -b:v "$MP4_RATE" -vf scale=640:480 -preset veryfast "$OUTPUT_MP4"
  if [ $i -gt 1 ]; then
    rm "$VIDEO_NO_AUDIO"
  fi
  VIDEO_NO_AUDIO="$OUTPUT_MP4"
done
echo -e "$PREFIX Combining compressed streams..."
sleep 1
ffmpeg -y -v quiet -stats -i "$OUTPUT_MP4" -i "$OUTPUT_MP3" -vf scale=1920:1080 -c:v libx264 -c:a copy -preset veryfast "$FINAL_MP4"
echo -e "$PREFIX File outputted to ${FINAL_MP4##*/}"
if [ "$DISABLE_DELETE" -eq 1 ]; then
  echo -e "$WARNING_PREFIX Removing work files..."
  sleep 1
  rm -rf "$WORK_DIR"
fi
