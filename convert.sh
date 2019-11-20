#!/bin/bash

# This script is putting together videoclips for the LED screens in Himmelstalundshallen.
# Written by mikael.olsson@emmio.se
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

# Config:
clip_length=10                     # Value in seconds.
target_folder="/Users/micke/Sync/" # Where to copy the finished clip. Leave empty if you don't wish to copy it.

# Get the current folder name to use as file name.
# I e, company/*.mp4 will result in company/company.mp4.
finished_filename=${PWD##*/}

# Remove any previous leftovers.
rm -f Icon$'\r'
rm -f long.mp4
rm -f part*.mp4
rm -f ${finished_filename}.mp4

# Get file names, if specified.
part1=$1
part2=$2
part3=$3
part4=$4

# If only 3 parameters are given, use the same clip for screens 2 and 4.
if [ "$#" -eq 3 ]; then
    part4=$2
fi

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
ffmpeg -i $part1 -c copy -t $clip_length part1_t.mp4
ffmpeg -i $part2 -c copy -t $clip_length part2_t.mp4
ffmpeg -i $part3 -c copy -t $clip_length part3_t.mp4
ffmpeg -i $part4 -c copy -t $clip_length part4_t.mp4

# Make a long (6240px x 160px) clip of all the individual clips.
ffmpeg -i part1_t.mp4 -i part2_t.mp4 -i part3_t.mp4 -i part4_t.mp4 -filter_complex hstack=4 long.mp4

# Divide the long clip into four equally wide clips (4 x 1560px x 160px).
ffmpeg -i long.mp4 -filter:v "crop=1600:160:0:0" part1.mp4
ffmpeg -i long.mp4 -filter:v "crop=1600:160:1600:0" part2.mp4
ffmpeg -i long.mp4 -filter:v "crop=1600:160:3200:0" part3.mp4
ffmpeg -i long.mp4 -filter:v "crop=1600:160:4800:0" part4.mp4

# Stack the four clips on top of each other to the finished clip. (1560px x 640px)
ffmpeg -i part1.mp4 -i part2.mp4 -i part3.mp4 -i part4.mp4 -filter_complex vstack=4 ${finished_filename}.mp4

# Remove the temporary files.
rm long.mp4 part*.mp4 

# Copy the finished clip to a folder (if set).
# Useful for example if you'd like to automatically upload it to Dropbox.
if [ ! -z "${target_folder}" ]; then
    cp ${finished_filename}.mp4 ${target_folder}
fi
