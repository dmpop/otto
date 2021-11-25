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

if [ -x "$(command -v apt)" ]; then
        echo "Looks like it's not an Ubuntu- or Debian-based system."
        exit 1
fi

if [[ $EUID -eq 0 ]]; then
   echo "Run the script as a regular user"
   exit 1
fi

sudo apt install git getopt bc jq curl perl-image-exiftool git gpsbabel
git clone https://github.com/dmpop/otto.git
cd otto
cp otto.sh $HOME/bin/otto
chmod +x $HOME/bin/otto