# ntfs-handler — Free NTFS for macOS

NTFS drives. On your Mac. Read and write. **Free.**

> Tired of paying $20–$50 for Paragon NTFS or Tuxera? This does the same thing. No license, no account, no catch.

---

## Install

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/WildBenji/ntfs-handler/main/install.sh)
```

The installer sets up Homebrew, ntfs-3g, and the `ntfs` command in one shot. macFUSE requires a manual approval step (it's a kernel extension — macOS requires user consent).

**Manual install:**

```sh
brew install ntfs-3g
# Install macFUSE from https://osxfuse.github.io/
# Then: System Settings → Privacy & Security → Allow → Reboot

git clone https://github.com/WildBenji/ntfs-handler.git
cd ntfs-handler && ./ntfs install
```

---

## Quick Start

```sh
ntfs list                     # see connected NTFS drives
ntfs mount                    # pick a drive to mount (interactive)
ntfs mount --all --visible    # mount everything, show in Finder
ntfs eject                    # safely unmount + spin down
sudo ntfs daemon install      # auto-mount every time you plug in a drive
```

---

## All Commands

### `ntfs list`
Shows all connected NTFS drives and their status.

```
  DISK           VOLUME                       SIZE       STATUS
  ────────────── ──────────────────────────── ────────── ──────────────
  disk2s1        MyExternalHDD                931.5 GB   read-write
  disk3s1        BackupDrive                  1.8 TB     macOS read-only
```

### `ntfs mount`

```sh
ntfs mount                    # interactive menu
ntfs mount --all              # mount all at once
ntfs mount --all --visible    # mount all, show in Finder sidebar
ntfs mount disk2s1            # skip the menu, mount directly
ntfs mount --readonly disk2s1 # read-only access
```

Drives mount at `/Volumes/<DriveName>`. Without `--visible` they're hidden from Finder — open them with **Go → Go to Folder** (`⌘⇧G`).

If the drive was grabbed by macOS as read-only when you plugged it in, `ntfs mount` releases it automatically.

### `ntfs unmount` / `ntfs eject`

```sh
ntfs unmount          # interactive
ntfs unmount disk2s1  # specific drive
ntfs eject            # unmount + spin down the physical disk (use this before unplugging)
ntfs eject disk2s1
```

### `ntfs status`
Shows what's currently mounted via ntfs-handler. Automatically cleans up stale records if a drive was unplugged without ejecting.

### `ntfs daemon`

Plug in a drive, it mounts itself. No commands needed.

```sh
sudo ntfs daemon install      # enable (survives reboots)
sudo ntfs daemon uninstall    # disable
ntfs daemon status            # check if running
sudo ntfs daemon logs         # live log stream
```

### `ntfs doctor`
Diagnoses your setup — checks ntfs-3g, macFUSE, SIP, the daemon, and connected volumes.

```sh
ntfs doctor
```

---

## Comparison

| | ntfs-handler | Paragon NTFS | Tuxera NTFS |
|---|:---:|:---:|:---:|
| Price | **Free** | ~$20 | ~$31 |
| Read/write | ✓ | ✓ | ✓ |
| Auto-mount on plug-in | ✓ | ✓ | ✓ |
| Finder integration | Optional | ✓ | ✓ |
| BitLocker | ✗ | ✓ | ✓ |
| Native kernel driver | ✗ | ✓ | ✓ |
| Open source | ✓ | ✗ | ✗ |
| Telemetry | None | Unknown | Unknown |

---

## Troubleshooting

**Drive not showing up**
Run `ntfs doctor`. Most likely macFUSE isn't approved yet — go to System Settings → Privacy & Security → Allow (next to macFUSE), then reboot.

**Mount fails**
ntfs-3g will automatically try to recover if the drive wasn't safely ejected from Windows. If it still fails, run `ntfs doctor` to check your setup.

**Drive still spinning after unmount**
Use `ntfs eject` — it sends the spin-down command to the disk. `ntfs unmount` only unmounts the filesystem.

**Stale records / drive shows as mounted but isn't**
Run `ntfs status` — it cleans these up automatically.

**Daemon not mounting drives**
Check `ntfs daemon status` and `sudo ntfs daemon logs`. macFUSE must be approved before the daemon can mount anything.

---

## Uninstall

```sh
sudo ntfs daemon uninstall           # remove auto-mount daemon (if installed)
sudo rm /usr/local/bin/ntfs          # remove the command
sudo rm /usr/local/share/zsh/site-functions/_ntfs  # remove zsh completion
rm -f ~/.ntfs-mounts                 # remove mount record
```

---

## What it doesn't do

- **No BitLocker** — ntfs-3g doesn't support encrypted NTFS volumes
- **No GUI** — command-line only
- **Not a kernel driver** — uses macFUSE (user-space). Works great for everyday use; throughput is lower than Paragon/Tuxera on large copies
- **No Finder eject button** for hidden mounts — use `ntfs eject`

---

## Known Limitations

**macFUSE requires a one-time manual approval.** macOS treats it as a third-party kernel extension and requires you to allow it in Security settings, followed by a reboot.

**Performance is lower than commercial tools.** FUSE adds user-space overhead. Fine for documents, photos, media. Noticeable on sustained large file transfers.

**The daemon polls every 10 seconds** (configurable via `NTFS_DAEMON_POLL_INTERVAL`). Detection isn't instant but is fast enough for real use.

**SIP does not need to be disabled.** macFUSE works with SIP enabled on Monterey and later.

---

## License

Public domain. No copyright claimed. Use, copy, modify, sell — no restrictions, no attribution required.

---

## Technical

- **Disk info:** `diskutil info -plist` + `plutil` — structured plist parsing, not fragile text scraping
- **Mount options:** `local,allow_other,auto_xattr,windows_names,volname=<name>` (+ `nobrowse` unless `--visible`, + `ro` if `--readonly`, + `recover` on retry)
- **Eject:** `umount` blocks until ntfs-3g exits and releases the device fd; then `diskutil unmountDisk force` clears any Disk Arbitration auto-remounts; then `diskutil eject` sends SCSI STOP UNIT
- **Daemon:** LaunchDaemon at `/Library/LaunchDaemons/com.ntfshandler.automount.plist`, runs as root, polls every `$NTFS_DAEMON_POLL_INTERVAL` seconds (default: 10); retries failed mounts; clears seen-list on start
- **Mount records:** `~/.ntfs-mounts` (user), `/var/run/ntfs-daemon-mounts` (daemon) — tab-separated, atomic `mktemp` + `mv`
- **Shell:** bash 3.2+; ShellCheck clean
- **Tested:** macOS Ventura 13, Sonoma 14 — Intel and Apple Silicon
