#!/bin/bash
# Pre-release checks, run by hand: bash test.sh
#
# Static checks plus behaviour tests of ntfs against stub sudo, diskutil,
# mount and ntfs-3g. Nothing is mounted and nothing runs as root.
set -euo pipefail
cd "$(dirname "$0")"

fails=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

echo "static"
check "shellcheck" shellcheck ntfs install.sh test.sh
check "syntax" /bin/bash -n ntfs
check "syntax (installer)" /bin/bash -n install.sh
check "SHA256SUMS (regenerate: shasum -a 256 ntfs install.sh completions/_ntfs > SHA256SUMS)" \
    shasum -a 256 -c --quiet SHA256SUMS

T=$(mktemp -d "${TMPDIR:-/tmp}/ntfs-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home"

# ntfs-3g stub: records that it ran, never mounts anything.
printf '#!/bin/sh\necho ran >> "%s/ntfs3g.log"\n' "$T" > "$T/bin/ntfs-3g"
# mount stub: prints the fake mount table.
printf '#!/bin/sh\ncat "%s/mounts" 2>/dev/null\n' "$T" > "$T/bin/mount"
# diskutil stub: two NTFS partitions on disk9.
cat > "$T/bin/diskutil" <<'EOF'
#!/bin/sh
case "$1" in
  list) printf '   1: Microsoft Basic Data A 1 GB disk9s1\n   2: Microsoft Basic Data B 1 GB disk9s2\n' ;;
  info) [ "$2" = -plist ] && printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
          '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
          '<plist version="1.0"><dict><key>FilesystemType</key><string>ntfs</string>' \
          '<key>VolumeName</key><string>Vol</string><key>TotalSize</key><integer>1</integer></dict></plist>' ;;
esac
exit 0
EOF
# sudo stub: logs the call; a "mount" just appends to the fake table.
cat > "$T/bin/sudo" <<EOF
#!/bin/sh
echo "\$*" >> "$T/sudo.log"
case "\$*" in
  *__mount-helper*) [ -n "\${STUB_FAIL:-}" ] && exit 1
                    echo "\$3 on \$4 (macfuse, synchronous)" >> "$T/mounts" ;;
  "umount "*) grep -vF " on \$2 " "$T/mounts" > "$T/m"; mv "$T/m" "$T/mounts" ;;
esac
exit 0
EOF
chmod +x "$T/bin/"*

run() { HOME="$T/home" NO_COLOR=1 PATH="$T/bin:/usr/bin:/bin:/usr/sbin:/sbin" /bin/bash ./ntfs "$@" >/dev/null 2>&1; }
reset() { : > "$T/mounts"; : > "$T/sudo.log"; rm -f "$T/ntfs3g.log" "$T/home/.ntfs-mounts"; }
expect() { # expect <status> <label> <ntfs args...>
    local want="$1" label="$2" got=0; shift 2
    run "$@" || got=$?
    if [ "$got" -eq "$want" ]; then pass "$label"; else fail "$label (exit $got, want $want)"; fi
}

echo "mount helper rejects unsafe arguments"
for mp in /etc /Volumes/a/b /Volumes/../etc /Volumes/.. /Volumes/. "/Volumes/Macintosh HD"; do
    reset; run __mount-helper /dev/disk9s1 "$mp" 0 0 0 0 X || true
    if [ -f "$T/ntfs3g.log" ]; then fail "accepted mount point '$mp'"; else pass "refuses '$mp'"; fi
done
reset; run __mount-helper /tmp/evil.img /Volumes/X 0 0 0 0 X || true
if [ -f "$T/ntfs3g.log" ]; then fail "accepted an image file as the device"; else pass "refuses an image file"; fi

echo "exit statuses"
reset;                                   expect 0 "direct mount succeeds"      mount disk9s1
reset; STUB_FAIL=1 expect 1 "direct mount fails" mount disk9s1
reset; STUB_FAIL=1 expect 1 "mount --all with a failure" mount --all
reset;                                   expect 1 "not an NTFS volume"         mount disk99s1
reset; printf '1\n' > "$T/in"
expect 0 "interactive mount succeeds" mount < "$T/in"
printf 'disk9s1\t/Volumes/Vol\n' > "$T/home/.ntfs-mounts"
expect 0 "interactive unmount succeeds" unmount < "$T/in"
for c in list status doctor version help; do reset; expect 0 "ntfs $c" "$c"; done

echo "a volume already mounted read-write is left alone"
reset; echo "/dev/disk9s1 on /Volumes/Vol (macfuse, synchronous)" > "$T/mounts"
run mount disk9s1 || true
if [ -s "$T/sudo.log" ]; then fail "direct mount touched a read-write mount"; else pass "direct mount skips it"; fi

echo
[ "$fails" -eq 0 ] && { echo "all checks passed"; exit 0; }
echo "$fails check(s) failed"; exit 1
