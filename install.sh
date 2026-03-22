#!/bin/bash
# ntfs-handler installer
# Usage: bash install.sh
# Or one-liner: curl -fsSL https://raw.githubusercontent.com/WildBenji/ntfs-handler/main/install.sh | bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info() { printf "${BLUE}=>${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${NC}  %s\n" "$*"; }
warn() { printf "${YELLOW}▲${NC}  %s\n" "$*"; }
err()  { printf "${RED}✗${NC}  %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "This installer is for macOS only."

printf "\n${BOLD}ntfs-handler installer${NC}\n"
printf "Free NTFS read/write for macOS — no license, no cost, no catch.\n\n"

# macOS version check
macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$macos_major" -lt 12 ]; then
    warn "macOS 12 (Monterey) or later is recommended. You have $(sw_vers -productVersion)."
fi

# Homebrew
if ! command -v brew &>/dev/null; then
    info "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
else
    ok "Homebrew at $(command -v brew)"
fi

# ntfs-3g
if command -v ntfs-3g &>/dev/null; then
    ok "ntfs-3g already installed"
else
    info "Installing ntfs-3g..."
    brew install ntfs-3g
    ok "ntfs-3g installed"
fi

# macFUSE (must be installed manually — kernel extension)
if [ -d /Library/Filesystems/macfuse.fs ] || [ -d /Library/Filesystems/osxfuse.fs ]; then
    ok "macFUSE already installed"
else
    echo
    warn "macFUSE must be installed manually (it's a kernel extension)."
    echo
    echo "  Steps:"
    echo "  1. Download macFUSE: https://osxfuse.github.io/"
    echo "  2. Open the .pkg and follow the installer"
    echo "  3. Go to: System Settings → Privacy & Security → scroll down → Allow"
    echo "  4. Reboot your Mac"
    echo
    read -rp "Press Enter once macFUSE is installed and you've rebooted, or Ctrl+C to cancel... "
fi

# Install the ntfs script
REPO="https://raw.githubusercontent.com/WildBenji/ntfs-handler/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NTFS_SCRIPT="$SCRIPT_DIR/ntfs"

COMP_SRC="$SCRIPT_DIR/completions/_ntfs"

if [ ! -f "$NTFS_SCRIPT" ]; then
    # Running via curl pipe — download and verify before installing
    info "Downloading ntfs script..."
    curl -fsSL "$REPO/ntfs"                  -o /tmp/ntfs-download
    curl -fsSL "$REPO/SHA256SUMS"            -o /tmp/ntfs-SHA256SUMS
    curl -fsSL "$REPO/completions/_ntfs"     -o /tmp/ntfs-completion

    expected=$(awk '$2 == "ntfs" || $2 == "*ntfs" { print $1 }' /tmp/ntfs-SHA256SUMS)
    actual=$(shasum -a 256 /tmp/ntfs-download | awk '{print $1}')

    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        rm -f /tmp/ntfs-download /tmp/ntfs-SHA256SUMS /tmp/ntfs-completion
        die "SHA256 mismatch — download may be corrupted or tampered. Aborting."
    fi
    ok "Checksum verified"
    NTFS_SCRIPT="/tmp/ntfs-download"
    COMP_SRC="/tmp/ntfs-completion"
fi

info "Installing ntfs to /usr/local/bin/ntfs..."
sudo mkdir -p /usr/local/bin
sudo cp "$NTFS_SCRIPT" /usr/local/bin/ntfs
sudo chown root:wheel /usr/local/bin/ntfs
sudo chmod 755 /usr/local/bin/ntfs
ok "ntfs installed to /usr/local/bin/ntfs"

# zsh completion
if [ -f "$COMP_SRC" ]; then
    sudo mkdir -p /usr/local/share/zsh/site-functions
    sudo cp "$COMP_SRC" /usr/local/share/zsh/site-functions/_ntfs
    ok "zsh completion installed"
fi

# Verify
ntfs version >/dev/null && ok "ntfs is working"

# Optional: auto-mount daemon
echo
read -rp "Enable auto-mount? NTFS drives will mount automatically when plugged in. [y/N] " yn
if [[ "${yn:-}" =~ ^[Yy]$ ]]; then
    sudo ntfs daemon install
fi

# Optional: passwordless sudo for mount/eject
echo
printf "  ${BOLD}Password-free mounting (optional)${NC}\n"
echo
printf "  Right now, every time you mount or eject a drive, macOS asks for your\n"
printf "  password. This is because mounting requires root access.\n"
echo
printf "  Saying yes adds a rule to /etc/sudoers.d/ntfs-handler that lets your\n"
printf "  account run the specific commands ntfs uses (ntfs-3g, diskutil, umount)\n"
printf "  without typing a password. Only those exact programs are affected —\n"
printf "  everything else still requires your password as usual.\n"
echo
printf "  ${YELLOW}▲${NC}  Security note: any admin user on this Mac will be able to mount and\n"
printf "  eject drives without a password. If you are the only user, or you trust\n"
printf "  everyone with an admin account on this machine, this is fine. If you share\n"
printf "  your Mac with other people who have admin accounts, say no.\n"
echo
printf "  Saying no changes nothing — you will keep being asked for your password\n"
printf "  when mounting or ejecting, which is the default macOS behavior.\n"
echo
read -rp "  Skip password prompts for ntfs? [y/N] " yn
if [[ "${yn:-}" =~ ^[Yy]$ ]]; then
    sudoers_file="/etc/sudoers.d/ntfs-handler"
    tmp=$(mktemp)
    cat > "$tmp" <<'SUDOERS'
# ntfs-handler — allow staff group to run mount/eject commands without a password.
# Installed by: install.sh
# Remove with:  sudo rm /etc/sudoers.d/ntfs-handler
%staff ALL=(root) NOPASSWD: /usr/local/bin/ntfs-3g, /opt/homebrew/bin/ntfs-3g, /usr/sbin/diskutil, /sbin/umount, /bin/rmdir
SUDOERS
    if visudo -c -f "$tmp" &>/dev/null; then
        sudo cp "$tmp" "$sudoers_file"
        sudo chown root:wheel "$sudoers_file"
        sudo chmod 440 "$sudoers_file"
        ok "Passwordless mounting enabled (rule saved to $sudoers_file)"
        info "To remove it later: sudo rm $sudoers_file"
    else
        err "sudoers syntax check failed — skipping"
    fi
    rm -f "$tmp"
else
    info "Skipped — you will be prompted for your password when mounting/ejecting"
fi

echo
printf "${GREEN}${BOLD}All done!${NC}\n\n"
printf "  ${BOLD}Quick start:${NC}\n"
printf "  ntfs list                    # see connected NTFS drives\n"
printf "  ntfs mount                   # mount interactively\n"
printf "  ntfs mount --all --visible   # mount all, show in Finder\n"
printf "  ntfs status                  # what's currently mounted\n"
printf "  ntfs doctor                  # check system health\n"
printf "  ntfs help                    # all commands\n\n"
