#!/data/data/com.termux/files/usr/bin/bash
#
# install.sh — Google Antigravity CLI (agy), native on Termux (aarch64). No proot.
#
# Google ships only a glibc-dynamic Go binary. Four fixes make it run native:
# 2MB->page segment re-alignment, glibc-loader-direct (patchelf corrupts Go), a
# private disposable loader (self-updates overwrite /proc/self/exe), and DNS via
# Go's pure resolver reading a byte-patched resolv path — /etc/resolv.conf when a
# real one exists (rooted resolv module), else /sdcard/.grokdns (no root).
#
set -euo pipefail
say(){ printf '\033[1;35m[agy-native]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[agy-native] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
GL="$PREFIX/glibc"
GLD="$GL/lib/ld-linux-aarch64.so.1"
DIR="$HOME_DIR/agents/antigravity"
UPDATER="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
RAW="https://raw.githubusercontent.com/Thr45hx/antigravity-cli-termux-native/main"

[ -d "$PREFIX" ] || die "Not a Termux environment."
case "$(uname -m)" in aarch64|arm64) ;; *) die "arm64/aarch64 only (found $(uname -m)).";; esac

SRC="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
need=0; for f in launcher.sh fix-align.py agy-dns.py; do [ -f "$SRC/$f" ] || need=1; done
if [ "$need" = 1 ]; then
  command -v curl >/dev/null || die "curl required to fetch sources."
  SRC="$(mktemp -d)"; say "Fetching source files…"
  for f in launcher.sh fix-align.py agy-dns.py; do curl -fsSL "$RAW/$f" -o "$SRC/$f" || die "fetch $f failed"; done
fi

say "Installing base packages (python curl ca-certificates)…"
pkg update -y >/dev/null 2>&1 || true
pkg install -y python curl ca-certificates >/dev/null || die "pkg install failed."

if [ ! -f "$GLD" ]; then
  say "Enabling the Termux glibc repo + runtime…"
  pkg install -y glibc-repo >/dev/null || die "glibc-repo failed."
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y glibc >/dev/null || die "glibc install failed."
fi
[ -f "$GLD" ] || die "glibc loader missing: $GLD"

mkdir -p "$DIR"
say "Fetching latest Antigravity CLI manifest…"
mani="$(curl -fsSL "$UPDATER/manifests/linux_arm64.json")" || die "manifest fetch failed."
url="$(printf '%s' "$mani" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
sha="$(printf '%s' "$mani" | sed -n 's/.*"sha512"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
ver="$(printf '%s' "$mani" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
[ -n "$url" ] || die "could not parse manifest."
say "Downloading agy $ver…"
t="$(mktemp -d)"
case "$url" in *.tar.gz*) pkgf="$t/p.tar.gz";; *) pkgf="$t/antigravity";; esac
curl -fsSL -o "$pkgf" "$url" || { rm -rf "$t"; die "download failed."; }
if [ -n "$sha" ]; then a="$(sha512sum "$pkgf" | cut -d' ' -f1)"; [ "$a" = "$sha" ] || { rm -rf "$t"; die "checksum mismatch."; }; fi
case "$pkgf" in *.tar.gz) tar xzf "$pkgf" -C "$t"; bin="$(find "$t" -type f -name antigravity | head -1)";; *) bin="$pkgf";; esac
install -m755 "$bin" "$DIR/agy"; rm -rf "$t"

install -m644 "$SRC/fix-align.py" "$DIR/fix-align.py"
install -m644 "$SRC/agy-dns.py"   "$DIR/agy-dns.py"
install -m755 "$SRC/launcher.sh"  "$DIR/launcher.sh"
python3 "$DIR/fix-align.py" "$DIR/agy"
cp -f "$GLD" "$DIR/ld.so"
ln -sf "$DIR/launcher.sh" "$PREFIX/bin/agy"

say "Verifying…"
if agy --version >/dev/null 2>&1; then say "Installed Antigravity CLI $(agy --version 2>/dev/null | head -1) — native, no proot."; else say "Installed; run 'agy' to finish."; fi
echo
say "DNS: auto — native /etc/resolv.conf if you have a resolv module, else /sdcard/.grokdns (no root)."
say "Sign in with:  agy    (opens Google login)"
