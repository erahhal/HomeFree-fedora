#!/usr/bin/env bash

virsh destroy --graceful homefree-fedora
virsh undefine homefree-fedora
virsh pool-destroy homefree-fedora
rm -rf ~/.local/share/images/homefree-fedora.qcow2
