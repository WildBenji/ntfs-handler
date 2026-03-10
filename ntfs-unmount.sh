#!/bin/bash
# NTFS unmount script for macOS
# Unmounts ntfs-3g volumes and attempts to spin down the disk

set -euo pipefail

MOUNT_RECORD="$HOME/.ntfs-mounts"

disks=()
mountpoints=()

# Load mounts from record file
if [ -f "$MOUNT_RECORD" ]; then
    while IFS=$'\t' read -r disk_id mount_point; do
        [ -n "$disk_id" ] && [ -n "$mount_point" ] && {
            disks+=("$disk_id")
            mountpoints+=("$mount_point")
        }
    done < "$MOUNT_RECORD"
fi

if [ ${#disks[@]} -eq 0 ]; then
    echo "No NTFS-3G volumes detected (mount record not found or empty)."
    exit 1
fi

# Display mounted volumes
echo
for i in "${!disks[@]}"; do
    num=$((i+1))
    echo "$num) ${mountpoints[$i]} (${disks[$i]})"
done

echo
echo -n "Select volumes to unmount (space-separated): "
read -r -a choices

success_count=0
fail_count=0

for choice in "${choices[@]}"; do
    idx=$((choice-1))
    disk_id="${disks[$idx]}"
    mount_point="${mountpoints[$idx]}"

    if [ -z "$mount_point" ]; then
        echo "Invalid selection: $choice"
        fail_count=$((fail_count + 1))
        continue
    fi

    echo
    echo "Unmounting $mount_point..."

    # Try umount first
    if sudo umount "$mount_point" 2>/dev/null; then
        echo "Successfully unmounted $mount_point"
        success_count=$((success_count + 1))
    else
        # Fall back to diskutil
        echo "umount failed, trying diskutil..."
        if sudo diskutil unmount "$mount_point" >/dev/null 2>&1; then
            echo "Successfully unmounted $mount_point"
            success_count=$((success_count + 1))
        else
            echo "Failed to unmount $mount_point"
            fail_count=$((fail_count + 1))
            continue
        fi
    fi

    # Attempt to spin down the disk by ejecting the parent physical disk
    # Strip partition suffix (e.g., disk2s1 -> disk2, disk2p1 -> disk2)
    parent_disk=$(echo "$disk_id" | sed 's/s[0-9]*$//;s/p[0-9]*$//')
    if [ "$parent_disk" != "$disk_id" ] && diskutil info "$parent_disk" >/dev/null 2>&1; then
        if sudo diskutil eject "$parent_disk" >/dev/null 2>&1; then
            echo "Ejected parent disk $parent_disk (spun down)"
        else
            echo "Note: parent disk $parent_disk still mounted or could not be ejected"
        fi
    fi

    # Remove this entry from mount record atomically
    tmp_file=$(mktemp) 2>/dev/null || tmp_file="/tmp/ntfs-unmount.$$"
    if [ -f "$MOUNT_RECORD" ]; then
        grep -v "^$disk_id	" "$MOUNT_RECORD" > "$tmp_file" 2>/dev/null || true
        mv "$tmp_file" "$MOUNT_RECORD" 2>/dev/null || true
    fi
done

# Clean up: remove mount record file if empty
if [ -f "$MOUNT_RECORD" ] && [ ! -s "$MOUNT_RECORD" ]; then
    rm -f "$MOUNT_RECORD"
    echo "Mount record file removed (empty)."
fi

echo
echo "Finished: $success_count succeeded, $fail_count failed."