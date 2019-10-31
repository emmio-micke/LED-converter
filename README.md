# LED converter
This bash script is putting together videoclips for the LED screens in Himmelstalundshallen. Feel free to use it any way you'd like, no responsibilty taken for data loss etc.

## Params
You can use the filenames for the videoclips as parameters to the script.

The script will try to identify any clips in the folder based on filename and use them. Since screens 2 and 4 are equally sized, if the script can only find three clips, it will use the same clip for screens 2 and 4.

## Install
Install by cloning repo and setting an alias:
```
git clone git@github.com:emmio-micke/LED-converter.git
```

Make it runnable:
```
cd LED-converter
chmod +x convert.sh
```

In your profile script:
```
alias ledcon="<path>/convert.sh"
```

Change folder and run script:
```
cd "<path>"
ledcon
```


## Screens

```
Section    M  Px
1          8  1280x160
2          7  1120x160
3         17  2720x160
4          7  1120x160
```

## Requirements
This script assumes that you have [ffmpeg](https://www.ffmpeg.org/) installed. It's written on Mac but should probably work on any environment with bash.
