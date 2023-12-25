#!/usr/bin/env bash

FEDORA_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/images
FEDORA_IMAGE=Fedora-Server-KVM-39-1.5.x86_64.qcow2

if [ ! -f "$FEDORA_IMAGE" ] || [ -f "${FEDORA_IMAGE}.st" ]; then
  axel -n 8 $FEDORA_URL/$FEDORA_IMAGE
  qemu-img resize $FEDORA_IMAGE +32G
fi

# Must run as root to allow guest to write to host share
sudo -E virtiofsd --socket-path /tmp/vhostqemu --shared-dir ./ --cache auto &
pids[1]=$!
    # -netdev tap,id=enp1s0,br=hfbr0,helper=$(which qemu-bridge-helper) \
    # -device e1000,netdev=enp1s0,mac=52:53:54:55:56:01 \
sudo -E qemu-kvm \
    -enable-kvm \
    -nographic \
    -chardev socket,id=char0,path=/tmp/vhostqemu \
    -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=host_share \
    -smp 4 \
    -m 16G \
    -object memory-backend-file,id=mem,size=16G,mem-path=/dev/shm,share=on \
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
