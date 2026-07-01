#!/data/data/com.termux/files/usr/bin/env python3
# Set the Antigravity (Go) binary's DNS-config path in place. Both targets are
# exactly 16 bytes, so this is a byte-for-byte swap (no relocation). The launcher
# uses it to point Go's pure resolver at /etc/resolv.conf (rooted: a systemless
# resolv module) or /sdcard/.grokdns (no-root byte-patch). Idempotent: only writes
# when the binary isn't already in the requested mode.
import sys, mmap

NATIVE = b"/etc/resolv.conf"
SDCARD = b"/sdcard/.grokdns"          # both exactly 16 bytes
assert len(NATIVE) == len(SDCARD) == 16

path, mode = sys.argv[1], sys.argv[2]
target = NATIVE if mode == "native" else SDCARD
other  = SDCARD if mode == "native" else NATIVE

with open(path, "r+b") as f:
    mm = mmap.mmap(f.fileno(), 0)
    n = 0
    i = mm.find(other)
    while i != -1:
        mm[i:i + 16] = target
        n += 1
        i = mm.find(other, i + 16)
    if n:
        mm.flush()
        sys.stderr.write(f"[agy] DNS path -> {target.decode()} ({n}x)\n")
    mm.close()
