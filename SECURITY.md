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
| 1.1.x   | ✅        |
| 1.0.x   | ❌ — local privilege escalation in the sudoers rule (below), please upgrade |
| < 1.0   | ❌ — known issues, please upgrade |

> **Local privilege escalation in the optional sudoers rule, affecting all releases up to and including 1.0.4.**
> The rule granted `%staff` passwordless `sudo` for `ntfs-3g` with unrestricted arguments. `staff` is the default
> primary group of every macOS account, so this covered standard users with no other route to root, and `ntfs-3g`
> accepts an arbitrary image file and mount point — enough to mount attacker-supplied content over a directory as
> root. On Apple Silicon the whitelisted `/opt/homebrew/bin/ntfs-3g` is additionally a user-owned symlink in a
> group-writable directory, so it could simply be re-pointed. `sudo` performs no writability check on whitelisted
> commands. The rule also allowed `mkdir`/`rmdir` under a `/Volumes/*` pattern that `..` traversal escapes.
>
> Fixed in 1.1.0 by scoping the rule to `%admin`, removing `ntfs-3g`, `mkdir` and `rmdir` from it, and routing
> mounting through a validating helper in the root-owned `/usr/local/bin/ntfs`. **Existing installs must refresh
> the rule:** `sudo rm /etc/sudoers.d/ntfs-handler && ntfs install` (then `ntfs daemon install` if auto-mount is
> in use).

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

1. **Passwordless sudo for unmount/eject is opt-in.** When the user accepts the optional sudoers rule, any **admin** user on the same Mac can run the whitelisted commands — the script's own validated mount helper, `diskutil unmount/unmountDisk/eject`, and `umount` — without a password. This means another admin on the machine can interrupt other users' work by unmounting/ejecting their drives. Admin users can already reach root with their own password, so the rule removes the prompt rather than granting new reach; the practical cost is that software running as an admin user can use it without asking. The prompt explains this and the user can decline.

   The rule targets `%admin`, **not `%staff`**. `staff` is the default primary group of every macOS account, including standard users who cannot `sudo` at all — a `%staff` rule would hand these commands to users with no other route to root. Releases up to and including 1.0.4 used `%staff`; see the entry above.

2. **`ntfs-3g` is never whitelisted directly.** `ntfs-3g` mounts `<device|image_file> <dir>`, so a sudoers entry for it with unrestricted arguments is equivalent to granting root: a caller can mount an attacker-authored image over an arbitrary directory. Mounting therefore re-enters the root-owned `/usr/local/bin/ntfs` as `__mount-helper`, which validates the device (`/dev/diskNsM`), the mount point (`/Volumes/` plus one path component, so `..` traversal is rejected), and the uid/gid, and builds the `-o` option string itself rather than accepting one. `ntfs install` refuses to write the rule at all if `/usr/local/bin` is not root-owned.

   Because that helper also creates and removes the mount point, `/bin/mkdir` and `/bin/rmdir` are no longer in the whitelist. Their previous `/Volumes/*` scope did not hold: sudoers wildcards match `/` inside command arguments, so `..` traversal made them arbitrary root-level directory create/remove.

3. **`diskutil` is scoped to three subcommands** (`unmount force`, `unmountDisk force`, `eject`). Other diskutil subcommands — `eraseDisk`, `partitionDisk`, `apfs`, etc. — correctly require a password. As of 1.0.0; pre-1.0 versions had unrestricted diskutil access and should be upgraded.

4. **Auto-mount agent runs as the logged-in user, not root.** Deliberate — LaunchDaemons can't open `/dev/disk*` on modern macOS without manual Full Disk Access grants that break on every Homebrew upgrade.

5. **`bash <(curl …)` install pattern.** Standard for shell tools; mitigated by `SHA256SUMS` verification of the downloaded `ntfs` script in `install.sh`. The process-substitution form is used rather than `curl … | bash` so the installer's interactive prompts read from your terminal instead of consuming the piped script. Downloads land in a private `mktemp -d` directory (mode 700) and are removed on exit, so another local user cannot swap them between verification and install. Users who want stronger guarantees should clone the repo and run `bash install.sh` from a verified checkout. Both `install.sh` and `SHA256SUMS` are served from the same origin, so this protects against transit corruption rather than origin compromise.

## Threat model

ntfs-handler protects:

- **Against** a passive attacker on the network during install (HTTPS + SHA256 verification).
- **Against** unintended privilege escalation via mistyped commands or unscoped sudo rules.
- **Against** silent failures that mask broken security state (e.g., the `SUDOERS_VERSION` gate prevents an outdated whitelist from running with newer code that expects different permissions).

ntfs-handler does **not** protect:

- Against a malicious admin user on the same Mac. Anyone with admin/sudo can already do anything; the sudoers rule is convenience, not a security boundary. It *is* meant to hold against non-admin users, which is why it targets `%admin` rather than `%staff`.
- Against a tampered `ntfs-3g` binary. Homebrew's prefix is user-owned by design, so an admin user can replace the `ntfs-3g` that the helper execs. Constraining that further would mean shipping our own copy of ntfs-3g and its dylibs, which is out of scope; the helper limits *what* can be mounted and *where*, not which driver binary is on disk.
- Against a compromised GitHub account or a tampered release. Sign your own checkouts if this is a concern.
- Against a malicious NTFS drive. ntfs-3g parses untrusted filesystem data; bugs there are upstream.
