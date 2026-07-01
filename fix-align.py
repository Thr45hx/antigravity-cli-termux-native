#!/data/data/com.termux/files/usr/bin/env python3
# Rewrite oversized PT_LOAD p_align (Go ships 0x200000 / 2 MB-aligned segments)
# down to the page size so Termux's glibc loader can map the Antigravity binary.
# Idempotent and cheap: only reads the ELF header + program-header table, and
# only writes if a fix is actually needed (so it's safe to run on every launch).
import sys, struct

PAGE = 0x1000
path = sys.argv[1]
with open(path, 'r+b') as f:
    hdr = f.read(64)
    if hdr[:4] != b'\x7fELF' or hdr[4] != 2:      # not ELF64
        sys.exit(0)
    phoff = struct.unpack_from('<Q', hdr, 0x20)[0]
    phentsize = struct.unpack_from('<H', hdr, 0x36)[0]
    phnum = struct.unpack_from('<H', hdr, 0x38)[0]
    f.seek(phoff)
    ph = bytearray(f.read(phentsize * phnum))
    changed = 0
    for i in range(phnum):
        o = i * phentsize
        p_type = struct.unpack_from('<I', ph, o)[0]
        p_align = struct.unpack_from('<Q', ph, o + 48)[0]
        if p_type == 1 and p_align > PAGE:        # PT_LOAD with oversized align
            struct.pack_into('<Q', ph, o + 48, PAGE)
            changed += 1
    if changed:
        f.seek(phoff)
        f.write(ph)
        sys.stderr.write(f"[agy] re-aligned {changed} segment(s) for native load\n")
