#!/data/data/com.termux/files/usr/bin/bash
# Native Antigravity CLI (agy) launcher for Termux — no proot.
#
# The Antigravity CLI is a glibc-dynamic Go binary. To run it natively we:
#   1) re-align its segments to page size — Go ships 2 MB-aligned PT_LOADs that
#      Termux's glibc loader can't map. Self-healed on every launch in case a
#      background self-update re-downloads a fresh (2 MB-aligned) binary.
#   2) run it via the glibc loader *directly* — patchelf corrupts Go binaries,
#      so we leave the bytes untouched and pass --library-path instead.
#   3) DNS: force Go's cgo/glibc resolver (GODEBUG=netdns=cgo) so resolv.conf
#      reads pass through libc, where claude-resolvfix.so redirects them. Go's
#      default pure resolver uses raw syscalls the LD_PRELOAD shim can't catch,
#      and falls back to a dead [::1]:53. SSL_CERT_FILE aims Go's TLS at Termux's
#      CA bundle (Go otherwise looks only in glibc paths that don't exist here).
PREFIX="/data/data/com.termux/files/usr"
DIR="$HOME/agents/antigravity"
BIN="$DIR/agy"
REAL_GLD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LDA="$DIR/ld.so"                 # private, disposable loader copy — see (4)
SHIM="$PREFIX/lib/claude-resolvfix.so"

[ -f "$BIN" ] || { echo "[agy] binary not found at $BIN — reinstall." >&2; exit 1; }
python3 "$DIR/fix-align.py" "$BIN" 2>/dev/null || true
#   4) agy self-updates by overwriting its own exe (/proc/self/exe). Since a Go
#      binary can't be patchelf'd, we must run it via the glibc loader — which
#      makes /proc/self/exe the LOADER. Point that at a private throwaway copy so
#      a self-update clobbers THIS copy, never the shared glibc loader (which
#      would brick Claude + every glibc tool). Heal the copy on each launch.
if [ ! -f "$LDA" ] || [ "$(stat -c%s "$LDA" 2>/dev/null)" != "$(stat -c%s "$REAL_GLD" 2>/dev/null)" ]; then
  cp -f "$REAL_GLD" "$LDA"
fi
exec env GODEBUG=netdns=cgo SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem" \
     LD_PRELOAD="$SHIM" "$LDA" --library-path "$PREFIX/glibc/lib" "$BIN" "$@"
