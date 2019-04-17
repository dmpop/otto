#!/usr/bin/env bash

# Author: Dmitri Popov, dmpop@linux.com
# License: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# Source code: https://gitlab.com/dmpop/otto

# opkg install getopt bc jq curl perl-image-exiftool

# Check whether the required packages are installed
if [ ! -x "$(command -v getopt)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v exiftool)" ]; then
    echo "Make sure that the following tools are installed on your system: getopt, bc, jq, curl, exiftool"
    exit 1
fi

echo
echo "-----------------------------------"
echo "        Hello! I'm Otto."
echo "Let's transfer and organize photos!"
echo "-----------------------------------"
echo

# Usage prompt
usage(){
cat <<EOF
$0 [OPTIONS]

$0 imports, geotags, adds metadata, and organizes photos and RAW files.

Usage:
  $0 -d <dir> -g <location>

Options:
  -d --directory    Specifies the source directory
  -g --geotag       Geotag using coordinates of the specified location (city)
  -c --correlate    Geocorrelate using the specified GPX file
EOF
  exit 1
}

# Specify options
OPTS=$(getopt -o d:g:c -l directory:geotag:correlate -- "$@")
[[ $# -eq 0 ]] && usage
eval set -- "$OPTS"

# Obtain values
while true; do
  case "$1" in
    -d | --directory ) src="$2"; shift 2;;
    -g | --geotag ) location="$2"; shift 2;;
    -c | --correlate) gpx="$3"; shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

CONFIG_DIR=$(dirname "$0")
CONFIG="${CONFIG_DIR}/otto.cfg"

#Check whether the path to the source directory is specified
if [ -z "$src" ]; then
    echo "Please specify the path to the source directory"
    exit 1
    fi

# Check whether the Photon service is reachable
check1=$(wget -q --spider http://photon.komoot.de/)
if [ ! -z "$check1" ]; then
    echo
    echo "--------------------------------------------------------"
    echo "Photon is not reachable. Check your Internet connection."
    echo "--------------------------------------------------------"
    exit 1
    fi

# Ask for the required info and write the obtained values into the configuration file
if [ ! -f "$CONFIG" ]; then
    echo "Specify destination directory and press [ENTER]:"
    read target
    echo "Specify copyright notice and press [ENTER]:"
    read copyright
    echo 'target="'$target'"' >> "$CONFIG"
    echo 'copyright="'$copyright'"' >> "$CONFIG"
    echo 'json="weather.json"' >> "$CONFIG"
    echo "Provide Dark Sky API key and press [ENTER]:"
    read api_key
    echo 'api_key="'$api_key'"' >> "$CONFIG"
    echo "Enter your Notify token and press [ENTER]."
    echo "Skip to disable notifications:"
    read notify_token
    echo 'notify_token="'$notify_token'"' >> "$CONFIG"
    fi

source "$CONFIG"
mkdir -p "$target"

echo
echo "---------------------"
echo "Transferring files..."
echo "---------------------"
echo

results=$(find "$src" -name '*' -exec file {} \; | grep -o -P '^.+: \w+ image' | cut -d":" -f1)
lines=$(echo -e "$results" | wc -l)
for line in $(seq 1 $lines)
        do
            file=$(echo -e "$results" | sed -n "$line p")
	    echo "$file"
            cp "$file" "$target"
            done

cd "$target"

if [ ! -z "$location" ]; then
    # Obtain latitude and longitude for the specified location
    lat=$(curl -k "photon.komoot.de/api/?q=$location" | jq '.features | .[0] | .geometry | .coordinates | .[1]')
    if (( $(echo "$lat > 0" |bc -l) )); then
        latref="N"
        else
        latref="S"
    fi
    lon=$(curl -k "photon.komoot.de/api/?q=$location" | jq '.features | .[0] | .geometry | .coordinates | .[0]')
    
    if (( $(echo "$lon > 0" |bc -l) )); then
        lonref="E"
        else
        lonref="W"
    fi
fi

# Geotag if the -g parameter is not empty
if [ ! -z "$location" ]; then
    echo
    echo "--------------"
    echo "Geotagging ..."
    echo "--------------"
    echo
    results=$(find "$target" -name '*' -exec file {} \; | grep -o -P '^.+: JPEG' | cut -d":" -f1)
    lines=$(echo -e "$results" | wc -l)
    for line in $(seq 1 $lines)
        do
            file=$(echo -e "$results" | sed -n "$line p")
            exiftool -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref "$file"
        done
    fi

# Geocorrecate if -c parameter is not empty
if [ ! -z "$gpx" ]; then
    exiftool -overwrite_original -r -geotag "$gpx" -geosync=180 "$target"
    fi

# Check whether the Dark Sky API is reachable
check2=$(wget -q --spider https://api.darksky.net/)
    if [ -z "$check2" ]; then
        echo
        echo "-------------------------"
        echo "Writing EXIF metadata ..."
        echo "-------------------------"
        echo
        # Obtain and write copyright camera model, lens, and weather conditions
	results=$(find "$target" -name '*' -exec file {} \; | grep -o -P '^.+: JPEG' | cut -d":" -f1)
        for line in $(seq 1 $lines)
            do
                file=$(echo -e "$results" | sed -n "$line p")
                lat=$(exiftool -gpslatitude -n "$file" | cut -d":" -f2 | tr -d " ")
                lon=$(exiftool -gpslongitude -n "$file" | cut -d":" -f2 | tr -d " ")
                t=$(exiftool -d %Y-%m-%d -DateTimeOriginal "$file" | cut -d":" -f2 | tr -d " " | xargs -I dt date --date=dt +"%s")
                camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
                lens=$(exiftool -LensID "$file" | cut -d":" -f2)
                curl -k "https://api.darksky.net/forecast/$api_key/$lat,$lon,$t?units=si&exclude=currently,hourly,flags" > "$json"
                w_sum=$(jq '.daily | .data | .[0] | .summary' "$json" | tr -d '"')
                w_temp=$(jq '.daily | .data | .[0] | .temperatureHigh' "$json" | tr -d '"')
                exiftool -overwrite_original -copyright="$copyright" -comment="$camera, $lens, $w_temp°C, $w_sum" "$file"
                done
        else
            echo
            echo "-------------------------------------------------------------"
            echo "Dark Sky API is not reachable. EXIF metadata was not updated."
            echo "-------------------------------------------------------------"
            echo
        fi

echo
echo "--------------------------"
echo "Renaming and organizing..."
echo "--------------------------"
echo
exiftool -d %Y%m%d-%H%M%S%%-c.%%e '-FileName<DateTimeOriginal' "$target"
exiftool '-Directory<CreateDate' -d ./%Y-%m-%d "$target"

if [ -f "$json" ]; then
    rm "$json"
    fi

cd

find "$target" -type d -exec chmod 755 {} \;

if [ ! -z "$notify_token" ]; then
    curl -k \
"https://us-central1-notify-b7652.cloudfunctions.net/sendNotification?to=${notify_token}&text=Otto%20is%20done!" \
	> /dev/null
else
    echo
    echo "---------"
    echo "All done!"
    echo "---------"
    echo
    fi
