#!/usr/bin/env bash

FEDORA_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/images
FEDORA_IMAGE=Fedora-Server-KVM-39-1.5.x86_64.qcow2
RECOMMENDED_IMAGE_SIZE=32

if [ ! -f "$FEDORA_IMAGE" ] || [ -f "${FEDORA_IMAGE}.st" ]; then
  axel -n 8 $FEDORA_URL/$FEDORA_IMAGE
fi

IMAGE_SIZE=$(qemu-img info $FEDORA_IMAGE | grep 'virtual size' | awk '{ print $3 }')
if [ "$IMAGE_SIZE" -lt "$RECOMMENDED_IMAGE_SIZE" ]; then
    read -p "Disk image is smaller than recommended. Increase to ${RECOMMENDED_IMAGE_SIZE}GB? (y/n) " yn

    case $yn in
        [yY] ) echo Resizing image...;
            qemu-img resize $FEDORA_IMAGE +${RECOMMENDED_IMAGE_SIZE}G
            ;;
        [nN] ) echo Not resizing...;
            exit;;
        * ) echo invalid response;
            exit 1;;
    esac
fi

# Must run as root to allow guest to write to host share
sudo -E virtiofsd --socket-path /tmp/vhostqemu --shared-dir ./ --cache auto &
pids[1]=$!
sudo -E qemu-system-x86_64 \
    -cpu host \
    -enable-kvm \
    -monitor telnet::45454,server,nowait \
    -chardev socket,id=char0,path=/tmp/vhostqemu \
    -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=host_share \
    -smp 4 \
    -m 12G \
    -object memory-backend-file,id=mem,size=12G,mem-path=/dev/shm,share=on \
    -numa node,memdev=mem \
    -hda $FEDORA_IMAGE \
    -net nic \
    -net user,hostfwd=tcp::2223-:22,hostfwd=tcp::8445-:443,hostfwd=tcp::8885-:80 \
    &
pids[2]=$!
for pid in ${pids[*]}; do
    wait $pid
done

# host_share /home/homefree/host_share virtiofs nofail 0 2
