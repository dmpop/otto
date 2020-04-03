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
  $0 -d <dir> -g <location> -c <dir>

Options:
  -d Specifies the source directory
  -g Geotag using coordinates of the specified location (city)
  -c path to a directory containing one or several GPX files (optional)
EOF
  exit 1
}
# Obtain values
while getopts "d:g:c:" opt; do
  case ${opt} in
      d ) src=$OPTARG
	  ;;
      g ) location=$OPTARG
	  ;;
      c ) gpx=$OPTARG
	  ;;
    \? ) usage
      ;;
  esac
done
shift $((OPTIND -1))
CONFIG_DIR=$(dirname "$0")
CONFIG="${CONFIG_DIR}/otto.cfg"
#Check whether the path to the source directory is specified
if [ -z "$src" ]; then
    echo "Please specify the path to the source directory"
    exit 1
    fi
# Check whether the Photon service is reachable
check=$(wget -q --spider http://photon.komoot.de/)
if [ ! -z "$check" ]; then
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
    echo 'TARGET="'$target'"' >> "$CONFIG"
    echo 'COPYRIGHT="'$copyright'"' >> "$CONFIG"
    echo "Enter your Notify token and press [ENTER]."
    echo "Skip to disable notifications:"
    read notify_token
    echo 'NOTIFY_TOKEN="'$notify_token'"' >> "$CONFIG"
    fi
source "$CONFIG"
mkdir -p "$TARGET"
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
    cp "$file" "$TARGET"
done
cd "$TARGET"
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
    results=$(find "$TARGET" -name '*' -exec file {} \; | grep -o -P '^.+: JPEG' | cut -d":" -f1)
    lines=$(echo -e "$results" | wc -l)
    for line in $(seq 1 $lines)
        do
            file=$(echo -e "$results" | sed -n "$line p")
            exiftool -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref "$file"
        done
        fi
if [ ! -z "$gpx" ]; then
    # Count GPX files in the specified directory
    cd "$gpx"
    fcount=$(ls -1 | wc -l)
    # Check for GPX files and GPSBabel
    if [ "$fcount" -eq "0" ]; then
	echo "No GPX files are found."
	exit 1
    fi
    # Check whether the required packages are installed
    if [ ! -x "$(command -v gpsbabel)" ]; then
	echo "GPSBabel is not found."
	exit 1
    fi
    # Geocorrelate with a single GPX file
    if [ "$fcount" -eq "1" ]; then
	echo
	echo "--------------"
	echo "Geotagging ..."
	echo "--------------"
	echo
	fgpx=$(ls "$gpx")
	exiftool -overwrite_original -r -geotag "$fgpx" -geosync=180 "$TARGET"
    fi
    if [ "$fcount" -gt "1" ]; then
	echo
	echo "---------------------"
	echo "Merging GPX files ..."
	echo "---------------------"
	echo
	cd "$gpx"
	ff=""
	for f in *.gpx
	do
	    ff="$ff -f $f"
	done
	gpsbabel -i gpx $ff -o gpx -F "output.gpx"
	gpx=$(pwd)"/output.gpx"
    fi
fi
cd "$TARGET"
echo "-------------------------"
echo "Writing EXIF metadata ..."
echo "-------------------------"
echo
# Obtain and write copyright camera model, lens, and weather conditions
results=$(find "$TARGET" -name '*' -exec file {} \; | grep -o -P '^.+: JPEG' | cut -d":" -f1)
lines=$(echo -e "$results" | wc -l)
for line in $(seq 1 $lines)
do
    file=$(echo -e "$results" | sed -n "$line p")
    lat=$(exiftool -gpslatitude -n "$file" | cut -d":" -f2 | tr -d " ")
    lon=$(exiftool -gpslongitude -n "$file" | cut -d":" -f2 | tr -d " ")
    camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
    lens=$(exiftool -LensID "$file" | cut -d":" -f2)
    exiftool -overwrite_original -copyright="$copyright" -comment="$camera $lens" "$file"
done
echo
echo "--------------------------"
echo "Renaming and organizing..."
echo "--------------------------"
echo
exiftool -d %Y%m%d-%H%M%S%%-c.%%e '-FileName<DateTimeOriginal' "$TARGET"
exiftool '-Directory<CreateDate' -d ./%Y-%m-%d "$TARGET"
cd
# find "$TARGET" -type d -exec chmod 755 {} \;
if [ ! -z "$NOTIFY_TOKEN" ]; then
    curl "https://api.simplepush.io/send/${NOTIFY_TOKEN}/Otto/All done!"
else
    echo
    echo "---------"
    echo "All done!"
    echo "---------"
    echo
fi
