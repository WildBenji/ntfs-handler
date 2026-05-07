# ntfs-handler — Free NTFS for macOS

Plug in a Windows drive. Read and write files. For free.

macOS can read NTFS drives but refuses to write to them out of the box. This fixes that.

---

## What you need before starting

- A Mac running macOS Monterey (12) or later
- An internet connection
- About 5 minutes
- **No Paragon NTFS or Tuxera NTFS installed.** These commercial NTFS drivers use kernel extensions that clash with macFUSE. Having both loaded at the same time can cause kernel panics (crashes during sleep/wake). Uninstall them before using ntfs-handler.

That's it. No account, no signup, no payment — ever.

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

> **Note:** All the commands below (like `ntfs list`, `ntfs daemon install`) assume you've run the installer first. If you're running directly from the cloned repo without installing, use `./ntfs` instead of `ntfs`.

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

Pick a drive from the menu. That's it — you can now read and write files on it. The drive shows up in the Finder sidebar by default.

If you'd rather keep it out of the sidebar (e.g., a backup drive you don't want to browse accidentally):

```sh
ntfs mount --hidden
```

You can still open a hidden drive in Finder via **⌘⇧G** → `/Volumes/YourDriveName`.

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
ntfs daemon install
```

After that, plugging in an NTFS drive will mount it automatically within about 10 seconds. No commands needed. Auto-mount runs while you're logged in; logging out stops it.

> Earlier versions (≤ 0.4.x) used a system-wide LaunchDaemon that required users to grant Full Disk Access to `ntfs-3g` in System Settings. The current LaunchAgent runs in your login session and inherits Finder/Terminal's TCC — no manual grant needed.

To turn it off:

```sh
ntfs daemon uninstall
```

If a drive can't be mounted (for example, it was unsafely ejected from Windows in a way ntfs-3g can't recover), the agent gives up after 3 attempts to avoid log spam — you'll see a `Giving up on diskNsM` line in `ntfs daemon logs`. Plug the drive into a Windows machine, eject it cleanly, then plug it back into the Mac.

---

## All commands

| Command | What it does |
|---|---|
| `ntfs list` | Show connected NTFS drives |
| `ntfs mount` | Mount a drive (interactive menu) |
| `ntfs mount --all` | Mount all connected NTFS drives |
| `ntfs mount --hidden` | Mount but hide from the Finder sidebar |
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
The drive probably wasn't safely ejected from Windows last time. ntfs-handler will try to recover it automatically. If it keeps failing, run `ntfs doctor`. The auto-mount agent stops retrying after 3 failures to avoid log spam — `ntfs daemon logs` will show `Giving up on diskNsM`. Plug the drive into a Windows machine and eject it cleanly to fix the dirty bit.

**Auto-mount stopped working after upgrading from a previous version**
The old LaunchDaemon doesn't work on modern macOS. Migrate: `sudo ntfs daemon uninstall && sudo rm /etc/sudoers.d/ntfs-handler && ntfs install && ntfs daemon install`.

**Can't delete files from a mounted drive**
This was fixed in 0.4.0 by mapping mounted files to your user via `uid`/`gid` mount options. If you're seeing this on an older version, upgrade.

**Drive still spinning after unplug**
Use `ntfs eject` next time instead of `ntfs unmount`. Eject sends the proper spin-down signal to the disk.

**Shows as mounted but I can't see it**
You probably mounted with `--hidden`. Open Finder, press **⌘⇧G**, and type `/Volumes/` — your drive will be listed there. Or `ntfs unmount` it and remount without `--hidden`.

**Stale "mounted" entry for a drive I already unplugged**
Run `ntfs status` — it cleans those up automatically.

**Kernel panic (crash) during sleep or wake**
You probably have Paragon NTFS or Tuxera NTFS installed alongside macFUSE. These kernel-level NTFS drivers conflict with macFUSE — both try to handle the same disk, and the kernel panics when it can't resolve the conflict. Uninstall Paragon/Tuxera completely, then restart your Mac.

---

## Uninstall

```sh
ntfs daemon uninstall             # remove auto-mount (if you set it up)
sudo rm /usr/local/bin/ntfs       # remove the command
sudo rm /usr/local/share/zsh/site-functions/_ntfs  # remove tab completion
sudo rm -f /etc/sudoers.d/ntfs-handler  # remove passwordless rule (if installed)
rm -f ~/.ntfs-mounts ~/.ntfs-mounts-daemon ~/.ntfs-handler-sudoers-version
```

---

## Limitations

**One-time macFUSE approval required.** macOS treats it as a third-party system extension and requires manual approval followed by a reboot. You only do this once.

**BitLocker-encrypted drives are not supported.** If your drive is encrypted with BitLocker (a Windows feature), this tool can't access it.

**No graphical interface.** Everything is done in Terminal.

**Performance.** This uses a user-space driver, not a kernel driver. It works great for everyday use — documents, photos, music, videos. On very large file transfers (100 GB+) it will be slower than a native driver would be.

**Auto-mount checks every 10 seconds.** When you plug in a drive, it may take up to 10 seconds to mount automatically.

---

## License

Licensed under the **[PolyForm Noncommercial License 1.0.0](LICENSE)**.

In plain English:

- **Free for personal use, hobby projects, and study.** Use it on as many of your own machines as you want, forever.
- **Free for noncommercial organizations** — schools, charities, research groups, public-safety and government institutions.
- **You can fork it, modify it, and redistribute it.** Just keep the license notice with it.
- **You cannot sell it. You cannot bundle it into a paid product or service. You cannot use it commercially.**

This is a **source-available, noncommercial-only** license — not "open source" in the strict OSI sense, because OSI licenses require commercial use to be permitted. That choice is deliberate. This project exists so nobody has to pay for basic NTFS support on macOS, and the license is what guarantees that — forever, for everyone.

---

## Technical details

- **Disk info:** `diskutil info -plist` + `plutil` — structured plist parsing
- **Mount options:** `allow_other,auto_xattr,noappledouble,windows_names,uid=$SUDO_UID,gid=$SUDO_GID,volname=<name>` (+ `nobrowse` if `--hidden`, + `ro` if `--readonly`, + `recover` on retry). `noappledouble` prevents Finder from hanging on move-to-trash. `uid`/`gid` map files to the invoking user so Finder can delete them; without these, files appear owned by root because ntfs-3g runs via sudo. The `local` flag was removed in 0.4.2 because it routed deletes through `.Trashes/<uid>/`, which triggered an `auto_xattr` write into NTFS Alternate Data Streams that locked the FUSE channel indefinitely. Trade-off: deletes do not go to Trash.
- **Mount sequence:** `diskutil unmount force <partition>` → `diskutil unmountDisk force <parent>` → `ntfs-3g` open. The parent unmount is required to release Disk Arbitration's hold on the block device; otherwise ntfs-3g gets `Operation not permitted`.
- **Eject sequence:** `umount` (waits for FUSE teardown) → `diskutil unmountDisk force <parent>` (clears DA auto-remount) → `diskutil eject <parent>` (SCSI STOP UNIT)
- **Auto-mount:** per-user LaunchAgent at `~/Library/LaunchAgents/com.ntfshandler.automount.plist`, runs in the user's session (not as root). LaunchDaemons can't open `/dev/disk*` on modern macOS without manual Full Disk Access grants; LaunchAgents inherit the user's TCC and sidestep this. Polls every `$NTFS_DAEMON_POLL_INTERVAL` seconds (default: 10, minimum: 2); retries up to `$NTFS_DAEMON_MAX_RETRIES` times (default: 3) per disk before giving up; per-disk counters reset on unplug. Log rotates when it exceeds 10 MB.
- **Sudoers whitelist:** `/usr/local/bin/ntfs-3g, /opt/homebrew/bin/ntfs-3g, /usr/sbin/diskutil unmount force *, /usr/sbin/diskutil unmountDisk force *, /usr/sbin/diskutil eject *, /sbin/umount, /bin/mkdir -p /Volumes/*, /bin/rmdir /Volumes/*`. The agent has no tty, so every command it runs via sudo must be in this list. `diskutil` is scoped to the three unmount/eject subcommands the script actually uses — `eraseDisk`, `partitionDisk`, `apfs`, etc. still prompt for a password. `mkdir`/`rmdir` are scoped to `/Volumes/` (note: sudoers' `*` glob does match `/`, so a determined staff user could traverse with `..` — defense in depth, not a hard boundary). The remaining residual risk is that any staff user can unmount/eject any disk without a password, which can interrupt other users' work but cannot exfiltrate or destroy data. Version tracked in `~/.ntfs-handler-sudoers-version`.
- **Mount records:** `~/.ntfs-mounts` (user), `~/.ntfs-mounts-daemon` (agent) — tab-separated, atomic `mktemp` + `mv`
- **Agent state:** `~/Library/Caches/ntfs-daemon-{seen,failures}`; logs at `~/Library/Logs/ntfs-daemon.log`
- **Shell:** bash 3.2+; ShellCheck clean
- **Tested:** macOS Ventura 13, Sonoma 14, Sequoia 15 — Intel and Apple Silicon
