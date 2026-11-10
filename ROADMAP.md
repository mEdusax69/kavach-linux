# Roadmap

Priorities, in order. Checked items are done.

## Now — make the existing release solid
- [x] CLI edition: BusyBox live ISO, tested in QEMU
- [x] Desktop edition: XFCE live ISO with autologin and wired networking, tested in QEMU
- [ ] **Fix normal-graphics boot in VirtualBox** (currently needs the "nomodeset" entry; capture the exact error, check initramfs/casper media detection and VBox graphics controller)
- [ ] **Run `desktop/build-desktop.sh` end to end** on a clean Ubuntu 24.04 VM and fix what breaks
- [ ] Test the desktop `kavach` commands and the main tools (nmap, Wireshark, Sleuth Kit, foremost, ddrescue)
- [ ] Add a real screenshot to the README

## Next — make it genuinely forensic-friendly
- [ ] **Forensic boot mode:** block auto-mounting of disks, set attached block devices read-only (`blockdev --setro`), disable swap on host disks
- [ ] **Original tool:** `kavach-log` — an evidence logger that records hashes, timestamps, tool versions and chain-of-custody notes into a report (Markdown/JSON)
- [ ] Add more forensics tooling (e.g. bulk_extractor, autopsy dependencies, volatility3 via pip) once size is under control
- [ ] Desktop menu entries and a short "first steps" guide on the desktop

## Size and distribution
- [ ] Shrink the desktop ISO (drop unneeded firmware, xz compression) so it downloads as one file
- [ ] Publish ISOs via GitHub Releases with checksums; consider GPG-signing the checksum file
- [ ] GitHub Actions workflow that builds the ISO and publishes the artifact

## Later
- [ ] Optional persistence (casper `persistent` partition) or an installer
- [ ] Secure Boot support
- [ ] Real-hardware and USB testing, VMware testing
- [ ] Wi-Fi tools documentation and tested USB adapters
