#!/bin/bash
# ntfs-handler installer
# Usage: bash install.sh
# Or one-liner: bash <(curl -fsSL https://raw.githubusercontent.com/WildBenji/ntfs-handler/main/install.sh)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info() { printf "${BLUE}=>${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${NC}  %s\n" "$*"; }
warn() { printf "${YELLOW}▲${NC}  %s\n" "$*" >&2; }
err()  { printf "${RED}✗${NC}  %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "This installer is for macOS only."

printf "\n${BOLD}ntfs-handler installer${NC}\n"
printf "Free NTFS read/write for macOS — free for personal use, no commercial resale.\n\n"

# macOS version check
macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$macos_major" -lt 12 ]; then
    warn "macOS 12 (Monterey) or later is recommended. You have $(sw_vers -productVersion)."
fi

# Homebrew
if ! command -v brew &>/dev/null; then
    warn "Homebrew is required to install macFUSE and ntfs-3g, and is not present."
    read -rp "Install Homebrew now? [y/N] " yn || yn=""
    [[ "${yn:-}" =~ ^[Yy]$ ]] || die "Homebrew is required — see https://brew.sh"
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
else
    ok "Homebrew at $(command -v brew)"
fi

# macFUSE (kernel extension — required by ntfs-3g-mac)
if [ -d /Library/Filesystems/macfuse.fs ] || [ -d /Library/Filesystems/osxfuse.fs ]; then
    ok "macFUSE already installed"
else
    info "Installing macFUSE via Homebrew..."
    brew install --cask macfuse 2>/dev/null || true
    if [ ! -d /Library/Filesystems/macfuse.fs ] && [ ! -d /Library/Filesystems/osxfuse.fs ]; then
        echo
        warn "macFUSE must be installed manually (it's a kernel extension)."
        echo
        echo "  Steps:"
        echo "  1. Download macFUSE: https://osxfuse.github.io/"
        echo "  2. Open the .pkg and follow the installer"
        echo "  3. Go to: System Settings → Privacy & Security → scroll down → Allow"
        echo "  4. Reboot your Mac"
        echo
        read -rp "Press Enter once macFUSE is installed and you've rebooted, or Ctrl+C to cancel... " || true
    else
        ok "macFUSE installed via Homebrew"
        echo
        warn "macFUSE is a kernel extension — you may need to:"
        echo "   go to System Settings → Privacy & Security → Allow, then reboot."
        echo
        read -rp "Press Enter after rebooting, or Ctrl+C to cancel... " || true
    fi
fi

# ntfs-3g (macOS build via gromgit/fuse tap — core formula is Linux-only)
BREW_NTFS3G="gromgit/fuse/ntfs-3g-mac"
if command -v ntfs-3g &>/dev/null; then
    ok "ntfs-3g already installed"
else
    info "Installing ntfs-3g (macOS) via gromgit/fuse tap..."
    brew tap gromgit/fuse 2>/dev/null || true
    brew install "$BREW_NTFS3G"
    ok "ntfs-3g installed"
fi

# Install the ntfs script
REPO="https://raw.githubusercontent.com/WildBenji/ntfs-handler/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NTFS_SCRIPT="$SCRIPT_DIR/ntfs"

COMP_SRC="$SCRIPT_DIR/completions/_ntfs"

if [ ! -f "$NTFS_SCRIPT" ]; then
    # Running from the curl one-liner (no local checkout) — download and verify before installing.
    # Use a private mktemp dir (mode 700) so another local user can't pre-plant
    # or swap the downloaded files between verification and the sudo install.
    info "Downloading ntfs script..."
    DL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ntfs-install.XXXXXX") || die "Could not create temp dir"
    trap 'rm -rf "$DL_DIR"' EXIT
    curl -fsSL "$REPO/ntfs"                  -o "$DL_DIR/ntfs"
    curl -fsSL "$REPO/SHA256SUMS"            -o "$DL_DIR/SHA256SUMS"
    curl -fsSL "$REPO/completions/_ntfs"     -o "$DL_DIR/_ntfs"

    expected=$(awk '$2 == "ntfs" || $2 == "*ntfs" { print $1 }' "$DL_DIR/SHA256SUMS")
    actual=$(shasum -a 256 "$DL_DIR/ntfs" | awk '{print $1}')

    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        die "SHA256 mismatch — download may be corrupted or tampered. Aborting."
    fi

    expected_comp=$(awk '$2 == "completions/_ntfs" || $2 == "*completions/_ntfs" { print $1 }' "$DL_DIR/SHA256SUMS")
    actual_comp=$(shasum -a 256 "$DL_DIR/_ntfs" | awk '{print $1}')
    if [ -z "$expected_comp" ] || [ "$expected_comp" != "$actual_comp" ]; then
        die "Completion checksum mismatch — download may be corrupted or tampered. Aborting."
    fi
    ok "Checksum verified"
    NTFS_SCRIPT="$DL_DIR/ntfs"
    COMP_SRC="$DL_DIR/_ntfs"
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

# Optional: passwordless sudo for mount/eject.
# Delegate to /usr/local/bin/ntfs so the rule and version marker stay in sync
# with the script that actually uses them. The agent install below requires it.
ntfs __install-sudoers || true

# Optional: auto-mount agent
echo
read -rp "Enable auto-mount? NTFS drives will mount automatically when plugged in. [y/N] " yn || yn=""
if [[ "${yn:-}" =~ ^[Yy]$ ]]; then
    ntfs daemon install
fi

echo
printf "${GREEN}${BOLD}All done!${NC}\n\n"
printf "  ${BOLD}Quick start:${NC}\n"
printf "  ntfs list                    # see connected NTFS drives\n"
printf "  ntfs mount                   # mount interactively\n"
printf "  ntfs mount --all             # mount every detected drive\n"
printf "  ntfs status                  # what's currently mounted\n"
printf "  ntfs doctor                  # check system health\n"
printf "  ntfs help                    # all commands\n\n"
