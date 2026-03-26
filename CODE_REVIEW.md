# CODE REVIEW: ntfs-handler
**Status:** Reviewed and actioned
**Review Date:** 2026-03-25
**Overall Rating:** A (95/100)

---

## Executive Summary

The `ntfs-handler` project is a **production-quality, well-architected Bash tool** for mounting NTFS drives on macOS with write support. It demonstrates senior-level shell programming with excellent separation of concerns, robust error handling, and thoughtful UX.

**Key Strengths:**
- Clean architecture with command handlers, daemon, and install logic
- Proper use of structured data parsing (`diskutil -plist` + `plutil`) — avoids fragile text parsing
- Comprehensive installer with checksum verification and `visudo` validation
- Excellent UX with colored output, interactive menus, `NO_COLOR` support, and clear documentation
- Solid security posture for single-user personal devices
- Thorough eject logic that handles Disk Arbitration races and FUSE teardown ordering
- Daemon with retry logic for failed mounts, seen-file deduplication, and configurable poll interval

**Issues found and fixed in v0.3.5:**
- Temp file leaks on error paths (medium priority) — **fixed**
- Daemon log rotation missing (medium priority) — **fixed**
- Overly permissive sudoers `rmdir` rule (low-medium priority) — **fixed**

---

## What was fixed

### 1. Temp file cleanup on error paths
**Location:** `record_mount()`, `record_unmount()`, `__daemon_run()`, `install_sudoers()` in `ntfs`; sudoers block in `install.sh`

`mktemp` files could leak if `mv` or `sudo cp` failed (e.g. full disk, permission denied, killed process). Each temp file path now has `rm -f` on every failure branch.

### 2. Daemon log rotation
**Location:** `__daemon_run()` in `ntfs`

`/var/log/ntfs-daemon.log` grew unbounded. A size check now runs at the top of each poll loop — if the log exceeds 10 MB, it's rotated to a timestamped file. Simple, no external dependencies.

### 3. Sudoers rmdir scope restricted
**Location:** `install_sudoers()` in `ntfs`; sudoers block in `install.sh`

The sudoers rule previously granted NOPASSWD `/bin/rmdir` on any directory. Now restricted to `/bin/rmdir /Volumes/*`, which is the only location ntfs-handler creates mount points.

---

## Review items considered and rejected

### Bash version check robustness (proposed: guard `BASH_VERSINFO`)
**Rejected.** `BASH_VERSINFO` is a readonly array set by Bash at startup — it is always present in any Bash invocation, including `--posix` mode. The script has `#!/bin/bash`, so it cannot run under a non-Bash shell. The proposed `-n "${BASH_VERSINFO:-}"` guard adds noise with no benefit.

### Locale-safe `safe_name()` (proposed: `LC_ALL=C` + strip non-ASCII)
**Rejected.** The proposed fix replaced `[[:cntrl:]]` with `[^ -~]`, which would strip all non-ASCII characters — the exact opposite of the function's design intent. The existing code deliberately preserves Unicode so international drive names remain human-readable. The comment in the source makes this explicit.

### Dynamic ntfs-3g path in sudoers (proposed: use `command -v` at install time)
**Rejected.** The sudoers rule intentionally lists both Homebrew paths (`/usr/local/bin` for Intel, `/opt/homebrew/bin` for ARM) so the rule works on either architecture without reinstallation. Using `command -v` would produce a rule for only the current machine's architecture.

### Config file for daemon (proposed: `/etc/ntfs-daemon.conf`)
**Rejected.** The poll interval is already configurable via `NTFS_DAEMON_POLL_INTERVAL` environment variable. Adding an INI config parser for a single setting is over-engineering.

### Cache diskutil plist results in loops
**Rejected.** The reviewer acknowledged "Performance impact negligible (<=3 volumes)." Not worth the added complexity.

### Error logging in find_ntfs_volumes (proposed: capture stderr to temp file)
**Rejected.** Creating a temp file per failed diskutil call to capture stderr at debug level adds more complexity than the problem warrants. The current `|| continue` is appropriate — if a disk disappears between `diskutil list` and `diskutil info`, skipping it silently is the correct behavior.

---

## Current state

The codebase is production-ready for single-user personal devices. All actionable issues from the review have been addressed. Remaining items are either over-engineering for the use case or based on incorrect assumptions about Bash internals.
