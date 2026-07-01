#!/data/data/com.termux/files/usr/bin/bash
# Native Antigravity CLI (agy) launcher for Termux — no proot.
#
# agy is a glibc-dynamic Go binary; self-update makes the pieces interact, so
# read before editing.
#
#  1) ALIGN — Go ships 2 MB-aligned PT_LOAD segments the Termux glibc loader
#     can't map; fix-align.py rewrites them to page size. Re-run every launch:
#     a self-update re-downloads a fresh (2 MB-aligned) binary.
#
#  2) LOADER-DIRECT — patchelf corrupts Go binaries, so we set no interpreter and
#     run `ld.so --library-path <glibc> agy`. That makes /proc/self/exe the
#     LOADER, not agy.
#
#  3) AUTO-UPDATE (kept ON, and made to persist) — because /proc/self/exe is the
#     loader, a self-update overwrites the loader with the freshly-downloaded agy
#     binary. We turn that into the update mechanism instead of a brick:
#       • $LDA is a PRIVATE throwaway loader copy, so a self-update clobbers THIS,
#         never the shared glibc loader (that would kill Claude + every glibc
#         tool).
#       • Next launch we ADOPT it: if $LDA is now a big valid ELF (the ~160 MB
#         agy binary, not the 241 KB loader) we back up the current agy and copy
#         the new one into place — so the update actually sticks — then restore
#         $LDA from the real loader. Updates take effect on the next relaunch.
#
#  4) DNS + glibc-child hygiene — always run under claude-resolvfix.so. Its
#     constructor scrubs LD_PRELOAD/LD_LIBRARY_PATH so the glibc HELPER processes
#     agy spawns interactively (agentapi, tools) load cleanly; without it,
#     interactive launches die with "libc.so: invalid ELF header". It also
#     redirects /etc/resolv.conf reads to $PREFIX/etc/resolv.conf, which we keep
#     synced from the root agent-resolv module's /etc/resolv.conf when mounted —
#     so the module's DNS is exactly what agy resolves through — or seed with
#     defaults for the non-root case. GODEBUG=netdns=cgo pins the glibc resolver
#     so the shim catches it; SSL_CERT_FILE aims TLS at Termux's CA bundle.
PREFIX="/data/data/com.termux/files/usr"
DIR="$HOME/agents/antigravity"
BIN="$DIR/agy"
REAL_GLD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LDA="$DIR/ld.so"                 # private, disposable loader copy — see (2)/(3)
SHIM="$PREFIX/lib/claude-resolvfix.so"
RE="$PREFIX/glibc/bin/readelf"

[ -f "$BIN" ] || { echo "[agy] binary not found at $BIN — reinstall." >&2; exit 1; }

# (3) Adopt a self-update that landed on the loader copy, then restore the loader.
real_sz=$(stat -c%s "$REAL_GLD" 2>/dev/null || echo 0)
lda_sz=$(stat -c%s "$LDA" 2>/dev/null || echo 0)
if [ -f "$LDA" ] && [ "$lda_sz" != "$real_sz" ] && [ "$lda_sz" -gt 50000000 ] \
   && "$RE" -h "$LDA" >/dev/null 2>&1; then
  cp -f "$BIN" "$DIR/agy.bak" 2>/dev/null || true   # keep the last-good binary
  cp -f "$LDA" "$BIN" && echo "[agy] adopted self-update ($lda_sz bytes)." >&2
fi
if [ ! -f "$LDA" ] || [ "$(stat -c%s "$LDA" 2>/dev/null)" != "$real_sz" ]; then
  cp -f "$REAL_GLD" "$LDA"       # restore the private loader
fi

# (1) Re-align (a fresh download is 2 MB-aligned again; idempotent otherwise).
python3 "$DIR/fix-align.py" "$BIN" 2>/dev/null || true

# (4) Keep the shim's resolv target synced from the root module when mounted,
#     else seed defaults so DNS still works with no root.
if [ -s /etc/resolv.conf ] && grep -q '^nameserver' /etc/resolv.conf 2>/dev/null; then
  cp -f /etc/resolv.conf "$PREFIX/etc/resolv.conf" 2>/dev/null || true
elif ! grep -qs '^nameserver' "$PREFIX/etc/resolv.conf" 2>/dev/null; then
  printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' > "$PREFIX/etc/resolv.conf" 2>/dev/null || true
fi

exec env GODEBUG=netdns=cgo SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem" \
     LD_PRELOAD="$SHIM" "$LDA" --library-path "$PREFIX/glibc/lib" "$BIN" "$@"
