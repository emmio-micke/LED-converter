#!/bin/bash

# This script is putting together videoclips for the LED screens in Himmelstalundshallen.
# Written by mikael.olsson@emmio.se
# Feel free to use it any way you'd like, no responsibilty taken for data loss etc.
# Params: You can use the filenames for the videoclips as parameters to the script.
# The script will try to identify any clips in the folder based on filename and use them.
# Since screens 2 and 4 are equally sized, if the script can only find three clips, it will
# use the same clip for screens 2 and 4.
# Screens:
# Section    M  Px
# 1          8  1280x160
# 2          7  1120x160
# 3         17  2720x160
# 4          7  1120x160

# Convert .mov to .mp4.
# ffmpeg -i my-video.mov -vcodec h264 -acodec mp2 my-video.mp4

# Config:

# Length of clip in seconds.
clip_length=10

# Where to copy the finished clip. Leave empty if you don't wish to copy it.
target_folder="/Users/mikael.olsson/Sync/LED/"

# Ending of demo clip. Leave empty if you don't want a demo clip.
demo_ending="_demo"

# Get the current folder name to use as file name.
# I e, company/*.mp4 will result in company/company.mp4.
finished_filename=${PWD##*/}

# Remove any previous leftovers.
rm -f Icon$'\r'
rm -f long.mp4
rm -f part*.mp4
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

# Make sure all clips have the right length.
ffmpeg -i "$part1" -c copy -t $clip_length part1_t.mp4
ffmpeg -i "$part2" -c copy -t $clip_length part2_t.mp4
ffmpeg -i "$part3" -c copy -t $clip_length part3_t.mp4
ffmpeg -i "$part4" -c copy -t $clip_length part4_t.mp4

# After trimming, list the trimmed files for verification
ls -l part*_t.mp4 > /dev/null 2>&1 || true

# --- New workflow for split screen 3 ---
# Physical order (left to right): Screen 3 part 2, Screen 4, Screen 2, Screen 1, Screen 3 part 1
# This requires splitting screen 3 into two parts and rearranging

# First, we need to split part3 (2720px) into two parts:
# part3_1: 1440px (9 blocks) - goes at the end
# part3_2: 1280px (8 blocks) - goes at the beginning

# Split screen 3 into two parts
ffmpeg -i part3_t.mp4 -filter:v "crop=1440:160:0:0" part3_1_t.mp4
ffmpeg -i part3_t.mp4 -filter:v "crop=1280:160:1440:0" part3_2_t.mp4

# Now create the long clip in the correct physical order with 160px padding at the end:
# part3_2 (1280px) + part4 (1120px) + part2 (1120px) + part1 (1280px) + part3_1 (1440px) + 160px padding = 6400px total
# Create long clip in physical order with 160px padding at the end
# Create a 160px black padding clip
ffmpeg -f lavfi -i color=black:size=160x160:duration=10 -c:v libx264 -pix_fmt yuv420p padding.mp4
# Stack everything together: all parts + padding
ffmpeg -y -i part3_2_t.mp4 -i part4_t.mp4 -i part2_t.mp4 -i part1_t.mp4 -i part3_1_t.mp4 -i padding.mp4 -filter_complex "hstack=6" long.mp4

# Calculate crop width: 6400px / 4 = 1600px per screen
crop_width=1600

# Divide the long clip into four equally wide clips for vertical stacking
# The 160px padding is now included in the long clip, so we can crop normally
# Crop long clip into 4 equal parts
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:160:0:0" part1.mp4
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:160:${crop_width}:0" part2.mp4
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:160:$((crop_width*2)):0" part3.mp4
ffmpeg -i long.mp4 -filter:v "crop=${crop_width}:160:$((crop_width*3)):0" part4.mp4

# Stack the four clips on top of each other to the finished clip
# Create final stacked video
ffmpeg -y -i part1.mp4 -i part2.mp4 -i part3.mp4 -i part4.mp4 -filter_complex "vstack=4" "${finished_filename}.mp4"

# Create a demo clip if user has set a demo file name ending
if [ ! -z "${demo_ending}" ]; then
    # Create demo clip
    # For demo, we'll use the same physical order as the main clip
    # Set padding for each clip to make them same size (use widest: 1440px for demo)
    ffmpeg -i part3_2_t.mp4 -filter:v "pad=1440:160:0:0:black" part3_2_d.mp4
    ffmpeg -i part4_t.mp4 -filter:v "pad=1440:160:0:0:black" part4_d.mp4
    ffmpeg -i part2_t.mp4 -filter:v "pad=1440:160:0:0:black" part2_d.mp4
    ffmpeg -i part1_t.mp4 -filter:v "pad=1440:160:0:0:black" part1_d.mp4
    ffmpeg -i part3_1_t.mp4 -filter:v "pad=1440:160:0:0:black" part3_1_d.mp4

    # Stack the clips on top of each other in physical order
    ffmpeg -y -i part3_2_d.mp4 -i part4_d.mp4 -i part2_d.mp4 -i part1_d.mp4 -i part3_1_d.mp4 -filter_complex "vstack=5" demo.mp4

    # Make it smaller
    ffmpeg -y -i demo.mp4 -vf scale=720:200 "${finished_filename}${demo_ending}.mp4"
    
    # Remove temporary files
    rm demo.mp4 part*_d.mp4 part3_*_t.mp4
fi

# Remove the temporary files.
rm long.mp4 part*.mp4 padding.mp4 

# Copy the finished clip to a folder (if set).
# Useful for example if you'd like to automatically upload it to Dropbox.
if [ ! -z "${target_folder}" ]; then
    cp ${finished_filename}.mp4 ${target_folder}
fi
