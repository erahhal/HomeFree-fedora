#!/usr/bin/env bash

FEDORA_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso
FEDORA_IMAGE=Fedora-Workstation-Live-x86_64-39-1.5.iso

if [ ! -f "$FEDORA_IMAGE" ] || [ -f "${FEDORA_IMAGE}.st" ]; then
  axel -n 8 $FEDORA_URL/$FEDORA_IMAGE
fi

virt-install \
--name homefree-fedora \
--memory 8192 \
--boot uefi \
--vcpus 4 \
--location $FEDORA_IMAGE \
--disk size=32 \
--network bridge=virbr0 \
--graphics none \
--os-variant fedora37 \
--extra-args "console=tty0 console=ttyS0,115200n8"
# --initrd-inject fedora39-kvm.ks \
# --extra-args "inst.ks=file:/fedora39-kvm.ks console=tty0 console=ttyS0,115200n8"
