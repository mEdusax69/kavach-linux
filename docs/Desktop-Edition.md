# Kavach Linux 1.0 "Rakshak" — Desktop Edition

A graphical live Linux distribution with an XFCE desktop and a set of security and forensics tools, in the spirit of Kali-style distros. It runs entirely from the ISO (nothing is installed to disk) and is built from Ubuntu 24.04 packages with my own branding and theme. It is **not** Kali and does not include Kali's tool collection.

| Item | Value |
|---|---|
| ISO | `kavach-linux-desktop-1.0.iso` (~1.4 GB) |
| SHA-256 | `a7b62221b5ab51ee57fed126914097d02bc56f8014172e52a7d2bb9918d45590` |
| Architecture | x86_64 |
| Base | Ubuntu 24.04 LTS ("noble") packages |
| Kernel | Linux 6.8.0-146-generic |
| Desktop | XFCE 4 with LightDM, Arc-Dark theme, Papirus-Dark icons |
| Live-boot system | casper (squashfs, zstd-compressed) |
| Bootloader | GRUB 2, built as a hybrid BIOS + UEFI ISO |
| Persistence | None. Changes are lost on reboot |
| Live user | `kavach`, no password, passwordless `sudo` |

The smaller command-line edition (`kavach-linux-1.0.iso`, 29 MB) is a separate project; see `Kavach-Linux-Documentation.md`.

---

## 1. Running it in VirtualBox

1. **New** → Type: *Linux*, Version: *Ubuntu (64-bit)*.
2. **Memory: 2048 MB or more** (it needs RAM because the whole live system is unpacked into memory; 1024 MB is the practical minimum).
3. Processors: 2 or more if you can. Skip creating a virtual hard disk.
4. Settings → **Display**: Graphics Controller *VMSVGA*, Video Memory *128 MB*.
5. Settings → **Storage**: attach `kavach-linux-desktop-1.0.iso` to the optical drive.
6. Settings → **Network**: *NAT* is fine.
7. Leave "Enable EFI" **off** for the first attempt.
8. Start the VM, choose the first GRUB entry (or wait 8 seconds). It logs in automatically and shows the desktop.

If the screen is black or garbled, reboot and choose **"safe graphics: nomodeset"** in the GRUB menu.

**QEMU:**
```bash
qemu-system-x86_64 -m 2048 -cdrom kavach-linux-desktop-1.0.iso -boot d -vga std -enable-kvm
```
(drop `-enable-kvm` if your machine has no KVM).

**USB stick (real hardware):** this erases the target device, so check the name with `lsblk` first.
```bash
sudo dd if=kavach-linux-desktop-1.0.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
Windows: Rufus in *DD Image mode*, or balenaEtcher.

### Boot menu entries
| Entry | Use |
|---|---|
| Live | normal boot |
| Live (safe graphics: nomodeset) | if the display fails with the normal entry |
| Live (verbose boot messages) | for troubleshooting |

**Boot time:** with hardware acceleration it should be fast. In my emulated test (no acceleration) it took roughly 7–8 minutes to reach the desktop, so be patient if you run it without KVM or virtualisation enabled in your BIOS.

---

## 2. What's on the desktop

- **Panel / dock:** Applications menu (Whisker menu), terminal, file manager (Thunar), web browser (Epiphany), application finder.
- **Desktop icons:** File System, Home, Trash, `Welcome.txt`.
- **Tray:** network (NetworkManager), volume, clock, current user.
- **Look:** dark Arc theme, custom Kavach shield wallpaper and login screen.
- **VM integration:** VirtualBox guest additions, open-vm-tools and SPICE agent are installed, which should give automatic screen resizing and clipboard sharing. I did not test these.

### Installed tools
| Category | Tools |
|---|---|
| Network | nmap, tcpdump, Wireshark, netcat, traceroute, whois, dig (dnsutils), curl, wget, ssh client |
| Forensics | Sleuth Kit (`fls`, `icat`, `mmls`, …), foremost, binwalk, TestDisk, GNU ddrescue, exiftool |
| Hex / disks | GHex, hexedit, xxd, GParted |
| Password / audit | John the Ripper, Hydra, aircrack-ng |
| General | Python 3 + pip, git, vim, nano, htop, 7-Zip, zip/unzip, tree |

Wireshark needs elevated rights to capture: start it with `sudo wireshark`.

### The `kavach` helper command
```
kavach info                  system information
kavach hash <file>           MD5 / SHA-1 / SHA-256
kavach disks                 list block devices (lsblk)
kavach image <src> <dst>     ddrescue copy of a device to a file + SHA-256
kavach mountro <dev> [dir]   mount read-only (ro,noexec,nosuid,nodev), default /mnt/evidence
kavach net                   addresses and routes
```
Note: Linux can still auto-mount drives you attach in the desktop file manager. For evidence handling, attach disks read-only at the hypervisor level and use `kavach mountro`. This ISO has **no hardware write-blocking**.

---

## 3. How it works

```
BIOS/UEFI → GRUB → /casper/vmlinuz + /casper/initrd
                         │ casper finds the ISO, mounts /casper/filesystem.squashfs
                         ▼
        read-only squashfs + RAM overlay = the live root filesystem
                         │ creates user "kavach", hostname "kavach"
                         ▼
      systemd → NetworkManager + LightDM (autologin) → XFCE session
```

ISO contents: `/casper/vmlinuz`, `/casper/initrd` (66 MB), `/casper/filesystem.squashfs` (~1.25 GB, zstd), `/boot/grub/grub.cfg`, plus GRUB's BIOS/EFI images.

### Customisation points (inside the root filesystem)
| What | Where |
|---|---|
| Branding | `/etc/os-release`, wallpaper `/usr/share/backgrounds/kavach/wallpaper.png` |
| Login screen | `/etc/lightdm/lightdm-gtk-greeter.conf` |
| Autologin | `/etc/lightdm/lightdm.conf.d/50-kavach.conf` |
| Default desktop theme for new users | `/etc/skel/.config/xfce4/xfconf/…` |
| Helper command | `/usr/local/bin/kavach` |
| Wired networking | empty `/etc/NetworkManager/conf.d/10-globally-managed-devices.conf` (overrides Ubuntu's default, which leaves Ethernet unmanaged) |

---

## 4. Rebuilding it

Files are in `desktop-build/`: `build-desktop.sh`, `chroot-setup.sh` (package list, theming, helper command), `grub.cfg`, `wallpaper.png`.

Requirements: root on Ubuntu 24.04, about 10 GB free disk, internet access, 1–2 hours depending on speed.
```bash
sudo ./desktop-build/build-desktop.sh
```
**Honest caveat:** I produced the ISO by running these steps by hand and fixing problems as they appeared. `build-desktop.sh` collects those steps into one file, but I have not run it start-to-finish as a single script, so expect to fix small things if it errors. To add a tool, add its package name to the `apt-get install` list in `chroot-setup.sh`.

---

## 5. What was tested

Tested in QEMU (BIOS mode, 2 GB RAM, emulated, no KVM):
- GRUB menu loads, kernel and live system boot
- Live user is created and **autologin goes straight to the XFCE desktop**
- Branded wallpaper, panel, dock and desktop icons appear
- The network icon shows a connected state after boot. (I checked the tray icon; I did not run ping or open a web page.)

**Not tested:** VirtualBox and VMware themselves, UEFI boot, real hardware, USB boot, auto screen-resize, clipboard sharing, sound, every individual security tool, and the `kavach` helper commands on this desktop edition. The Floppy Disk icon on the desktop is a harmless cosmetic leftover.

## 6. Limitations

- Live only: no installer, nothing saved between boots.
- Needs about 2 GB of RAM.
- Epiphany is the only browser; Firefox and Chromium are snap-only on Ubuntu, so I left them out.
- Passwordless login and sudo are meant for a throwaway lab session; do not expose this system to untrusted networks.
- Wi-Fi tools (aircrack-ng) need a compatible USB Wi-Fi adapter passed through to the VM; this was not tested.
- Security tools are for **systems you own or have written permission to test**.

## 7. Licensing
A collection of open-source packages from Ubuntu (Linux kernel, XFCE, GRUB, Wireshark, nmap and others), each under its own license (mostly GPL-family). Redistributing the ISO means complying with those licenses, including making source available. Some packages (for example nmap, John the Ripper) have additional license terms; check them if you plan to redistribute commercially.
