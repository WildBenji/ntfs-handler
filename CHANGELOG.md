# Changelog

## [0.4.1] - 2026-03-26

### Fixed
- **Daemon restarting every 10 seconds** — `diskutil activity` requires a Core Foundation run loop that doesn't exist in a LaunchDaemon process; it exited immediately causing launchd to restart the whole daemon. Reverted to polling, which works correctly in the LaunchDaemon environment
- **Finder hangs on file delete** — added `noappledouble` mount option to prevent macFUSE from creating `._` AppleDouble files; Finder was blocking indefinitely trying to write extended attributes during move-to-trash

---

## [0.4.0] - 2026-03-26

### Changed
- **Daemon is now event-driven instead of polling** — replaced the `sleep 10` poll loop with `diskutil activity`, which fires only when disks actually connect or disconnect. The daemon no longer touches the disk subsystem during sleep/wake transitions, which was the root cause of the `IOMediaBSDClient` kernel panic on logout/wake. Zero CPU usage when idle.

### Fixed
- **Disk reconnect not detected after unplug** — when a disk disappeared and was replugged, it was stuck in the seen-list and silently skipped. The daemon now removes a disk from the seen-list on `DiskDisappeared` so it gets re-mounted on reconnect.

---

## [0.3.5] - 2026-03-25

### Fixed
- **Daemon crash on startup** — `$HOME` is unset in the LaunchDaemon environment; `set -u` made the script exit immediately. Now falls back to `/var/root`
- **Daemon crash on empty disk list** — Bash 3.2 (macOS default) treats empty arrays as unbound under `set -u`; fixed with `${arr[@]+"${arr[@]}"}` pattern
- **Daemon "Operation not permitted"** — on macOS Tahoe+, raw block device access requires Full Disk Access even for root LaunchDaemons. Removed unnecessary `sudo` wrapper inside the daemon (already runs as root) which was creating a different security context. Documented FDA requirement for ntfs-3g
- **Temp file leaks on error paths** — `record_mount()`, `record_unmount()`, daemon loop, and `install_sudoers()` now clean up `mktemp` files on every failure branch (`mv` failure, `sudo cp` failure, etc.) instead of leaking them in `/tmp`
- **Daemon log grows unbounded** — `/var/log/ntfs-daemon.log` is now rotated to a timestamped file when it exceeds 10 MB, checked at the top of each poll loop
- **Sudoers rmdir too permissive** — the NOPASSWD rule for `/bin/rmdir` is now scoped to `/bin/rmdir /Volumes/*` instead of allowing any directory; both `ntfs install` and `install.sh` updated

### Changed
- **Daemon mounts are now visible in Finder** — previously daemon-mounted drives were hidden (`nobrowse`), which confused users because macOS briefly shows the drive read-only, then it disappears when re-mounted read-write by the daemon
- **ntfs-3g errors are no longer suppressed** — mount failures now show the actual ntfs-3g error message instead of a generic "Failed to mount" so users can diagnose issues

---

## [0.3.4] - 2026-03-22

### Added
- **Password-free mounting (optional)** — `ntfs install` and `install.sh` now offer to write `/etc/sudoers.d/ntfs-handler`, granting the `staff` group NOPASSWD access to exactly the binaries ntfs uses (`ntfs-3g`, `diskutil`, `umount`, `rmdir`). The prompt explains what it does, what it doesn't affect, the security trade-off, and the exact removal command (`sudo rm /etc/sudoers.d/ntfs-handler`) before asking. Validated with `visudo -c` before writing.
- **VERSION string corrected** — was stuck at `0.2.0` since the v0.2 rewrite; now reflects the actual release.

---

## [0.3.3] - 2026-03-22

### Fixed
- **`ntfs eject` on untracked spinning disk** — when no ntfs-handler mounts are recorded (drive is spinning but was never mounted by us, or was grabbed read-only by macOS), `ntfs eject` now detects all connected NTFS volumes and offers a menu to eject them directly via `diskutil unmountDisk force` + `diskutil eject`

---

## [0.3.2] - 2026-03-22

### Fixed
- **`safe_name` consecutive underscores** — "My / Data : Volume" now produces `My_Data_Volume` instead of `My___Data___Volume`; consecutive underscores are collapsed
- **Ghost mount point directories** — `get_mount_point` now skips any existing directory (mounted or not), preventing ntfs-3g from failing on a non-empty leftover directory from a previous crashed mount

---

## [0.3.1] - 2026-03-22

### Changed
- **International drive names preserved** — `safe_name()` now only strips `/`, `:`, and control characters; Unicode is left intact so drives named "磁盘", "Мой Диск", etc. mount at a recognisable path instead of falling back to the disk ID
- **Daemon `seen_file` moved to `/var/run`** — consistent with other daemon state files; `/tmp` was correct but `/var/run` is the proper location for root-owned runtime state
- **`ntfs mount --all` shows skip count** — when all volumes are already mounted read-write, prints "N already mounted read-write — nothing to do" instead of silent exit
- **`ntfs install` informs when zsh completions are missing** — prints a hint to use the curl installer or clone the full repo instead of silently skipping

---

## [0.3.0] - 2026-03-22

### Added
- **zsh tab completion** — `completions/_ntfs` covers all subcommands, flags, and daemon subcommands; installed automatically by `ntfs install` and `install.sh`
- **Dirty volume auto-recovery** — if a drive wasn't safely ejected from Windows (dirty bit set), mount is retried automatically with `-o recover`; user sees a warning instead of a silent failure

### Changed
- **Daemon poll interval default: 3s → 10s** — reduces idle CPU and battery drain; configurable via `NTFS_DAEMON_POLL_INTERVAL`
- **Binary ownership hardened** — `ntfs install` and `ntfs daemon install` now set `root:wheel` ownership and `chmod 755`; only an admin can modify the installed script

### Fixed
- **Eject failing after unmount** — Disk Arbitration races to re-mount the NTFS partition read-only the moment ntfs-3g exits; `diskutil unmountDisk force` now runs immediately after `umount` to beat it before calling `diskutil eject`
- **`_2` mount point on second mount** — running `ntfs mount` then `ntfs mount --all` would try to re-mount an already read-write volume, force-unmounting the first mount and creating a `_2` mount point; all mount paths now skip disks that are already mounted read-write
- **`diskutil unmount force` stdout leaking** — "Volume X on diskYsZ force-unmounted" was printed to the user's terminal during the macOS read-only release step; suppressed

---

## [0.2.0] - 2026-03-21

### Added
- Unified `ntfs` command replacing the two separate scripts — `list`, `mount`, `unmount`, `eject`, `status`, `daemon`, `doctor`, `install`
- Auto-mount daemon (`ntfs daemon install`) — NTFS drives mount automatically on plug-in via a LaunchDaemon
- `ntfs list` — table view of all connected NTFS volumes with size and mount status
- `ntfs status` — shows mounted volumes, auto-removes stale records from surprise disconnects
- `ntfs doctor` — checks ntfs-3g, macFUSE, SIP, daemon, and detected volumes
- `--all` flag — mount every NTFS volume in one command
- `--readonly` flag — mount without write access
- Direct disk targeting — `ntfs mount disk2s1` skips the interactive menu
- Short aliases for all commands (`m`, `u`, `e`, `st`, `ls`)
- `install.sh` — one-command installer with Homebrew setup, macFUSE guidance, and optional daemon install
- SHA256 checksum verification when downloading via curl pipe
- Color output with `NO_COLOR` support
- Daemon PID file at `/var/run/ntfs-daemon.pid` with SIGTERM trap for clean shutdown
- Configurable daemon poll interval via `NTFS_DAEMON_POLL_INTERVAL` (default: 3 seconds)
- Upfront `sudo -v` validation before mount/unmount operations
- macOS read-only auto-mount detection — volumes grabbed by macOS on plug-in are released before ntfs-3g mounts them read-write; list and mount menu show `[macOS read-only — will be released]` label
- `volname=` passed to ntfs-3g so Finder displays the real drive name instead of "macFUSE Volume 0 (ntfs-3g)"
- ⌘⇧G shortcut shown in hidden-mount hint

### Changed
- Mount points now use volume names (`/Volumes/MyDrive`) instead of disk IDs (`/Volumes/disk2s1`)
- Disk info now read via `diskutil info -plist` + `plutil` — no longer fragile text parsing
- `ntfs-mount.sh` and `ntfs-unmount.sh` reduced to thin wrappers for backwards compatibility
- Daemon mount logic now calls shared `do_mount` — no duplicate code
- Input validation now catches non-numeric and out-of-range selections with a clear error
- Eject message shows volume name instead of parent disk ID
- `launchctl bootstrap system` tried before deprecated `launchctl load` for daemon install

### Fixed
- Silent failure when selecting an out-of-range disk number
- SC2155 ShellCheck warning (masked return value in local declaration)
- Unmount hang — `umount` (blocks until ntfs-3g exits cleanly) is now primary; required for `diskutil eject` to send the SCSI spin-down command
- HDD still spinning after eject — root cause was ntfs-3g holding the device open; fixed by the unmount ordering above
- `record_unmount` crashing with permission error when a non-root user cleans stale daemon mount records (`/var/run/ntfs-daemon-mounts` is root-owned)
- Daemon never auto-mounting when macOS grabbed the drive first — the "already mounted" check was skipping read-only mounts; daemon now only skips read-write mounts and releases macOS read-only ones
- Daemon `seen_file` using substring grep — `disk5s1` could falsely match `disk5s11`; fixed with whole-line match (`grep -xF`)
- Daemon `seen_file` not cleared on restart — drives already plugged in when daemon restarts were silently skipped; file is now cleared on every daemon start
- Daemon marking failed mounts as seen — a drive that failed to mount would never be retried; failed disks are now removed from `seen_file` so the next poll retries them
- `cmd_unmount` silently ignoring unexpected arguments instead of erroring

### Technical
- ShellCheck clean (zero warnings) with `.shellcheckrc` documenting intentional suppressions
- Daemon mount record: `/var/run/ntfs-daemon-mounts` (root-owned, world-readable)
- User mount record: `~/.ntfs-mounts` (unchanged format, backwards compatible)
- Mount options: `local,allow_other,auto_xattr,windows_names,volname=<name>` (+ `ro` and/or `nobrowse`)

---

## [0.1.0] - 2026-03-10

### Added
- `ntfs-mount.sh`: Interactive NTFS volume mounting with menu selection
- `ntfs-unmount.sh`: Interactive unmounting with automatic disk ejection
- Hidden-by-default mounting to avoid Finder issues
- Visible mode (`--visible` flag) for Finder integration
- Atomic mount record updates using temp files
- Parent disk ejection after unmount to spin down external HDDs
- NTFS filesystem verification before mounting
- Multi-disk support with numbered selection
- Mount tracking in `~/.ntfs-mounts` for reliable unmounting

### Technical Details
- Requires Bash 3+, macOS with macFUSE and ntfs-3g
- Mount points: `/Volumes/<disk-id>` (e.g., `/Volumes/disk2s1`)
- Uses `nobrowse` option for hidden mounts
- Fallback unmount methods: `umount` then `diskutil`
- Tab-delimited mount record format
