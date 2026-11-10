#!/bin/bash
# Kavach Linux (desktop edition) - build steps, as performed manually to produce the ISO.
# Run as root on Ubuntu 24.04 with ~10 GB free disk and internet access.
# NOTE: this wrapper collects the commands I ran by hand; it has not been run end-to-end as one script.
set -euo pipefail
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools
W=${W:-$PWD/live}; R=$W/rootfs; HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p $W/iso/casper $W/iso/boot/grub

# 1. base system
debootstrap --variant=minbase --arch=amd64 --components=main,universe noble $R http://archive.ubuntu.com/ubuntu

# 2. configure inside chroot (kernel, XFCE, tools, theme, helper command)
cp $HERE/wallpaper.png $HERE/chroot-setup.sh $R/tmp/ ; cp /etc/resolv.conf $R/etc/resolv.conf
mount --bind /dev $R/dev; mount -t devpts devpts $R/dev/pts; mount -t proc proc $R/proc; mount -t sysfs sys $R/sys
chroot $R /bin/bash /tmp/chroot-setup.sh

# 3. autologin + greeter tweaks (+ let NetworkManager manage ethernet)
touch $R/etc/NetworkManager/conf.d/10-globally-managed-devices.conf
mkdir -p $R/etc/lightdm/lightdm.conf.d
printf '[Seat:*]\nautologin-user=kavach\nautologin-user-timeout=0\nuser-session=xfce\ngreeter-session=lightdm-gtk-greeter\n' > $R/etc/lightdm/lightdm.conf.d/50-kavach.conf
sed -i '/^\[greeter\]/a indicators=~host;~spacer;~clock;~session;~power' $R/etc/lightdm/lightdm-gtk-greeter.conf

# 4. the final initramfs step in chroot-setup.sh did not produce a file for me, so generate it explicitly
KVER=$(ls $R/lib/modules | head -1)
chroot $R /bin/bash -c "LC_ALL=C update-initramfs -c -k $KVER"
cp $R/boot/vmlinuz-$KVER $W/iso/casper/vmlinuz; cp $R/boot/initrd.img-$KVER $W/iso/casper/initrd; chmod 644 $W/iso/casper/*
umount $R/dev/pts $R/dev $R/sys $R/proc

# 5. compress, add bootloader config, build hybrid BIOS+UEFI ISO
mksquashfs $R $W/iso/casper/filesystem.squashfs -comp zstd -Xcompression-level 10 -b 256K -noappend -e boot/initrd.img-$KVER boot/initrd.img.old
cp $HERE/grub.cfg $W/iso/boot/grub/grub.cfg
grub-mkrescue -o $W/kavach-linux-desktop-1.0.iso $W/iso -- -volid KAVACH_DESKTOP
sha256sum $W/kavach-linux-desktop-1.0.iso

