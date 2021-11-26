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

cd

if [ ! -d "$HOME/bin" ]; then
        mkdir $HOME/bin
        echo 'export PATH='$HOME'/bin:$PATH' >>.bashrc
fi

sudo mkdir -p /etc/systemd/system/systemd-udevd.service.d
sudo sh -c "echo '[Service]' > /etc/systemd/system/systemd-udevd.service.d/00-privatemounts-no.conf"
sudo sh -c "echo 'PrivateMounts=no' >> /etc/systemd/system/systemd-udevd.service.d/00-privatemounts-no.conf"
sudo systemctl daemon-reexec
sudo service systemd-udevd restart

sudo apt update
sudo apt upgrade
sudo apt install git bc jq curl exiftool git gpsbabel screen usbmount
git clone https://github.com/dmpop/otto.git
cd otto
cp otto.sh $HOME/bin/otto
chmod +x $HOME/bin/otto
cd
echo "All done. The system will reboot now."
sudo reboot