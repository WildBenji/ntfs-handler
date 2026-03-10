# NTFS Mount/Unmount Scripts for macOS

Easy command-line mounting of NTFS disks with full read/write support on macOS.

---

## Overview

These scripts provide a simple way to mount and unmount NTFS-formatted external drives on macOS using `ntfs-3g`. Volumes are hidden from Finder by default to avoid issues, and the scripts keep track of mounted disks for clean unmounting.

---

## Requirements

- macOS (Ventura, Sonoma, Monterey or later)
- [macFUSE](https://osxfuse.github.io/) - kernel extension for filesystem support
- [ntfs-3g](https://github.com/tuxera/ntfs-3g) - NTFS driver
- Bash 3+ (included with macOS)

### Installing Requirements

```sh
# Install ntfs-3g via Homebrew
brew install ntfs-3g

# macFUSE must be installed from the website:
# https://osxfuse.github.io/
```

---

## Installation

1. Download `ntfs-mount.sh` and `ntfs-unmount.sh`
2. Make them executable:

```sh
chmod +x ntfs-mount.sh ntfs-unmount.sh
```

3. (Optional) Move to a directory in your `PATH` for global access:

```sh
sudo mv ntfs-mount.sh /usr/local/bin/ntfs-mount
sudo mv ntfs-unmount.sh /usr/local/bin/ntfs-unmount
```

Now you can run `ntfs-mount` and `ntfs-unmount` from anywhere.

---

## Usage

### Mounting NTFS Disks

```sh
./ntfs-mount.sh [--visible]
```

**What happens:**

1. The script scans for NTFS volumes (Microsoft Basic Data partitions)
2. Lists detected volumes with numbers
3. You enter the numbers (space-separated) to mount
4. Volumes mount at `/Volumes/<disk-id>` (e.g., `/Volumes/disk2s1`)

**Visibility options:**

- Default: volumes are **hidden from Finder** (use `Cmd+Shift+G` and type the path to access)
- `--visible` flag: mounts show in Finder like normal disks

**Example:**

```sh
$ ./ntfs-mount.sh
Searching for NTFS volumes...
1) MyExternalHDD (disk2s1)
2) BackupDrive (disk3s1)

Select disks (space-separated): 1
```

### Unmounting NTFS Disks

```sh
./ntfs-unmount.sh
```

**What happens:**

1. Script reads the list of disks previously mounted by this tool
2. Shows them with numbers
3. You select which to unmount
4. For each disk:
   - Unmounts the filesystem
   - Ejects the parent physical disk (spins down external HDDs)
   - Updates the mount record

**Example:**

```sh
$ ./ntfs-unmount.sh
1) /Volumes/disk2s1 (disk2s1)

Select volumes to unmount (space-separated): 1

Unmounting /Volumes/disk2s1...
Ejected parent disk disk2 (spun down)
```

---

## How It Works

- **Mount tracking**: When you mount a disk, the script saves `disk-id` and mount path to `~/.ntfs-mounts` (tab-separated). This ensures clean unmounting even if Finder doesn't recognize the disk.
- **Atomic updates**: The mount record is updated safely using temp files and `mv`.
- **Disk ejection**: Unmounting also ejects the parent physical disk (strips partition suffix like `s1`, `p1`) to spin down external drives.
- **Permission**: All mount/unmount operations require `sudo` for system-level access.

---

## Notes

- Mount points use the **disk identifier** (`disk2s1`) rather than volume names to avoid path issues with special characters.
- Hidden mounts (`-o nobrowse`) prevent Finder crashes and make eject safer.
- If the mount record file (`~/.ntfs-mounts`) is deleted, you can still unmount manually with `diskutil unmount /Volumes/<disk>`.
- The scripts verify that disks are actually NTFS before mounting.

---

## Troubleshooting

### "No NTFS volumes" detected

- Ensure the disk is NTFS-formatted
- Check it appears as "Microsoft Basic Data" in `diskutil list`
- Verify the disk is properly connected and powered

### Mount fails with permission errors

- You need administrator privileges. The script uses `sudo` but may prompt for your password.
- Ensure your user is in the `admin` group.

### Disk spins continuously after unmount

- Some external enclosures don't properly support spin-down via `diskutil eject`
- Check if other processes are accessing the disk: `lsof | grep /Volumes/diskX`
- Try physically disconnecting if safe (all activity stopped)

### Stale mount records

If the script behaves unexpectedly, remove the record file:

```sh
rm ~/.ntfs-mounts
```

Then remount your disks.

### macFUSE not loading (kext error)

On newer macOS versions, you may need to approve the kernel extension in **System Settings > Privacy & Security** after installing macFUSE.

---

## Uninstall

Remove the scripts from `/usr/local/bin` (if installed) and delete or ignore the `~/.ntfs-mounts` file - it causes no harm if left behind.

---

## License

These scripts are released into the **public domain**. There is no license, no copyright claimed, and no restrictions on use. You are free to use, modify, distribute, and sell these scripts without attribution.

---

## Technical Details

- **Shebang**: `#!/bin/bash` (requires bash, not plain `sh`)
- **Arrays**: Uses bash arrays to handle volume names with spaces
- **Process substitution**: `< <(...)` requires bash (not POSIX sh)
- **Mount options**: `local, allow_other, auto_xattr, windows_names` for optimal compatibility
- **Tested**: macOS Sonoma/Ventura on Intel and Apple Silicon with Homebrew-installed ntfs-3g