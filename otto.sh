#!/usr/bin/env bash

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.

# Author: Dmitri Popov, dmpop@linux.com
# Source code: https://gitlab.com/dmpop/otto

# Check whether the required packages are installed
if [ ! -x "$(command -v dialog)" ] || [ ! -x "$(command -v getopt)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v exiftool)" ] || [ ! -x "$(command -v rsync)" ] || [ ! -x "$(command -v gpsbabel)" ]; then
    echo "Make sure that the following tools are installed on your system: dialog, getopt, bc, jq, curl, exiftool, rsync, gpsbabel"
    exit 1
fi

# Usage prompt
usage() {
    cat <<EOF
$0 [OPTIONS]
------
$0 imports, geotags, adds metadata, and organizes photos and RAW files.

USAGE:
------
  $0 -d <dir> -g <location> -c <dir>

OPTIONS:
--------
  -d Specifies the source directory
  -g Geotag using coordinates of the specified location (city)
  -c path to a directory containing one or several GPX files (optional)
EOF
    exit 1
}

notify() {
    if [ -x "$(command -v notify-send)" ]; then
        notify-send "$1" -t 1
    fi
}

echo
echo "   ____  __  __       "
echo "  / __ \/ /_/ /_____  "
echo " / / / / __/ __/ __ \ "
echo "/ /_/ / /_/ /_/ /_/ / "
echo "\____/\__/\__/\____/  "
echo "----------------------"
echo
notify " Hello! I'm Otto. Let's transfer and organize photos :-)"

# Obtain values
while getopts "d:g:c:" opt; do
    case ${opt} in
    d)
        src=$OPTARG
        ;;
    g)
        location=$OPTARG
        ;;
    c)
        gpx=$OPTARG
        ;;
    \?)
        usage
        ;;
    esac
done
shift $((OPTIND - 1))
CONFIG="$HOME/.otto.cfg"

# Ask for the required info and write the obtained values into the configuration file
if [ ! -f "$CONFIG" ]; then
    dialog --title "Otto configuration" \
        --form "\n          Specify the required settings" 16 56 6 \
        "Target directory:" 1 4 "" 1 23 25 512 \
        "Copyright notice:" 2 4 "" 2 23 25 512 \
        "    Notify token:" 3 4 "" 3 23 25 512 \
        "      FTP server:" 4 4 "" 4 23 25 512 \
        "        FTP user:" 5 4 "" 5 23 25 512 \
        "    FTP password:" 6 4 "" 6 23 25 512 \
        >/tmp/dialog.tmp \
        2>&1 >/dev/tty
    if [ -s "/tmp/dialog.tmp" ]; then
        target=$(sed -n 1p /tmp/dialog.tmp)
        copyright=$(sed -n 2p /tmp/dialog.tmp)
        notify_token=$(sed -n 3p /tmp/dialog.tmp)
        ftp=$(sed -n 4p /tmp/dialog.tmp)
        user=$(sed -n 5p /tmp/dialog.tmp)
        password=$(sed -n 6p /tmp/dialog.tmp)
        echo "TARGET='$target'" >>"$CONFIG"
        echo "COPYRIGHT='$copyright'" >>"$CONFIG"
        echo "NOTIFY_TOKEN='$notify_token'" >>"$CONFIG"
        echo "FTP='$ftp'" >>"$CONFIG"
        echo "USER='$user'" >>"$CONFIG"
        echo "PASSWORD='$password'" >>"$CONFIG"
        echo "DATE_FORMAT='%Y%m%d-%H%M%S%%-c.%%e'" >>"$CONFIG"
        rm -f /tmp/dialog.tmp
    else
        exit 1
    fi
fi

source "$CONFIG"

# Check whether the path to the source directory is specified
if [ -z "$src" ]; then
    src="$DIR"
    echo $src
fi

if [ -z "$src" ]; then
    usage
    exit 1
fi

mkdir -p "$TARGET"

echo
echo "----------------------------"
echo "     Transferring files     "
echo "----------------------------"
echo

notify-send "Transferring files"

rsync -avh --delete "$src" "$TARGET"

cd "$TARGET"

echo "------------------------"
echo "     Renaming files     "
echo "------------------------"
echo

notify-send "Renaming files"

exiftool -d "$DATE_FORMAT" '-FileName<DateTimeOriginal' -directory="$TARGET" -r .

echo "-------------------------------"
echo "     Writing EXIF metadata     "
echo "-------------------------------"
echo

notify-send "Writing EXIF metadata"

# Obtain and write copyright camera model, lens, and weather info
for file in *.*; do
    date=$(exiftool -DateTimeOriginal -d %Y-%m-%d "$file" | cut -d":" -f2 | tr -d " ")
    wf=$date".txt"
    if [ ! -z "$FTP" ]; then
        if [ ! -f "$HOME/$wf" ]; then
            curl -s -u "$USER":"$PASSWORD" "$FTP$wf" -o "$HOME/$wf"
        fi
        if [ -f "$HOME/$wf" ]; then
            weather=$(<"$HOME/$wf")
        else
            weather="Weather not available"
        fi
    fi
    camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
    lens=$(exiftool -LensID "$file" | cut -d":" -f2)
    if [ -z "$lens" ]; then
        lens=$(exiftool -LensModel "$file" | cut -d":" -f2)
    fi
    exiftool -overwrite_original -copyright="$copyright" -comment="$camera $lens $weather" "$file"
done

if [ ! -z "$location" ]; then
    # Check whether the Photon service is reachable
    check=$(wget -q --spider https://photon.komoot.io/)
    if [ ! -z "$check" ]; then
        echo
        echo "--------------------------------------------------------------"
        echo "   Photon is not reachable. Check your Internet connection.   "
        echo "                  Geotagging skipped.                         "
        echo "--------------------------------------------------------------"

        notify "Photon is not reachable. Geotagging skipped. :-("

    else
        # Obtain latitude and longitude for the specified location
        lat=$(curl -k "https://photon.komoot.io/api/?q=$location" | jq '.features | .[0] | .geometry | .coordinates | .[1]')
        if (($(echo "$lat > 0" | bc -l))); then
            latref="N"
        else
            latref="S"
        fi
        lon=$(curl -k "https://photon.komoot.io/api/?q=$location" | jq '.features | .[0] | .geometry | .coordinates | .[0]')
        if (($(echo "$lon > 0" | bc -l))); then
            lonref="E"
        else
            lonref="W"
        fi
        echo
        echo "--------------------"
        echo "     Geotagging     "
        echo "--------------------"
        echo

        notify "Geotagging"

        exiftool -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref -r .
    fi
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
    # Geocorrelate with a single GPX file
    if [ "$fcount" -eq "1" ]; then
        echo
        echo "--------------------"
        echo "     Geotagging     "
        echo "--------------------"
        echo

        notify "Geotagging"

        fgpx=$(ls "$gpx")
        exiftool -overwrite_original -r -geotag "$fgpx" -geosync=180 -r .
    fi
    if [ "$fcount" -gt "1" ]; then
        echo
        echo "---------------------------"
        echo "     Merging GPX files     "
        echo "---------------------------"
        echo

        notify "Merging GPX files"

        cd "$gpx"
        ff=""
        for f in *.gpx; do
            ff="$ff -f $f"
        done
        gpsbabel -i gpx $ff -o gpx -F "output.gpx"
        fgpx=$(pwd)"/output.gpx"
        exiftool -overwrite_original -r -geotag "$fgpx" -geosync=180 -r .
    fi
fi

echo
echo "--------------------------"
echo "     Organizing files     "
echo "--------------------------"
echo

notify "Organizing files"

exiftool '-Directory<CreateDate' -d ./%Y-%m-%d -r .
cd
# find "$TARGET" -type d -exec chmod 755 {} \;
if [ ! -z "$NOTIFY_TOKEN" ]; then
    curl --data "key=${NOTIFY_TOKEN}&title=Otto&msg=All done!&event=otto" https://api.simplepush.io/send
else
    echo
    echo "---------------"
    echo "   All done!   "
    echo "---------------"
    echo
    notify "All done! Have a nice day."
fi
