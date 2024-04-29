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

# Author: Dmitri Popov, dmpop@cameracode.coffee
# Source code: https://github.com/dmpop/otto

if [ ! -x "$(command -v apt)" ]; then
        echo "Looks like it's not an Ubuntu- or Debian-based system."
        exit 1
fi

if [[ $EUID -eq 0 ]]; then
        echo "Run the script as a regular user"
        exit 1
fi

sudo apt update
sudo apt upgrade -y

cd
sudo apt update
sudo apt upgrade
sudo apt install git dialog bc jq curl exiftool exiv2 rsync wget gpsbabel exfat-fuse exfat-utils
git clone https://github.com/dmpop/otto.git
chmod +x otto/*.sh
mkdir -p $HOME/storage
mkdir -p $HOME/bin
echo "PATH=$HOME/bin:$PATH" >> ~/.bashrc
ln -s $HOME/otto/otto.sh $HOME/bin/otto