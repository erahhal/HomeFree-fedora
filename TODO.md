TODO
====

* Look into image builder
  * https://www.redhat.com/sysadmin/linux-golden-homelab-rhel
* Automate Installation
  * 2. Time Settings
    * 1. Change timezone
      * 2. America
        * Enter
        * 94. Los Angeles
      * c. Continue
  * 5. User creation
    * 1. Create user
      * 3. User name
        * homefree
      * 5. Password
        * <password>
        * <password> confirm
        * "yes" if password is considered week
        * c. Continue
      * c. Continue
* Setup host mount
  * mkdir -p /home/homefree/host
  * # Can't add "user" flag here, as it implies noexec - can't directly run anything in mount
  * echo "host_share /home/homefree/host virtiofs defaults,nofail,auto 0 2" | sudo tee -a /etc/fstab
  * systemctl daemon-reload
  * sudo mount -a
* Extend disk size
  * Resize qcow2 image first
    * qemu-img resize image-file.qcow2 +32G
  * See: https://www.redhat.com/sysadmin/resize-lvm-simple
  * sudo fdisk /dev/sda
    * n
    * <enter> (should be partition 4)
    * <enter>
    * <enter>
    * t
    * 4
    * 44 (should be LVM)
    * w
  * # sudo vgs should list volumes, but it doesn't work
  * # Need to use `sudo vgs --devicesfile=""` to see volume, which should be sysvg
  * sudo pvcreate --devicesfile="" /dev/sda4
  * sudo vgextend --devicesfile="" sysvg /dev/sda4
  * sudo lvextend --devicesfile="" -l +100%FREE /dev/mapper/sysvg-root
  * sudo xfs_growfs /dev/mapper/sysvg-root
