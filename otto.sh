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
# Source code: https://github.com/dmpop/otto

# Check whether the required packages are installed
if [ ! -x "$(command -v dialog)" ] || [ ! -x "$(command -v getopt)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v exiftool)" ] || [ ! -x "$(command -v rsync)" ] || [ ! -x "$(command -v sshpass)" ] || [ ! -x "$(command -v gpsbabel)" ]; then
    echo "Make sure that the following tools are installed on your system: dialog, getopt, bc, jq, curl, exiftool, sshpass, rsync, gpsbabel"
    exit 1
fi

# Usage prompt
usage() {
    cat <<EOF
$0 [OPTIONS]
------
$0 transfers, geotags, adds metadata, and organizes photos and RAW files.

USAGE:
------
  $0 -d <dir> -g <location> -c <dir> -b <dir> -k "keyword1, keyword2, keyword3"

OPTIONS:
--------
  -d Specifies the source directory
  -g Geotag using coordinates of the specified location (city)
  -c path to a directory containing one or several GPX files (optional)
  -b Perform backup only
  -k Write specified keywords into EXIF medata
EOF
    exit 1
}

echo ''
echo '               ~'
echo '            o{°_°}o'
echo '             /(.)~[*O]'
echo '              / \'
echo '         ---------------='
echo "         Hello! I'm Otto."
echo ''

# Obtain parameter values
while getopts "d:g:c:b:k:" opt; do
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
    b)
        bak_dir=$OPTARG
        ;;
    k)
        keywords=$OPTARG
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
        --form "\n          Specify the required settings" 16 56 7 \
        " Target directory:" 1 4 "/home/user/OTTO" 1 23 25 512 \
        " Copyright notice:" 2 4 "© YYYY Full Name" 2 23 25 512 \
        "       NTFY topic:" 3 4 "unique-string" 3 23 25 512 \
        "    Remote server:" 4 4 "hello.xyz" 4 23 25 512 \
        "      Remote path:" 5 4 "/var/www/html/data" 5 23 25 512 \
        "            User:" 6 4 "Remote username" 6 23 25 512 \
        "        Password:" 7 4 "Remote user password" 7 23 25 512 \
        >/tmp/dialog.tmp \
        2>&1 >/dev/tty
    if [ -s "/tmp/dialog.tmp" ]; then
        target=$(sed -n 1p /tmp/dialog.tmp)
        copyright=$(sed -n 2p /tmp/dialog.tmp)
        NTFY_TOPIC=$(sed -n 3p /tmp/dialog.tmp)
        server=$(sed -n 4p /tmp/dialog.tmp)
        path=$(sed -n 5p /tmp/dialog.tmp)
        user=$(sed -n 6p /tmp/dialog.tmp)
        password=$(sed -n 7p /tmp/dialog.tmp)
        echo "TARGET='$target'" >>"$CONFIG"
        echo "COPYRIGHT='$copyright'" >>"$CONFIG"
        echo "NTFY_TOPIC='$NTFY_TOPIC'" >>"$CONFIG"
        echo "REMOTE_SERVER='$server'" >>"$CONFIG"
        echo "REMOTE_PATH='$path'" >>"$CONFIG"
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
    usage
    exit 1
fi

if [ -z '$(ls -A "'$src'")' ]; then
    echo
    echo "ERROR: Is the storage device mounted?"
    exit 1
fi

# If -b parameter specified, perform a simple backup
if [ ! -z "$bak_dir" ]; then
    echo
    echo "--- Transferring files ---"
    echo

    mkdir -p "$bak_dir"
    rsync -avh "$src" "$bak_dir"

    if [ ! -z "$NTFY_TOPIC" ]; then
        curl -d "All done!" ntfy.sh/${NTFY_TOPIC}
    else
        echo
        echo "--- All done. Have a nice day! ---"
        echo
    fi
    exit 1
fi

mkdir -p "$TARGET"

# Check whether keywords are provided
if [ -z "$keywords" ]; then
    keywords=""
fi

echo
echo "--- Transferring files ---"
echo

find "$src" -type f -exec cp -t "$TARGET" {} +

cd "$TARGET"

echo
echo "--- Renaming files ---"
echo

exiftool -d "$DATE_FORMAT" '-FileName<DateTimeOriginal' -directory="$TARGET" .

echo
echo "--- Writing EXIF metadata ---"
echo

# Obtain and write copyright camera model, lens, and notes
for file in *.*; do
    date=$(exiftool -DateTimeOriginal -d %Y-%m-%d "$file" | cut -d":" -f2 | tr -d " ")
    wf=$date".txt"
    if [ ! -z "$REMOTE_SERVER" ]; then
        if [ ! -f "$HOME/$wf" ]; then
            sshpass -p "$PASSWORD" rsync -ave ssh "$USER@$REMOTE_SERVER:$REMOTE_PATH/$wf" "$HOME"
        fi
        if [ -f "$HOME/$wf" ]; then
            notes=$(<"$HOME/$wf")
        else
            notes=""
        fi
    fi
    camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
    lens=$(exiftool -LensID "$file" | cut -d":" -f2)
    if [ -z "$lens" ]; then
        lens=$(exiftool -LensModel "$file" | cut -d":" -f2)
    fi
    exiftool -overwrite_original -copyright="$copyright" -comment="$camera $lens $notes" -sep ", " -keywords="$keywords" "$file"
done

if [ ! -z "$location" ]; then
    # Check whether the Photon service is reachable
    check=$(wget -q --spider https://photon.komoot.io/)
    if [ ! -z "$check" ]; then
        echo
        echo "--- Photon is not reachable. Geotagging skipped. ---"
        echo

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
        echo "--- Geotagging ---"
        echo

        exiftool -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref .
    fi
fi

if [ ! -z "$gpx" ]; then
    # Count GPX files in the specified directory
    cd "$gpx"
    fcount=$(ls -1 | wc -l)
    # Check for GPX files and GPSBabel
    if [ "$fcount" -eq "0" ]; then
        echo
        echo "--- No GPX files are found ---"
        echo
        exit 1
    fi
    # Geocorrelate with a single GPX file
    if [ "$fcount" -eq "1" ]; then
        echo
        echo "--- Geocorrelating ---"
        echo

        fgpx=$(ls "$gpx")
        exiftool -overwrite_original -geotag "$fgpx" -geosync=180 .
    fi
    if [ "$fcount" -gt "1" ]; then
        echo
        echo "--- Merging GPX files ---"
        echo

        cd "$gpx"
        ff=""
        for f in *.gpx; do
            ff="$ff -f $f"
        done
        gpsbabel -i gpx $ff -o gpx -F "merged.gpx"
        fgpx=$(pwd)"/merged.gpx"
        exiftool -overwrite_original -geotag "$fgpx" -geosync=180 .
    fi
fi

echo
echo "--- Organizing files ---"
echo

exiftool '-Directory<CreateDate' -d ./%Y-%m-%d .
cd

if [ ! -z "$NTFY_TOPIC" ]; then
    curl -d "All done!" ntfy.sh/${NTFY_TOPIC}
else
    echo
    echo "--- All done. Have a nice day! ---"
    echo
fi
