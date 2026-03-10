# Changelog

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