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
  $0 -d <dir> -g <location> -c <dir> -b -t "This is text" -k "keyword1, keyword2, keyword3" -p <file>
  
OPTIONS:
--------
  -d Specifies the source directory
  -g Geotag using coordinates of the specified location (city)
  -c path to a directory containing one or several GPX files
  -b Perform backup only
  -t Write the specificed text into the Comment field on EXIF medata
  -k Write the specified keywords into EXIF medata
  -p Apply the specified Hald CLUT file and sharpening to all JPEG files
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
    else
        clear
        dialog --clear --title "Success" --backtitle "OTTO" --msgbox "\nAll done. Have a nice day!" 7 30
    fi
}

clear
dialog --title "OTTO" --msgbox "          ~\n       o{°_°}o\n        /(.)~[*O]\n         / \\\n   ----------------\n   Hello! I'm Otto.\n   ----------------" 11 26
clear

CONFIG="$HOME/.otto.cfg"

# Obtain parameter values
while getopts "d:g:c:bt:k:p:" opt; do
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
    t)
        text=$OPTARG
        ;;
    k)
        keywords=$OPTARG
        ;;
    p)
        process=$OPTARG
        ;;
    \?)
        usage
        ;;
    esac
done
shift $((OPTIND - 1))

# Ask for the required info and write the obtained values into the configuration file
if [ ! -f "$CONFIG" ]; then
    dialog --title "Otto configuration" \
        --form "\n          Specify the required settings" 16 56 8 \
        " Target directory:" 1 4 "/home/user/OTTO" 1 23 25 512 \
        " Copyright notice:" 2 4 "© YYYY Full Name" 2 23 25 512 \
        "      ntfy server:" 3 4 "ntfy.sh" 3 23 25 512 \
        "       ntfy topic:" 4 4 "unique-string" 4 23 25 512 \
        "    Remote server:" 5 4 "hello.xyz" 5 23 25 512 \
        "      Remote path:" 6 4 "/var/www/html/data" 6 23 25 512 \
        "            User:" 7 4 "Remote username" 7 23 25 512 \
        "        Password:" 8 4 "Remote user password" 8 23 25 512 \
        >/tmp/dialog.tmp \
        2>&1 >/dev/tty
    if [ -s "/tmp/dialog.tmp" ]; then
        target=$(sed -n 1p /tmp/dialog.tmp)
        copyright=$(sed -n 2p /tmp/dialog.tmp)
        ntfy_server=$(sed -n 3p /tmp/dialog.tmp)
        ntfy_topic=$(sed -n 4p /tmp/dialog.tmp)
        server=$(sed -n 5p /tmp/dialog.tmp)
        path=$(sed -n 6p /tmp/dialog.tmp)
        user=$(sed -n 7p /tmp/dialog.tmp)
        password=$(sed -n 8p /tmp/dialog.tmp)
        echo "TARGET='$target'" >>"$CONFIG"
        echo "COPYRIGHT='$copyright'" >>"$CONFIG"
        echo "NTFY_SERVER='$ntfy_server'" >>"$CONFIG"
        echo "NTFY_TOPIC='$ntfy_topic'" >>"$CONFIG"
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
    clear
    dialog --clear --title "Error" --backtitle "OTTO" --msgbox "\nSource directory is empty. The process stopped." 7 51
    exit 1
fi

if [ -f "/tmp/otto.log" ]; then
    rm "/tmp/otto.log"
fi

# Create the target directory
# If the directory exists, prompt to empty it
mkdir -p "$TARGET"
if [ "$(ls -A $TARGET)" ]; then
    dialog --clear \
        --title "OTTO" \
        --backtitle "OTTO" \
        --yesno "The target directory is not empty. Do you want to empty it?" 7 65

    response=$?
    case $response in
    0)
        clear
        rm -rf "$TARGET"
        mkdir -p "$TARGET"
        ;;
    1)
        dialog --clear --title "Status" --backtitle "OTTO" --msgbox "The process has been stopped. No changes were made." 5 55
        clear
        exit 1
        ;;
    255)
        dialog --clear --title "Status" --backtitle "OTTO" --msgbox "The process has been stopped. No changes were made." 5 55
        clear
        exit 1
        ;;
    esac
fi

# If -b parameter specified, perform a simple backup
if [ ! -z "$backup" ]; then
    clear
    dialog --title "OTTO" --infobox "\nTransferring files..." 5 25
    rsync -avh "$src" "$TARGET" >>"/tmp/otto.log" 2>&1
    clear
    notify
    exit 1
fi

# Check whether keywords are specified
if [ -z "$keywords" ]; then
    keywords=""
fi

clear
dialog --title "OTTO" --infobox "\nTransferring and renaming files..." 5 38
cd "$src"
exiftool -r -o "$TARGET" -d "$DATE_FORMAT" '-FileName<DateTimeOriginal' . >>"/tmp/otto.log" 2>&1

clear
dialog --title "OTTO" --infobox "\nWriting EXIF metadata..." 5 28
cd "$TARGET"
# Obtain and write copyright camera model, lens, and note
for file in *.*; do
    date=$(exiftool -DateTimeOriginal -d %Y-%m-%d "$file" | cut -d":" -f2 | tr -d " ")
    wf=$date".txt"
    if [ ! -z "$text" ]; then
        note="$text"
    elif [ ! -z "$REMOTE_SERVER" ]; then
        if [ ! -f "$HOME/$wf" ]; then
            sshpass -p "$PASSWORD" rsync -ave ssh "$USER@$REMOTE_SERVER:$REMOTE_PATH/$wf" "$HOME" >>"/tmp/otto.log" 2>&1
        fi
        if [ -f "$HOME/$wf" ]; then
            note=$(<"$HOME/$wf")
        fi
    else
        note=""
    fi
    camera=$(exiftool -Model "$file" | cut -d":" -f2 | tr -d " ")
    lens=$(exiftool -LensID "$file" | cut -d":" -f2)
    if [ -z "$lens" ]; then
        lens=$(exiftool -LensModel "$file" | cut -d":" -f2)
    fi
    exiftool -overwrite_original -copyright="$copyright" -comment="$camera $lens $note" -sep ", " -keywords="$keywords" "$file" >>"/tmp/otto.log" 2>&1
done

# Geotag files
if [ ! -z "$location" ]; then
    # Check whether the Photon service is reachable
    check=$(wget -q --spider https://photon.komoot.io/)
    if [ ! -z "$check" ]; then
        clear
        dialog --clear --title "Error" --backtitle "OTTO" --msgbox "\nPhoton is not reachable. Geotagging skipped." 7 48
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
        clear
        dialog --title "OTTO" --infobox "\nGeotagging..." 5 17
        exiftool -overwrite_original -GPSLatitude=$lat -GPSLatitudeRef=$latref -GPSLongitude=$lon -GPSLongitudeRef=$lonref . >>"/tmp/otto.log" 2>&1
    fi
fi

if [ ! -z "$gpx" ]; then
    # Count GPX files in the specified directory
    cd "$gpx"
    fcount=$(ls -1 | wc -l)
    # Check for GPX files and GPSBabel
    if [ "$fcount" -eq "0" ]; then
        clear
        dialog --clear --title "Error" --backtitle "OTTO" --msgbox "\nNo GPX files are found." 7 27
        exit 1
    fi
    # Geocorrelate with a single GPX file
    if [ "$fcount" -eq "1" ]; then
        clear
        dialog --title "OTTO" --infobox "\nGeocorrelating..." 5 21
        fgpx=$(ls "$gpx")
        exiftool -overwrite_original -geotag "$fgpx" -geosync=180 . >>"/tmp/otto.log" 2>&1
    fi
    if [ "$fcount" -gt "1" ]; then
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

if [ ! -z "$process" ]; then
    clear
    dialog --title "OTTO" --infobox "\nProcessing files..." 5 23
    shopt -s nocaseglob
    for file in *.jpg; do
        filename=${file%.*}
        convert "$file" "$process" -hald-clut "$filename-0.jpeg"
        mogrify -sharpen 0x2 "$filename-0.jpeg"
    done
fi

clear
dialog --title "OTTO" --infobox "\nOrganizing files..." 5 23
exiftool '-Directory<CreateDate' -d ./%Y-%m-%d . >>"/tmp/otto.log" 2>&1
cd
clear
notify
