#!/bin/bash
# NTFS mount script for macOS
# Uses ntfs-3g, hidden from Finder by default

set -euo pipefail

MOUNT_RECORD="$HOME/.ntfs-mounts"
mkdir -p "$(dirname "$MOUNT_RECORD")" 2>/dev/null || true

HIDE_OPT="-o nobrowse"
if [ "${1:-}" = "--visible" ]; then
    HIDE_OPT=""
fi

echo "Searching for NTFS volumes..."

disks=()
volnames=()

# Find Microsoft Basic Data partitions
while IFS= read -r disk_id; do
    [ -z "$disk_id" ] && continue

    if ! diskutil info "$disk_id" >/dev/null 2>&1; then
        continue
    fi

    # Get volume name
    vol_name=$(diskutil info "$disk_id" 2>/dev/null | awk -F': ' '/Volume Name/ {print $2}')
    vol_name=$(echo "$vol_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$vol_name" ] && vol_name="NTFSVolume"

    # Verify NTFS
    fs_type=$(diskutil info "$disk_id" 2>/dev/null | awk -F': ' '/File System Personality/ {print $2}')
    fs_type=$(echo "$fs_type" | tr '[:upper:]' '[:lower:]')
    case "$fs_type" in
        *ntfs*) ;;
        *) echo "Skipping $disk_id ($vol_name): not NTFS ($fs_type)"; continue ;;
    esac

    disks+=("$disk_id")
    volnames+=("$vol_name")
done < <(diskutil list 2>/dev/null | awk '/Microsoft Basic Data/ {print $NF}')

if [ ${#disks[@]} -eq 0 ]; then
    echo "No NTFS volumes found."
    exit 1
fi

# List for selection
echo
for i in "${!disks[@]}"; do
    num=$((i+1))
    echo "$num) ${volnames[$i]} (${disks[$i]})"
done

echo
echo -n "Select disk numbers to mount (space-separated): "
read -r -a choices

for choice in "${choices[@]}"; do
    idx=$((choice-1))
    disk_id="${disks[$idx]}"
    vol_name="${volnames[$idx]}"

    if [ -z "$disk_id" ]; then
        echo "Invalid selection: $choice"
        continue
    fi

    device_path="/dev/$disk_id"
    mount_point="/Volumes/$disk_id"

    echo
    echo "Preparing mount point: $mount_point"
    sudo mkdir -p "$mount_point"

    # Unmount existing if present
    if mount | grep -Fq "on $device_path "; then
        echo "Unmounting existing mount..."
        sudo diskutil unmount "$disk_id" >/dev/null 2>&1 || echo "Warning: could not unmount $disk_id"
    fi

    echo "Mounting $vol_name..."
    if sudo ntfs-3g "$device_path" "$mount_point" \
        -o local \
        -o allow_other \
        -o auto_xattr \
        -o windows_names \
        $HIDE_OPT; then

        echo "Mounted $vol_name at $mount_point"

        # Update mount record atomically
        tmp_file=$(mktemp) 2>/dev/null || tmp_file="/tmp/ntfs-mount.$$"
        if [ -f "$MOUNT_RECORD" ]; then
            grep -v "^$disk_id	" "$MOUNT_RECORD" > "$tmp_file" 2>/dev/null || true
        fi
        echo "$disk_id	$mount_point" >> "$tmp_file"
        mv "$tmp_file" "$MOUNT_RECORD" 2>/dev/null

        echo "Mount info stored: $MOUNT_RECORD"
        [ -n "$HIDE_OPT" ] && echo "Note: mount hidden from Finder. Access via Cmd+Shift+G -> $mount_point"
        echo
    else
        echo "Failed to mount $vol_name ($disk_id)"
    fi
done