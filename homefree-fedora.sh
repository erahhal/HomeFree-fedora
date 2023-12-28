#!/usr/bin/env bash

# FEDORA_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/images
# FEDORA_IMAGE=Fedora-Server-KVM-39-1.5.x86_64.qcow2

FEDORA_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images
FEDORA_IMAGE=Fedora-Cloud-Base-39-1.5.x86_64.qcow2

RECOMMENDED_IMAGE_SIZE=32

if [ ! -f "$FEDORA_IMAGE" ] || [ -f "${FEDORA_IMAGE}.st" ]; then
    axel --timeout=10 -n 8 $FEDORA_URL/$FEDORA_IMAGE
fi

if [ -f "${FEDORA_IMAGE}.st" ]; then
    echo "Download not finished. Please try again."
    exit 1
fi

if [ ! -f "meta-data" ]; then
cat > meta-data << EOF
instance-id: HomeFreeDev
local-hostname: homefree-dev
EOF
fi

if [ ! -f "user-data" ]; then
cat > user-data << EOF
#cloud-config
# Set the default user
system_info:
  default_user:
    name: homefree

# Unlock the default user
chpasswd:
  list: |
     homefree:password
  expire: False

# Other settings
resize_rootfs: True
ssh_pwauth: True
timezone: America/Los_Angeles

# Add any ssh public keys
ssh_authorized_keys:
 - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNvmGn1/uFnfgnv5qsec0GC04LeVB1Qy/G7WivvvUZVBBDzp8goe1DsE8M8iqnBSin56gQZDWsd50co2MbFAWuqH2HxY7OGay7P/V2q+SziTYFva85WGl84qWvYMmdB+alAFBT3L4eH5cegC5NhNp+OGsQuq32RdojgXXQt6vyZnaOypuz90k3rqV6Rt+iBTLz6VziasCLcYydwOvi9f1q6YQwGPLKaupDrV6gxvoX9bXLdopqwnXPSE/Eqczxgwc3PefvAJPSd6TOqIXvbtpv/B3Evt5SPe2gq+qASc5K0tzgra8KAe813kkpq4FuKJzHbT+EmO70wiJjru7zMEhd erahhal@nfml-erahhalQFL

bootcmd:
 - [ sh, -c, echo "=========bootcmd=========" ]

runcmd:
 - [ sh, -c, echo "=========runcmd=========" ]

# For pexpect to know when to log in and begin tests
final_message: "SYSTEM READY TO LOG IN"
EOF
fi

if [ ! -e "seed.iso" ]; then
    genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
fi

IMAGE_SIZE=$(qemu-img info $FEDORA_IMAGE | grep 'virtual size' | awk '{ print $3 }')
if [ "$IMAGE_SIZE" -lt "$RECOMMENDED_IMAGE_SIZE" ]; then
    while true
    do
        read -p "Disk image is smaller than recommended. Increase to ${RECOMMENDED_IMAGE_SIZE}GB? (y/n) " yn

        case $yn in
            [yY] ) echo Resizing image...;
                qemu-img resize $FEDORA_IMAGE +${RECOMMENDED_IMAGE_SIZE}G
                break
                ;;
            [nN] ) echo Not resizing...;
                break
                ;;
            * ) echo invalid response;
                ;;
        esac
    done
fi

# Must run as root to allow guest to write to host share
sudo -E virtiofsd --socket-path /tmp/vhostqemu --shared-dir ./ --cache auto &
pids[1]=$!
sudo -E qemu-system-x86_64 \
    -nographic \
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
    -cdrom seed.iso \
    -net nic \
    -net user,hostfwd=tcp::2223-:22,hostfwd=tcp::8445-:443,hostfwd=tcp::8885-:80 \
    &
pids[2]=$!

# Wait for machine to be up, then run install script
ssh-keygen -R "[localhost]:2223"
ssh -p 2223 -o StrictHostKeyChecking=no homefree@localhost 'bash -s' < ./setup-guest.sh 2> /dev/null
while test $? -gt 0
do
    sleep 5
    ssh -p 2223 -o StrictHostKeyChecking=no homefree@localhost 'bash -s' < ./setup-guest.sh 2> /dev/null
done

echo "Setup complete!"

for pid in ${pids[*]}; do
    wait $pid
done

# host_share /home/homefree/host_share virtiofs nofail 0 2
