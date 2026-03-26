# ntfs-handler — Free NTFS for macOS

Plug in a Windows drive. Read and write files. For free.

macOS can read NTFS drives but refuses to write to them out of the box. This fixes that.

---

## What you need before starting

- A Mac running macOS Monterey (12) or later
- An internet connection
- About 5 minutes
- **No Paragon NTFS or Tuxera NTFS installed.** These commercial NTFS drivers use kernel extensions that clash with macFUSE. Having both loaded at the same time can cause kernel panics (crashes during sleep/wake). Uninstall them before using ntfs-handler.

That's it. No account, no license, no payment.

---

## Install

Open **Terminal** (press `⌘ Space`, type "Terminal", press Enter) and paste this:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/WildBenji/ntfs-handler/main/install.sh)
```

The installer will walk you through everything. The only part that requires a manual step is **macFUSE** — macOS requires you to approve it in Security settings because it's a low-level system component. The installer tells you exactly what to do.

**After macFUSE is approved you must restart your Mac** before it works.

If you cloned the repo instead, run the installer from the repo directory:

```sh
bash install.sh
```

> **Note:** All the commands below (like `ntfs list`, `sudo ntfs daemon install`) assume you've run the installer first. If you're running directly from the cloned repo without installing, use `./ntfs` instead of `ntfs`.

---

## Using it

Once installed, you use the `ntfs` command in Terminal.

### See your connected NTFS drives

```sh
ntfs list
```

This shows all the NTFS drives plugged in and whether they're writable.

### Mount a drive (make it writable)

```sh
ntfs mount
```

Pick a drive from the menu. That's it — you can now read and write files on it.

The drive won't show up in the Finder sidebar by default (this avoids a macOS quirk). To open it, press **⌘⇧G** in Finder and type `/Volumes/YourDriveName`.

If you want it in the Finder sidebar:

```sh
ntfs mount --visible
```

### Safely unplug a drive

Always do this before pulling the cable:

```sh
ntfs eject
```

Pick the drive. Wait for the "safe to unplug" message. Then unplug.

> Pulling the cable without ejecting can corrupt the drive, just like on Windows.

### Check what's currently mounted

```sh
ntfs status
```

---

## Auto-mount (plug in and it just works)

If you want drives to mount automatically every time you plug one in, run this once:

```sh
sudo ntfs daemon install
```

After that, plugging in an NTFS drive will mount it automatically within a few seconds. No commands needed. The drive will appear in Finder just like any other disk.

**Important (macOS Sequoia / Tahoe and later):** The auto-mount daemon needs Full Disk Access for ntfs-3g, otherwise macOS blocks it from accessing the drive.

1. Find where ntfs-3g is installed: `which ntfs-3g`
2. Open **System Settings → Privacy & Security → Full Disk Access**
3. Click **+**, press **⌘⇧G**, paste the path (usually `/opt/homebrew/bin/ntfs-3g`), and add it

You only need to do this once. Manual mounting from Terminal (`ntfs mount`) works without this step because Terminal already has Full Disk Access.

To turn it off:

```sh
sudo ntfs daemon uninstall
```

---

## All commands

| Command | What it does |
|---|---|
| `ntfs list` | Show connected NTFS drives |
| `ntfs mount` | Mount a drive (interactive menu) |
| `ntfs mount --all` | Mount all connected NTFS drives |
| `ntfs mount --visible` | Mount and show in Finder sidebar |
| `ntfs unmount` | Unmount a drive |
| `ntfs eject` | Unmount and safely spin down the disk |
| `ntfs status` | Show what's currently mounted |
| `ntfs daemon install` | Enable auto-mount on plug-in |
| `ntfs daemon status` | Check if auto-mount is running |
| `ntfs doctor` | Check your setup for problems |

---

## Troubleshooting

**Drive not showing up in `ntfs list`**
Run `ntfs doctor`. The most likely cause is macFUSE hasn't been approved yet — go to System Settings → Privacy & Security, find the macFUSE entry, click Allow, then restart.

**Mount fails or says "dirty volume"**
The drive probably wasn't safely ejected from Windows last time. ntfs-handler will try to recover it automatically. If it keeps failing, run `ntfs doctor`.

**Drive still spinning after unplug**
Use `ntfs eject` next time instead of `ntfs unmount`. Eject sends the proper spin-down signal to the disk.

**Shows as mounted but I can't see it**
Open Finder, press **⌘⇧G**, and type `/Volumes/` — your drive should be listed there. Or run `ntfs mount --visible` to remount it with Finder sidebar visibility.

**Stale "mounted" entry for a drive I already unplugged**
Run `ntfs status` — it cleans those up automatically.

**Kernel panic (crash) during sleep or wake**
You probably have Paragon NTFS or Tuxera NTFS installed alongside macFUSE. These kernel-level NTFS drivers conflict with macFUSE — both try to handle the same disk, and the kernel panics when it can't resolve the conflict. Uninstall Paragon/Tuxera completely, then restart your Mac.

---

## Uninstall

```sh
sudo ntfs daemon uninstall        # remove auto-mount (if you set it up)
sudo rm /usr/local/bin/ntfs       # remove the command
sudo rm /usr/local/share/zsh/site-functions/_ntfs  # remove tab completion
sudo rm -f /etc/sudoers.d/ntfs-handler  # remove passwordless rule (if installed)
rm -f ~/.ntfs-mounts              # remove mount records
```

---

## Limitations

**One-time macFUSE approval required.** macOS treats it as a third-party system extension and requires manual approval followed by a reboot. You only do this once.

**BitLocker-encrypted drives are not supported.** If your drive is encrypted with BitLocker (a Windows feature), this tool can't access it.

**No graphical interface.** Everything is done in Terminal.

**Performance.** This uses a user-space driver, not a kernel driver. It works great for everyday use — documents, photos, music, videos. On very large file transfers (100 GB+) it will be slower than a native driver would be.

**Auto-mount latency.** The daemon reacts to disk events as they happen, so drives typically mount within a few seconds of being plugged in.

---

## License

Free and open source, forever. Use it, copy it, modify it, share it — but don't sell it. This project exists so nobody has to pay for basic NTFS support on macOS.

---

## Technical details

- **Disk info:** `diskutil info -plist` + `plutil` — structured plist parsing
- **Mount options:** `local,allow_other,auto_xattr,windows_names,volname=<name>` (+ `nobrowse` unless `--visible`, + `ro` if `--readonly`, + `recover` on retry)
- **Eject sequence:** `umount` (waits for FUSE teardown) → `diskutil unmountDisk force` (clears Disk Arbitration auto-remount) → `diskutil eject` (SCSI STOP UNIT)
- **Daemon:** LaunchDaemon at `/Library/LaunchDaemons/com.ntfshandler.automount.plist`, runs as root, event-driven via `diskutil activity` (no polling); initial scan on start; retries failed mounts on next disk event; clears seen-list on start
- **Mount records:** `~/.ntfs-mounts` (user), `/var/run/ntfs-daemon-mounts` (daemon) — tab-separated, atomic `mktemp` + `mv`
- **Shell:** bash 3.2+; ShellCheck clean
- **Tested:** macOS Ventura 13, Sonoma 14 — Intel and Apple Silicon
