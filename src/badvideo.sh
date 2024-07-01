#!/usr/bin/env bash

# badvideo Copyright (C) 2024 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

# Variable setup
VERSION="5.2"
NUM_MP3_PASSES=10
NUM_MP4_PASSES=2
MP3_RATE="20k"
MP4_RATE="50k"
DATE=$(date +'%d-%m-%y')
DISABLE_DELETE=1
ENABLE_DEBUG=0
PREFIX=$'\e[37m[\e[0m\e[35m * \e[0m\e[37m]\e[0m'
START_PREFIX=$'\e[37m[\e[0m\e[32m * \e[0m\e[37m]\e[0m'
WARNING_PREFIX=$'\e[37m[\e[0m\e[31m * \e[0m\e[37m]\e[0m'
PASS_PREFIX=$'\e[37m[\e[0m\e[32m ! \e[0m\e[37m]\e[0m'
EXIT_PREFIX=$'\e[37m[\e[0m\e[31m ! \e[0m\e[37m]\e[0m'
BANNER_P1=$'\e[95m'" _             _     _    _"$'\e[0m'
BANNER_P2=$'\e[95m'"| |__  __ _ __| |_ _(_)__| |___ ___"$'\e[0m'
BANNER_P3=$'\e[95m'"| '_ \/ _\` / _\` \ V / / _\` / -_) _ \\"$'\e[0m'
BANNER_P4=$'\e[95m'"|_.__/\__,_\__,_|\_/|_\__,_\___\___/"$'\e[0m'

# Function definitions
check_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                echo -e "badvideo v$VERSION\nThis program is licensed under the BSD-3-Clause license.\nThe license document can be viewed here: https://opensource.org/license/bsd-3-clause"
                exit 0
                ;;
            -h|--help)
                echo -e "Usage: badvideo [-v] [-h] [-d|--disable-delete] [-D|--debug] [-p1|--audio-passes] <audio_passes> [-p2|--video-passes] <video_passes> [-b1|--audio-bitrate] <audio_bitrate> [-b2|--video-bitrate] <video_bitrate> <input>"
                exit 0
                ;;
            -d|--disable-delete)
                DISABLE_DELETE=0
                shift
                ;;
            -D|--debug)
                ENABLE_DEBUG=1
                shift
                ;;
            -p1|--audio-passes)
                if [[ -n "$2" && "$2" != -* ]]; then
                    NUM_MP3_PASSES="$2"
                    shift 2
                else
                    echo "Error: -p1 requires an argument" >&2
                    exit 1
                fi
                ;;
            -p2|--video-passes)
                if [[ -n "$2" && "$2" != -* ]]; then
                    NUM_MP4_PASSES="$2"
                    shift 2
                else
                    echo "Error: -p2 requires an argument" >&2
                    exit 1
                fi
                ;;
            -b1|--audio-bitrate)
                if [[ -n "$2" && "$2" != -* ]]; then
                    MP3_RATE="$2"
                    shift 2
                else
                    echo "Error: -b1 requires an argument" >&2
                    exit 1
                fi
                ;;
            -b2|--video-bitrate)
                if [[ -n "$2" && "$2" != -* ]]; then
                    MP4_RATE="$2"
                    shift 2
                else
                    echo "Error: -b2 requires an argument" >&2
                    exit 1
                fi
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Invalid option: $1" >&2
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    if [ "$#" -lt 1 ]; then
        echo -e "No input file supplied.\nPlease supply at least the input filename.\nUsage: badvideo [-v] [-h] [-d|--disable-delete] [-D|--debug] [-p1|--audio-passes] <audio_passes> [-p2|--video-passes] <video_passes> [-b1|--audio-bitrate] <audio_bitrate> [-b2|--video-bitrate] <video_bitrate> <input>"
        exit 1
    fi

    VIDEO_INPUT="$1"
    shift
}

cleanup() {
	if [[ "$DISABLE_DELETE" -eq 1 ]]; then
		echo -e "$WARNING_PREFIX Removing work files..."
		sleep 1
		rm -rf "$WORK_DIR"
	fi
	echo -e "$EXIT_PREFIX Exiting."
	exit 1
}

check_bitrate_format() {
	local rate="$1"
	if [[ "$rate" =~ ^[0-9]+[kK]$ ]]; then
		return 0  # Valid bitrate format
	else
		return 1  # Invalid bitrate format
	fi
}

die() {
	local exit="$?"
	if [[ "$exit" -ne 0  ]]; then
		echo -e "$EXIT_PREFIX FFMpeg returned exit code $exit!"
	fi
	cleanup
}

panic() {
	if [[ "$VIDEO_INPUT" == *.mp3 ]]; then
		echo -e "$WARNING_PREFIX Only video files are supported."
		exit 1
	fi
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
	if ! [ -f "$VIDEO_INPUT" ]; then
		echo -e "$EXIT_PREFIX Input file $VIDEO_INPUT doesn't exist!"
		echo -e "$EXIT_PREFIX Exiting."
		exit 1
	fi
}

debug() {
	echo "VIDEO_INPUT: $VIDEO_INPUT"
	echo "NUM_MP3_PASSES: $NUM_MP3_PASSES"
	echo "NUM_MP4_PASSES: $NUM_MP4_PASSES"
	echo "MP3_RATE: $MP3_RATE"
	echo "MP4_RATE: $MP4_RATE"
	echo "DISABLE_DELETE: $DISABLE_DELETE"
	echo "PREFIX: $PREFIX"
	echo "START_PREFIX: $START_PREFIX"
	echo "WARNING_PREFIX: $WARNING_PREFIX"
	echo "PASS_PREFIX: $PASS_PREFIX"
	echo "EXIT_PREFIX: $EXIT_PREFIX"
	echo "VIDEO_INPUT: $VIDEO_INPUT"
	echo "INPUT_DIR: $INPUT_DIR"
	echo "INPUT_FILENAME: $INPUT_FILENAME"
	echo "VIDEO_INPUT_NOEXT: $VIDEO_INPUT_NOEXT"
	echo "VIDEO_INPUT_CONVERTED: $VIDEO_INPUT_CONVERTED"
	echo "VIDEO_NO_AUDIO: $VIDEO_NO_AUDIO"
	echo "OUTPUT_AAC: $OUTPUT_AAC"
	echo "OUTPUT_MP3: $OUTPUT_MP3"
	echo "OUTPUT_MP4: $OUTPUT_MP4"
	echo "FINAL_MP4: $FINAL_MP4"
	echo "WORK_DIR: $WORK_DIR"
}

badvideo() {
	for (( i=1; i<=4; i++))
	do
		banner_var="BANNER_P${i}"
		echo -e "${!banner_var}"
	done
	echo "Ruin your videos in SECONDS!"
	echo -e "$START_PREFIX Starting badvideo v$VERSION"
	# Variable setup for jobs
	INPUT_DIR=$(dirname "$VIDEO_INPUT")
	INPUT_FILENAME=$(basename "$VIDEO_INPUT")
	VIDEO_INPUT_NOEXT="${INPUT_FILENAME%.*}"
	if [[ "$INPUT_DIR" == "." ]]; then
		WORK_DIR="./work_${VIDEO_INPUT_NOEXT}_$DATE/"
	else
		WORK_DIR="${INPUT_DIR}/work_${VIDEO_INPUT_NOEXT}_$DATE/"
	fi
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
	if [[ "$ENABLE_DEBUG" -eq 1 ]]; then
		echo -e "$WARNING_PREFIX Debug is enabled!"
		debug
	fi
	# Compression jobs
	echo -e "$PREFIX Converting input to workable format..."
	sleep 1
	ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT" -c:v libx264 -c:a aac -strict experimental "$VIDEO_INPUT_CONVERTED" || die
	echo -e "$PREFIX Copying audio stream to external AAC..."
	sleep 1
	ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT_CONVERTED" -vn -acodec copy "$OUTPUT_AAC" || die
	echo -e "$PREFIX Removing audio stream from video..."
	sleep 1
	ffmpeg -y -v quiet -stats -i "$VIDEO_INPUT_CONVERTED" -an -c:v copy "$VIDEO_NO_AUDIO" || die
	echo -e "$PREFIX Compressing audio stream..."
	sleep 1
	for (( i=1; i<=NUM_MP3_PASSES; i++ ))
	do
		OUTPUT_MP3="${WORK_DIR}${VIDEO_INPUT_NOEXT}_${i}.opus"
		echo -e "$PASS_PREFIX Pass: ${i}"
		ffmpeg -y -v quiet -stats -i "$OUTPUT_AAC" -c:a libopus -ac 1 -ar 16000 -b:a "$MP3_RATE" -vbr constrained "$OUTPUT_MP3" || die
		if [ $i -gt 1 ]; then
			rm "$OUTPUT_AAC"
		fi
		OUTPUT_AAC="$OUTPUT_MP3"
	done
	echo -e "$PREFIX Compressing video stream..."
	sleep 1
	for (( i=1; i<=NUM_MP4_PASSES; i++ ))
	do
		OUTPUT_MP4="${WORK_DIR}${VIDEO_INPUT_NOEXT}_${i}.mp4"
		echo -e "$PASS_PREFIX Pass: ${i}"
		ffmpeg -y -v quiet -stats -i "$VIDEO_NO_AUDIO" -c:v libx264 -b:v "$MP4_RATE" -preset veryfast "$OUTPUT_MP4" || die
		if [ $i -gt 1 ]; then
			rm "$VIDEO_NO_AUDIO"
		fi
		VIDEO_NO_AUDIO="$OUTPUT_MP4"
	done
	echo -e "$PREFIX Combining compressed streams..."
	sleep 1
	ffmpeg -y -v quiet -stats -i "$OUTPUT_MP4" -i "$OUTPUT_MP3" -c:v libx264 -c:a copy -preset veryfast "$FINAL_MP4" || die
	echo -e "$PREFIX File outputted to ${FINAL_MP4##*/}"
	if [ "$DISABLE_DELETE" -eq 1 ]; then
		echo -e "$WARNING_PREFIX Removing work files..."
		sleep 1
		rm -rf "$WORK_DIR"
	fi
}

# Argument checking
check_args "$@"

# If the user ends the script prematurely, make sure to cleanup any previous files
trap cleanup SIGINT

# Exit if the user provides invalid input
panic

# Run the jobs
badvideo
