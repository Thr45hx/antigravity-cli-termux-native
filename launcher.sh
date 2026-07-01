#!/data/data/com.termux/files/usr/bin/bash
# Native Antigravity CLI (agy) launcher for Termux — no proot.
#
# The Antigravity CLI is a glibc-dynamic Go binary. To run it natively we:
#   1) re-align its 2 MB PT_LOAD segments to page size (glibc loader can't map them);
#   2) run it via the glibc loader *directly* (patchelf corrupts Go binaries);
#   3) use a private disposable loader copy so a self-update (which overwrites
#      /proc/self/exe = the loader) can't brick the real glibc loader;
#   4) DNS: Go's pure resolver (GODEBUG=netdns=go) reads a resolv.conf-format file
#      whose path is byte-patched into the binary — /etc/resolv.conf when a real one
#      exists (rooted: systemless resolv module), else /sdcard/.grokdns (no root).
#      Both are 16 bytes, so the swap is in place; re-applied on mode change or a
#      self-update. SSL_CERT_FILE aims TLS at Termux's CA bundle.
PREFIX="/data/data/com.termux/files/usr"
DIR="$HOME/agents/antigravity"
BIN="$DIR/agy"
REAL_GLD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LDA="$DIR/ld.so"

[ -f "$BIN" ] || { echo "[agy] binary not found at $BIN — reinstall." >&2; exit 1; }
python3 "$DIR/fix-align.py" "$BIN" 2>/dev/null || true
if [ ! -f "$LDA" ] || [ "$(stat -c%s "$LDA" 2>/dev/null)" != "$(stat -c%s "$REAL_GLD" 2>/dev/null)" ]; then
  cp -f "$REAL_GLD" "$LDA"
fi

# DNS mode: native /etc/resolv.conf if a real one exists (rooted resolv module),
# else sdcard byte-patch (no root). agy-dns.py is idempotent (only writes on change).
if [ -s /etc/resolv.conf ] && grep -q '^nameserver' /etc/resolv.conf 2>/dev/null; then
  MODE=native
else
  MODE=sdcard
  grep -qs nameserver /sdcard/.grokdns 2>/dev/null || printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' > /sdcard/.grokdns 2>/dev/null
fi
python3 "$DIR/agy-dns.py" "$BIN" "$MODE" 2>/dev/null || true

exec env GODEBUG=netdns=go SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem" \
     "$LDA" --library-path "$PREFIX/glibc/lib" "$BIN" "$@"
