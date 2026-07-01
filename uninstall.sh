#!/data/data/com.termux/files/usr/bin/bash
#
# uninstall.sh — remove the native Antigravity CLI launcher + install dir.
# Leaves glibc, the shared DNS shim, and ~/.gemini/antigravity-cli (config/creds).
#
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DIR="$HOME/agents/antigravity"
say(){ printf '\033[1;35m[agy-native]\033[0m %s\n' "$*"; }

say "Removing launcher symlink…"; rm -f "$PREFIX/bin/agy"
say "Removing install dir ($DIR: agy, ld.so, launcher, fix-align)…"; rm -rf "$DIR"
say "Left intact: glibc, the shared DNS shim, and ~/.gemini/antigravity-cli."
say "To remove config/creds too:  rm -rf ~/.gemini/antigravity-cli"
