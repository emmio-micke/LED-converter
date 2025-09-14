#!/bin/bash

# This script is putting together videoclips for the LED screens in Himmelstalundshallen.
# Written by mikael.olsson@emmio.se
# Feel free to use it any way you'd like, no responsibilty taken for data loss etc.
# Params: You can use the filenames for the videoclips as parameters to the script.
# The script will try to identify any clips in the folder based on filename and use them.
# Since screens 2 and 4 are equally sized, if the script can only find three clips, it will
# use the same clip for screens 2 and 4.

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq to parse JSON configuration."
    echo "On macOS: brew install jq"
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Check if config.json exists in the script directory
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found in script directory: $SCRIPT_DIR"
    echo "Please create a configuration file in the same directory as this script."
    exit 1
fi

# Read configuration from JSON
ROWS=$(jq -r '.movie.rows' "$CONFIG_FILE")
COLUMNS=$(jq -r '.movie.columns' "$CONFIG_FILE")
PANEL_RESOLUTION=$(jq -r '.movie.panel_resolution' "$CONFIG_FILE")

# Extract panel dimensions
PANEL_WIDTH=$(echo $PANEL_RESOLUTION | cut -d'x' -f1)
PANEL_HEIGHT=$(echo $PANEL_RESOLUTION | cut -d'x' -f2)

# Calculate total panels
TOTAL_PANELS=$((ROWS * COLUMNS))

echo "Configuration loaded:"
echo "  Grid: ${ROWS}x${COLUMNS} = ${TOTAL_PANELS} panels"
echo "  Panel resolution: ${PANEL_RESOLUTION}"

# Config:
clip_length=10
target_folder="/Users/mikael.olsson/Sync/LED/"
demo_ending="_demo"
finished_filename=${PWD##*/}

# Remove any previous leftovers.
rm -f Icon$'\r'
rm -f long.mp4
rm -f part*.mp4
rm -f panel_*.mp4
rm -f ${finished_filename}.mp4
rm -f ${finished_filename}${demo_ending}.mp4

# Get file names, if specified.
part1=$1
part2=$2
part3=$3
part4=$4

# If only 3 parameters are given, use the same clip for screens 2 and 4.
if [ "$#" -eq 3 ]; then
    part4=$2
fi

# Rename all files in folder to get rid of whitespaces in filenames.
for f in *\ *; do mv "$f" "${f// /_}"; done

# Look through the files in the folder the script was run from, find files
# with extension mv4 or mp4 and try to get a map between file and section
# based on file name.
if [ "$#" -eq 0 ]; then
    for filename in *.{m4v,mp4}; do
        # Check if file names have screen sizes in them.
        if [[ $filename == *"1280"* ]]; then
            part1="${filename}"
        fi
        if [[ $filename == *"1120"* ]]; then
            part2="${filename}"
            part4="${filename}"
        fi
        if [[ $filename == *"2720"* ]]; then
            part3="${filename}"
        fi

        # Check if file names have section names in them.
        if [[ $filename == *"e"*"tion"*"1"*"."* ]]; then
            part1="${filename}"
        fi
        if [[ $filename == *"e"*"tion"*"2"*"."* ]]; then
            part2="${filename}"
            part4="${filename}"
        fi
        if [[ $filename == *"e"*"tion"*"3"*"."* ]]; then
            part3="${filename}"
        fi
        if [[ $filename == *"e"*"tion"*"4"*"."* ]]; then
            part4="${filename}"
        fi
    done
fi

# Check that we have all four clips defined.
if [[ -z $part1 || -z $part2 || -z $part3 || -z $part4 ]]; then
  echo 'One or more clips could not be defined'
  exit 1
fi

echo "Using input files:"
echo "  Screen 1: $part1"
echo "  Screen 2: $part2"
echo "  Screen 3: $part3"
echo "  Screen 4: $part4"

# Make sure all clips have the right length.
ffmpeg -i "$part1" -c copy -t $clip_length part1_t.mp4
ffmpeg -i "$part2" -c copy -t $clip_length part2_t.mp4
ffmpeg -i "$part3" -c copy -t $clip_length part3_t.mp4
ffmpeg -i "$part4" -c copy -t $clip_length part4_t.mp4

# Function to get panel list for a screen
get_panels() {
    local screen_name=$1
    jq -r ".screens.${screen_name}.panels[]" "$CONFIG_FILE" | tr '\n' ' '
}

# Function to create panel videos from a screen video
create_panel_videos() {
    local screen_name=$1
    local input_file=$2
    local panels=($(get_panels $screen_name))
    
    echo "Creating panel videos for $screen_name (${#panels[@]} panels) from $input_file"
    
    # Get screen dimensions from panel count
    local panel_count=${#panels[@]}
    local screen_width=$((panel_count * PANEL_WIDTH))
    
    echo "  Screen width: ${screen_width}px (${panel_count} panels)"
    
    # Create individual panel videos
    for i in "${!panels[@]}"; do
        local panel_num=${panels[$i]}
        local x_offset=$((i * PANEL_WIDTH))
        
        echo "  Creating panel $panel_num at x=$x_offset"
        ffmpeg -i "$input_file" -filter:v "crop=${PANEL_WIDTH}:${PANEL_HEIGHT}:${x_offset}:0" "panel_${panel_num}.mp4" -y
    done
}

# Create panel videos for each screen
create_panel_videos "screen1" "part1_t.mp4"
create_panel_videos "screen2" "part2_t.mp4"
create_panel_videos "screen3" "part3_t.mp4"
create_panel_videos "screen4" "part4_t.mp4"

# Create black panel for unused panel
echo "Creating black panel for unused panel 40"
ffmpeg -f lavfi -i color=black:size=${PANEL_WIDTH}x${PANEL_HEIGHT}:duration=$clip_length -c:v libx264 -pix_fmt yuv420p panel_40.mp4 -y

# Create the long horizontal video by arranging panels in order 1-40
echo "Creating long horizontal video from panels 1-40"
panel_inputs=""
for i in $(seq 1 $TOTAL_PANELS); do
    panel_inputs="$panel_inputs -i panel_${i}.mp4"
done

# Use hstack to create long video
ffmpeg -y $panel_inputs -filter_complex "hstack=${TOTAL_PANELS}" long.mp4

# Calculate crop width for dividing into 4 equal parts
crop_width=$((TOTAL_PANELS * PANEL_WIDTH / ROWS))
echo "Crop width: ${crop_width}px (${TOTAL_PANELS} panels / ${ROWS} rows)"

# Divide the long clip into four equally wide clips for vertical stacking
echo "Dividing long video into 4 equal parts"
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:${PANEL_HEIGHT}:0:0" part1.mp4 -y
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:${PANEL_HEIGHT}:${crop_width}:0" part2.mp4 -y
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:${PANEL_HEIGHT}:$((crop_width*2)):0" part3.mp4 -y
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:${PANEL_HEIGHT}:$((crop_width*3)):0" part4.mp4 -y

# Stack the four clips on top of each other to the finished clip
echo "Creating final stacked video"
ffmpeg -y -i part1.mp4 -i part2.mp4 -i part3.mp4 -i part4.mp4 -filter_complex "vstack=4" "${finished_filename}.mp4"

# Create a demo clip if user has set a demo file name ending
if [ ! -z "${demo_ending}" ]; then
    echo "Creating demo clip"
    # For demo, we'll create a simplified version showing the panel layout
    # Create a smaller version of the long video
    ffmpeg -y -i long.mp4 -vf scale=800:200 "${finished_filename}${demo_ending}.mp4"
fi

# Clean up temporary files
echo "Cleaning up temporary files"
rm -f long.mp4 part*.mp4 panel_*.mp4

# Copy the finished clip to a folder (if set).
if [ ! -z "${target_folder}" ]; then
    echo "Copying to target folder: ${target_folder}"
    cp ${finished_filename}.mp4 ${target_folder}
fi

echo "Conversion complete! Output: ${finished_filename}.mp4"
