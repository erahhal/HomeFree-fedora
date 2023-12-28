#!/usr/bin/env bash

PLATFORM=$(sudo dmidecode -s system-manufacturer)

if [ $PLATFORM == "QEMU" ]; then

    sudo dnf install -y git bc

    # Setup host share mount
    if ! grep -q "/home/homefree/host" /etc/fstab; then
        mkdir -p /home/homefree/host
        echo "host_share /home/homefree/host virtiofs defaults,nofail,auto 0 2" | sudo tee -a /etc/fstab
        sudo systemctl daemon-reload
        sudo mount -a
    fi

    TMP_MOUNT_SIZE=$(df -h | grep "/tmp" | awk '{ print $2 }')
    TMP_MOUNT_SIZE=${TMP_MOUNT_SIZE::-1}

    RECOMMENDED_TMP_SIZE=12

    if [ $(echo "$TMP_MOUNT_SIZE < $RECOMMENDED_TMP_SIZE" | bc) -ne 0 ]; then
        # while true
        # do
        #     read -p "/tmp is too small. Increase to ${RECOMMENDED_TMP_SIZE}GB? (y/n) " yn
        #
        #     case $yn in
        #         [yY] ) echo Resizing tmp...;
        #             if grep -q "/tmp" /etc/fstab; then
        #                 sudo sed -i '\|/tmp|d' /etc/fstab
        #             fi
        #             echo "tmpfs     /tmp     tmpfs     defaults,size=${RECOMMENDED_TMP_SIZE}G,mode=1777     0     0" | sudo tee -a /etc/fstab
        #             sudo systemctl daemon-reload
        #             sudo mount -o remount,size=${RECOMMENDED_TMP_SIZE}G /tmp
        #             break
        #             ;;
        #         [nN] ) echo Not resizing...;
        #             break
        #             ;;
        #         * ) echo invalid response;
        #             ;;
        #     esac
        # done

        # Update automatically
        if grep -q "/tmp" /etc/fstab; then
            sudo sed -i '\|/tmp|d' /etc/fstab
        fi
        echo "tmpfs     /tmp     tmpfs     defaults,size=${RECOMMENDED_TMP_SIZE}G,mode=1777     0     0" | sudo tee -a /etc/fstab
    fi

    # Check unallocated disk space
    UNALLOCATED=$(sudo parted --script /dev/sda unit GB print free 2> /dev/null | grep 'Free Space' | tail -n1 | awk '{print $3}')
    UNALLOCATED=${UNALLOCATED::-2}

    # UNALLOCATED is floating point
    if [ $(echo "$UNALLOCATED > 0" | bc) -ne 0 ] ; then
        LAST_PARTITION_NUM=$(grep -c 'sda[0-9]' /proc/partitions)
        NEXT_PARTITION_NUM=$((LAST_PARTITION_NUM+1))

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<-_EOF_ | sudo fdisk /dev/sda
  n # new partition
    # default - next available partition number
    # default
    # default
  t # change type
  ${NEXT_PARTITION_NUM} # new partition number
  44 # LVM
  w # write the partition table
  q # and we're done
_EOF_

        sudo pvcreate --devicesfile="" /dev/sda${NEXT_PARTITION_NUM}
        sudo vgextend --devicesfile="" sysvg /dev/sda${NEXT_PARTITION_NUM}
        sudo lvextend --devicesfile="" -l +100%FREE /dev/mapper/sysvg-root
        sudo xfs_growfs /dev/mapper/sysvg-root
    fi

    if ! git ls-remote HomeFree -q; then
        git clone https://github.com/erahhal/HomeFree.git
    fi

    cd HomeFree
    ./setup.sh
fi
