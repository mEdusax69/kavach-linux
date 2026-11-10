#!/bin/bash
# Kavach Linux build script - assembles kernel + busybox rootfs into a bootable hybrid ISO
set -euo pipefail
KVER=6.8.0-146-generic
SRC=/home/claude/build/kdl/ex
W=/home/claude/build/work
OUT=/mnt/user-data/outputs
rm -rf $W && mkdir -p $W/rootfs $W/iso/boot/grub
R=$W/rootfs

# 1. directory skeleton
mkdir -p $R/{bin,sbin,etc/init.d,proc,sys,dev,run,tmp,root,home/kavach,var/log,mnt,usr/bin,usr/sbin,usr/share/udhcpc,usr/share/kavach,lib/modules/$KVER}
chmod 1777 $R/tmp

# 2. busybox + applet symlinks
cp /usr/bin/busybox $R/bin/busybox
for a in $($R/bin/busybox --list); do
  [ -e $R/bin/$a ] || ln -s busybox $R/bin/$a
done
ln -sf ../bin/busybox $R/sbin/init
ln -sf bin/busybox $R/init.link 2>/dev/null; rm -f $R/init.link

# 3. kernel modules (curated, decompressed)
MODS="xhci_pci xhci_hcd ehci_pci ehci_hcd uhci_hcd ohci_pci ohci_hcd usbhid hid_generic usb_storage uas
 ahci libahci ata_piix ata_generic sd_mod sr_mod cdrom nvme virtio_pci virtio_blk virtio_net virtio_scsi
 e1000 e1000e r8169 igb 8139too bochs drm_vram_helper vmwgfx virtio_gpu vfat fat ntfs3 exfat ext4 isofs
 squashfs loop dm_mod mmc_block sdhci_pci i8042 atkbd psmouse"
: > $W/modlist
for m in $MODS; do
  modprobe -d $SRC -S $KVER --show-depends $m 2>/dev/null | awk '/^insmod/{print $2}' >> $W/modlist || true
done
sort -u $W/modlist | while read f; do
  rel=${f#$SRC/lib/modules/$KVER/}
  mkdir -p $R/lib/modules/$KVER/$(dirname $rel)
  out=$R/lib/modules/$KVER/${rel%.zst}
  case $f in *.zst) zstd -dq -c $f > $out;; *) cp $f $out;; esac
done
cp $SRC/lib/modules/$KVER/modules.{builtin,builtin.modinfo,order} $R/lib/modules/$KVER/ 2>/dev/null || true
depmod -b $R $KVER
echo "modules: $(find $R/lib/modules -name '*.ko' | wc -l)"

# 4. config files
cat > $R/etc/os-release <<OS
NAME="Kavach Linux"
PRETTY_NAME="Kavach Linux 1.0 (Rakshak)"
ID=kavach
VERSION="1.0"
VERSION_ID="1.0"
HOME_URL="https://example.invalid/kavach"
OS
echo "kavach" > $R/etc/hostname
cat > $R/etc/passwd <<P
root::0:0:root:/root:/bin/sh
kavach::1000:1000:Kavach User:/home/kavach:/bin/sh
P
cat > $R/etc/group <<G
root:x:0:
kavach:x:1000:
G
echo "/bin/sh" > $R/etc/shells
cat > $R/etc/profile <<'P'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
export HOME=${HOME:-/root}
alias ll='ls -lah'
alias ..='cd ..'
[ -z "$KAVACH_MOTD" ] && { export KAVACH_MOTD=1; cat /etc/motd; }
P
cat > $R/etc/motd <<'M'

  _  __                     _        _     _
 | |/ /__ ___   ____ _  ___| |__    | |   (_)_ __  _   ___  __
 | ' // _` \ \ / / _` |/ __| '_ \   | |   | | '_ \| | | \ \/ /
 | . \ (_| |\ V / (_| | (__| | | |  | |___| | | | | |_| |>  <
 |_|\_\__,_| \_/ \__,_|\___|_| |_|  |_____|_|_| |_|\__,_/_/\_\

  Kavach Linux 1.0 "Rakshak" - a minimal live distro
  Type 'kavach help' for built-in tools.  Login: root or kavach (no password)

M
cat > $R/etc/inittab <<'I'
::sysinit:/etc/init.d/rcS
tty1::respawn:/bin/getty -n -l /bin/login 0 tty1 linux
tty2::respawn:/bin/getty -n -l /bin/login 0 tty2 linux
tty3::respawn:/bin/getty -n -l /bin/login 0 tty3 linux
ttyS0::respawn:/bin/getty -n -l /bin/login 115200 ttyS0 vt100
::ctrlaltdel:/bin/reboot
::shutdown:/bin/umount -a -r
I
cat > $R/etc/init.d/rcS <<'S'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev 2>/dev/null || mount -t tmpfs dev /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /run
hostname -F /etc/hostname
echo "[kavach] loading hardware drivers..."
find /sys -name modalias -type f 2>/dev/null | xargs cat 2>/dev/null | sort -u | xargs modprobe -a -q 2>/dev/null
sleep 1
mdev -s 2>/dev/null
echo "[kavach] bringing up networking..."
ip link set lo up
for i in $(ls /sys/class/net 2>/dev/null | grep -v '^lo$'); do
  ip link set "$i" up
  udhcpc -i "$i" -n -q -t 3 -s /usr/share/udhcpc/default.script >/dev/null 2>&1 &
done
echo "[kavach] ready."
S
chmod +x $R/etc/init.d/rcS
cat > $R/usr/share/udhcpc/default.script <<'D'
#!/bin/sh
case "$1" in
 bound|renew)
  ip addr flush dev $interface 2>/dev/null
  ip addr add $ip/${mask:-24} dev $interface
  [ -n "$router" ] && ip route add default via ${router%% *} dev $interface
  : > /etc/resolv.conf
  for d in $dns; do echo "nameserver $d" >> /etc/resolv.conf; done ;;
esac
D
chmod +x $R/usr/share/udhcpc/default.script

# 5. the 'kavach' helper tool
cat > $R/usr/bin/kavach <<'K'
#!/bin/sh
case "$1" in
 info)    . /etc/os-release; echo "$PRETTY_NAME"; uname -r; echo "Uptime: $(uptime)"; free -m | sed -n 1,2p ;;
 hash)    [ -f "$2" ] || { echo "usage: kavach hash <file>"; exit 1; }
          for h in md5sum sha1sum sha256sum; do $h "$2"; done ;;
 hexview) [ -e "$2" ] || { echo "usage: kavach hexview <file|device> [bytes]"; exit 1; }
          hexdump -C -n ${3:-256} "$2" ;;
 disks)   echo "== Block devices =="; cat /proc/partitions; echo; fdisk -l 2>/dev/null | grep -E '^Disk /' ;;
 image)   [ -n "$2" ] && [ -n "$3" ] || { echo "usage: kavach image <source-device> <dest-file>"; exit 1; }
          echo "Imaging $2 -> $3 (read-only source)"; dd if="$2" of="$3" bs=1M conv=noerror,sync 2>&1
          echo "Verifying hash..."; sha256sum "$3" ;;
 mountro) [ -n "$2" ] || { echo "usage: kavach mountro <device> [mountpoint]"; exit 1; }
          mp=${3:-/mnt}; mkdir -p "$mp"; mount -o ro,noexec,nosuid,nodev "$2" "$mp" && echo "Mounted $2 read-only at $mp" ;;
 net)     ip addr show; echo; ip route; echo; cat /etc/resolv.conf 2>/dev/null ;;
 strings) [ -f "$2" ] || { echo "usage: kavach strings <file>"; exit 1; }
          strings -n ${3:-8} "$2" ;;
 *)       cat <<H
kavach - built-in helper tools
  kavach info                 system information
  kavach hash <file>          MD5 / SHA-1 / SHA-256 of a file
  kavach hexview <f> [n]      hex dump first n bytes (default 256)
  kavach disks                list block devices
  kavach image <src> <dst>    forensic-style raw copy with SHA-256
  kavach mountro <dev> [dir]  mount a device read-only (ro,noexec,nosuid,nodev)
  kavach net                  show network state
  kavach strings <f> [min]    printable strings from a file
H
 ;;
esac
K
chmod +x $R/usr/bin/kavach
echo "Welcome to Kavach Linux." > $R/home/kavach/README.txt

# 6. pack initramfs
cp $R/sbin/init $R/init 2>/dev/null || true
rm -f $R/init; ln -s sbin/init $R/init
( cd $R && find . | cpio -o -H newc --quiet | gzip -9 ) > $W/iso/boot/initrd.img
cp $SRC/boot/vmlinuz-$KVER $W/iso/boot/vmlinuz

# 7. GRUB config + ISO
cat > $W/iso/boot/grub/grub.cfg <<'G'
set timeout=5
set default=0
menuentry "Kavach Linux 1.0 (Rakshak) - Live" {
    linux /boot/vmlinuz console=tty0 quiet loglevel=3 rdinit=/sbin/init
    initrd /boot/initrd.img
}
menuentry "Kavach Linux 1.0 - Live (verbose + serial console)" {
    linux /boot/vmlinuz console=tty0 console=ttyS0,115200 rdinit=/sbin/init
    initrd /boot/initrd.img
}
G
grub-mkrescue -o $W/kavach-linux-1.0.iso $W/iso -- -volid KAVACH_1_0 2>&1 | tail -3
mkdir -p $OUT
cp $W/kavach-linux-1.0.iso $OUT/
( cd $OUT && sha256sum kavach-linux-1.0.iso > kavach-linux-1.0.iso.sha256 )
ls -lh $OUT
