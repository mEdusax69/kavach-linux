#!/bin/bash
# Runs INSIDE the chroot
set -e
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
cat > /etc/apt/sources.list <<S
deb http://archive.ubuntu.com/ubuntu noble main universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main universe multiverse
S
echo "kavach" > /etc/hostname
echo "127.0.0.1 localhost kavach" > /etc/hosts
cat > /usr/sbin/policy-rc.d <<'P'
#!/bin/sh
exit 101
P
chmod +x /usr/sbin/policy-rc.d
apt-get update -q
apt-get install -y -q --no-install-recommends \
  linux-image-generic linux-modules-extra-$(ls /lib/modules 2>/dev/null | head -1 || true) 2>/dev/null || \
apt-get install -y -q --no-install-recommends linux-image-generic
apt-get install -y -q --no-install-recommends \
  casper initramfs-tools busybox-initramfs systemd-sysv sudo dbus udev \
  xserver-xorg-core xserver-xorg-input-libinput xserver-xorg-video-fbdev xserver-xorg-video-vesa x11-xserver-utils xinit \
  xfce4-session xfce4-panel xfce4-settings xfdesktop4 xfwm4 xfce4-terminal thunar xfce4-appfinder xfce4-notifyd \
  xfce4-whiskermenu-plugin xfce4-taskmanager xfce4-screenshooter mousepad ristretto xfce4-pulseaudio-plugin \
  lightdm lightdm-gtk-greeter policykit-1 policykit-1-gnome gvfs gvfs-backends thunar-volman \
  network-manager network-manager-gnome \
  arc-theme papirus-icon-theme fonts-dejavu-core fonts-noto-core fonts-hack \
  epiphany-browser ca-certificates \
  nmap tcpdump wireshark netcat-openbsd whois dnsutils iproute2 iputils-ping traceroute curl wget openssh-client \
  sleuthkit foremost binwalk testdisk gddrescue ghex hexedit xxd libimage-exiftool-perl john hydra aircrack-ng \
  gparted file git vim nano python3 python3-pip less htop tree unzip zip p7zip-full bash-completion \
  virtualbox-guest-x11 open-vm-tools-desktop spice-vdagent \
  locales console-setup keyboard-configuration
# live-session niceties
locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8 || true
# branding
cat > /etc/os-release <<OS
PRETTY_NAME="Kavach Linux 1.0 (Rakshak)"
NAME="Kavach Linux"
VERSION_ID="1.0"
VERSION="1.0 (Rakshak)"
ID=kavach
ID_LIKE="ubuntu debian"
UBUNTU_CODENAME=noble
HOME_URL="https://example.invalid/kavach"
OS
cp /etc/os-release /usr/lib/os-release 2>/dev/null || true
mkdir -p /usr/share/backgrounds/kavach
cp /tmp/wallpaper.png /usr/share/backgrounds/kavach/wallpaper.png
# lightdm greeter look
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<G
[greeter]
background=/usr/share/backgrounds/kavach/wallpaper.png
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
font-name=DejaVu Sans 11
G
# system-wide XFCE defaults (applied to every new user incl. the live user)
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<X
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="DejaVu Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Hack 10"/>
  </property>
</channel>
X
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<X
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
X
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<X
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual-1" type="empty"><property name="workspace0" type="empty">
        <property name="last-image" type="string" value="/usr/share/backgrounds/kavach/wallpaper.png"/>
        <property name="image-style" type="int" value="5"/></property></property>
      <property name="monitor0" type="empty"><property name="workspace0" type="empty">
        <property name="last-image" type="string" value="/usr/share/backgrounds/kavach/wallpaper.png"/>
        <property name="image-style" type="int" value="5"/></property></property>
      <property name="monitorVGA-1" type="empty"><property name="workspace0" type="empty">
        <property name="last-image" type="string" value="/usr/share/backgrounds/kavach/wallpaper.png"/>
        <property name="image-style" type="int" value="5"/></property></property>
      <property name="monitorVirtual1" type="empty"><property name="workspace0" type="empty">
        <property name="last-image" type="string" value="/usr/share/backgrounds/kavach/wallpaper.png"/>
        <property name="image-style" type="int" value="5"/></property></property>
    </property>
  </property>
</channel>
X
# welcome file on desktop
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/Welcome.txt <<W
Welcome to Kavach Linux 1.0 "Rakshak"
-------------------------------------
Live session user: kavach (no password; sudo works without a password)
Tools: Terminal -> nmap, wireshark, tcpdump, sleuthkit (fls, icat, mmls), foremost,
       binwalk, testdisk, ddrescue, exiftool, john, hydra, aircrack-ng, ghex, gparted
Quick forensic helper:  kavach help
Use these tools only on systems you own or have written permission to test.
W
# the kavach helper (graphical-system version)
cat > /usr/local/bin/kavach <<'K'
#!/bin/sh
case "$1" in
 info)    . /etc/os-release; echo "$PRETTY_NAME"; uname -r; uptime; free -h | sed -n 1,2p ;;
 hash)    [ -f "$2" ] || { echo "usage: kavach hash <file>"; exit 1; }
          md5sum "$2"; sha1sum "$2"; sha256sum "$2" ;;
 disks)   lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,RO ;;
 image)   [ -n "$2" ] && [ -n "$3" ] || { echo "usage: kavach image <src-device> <dest-file>"; exit 1; }
          sudo ddrescue -n "$2" "$3" "$3.map" && sha256sum "$3" | tee "$3.sha256" ;;
 mountro) [ -n "$2" ] || { echo "usage: kavach mountro <device> [mountpoint]"; exit 1; }
          mp=${3:-/mnt/evidence}; sudo mkdir -p "$mp"; sudo mount -o ro,noexec,nosuid,nodev "$2" "$mp" && echo "Mounted $2 read-only at $mp" ;;
 net)     ip addr show; ip route ;;
 *)       cat <<H
kavach - helper tools
  kavach info | hash <file> | disks | image <src> <dst> | mountro <dev> [dir] | net
H
 ;;
esac
K
chmod +x /usr/local/bin/kavach
# live user + hostname are set by casper via boot params; make sure sudo is passwordless for sudo group
echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kavach-live
chmod 440 /etc/sudoers.d/kavach-live
systemctl enable NetworkManager lightdm >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null 2>&1 || true
# initramfs: include everything needed to find the ISO
cat > /etc/initramfs-tools/conf.d/kavach <<C
MODULES=most
COMPRESS=zstd
C
update-initramfs -u -k all
# cleanup
rm -f /usr/sbin/policy-rc.d
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/cache/debconf/*-old /usr/share/doc/* /usr/share/man/* /usr/share/info/*
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
truncate -s 0 /etc/machine-id
echo "CHROOT SETUP DONE"
