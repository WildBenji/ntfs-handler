# Changelog

## [1.0.1] - 2026-05-07

Hardening release. Tightens the sudoers whitelist from "all of `diskutil`" down to the three subcommands the script actually uses, adds a real LICENSE file and security disclosure policy, and fixes documentation polarity that had been inverted since the visible-by-default change.

### Security
- **Sudoers `/usr/sbin/diskutil` is now subcommand-scoped** — was unrestricted, which made `diskutil eraseDisk`, `partitionDisk`, `apfs deleteContainer`, etc. passwordless for any staff user. Tightened to the three subcommand forms the script actually invokes: `diskutil unmount force *`, `diskutil unmountDisk force *`, `diskutil eject *`. Erase/partition/apfs now correctly prompt for a password. The interactive sudoers prompt has been updated to no longer warn about risks that no longer exist.
- **Sudoers `/bin/mkdir` is now path-scoped** — the whitelist entry was unrestricted (`/bin/mkdir`), letting any staff user `sudo mkdir` anywhere on disk without a password. Tightened to `/bin/mkdir -p /Volumes/*`, matching the exact form the daemon needs and mirroring the existing `/bin/rmdir /Volumes/*` scope.
- `SUDOERS_VERSION` bumped to `5`. Existing 1.0.0 installs must refresh: `sudo rm /etc/sudoers.d/ntfs-handler && ntfs install` (then `ntfs daemon install` if auto-mount is in use).
- **`SECURITY.md` added** — formal disclosure policy: report vulnerabilities via GitHub private security advisories, supported-version matrix, in-scope/out-of-scope list, and explicit threat model documenting the four intentional residual risks.

### Added
- **`LICENSE` file** — project is now licensed under the **PolyForm Noncommercial License 1.0.0** (source-available, free for personal and noncommercial use, no commercial use or resale). Resolves the prior contradiction between the script header ("public domain"), `install.sh` ("not for resale"), and the README ("don't sell it") — none of which were a real, enforceable license.
- **`.gitignore`** — covers macOS Finder/Spotlight/Time Machine droppings, editor state (VS Code, JetBrains, vim), and defensive secret patterns (`.env`, `*.pem`, `*.key`).
- **`.shellcheckrc` is now tracked** (was untracked) — documents the intentional `SC2059` suppression so contributors and CI lint with the same config.

### Fixed
- **Daemon `uninstall` no longer prints "No daemon installed" after a successful removal** — the post-`rm` `[ -f "$DAEMON_PLIST" ]` check ran *after* the file was deleted, so it always reported "no daemon" even when one had just been removed. Now tracked with a `removed` flag.
- **README sidebar polarity inverted** — README claimed drives were hidden by default and `--visible` made them appear; the actual default has been visible-in-Finder for a while, with `--hidden` as the opt-out. Reflected in README, command table, and troubleshooting.
- **README upgrade-from-pre-1.0 step** — drops misleading "always sudo" framing.
- **`install.sh` "All done" example** — referenced a no-op flag (`--all --visible`); now `--all`.

### Removed
- **Phantom `~/Library/Caches/ntfs-daemon-failures` cleanup** — the daemon-uninstall path tried to remove a cache file that the codebase never writes; failure tracking has been in-memory parallel arrays since 0.5.0.

### Changed
- **README License section rewritten** — explicit bullet list of what's permitted and forbidden, honest "this is source-available, not OSI open source" framing.
- **`ntfs` script header rewritten** — copyright + license pointer to LICENSE file.
- **`install.sh` tagline** updated from "open source, not for resale" to "free for personal use, no commercial resale" so the messaging matches the license.

---

## [1.0.0] - 2026-05-07

First stable release. The eject path is now battle-tested and the auto-mount agent has been hardened through real-world use.

### Fixed
- **`set -e` crash on direct-disk mount failure** — `do_mount` in `cmd_mount` direct-disk path now uses `|| true` so `set -e` doesn't abort the script before processing remaining targets or reporting the error.
- **`set -e` crash on direct-disk unmount failure** — `do_unmount` in `cmd_unmount` direct-disk path now uses `|| true` for the same reason.
- **Stuck ntfs-3g PID surfaced on unmount failure** — when both `umount` and `diskutil unmount force` fail (hung FUSE process), the script now prints the stuck ntfs-3g PID and the exact `sudo kill -9` command to force-release it. `kill` is deliberately excluded from the sudoers whitelist to avoid broadening passwordless root scope.
- **Untracked-eject path unmounts FUSE mounts first** — when running `ntfs eject` without mount records, the script now attempts `sudo umount` on each partition before `diskutil unmountDisk force`, so a lost/corrupted mount record doesn't block ejection.
- **`record_mount` failure handled gracefully** — mount succeeds even if tracking fails; user sees a warning instead of a silent crash.
- **Doctor checks for conflicting Paragon/Tuxera kexts** — `ntfs doctor` now scans for loaded Paragon or Tuxera kernel extensions that clash with macFUSE and can cause kernel panics during sleep/wake.
- **Doctor uses correct LaunchAgent query** — no longer uses `sudo launchctl list` (which can't see user-scoped agents); now queries `launchctl print gui/$(id -u)/...`.
- **`install_sudoers` version check** — existing sudoers rules from older versions are now detected and the user is prompted to refresh them instead of silently accepting a stale whitelist.

### Changed
- **`install.sh` delegates sudoers to `ntfs __install-sudoers`** — removes the duplicate sudoers prompt and inline sudoers template from the installer; the rule and version marker always stay in sync with the script that uses them.
- **`install.sh` auto-mount prompt no longer runs with sudo** — the agent is per-user (LaunchAgent since 0.5.0); `sudo ntfs daemon install` was always wrong post-migration.
- **`install.sh` drops unused `DIM` variable** — was defined but only `ntfs` (not `install.sh`) used it.
- **zsh completion updated** — daemon subcommands no longer claim to require sudo; mount flag corrected from `--visible` (default) to `--hidden`.

---

## [0.5.0] - 2026-05-06

Major release. Auto-mount re-architected from a system-wide LaunchDaemon to a per-user LaunchAgent so it can actually access raw block devices on modern macOS. Adds bounded retries, fixes Finder deletes, tightens sudoers. **Existing 0.4.x installs must migrate** — see below.

### Breaking changes

- **Auto-mount migrated from LaunchDaemon to LaunchAgent.** Origin's 0.3.5–0.4.2 line documented Full Disk Access as a manual user step ("grant FDA to ntfs-3g in System Settings"), but that grant breaks every time Homebrew replaces the binary. The new LaunchAgent at `~/Library/LaunchAgents/com.ntfshandler.automount.plist` runs in the user's login session and inherits Finder/Terminal's TCC — no manual FDA grant, no breakage on `brew upgrade`.
- **`ntfs daemon install` no longer takes sudo.** The agent is per-user; the plist lives in your home directory.
- **Auto-mount no longer runs without an active login.** Logging out stops the agent. Suitable for desk-bound Macs; headless servers should mount manually.

### Added

- **Bounded retries (default 3, configurable via `NTFS_DAEMON_MAX_RETRIES`).** A drive that ntfs-3g can't open (dirty volume that `recover` can't fix, hardware fault) is no longer retried every 10 seconds forever. After 3 attempts the agent logs `Giving up on $disk_id after 3 attempts. To retry: ntfs mount $disk_id` and stays silent until the disk is unplugged. Per-disk counters reset on unplug.
- **Suppressed retry log spam.** First failure logs the full ntfs-3g diagnostic; retries 2 and 3 log a single terse line each.
- **`uid`/`gid` mount options** derived from `$SUDO_UID`/`$SUDO_GID` (or `id -u`/`id -g`) so Finder can delete files. Complements 0.4.2's removal of `local`.
- **`/bin/mkdir` added to the sudoers whitelist** and **`/bin/rmdir` scoped to `/Volumes/*`**. The agent has no controlling tty, so every command it invokes via sudo must be NOPASSWD-whitelisted or it hangs forever. `mkdir` is required to create mount points under root-owned `/Volumes`. Scoping `rmdir` limits blast radius.
- **Sudoers version marker** at `~/.ntfs-handler-sudoers-version`. The sudoers file itself is mode 440 (root-readable only); the marker lets `daemon install` detect a stale rule without sudo. `SUDOERS_VERSION=3` in this release.
- **Disk Arbitration parent-disk unmount before opening the block device.** Without this, ntfs-3g intermittently returns `Operation not permitted` because DA still holds `/dev/diskN` open after a partition unmount. Now unconditionally runs `diskutil unmountDisk force <parent>` before the ntfs-3g call.
- **Mount diagnostics surfaced.** Recovery-attempt stderr is captured and printed on failure (was suppressed; users got "Failed to mount" with no info).

### Fixed

- **`install.sh` `${DIM}` undefined.** The colour-vars line on line 8 never defined `DIM`, so the sudoers-prompt message crashed under `set -u`. Defined alongside the others.
- **`/dev/$disk_id on` greps anchored.** Several `mount | grep` calls used unanchored substring matches; `disk2s1` could match `disk2s11`, breaking detection on systems with double-digit partition numbers.
- **`NTFS_DAEMON_POLL_INTERVAL` validated.** Non-numeric or `0` values previously crashed `sleep` (with `KeepAlive=true`, that was an infinite respawn). Validated and clamped to ≥ 2.
- **`record_mount` `mv` error handling** — was missing the `|| { rm -f "$tmp"; return 1; }` cleanup that `record_unmount` already had.
- **`warn()` writes to stderr** in both `ntfs` and `install.sh` (was going to stdout, polluting `$(...)` capture).
- **Daemon unnamed-volume fallback unified** to `"NTFS Volume"` (interactive used `"NTFS Volume"`, daemon used `"NTFS_$disk_id"`).
- **`cmd_install` no longer aborts when invoked via PATH.** `sudo cp /usr/local/bin/ntfs /usr/local/bin/ntfs` returns 1 and `set -e` killed the script before `install_sudoers` ran. Skipped when source equals destination.

### Migration

```sh
# 1. Tear down the old LaunchDaemon (and its state)
sudo cp <path-to-new-ntfs> /usr/local/bin/ntfs    # or re-run install.sh
sudo ntfs daemon uninstall                         # handles legacy /Library/LaunchDaemons + /var/run + /var/log

# 2. Refresh sudoers (adds /bin/mkdir, scopes /bin/rmdir, writes the v3 marker)
sudo rm /etc/sudoers.d/ntfs-handler
ntfs install

# 3. Install the agent (no sudo)
ntfs daemon install

# Verify
launchctl print "gui/$(id -u)/com.ntfshandler.automount" | grep -E "state|last exit code"
```

### Lessons learned (for future maintainers)

- **LaunchDaemons can't open `/dev/disk*` on modern macOS without manual Full Disk Access grants** — and the grant breaks every time the underlying binary moves (Homebrew updates, version bumps). LaunchAgents inherit the user's session TCC and sidestep this entirely. Use an Agent for any tool that touches raw block devices.
- **launchd-spawned processes inherit no `HOME`** unless the plist sets it. Combined with `set -u` and a top-level `$HOME` reference, that's a silent crash loop. Default it: `${HOME:-/var/root}`.
- **bash 3.2 (the default `/bin/bash` on every macOS) treats empty `"${arr[@]}"` as unbound** under `set -u`. Guard with `[ ${#arr[@]} -gt 0 ]` or use the `${arr[@]+...}` idiom.
- **Sudoers files are mode 440** by `visudo` mandate — non-root users can't read them. Track installed-version state in a user-readable marker file.
- **LaunchAgents have no controlling tty.** Sudo password prompts hang forever (or fail silently with `KeepAlive`). Every binary the agent invokes via sudo must be in the NOPASSWD whitelist.
- **Disk Arbitration may re-mount a partition read-only after `diskutil unmount` of just the partition.** Fix: `diskutil unmountDisk force <parent>` to fully release DA's hold on the device node.
- **ntfs-3g via sudo mounts files as root by default**, breaking Finder deletes. Pass `uid`/`gid` from `$SUDO_UID`/`$SUDO_GID` (or `id -u`/`id -g`).

---

## [0.4.2] - 2026-03-26

### Fixed
- **Finder hangs permanently on file delete** — removed `local` mount option. With `local`, macOS uses on-volume trash (`.Trashes/<uid>/`) which triggers an `auto_xattr` write into NTFS Alternate Data Streams that blocks the FUSE kernel channel indefinitely. Without `local`, Finder deletes files directly without attempting the on-volume trash write. Note: deleted files do not currently go to Trash — this is a known limitation being investigated.

### Changed
- Restored `auto_xattr` mount option — required for file metadata resolution; without it, only directories are visible in Finder

---

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
