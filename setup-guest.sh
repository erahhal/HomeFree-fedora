#!/usr/bin/env bash

PLATFORM=$(sudo dmidecode -s system-manufacturer)

if [ $PLATFORM == "QEMU" ]; then

echo "tmpfs     /tmp     tmpfs     defaults,size=10G,mode=1777     0     0" | sudo tee -a /etc/fstab
mount -o remount,size=10G /tmp

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk /dev/sda
  n # new partition
    # default - should be 4
    # default
    # default
  t # change type
  4 # partition 4
  44 # LVM
  w # write the partition table
  q # and we're done
EOF

sudo pvcreate --devicesfile="" /dev/sda4
sudo vgextend --devicesfile="" sysvg /dev/sda4
sudo lvextend --devicesfile="" -l +100%FREE /dev/mapper/sysvg-root
sudo xfs_growfs /dev/mapper/sysvg-root

fi

sudo dnf install -y vim git make qemu-img qemu-kvm

## This doesn't work without disabling selinux:
# sh <(curl -L https://nixos.org/nix/install) --daemon

## From: https://nix-community.github.io/nix-installers/
echo "Installing Nix from URL, may take a moment..."
RPM_URL=https://nix-community.github.io/nix-installers/x86_64/nix-multi-user-2.17.1.rpm
sudo rpm -i $RPM_URL

git clone https://github.com/erahhal/HomeFree.git
