# Security Policy

## Reporting a Vulnerability

If you find a security issue in ntfs-handler, **please report it privately** so it can be fixed before being disclosed publicly. Use GitHub's private security advisory feature:

> **[Open a private security advisory →](https://github.com/WildBenji/ntfs-handler/security/advisories/new)**

This lets us discuss and patch the issue privately before any details become public. Please do **not** open a public GitHub issue for security problems.

You should expect an initial response within **7 days**. Fix timelines depend on severity — anything that lets a non-admin user gain root, or that exposes data without consent, will be prioritized.

## Supported Versions

Only **1.0.0 and later** are supported. Earlier 0.x versions had known security issues that 1.0.0 resolves — please upgrade.

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅        |
| < 1.0   | ❌ — known issues, please upgrade |

## What's in scope

- The `ntfs` script itself — privilege escalation, command injection, unintended sudo invocations.
- The `install.sh` installer — download verification, supply-chain concerns.
- The sudoers rule at `/etc/sudoers.d/ntfs-handler` — over-broad scope, missing path restrictions, version-skew bypass.
- The LaunchAgent plist at `~/Library/LaunchAgents/com.ntfshandler.automount.plist` — privilege boundary, environment leaks.
- The mount/unmount logic — TOCTOU races, symlink attacks on `/Volumes/`.
- Documentation that materially misrepresents the security model.

## What's out of scope

- **macFUSE kernel-level vulnerabilities** — tracked at the [macFUSE project](https://github.com/macfuse/macfuse).
- **ntfs-3g vulnerabilities** — tracked upstream at [tuxera/ntfs-3g](https://github.com/tuxera/ntfs-3g).
- **Kernel panics from FUSE channel hangs** — an architectural limitation of running filesystem drivers in user space on macOS, not a defect of this script. Documented in the README troubleshooting section.
- **Conflicts with Paragon NTFS or Tuxera NTFS** — installing two NTFS drivers simultaneously is unsupported by macFUSE; documented in the install prerequisites.

## Known security tradeoffs (by design)

These are intentional choices, disclosed to users at install time. They are **not** bugs — but if you believe one has been mis-described, has consequences not covered here, or could be tightened further without breaking functionality, please report it.

1. **Passwordless sudo for unmount/eject is opt-in.** When the user accepts the optional sudoers rule, any admin (staff) user on the same Mac can run the whitelisted commands — `ntfs-3g`, `diskutil unmount/unmountDisk/eject`, `umount`, `mkdir`/`rmdir` under `/Volumes/` — without a password. This means another admin on the machine can interrupt other users' work by unmounting/ejecting their drives. It cannot delete, exfiltrate, or corrupt data. The prompt explains this clearly and the user can decline.

2. **`mkdir`/`rmdir` are scoped to `/Volumes/*`, but sudoers' `*` glob matches `/`.** A determined staff user could traverse with `..` (e.g., `/Volumes/foo/../usr/local/bin/X`). This is defense-in-depth, not a hard boundary. Filed as a known limitation rather than a bug; the staff user already has unlimited admin password access via normal `sudo`.

3. **`diskutil` is scoped to three subcommands** (`unmount force`, `unmountDisk force`, `eject`). Other diskutil subcommands — `eraseDisk`, `partitionDisk`, `apfs`, etc. — correctly require a password. As of 1.0.0; pre-1.0 versions had unrestricted diskutil access and should be upgraded.

4. **Auto-mount agent runs as the logged-in user, not root.** Deliberate — LaunchDaemons can't open `/dev/disk*` on modern macOS without manual Full Disk Access grants that break on every Homebrew upgrade.

5. **`bash <(curl …)` install pattern.** Standard for shell tools; mitigated by `SHA256SUMS` verification of the downloaded `ntfs` script in `install.sh`. The process-substitution form is used rather than `curl … | bash` so the installer's interactive prompts read from your terminal instead of consuming the piped script. Downloads land in a private `mktemp -d` directory (mode 700) and are removed on exit, so another local user cannot swap them between verification and install. Users who want stronger guarantees should clone the repo and run `bash install.sh` from a verified checkout. Both `install.sh` and `SHA256SUMS` are served from the same origin, so this protects against transit corruption rather than origin compromise.

## Threat model

ntfs-handler protects:

- **Against** a passive attacker on the network during install (HTTPS + SHA256 verification).
- **Against** unintended privilege escalation via mistyped commands or unscoped sudo rules.
- **Against** silent failures that mask broken security state (e.g., the `SUDOERS_VERSION` gate prevents an outdated whitelist from running with newer code that expects different permissions).

ntfs-handler does **not** protect:

- Against a malicious admin user on the same Mac. Anyone with admin/sudo can already do anything; the sudoers rule is convenience, not a security boundary.
- Against a compromised GitHub account or a tampered release. Sign your own checkouts if this is a concern.
- Against a malicious NTFS drive. ntfs-3g parses untrusted filesystem data; bugs there are upstream.
