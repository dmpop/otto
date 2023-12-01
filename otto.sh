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
if [ ! -x "$(command -v dialog)" ] || [ ! -x "$(command -v getopt)" ] ||
    [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] ||
    [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v exiftool)" ] ||
    [ ! -x "$(command -v exiv2)" ] || [ ! -x "$(command -v rsync)" ] ||
    [ ! -x "$(command -v sshpass)" ] || [ ! -x "$(command -v gpsbabel)" ]; then
    echo "Make sure that the following tools are installed on your system: dialog, getopt, bc, jq, curl, exiftool, exiv2, sshpass, rsync, gpsbabel"
    exit 1
fi

# Usage prompt
usage() {
    cat <<EOF
$0 [OPTIONS]
------
$0 transfers, geotags, adds metadata, organizes photos and RAW files, generates EXIF-based stats.

EXAMPLES:
------
  $0 -d <dir> -b
  $0 -d <dir> -g <location> -t "This is text" -k "keyword1 keyword2 keyword3"
  $0 -d <dir> -c <dir>
  $0 -d <dir> -g <location> -r NEF
  $0 -d <dir> -s <EXIF tag>
  
OPTIONS:
--------
  -d Specifies the source directory
  -g Geotag using coordinates of the specified location (city)
  -c path to a directory containing one or several GPX files
  -b Perform backup only
  -r Transfer RAW files in the specified format only
  -i Perform backup to an individual directory named after the current date
  -t Write the specified text into the Comment field on EXIF medata
  -k Write the specified keywords into EXIF medata
  -s Generate stats for the given EXIF tag
EOF
    exit 1
}

# Notification function
function notify() {
    if [ ! -z "$NTFY_TOPIC" ]; then
        curl \
            -d "I'm done. Have a nice day!" \
            -H "Title: Message from Otto" \
            -H "Tags: monkey" \
            "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1
    fi
    dialog --erase-on-exit --title "OTTO" --msgbox "            ~\n         o{°_°}o\n          /(.)~[*O]\n           / \\\n--------------------------\nAll done! Have a nice day.\n--------------------------" 11 30
}

CONFIG="$HOME/.otto.cfg"

# Obtain parameter values
while getopts "d:g:c:bir:t:k:s:" opt; do
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
        backup=1
        ;;
    i)
        ind=1
        ;;
    r)
        raw=$OPTARG
        ;;
    t)
        text=$OPTARG
        ;;
    k)
        keywords=$OPTARG
        ;;
    s)
        exif_tag=$OPTARG
        ;;
    \?)
        usage
        ;;
    esac
done
shift $((OPTIND - 1))

yyyy=$(date +%Y)

# Ask for the required info and write the obtained values into the configuration file
if [ ! -f "$CONFIG" ]; then
    dialog --erase-on-exit --title "Otto configuration" \
        --form "\n          Specify the required settings" 16 56 8 \
        "      Destination:" 1 4 "$HOME/OTTO" 1 23 25 512 \
        "           Author:" 2 4 "Full Name" 2 23 25 512 \
        "      ntfy server:" 3 4 "ntfy.sh" 3 23 25 512 \
        "       ntfy topic:" 4 4 "unique-string" 4 23 25 512 \
        "    Remote server:" 5 4 "hello.xyz" 5 23 25 512 \
        "      Remote path:" 6 4 "/var/www/html/data" 6 23 25 512 \
        "      Remote user:" 7 4 "Remote user name" 7 23 25 512 \
        "        Password:" 8 4 "Remote user password" 8 23 25 512 \
        >/tmp/dialog.tmp \
        2>&1 >/dev/tty
    if [ -s "/tmp/dialog.tmp" ]; then
        destination=$(sed -n 1p /tmp/dialog.tmp)
        author=$(sed -n 2p /tmp/dialog.tmp)
        ntfy_server=$(sed -n 3p /tmp/dialog.tmp)
        ntfy_topic=$(sed -n 4p /tmp/dialog.tmp)
        remote_server=$(sed -n 5p /tmp/dialog.tmp)
        remote_path=$(sed -n 6p /tmp/dialog.tmp)
        remote_user=$(sed -n 7p /tmp/dialog.tmp)
        password=$(sed -n 8p /tmp/dialog.tmp)
        echo "DESTINATION=\"$destination\"" >>"$CONFIG"
        echo "AUTHOR=\"$author\"" >>"$CONFIG"
        echo "NTFY_SERVER=\"$ntfy_server\"" >>"$CONFIG"
        echo "NTFY_TOPIC=\"$ntfy_topic\"" >>"$CONFIG"
        echo "REMOTE_SERVER=\"$remote_server\"" >>"$CONFIG"
        echo "REMOTE_PATH=\"$remote_path\"" >>"$CONFIG"
        echo "REMOTE_USER=\"$remote_user\"" >>"$CONFIG"
        echo "PASSWORD=\"$password\"" >>"$CONFIG"
        echo "DATE_FORMAT=\"%Y%m%d-%H%M%S%%-c.%%e\"" >>"$CONFIG"
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

# Check whether the source directory exists
if [ ! -d "$src" ]; then
    dialog --erase-on-exit --backtitle "ERROR" --msgbox "Source directory not found." 5 31
    exit 1
fi

if [ -z '$(ls -A "'$src'")' ]; then
    dialog --erase-on-exit --backtitle "ERROR" --msgbox "Source directory is empty." 5 31
    exit 1
fi

if [ -f "/tmp/otto.log" ]; then
    rm "/tmp/otto.log"
fi

# Create the destionation directory
srcdir=$(basename "$src")
ENDPOINT="$DESTINATION/$srcdir"
mkdir -p "$ENDPOINT"

# If -s parameter specified, generate stats for the given EXIF tag
if [ ! -z "$exif_tag" ]; then
    dialog --infobox "Generating $exif_tag stats..." 3 41
    results=$(mktemp)
    exiftool -r -T "-$exif_tag" "$src" >"$results"
    if [ -f "$HOME/$exif_tag.csv" ]; then
        rm "$HOME/$exif_tag.csv"
    fi
    echo "$exif_tag, Count," >>"$HOME/$exif_tag.csv"
    sort "$results" | uniq -c | awk '{print $0 ", " $1 ","}' | awk '{$1=""; print $0}' | awk '{$1=$1;print}' >>"$HOME/$exif_tag.csv"
    clear
    notify
    exit 1
fi

# If -b parameter specified, perform a simple backup
if [ ! -z "$backup" ]; then
    dialog --infobox "Transferring files..." 3 26
    rsync -avh "$src/" "$ENDPOINT" >>"/tmp/otto.log" 2>&1
    clear
    notify
    exit 1
fi

# If -u parameter specified, perform a simple backup
# to a dedicated directory named after the current date
if [ ! -z "$ind" ]; then
    d=$(date -d "today" +"%Y-%m-%d")
    dialog --infobox "Transferring files..." 3 26
    rsync -avh "$src/" "$ENDPOINT/$d" >>"/tmp/otto.log" 2>&1
    clear
    notify
    exit 1
fi

dialog --infobox "Transferring and renaming files..." 3 39
cd "$src"
if [ ! -z "$raw" ]; then
    exiftool -q -q -m -r -o "$ENDPOINT" -d "$DATE_FORMAT" '-FileName<DateTimeOriginal' -ext $raw . >>"/tmp/otto.log" 2>&1
else
    exiftool -q -q -m -r -o "$ENDPOINT" -d "$DATE_FORMAT" '-FileName<DateTimeOriginal' . >>"/tmp/otto.log" 2>&1
fi
exit

dialog --infobox "Writing EXIF metadata..." 3 28
cd "$ENDPOINT"
# Obtain and write copyright camera model, lens, and note
for file in "*.*"; do
    date=$(exiftool -q -q -m -DateTimeOriginal -d %Y-%m-%d "$file" | cut -d":" -f2 | tr -d " ")
    wf=$date".txt"
    if [ ! -z "$text" ]; then
        note="$text"
    elif [ ! -z "$REMOTE_SERVER" ]; then
        sshpass -p "$PASSWORD" rsync -ave ssh "$REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH/$wf" "/tmp/" >>"/tmp/otto.log" 2>&1
        if [ -f "/tmp/$wf" ]; then
            note=$(<"/tmp/$wf")
        fi
    else
        note=""
    fi
    camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
    lens=$(exiftool -q -q -m -LensID "$file" | cut -d":" -f2)
    if [ -z "$lens" ]; then
        lens=$(exiftool -q -q -m -LensModel "$file" | cut -d":" -f2)
    fi
    exiv2 --Modify "set Xmp.exif.UserComment $camera $lens $note" "$file" >>"/tmp/otto.log" 2>&1
    exiv2 --Modify "set Exif.Image.Copyright $yyyy $AUTHOR" "$file" >>"/tmp/otto.log" 2>&1
    # Check whether keywords are specified
    if [ ! -z "$keywords" ]; then
        exiv2 --Modify "set Iptc.Application2.Keywords $keywords" "$file" >>"/tmp/otto.log" 2>&1
    fi
done

# Geotag files
if [ ! -z "$location" ]; then
    # Check whether the Photon service is reachable
    check=$(wget -q --spider https://photon.komoot.io/)
    if [ ! -z "$check" ]; then
        dialog --erase-on-exit --backtitle "ERROR" --msgbox "Photon is not reachable. Geotagging skipped." 6 28
    else
        # Obtain latitude and longitude for the specified location
        geo="$(curl -k "https://photon.komoot.io/api/?q=$location")"
        lat=$(echo "$geo" | jq '.features | .[0] | .geometry | .coordinates | .[1]')
        lon=$(echo "$geo" | jq '.features | .[0] | .geometry | .coordinates | .[0]')
        if (($(echo "$lat > 0" | bc -l))); then
            latref="N"
        else
            latref="S"
        fi
        if (($(echo "$lon > 0" | bc -l))); then
            lonref="E"
        else
            lonref="W"
        fi
        dialog --infobox "Geotagging..." 3 17
        exiftool -q -q -m -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref . >>"/tmp/otto.log" 2>&1
    fi
fi

if [ ! -z "$gpx" ]; then
    # Count GPX files in the specified directory
    cd "$gpx"
    fcount=$(ls -1 | wc -l)
    # Check for GPX files and GPSBabel
    if [ "$fcount" -eq "0" ]; then
        dialog --erase-on-exit --backtitle "ERROR" --msgbox "No GPX files found." 5 23
        exit 1
    fi
    # Geocorrelate with a single GPX file
    if [ "$fcount" -eq "1" ]; then
        dialog --infobox "Geocorrelating..." 3 21
        track=$(ls "$gpx")
        exiftool -q -q -m -overwrite_original -geotag "$track" -geosync=180 "$ENDPOINT" >>"/tmp/otto.log" 2>&1
    elif [ "$fcount" -gt "1" ]; then
        ff=""
        for f in *.gpx; do
            ff="$ff -f $f"
        done
        gpsbabel -i gpx $ff -o gpx -F "/tmp/merged-track.gpx"
        track="/tmp/merged-track.gpx"
        exiftool -q -q -m -overwrite_original -geotag "$track" -geosync=180 "$ENDPOINT" >>"/tmp/otto.log" 2>&1
    else
        dialog --erase-on-exit --backtitle "ERROR" --msgbox "Something went wrong. Geotagging skipped." 6 25
    fi
fi

dialog --infobox "Organizing files..." 3 23
cd "$ENDPOINT"
exiftool -q -q -m '-Directory<CreateDate' -d ./%Y-%m-%d . >>"/tmp/otto.log" 2>&1
cd
clear
notify
