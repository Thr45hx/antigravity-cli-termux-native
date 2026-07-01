# antigravity-cli-termux-native

Run **Google's Antigravity CLI (`agy`) fully native on Termux** (Android · aarch64) — **no proot, no chroot, no container.**

Google ships Antigravity CLI only as a **glibc-dynamic Go binary** for `linux_arm64`. On Termux (bionic) it normally can't run at all — it `SIGSEGV`s in the loader before `main()`. This installer gets it running natively, sign-in and streaming models included.

> Runtime only — no account data. First `agy` run does the Google sign-in; creds live in `~/.gemini/antigravity-cli/`.

## Demo — Antigravity explaining its own install

Asked how it's running, Antigravity inspects its own launcher on-device (Android 17, Pixel 9 Pro XL) and walks through the exact tricks that make a desktop-Linux Go binary run native on a phone:

![Antigravity explains its native install](screenshots/antigravity-explains-native.png)

## Why it's hard — and the four fixes

| # | Problem | Fix |
|---|---------|-----|
| 1 | **2 MB-aligned segments.** Go ships `PT_LOAD` segments with `p_align = 0x200000`; Termux's glibc loader can't map them → `SIGSEGV` at *"generating link map"*. | `fix-align.py` rewrites the oversized `p_align` fields down to page size (`0x1000`). Safe: 2 MB-congruent ⇒ page-congruent. |
| 2 | **patchelf corrupts Go binaries.** The usual "patchelf the interpreter" trick crashes the Go binary. | Don't patchelf. Invoke the glibc loader **directly**: `ld.so --library-path … ./agy`. |
| 3 | **Self-update overwrites the loader.** `agy` self-updates by overwriting `/proc/self/exe` — which, run via `ld.so agy`, is the *loader*. | Run `agy` through a **private disposable copy** of the loader (`~/agents/antigravity/ld.so`). A self-update clobbers the throwaway (never the shared system loader), and the launcher **adopts** that downloaded binary as the new `agy` on the next run — so **auto-update stays ON and actually persists**. |
| 4 | **Interactive helpers + DNS + TLS.** agy spawns glibc helper processes interactively that die with `libc.so: invalid ELF header`; Go's resolver can't reach DNS; Go can't find CA certs. | An `LD_PRELOAD` shim (`claude-resolvfix.so`) scrubs `LD_PRELOAD`/`LD_LIBRARY_PATH` so helpers load cleanly, and redirects `/etc/resolv.conf`. `GODEBUG=netdns=cgo` pins the glibc resolver so the shim catches it; `SSL_CERT_FILE` points TLS at Termux's CA bundle. |

## Requirements

- Termux on **aarch64 / arm64**
- Internet on first run
- `clang` (installed automatically — used once to build the tiny DNS shim)

## Install

```bash
git clone https://github.com/Thr45hx/antigravity-cli-termux-native
cd antigravity-cli-termux-native
bash install.sh
```

or one-shot:

```bash
curl -fsSL https://raw.githubusercontent.com/Thr45hx/antigravity-cli-termux-native/main/install.sh | bash
```

Then sign in:

```bash
agy
```

## DNS: works with or without root

DNS goes through the `claude-resolvfix.so` shim, which redirects agy's `/etc/resolv.conf` reads to `$PREFIX/etc/resolv.conf`. The launcher keeps that target current every run:

- **No root (default):** `$PREFIX/etc/resolv.conf` is seeded with `8.8.8.8 / 8.8.4.4`. Zero root, zero proot.
- **Rooted:** if a real `/etc/resolv.conf` exists (e.g. a systemless module mounting `/system/etc/resolv.conf`, since `/etc → /system/etc`), the launcher **syncs it into the shim target** — so the module's nameservers are exactly what agy resolves through.

The shim isn't only for DNS: its constructor scrubs the glibc loader vars so the helper processes agy spawns in interactive mode load cleanly (that's what fixes the `libc.so: invalid ELF header` crash).

## Install layout

```
~/agents/antigravity/
├── agy           # Antigravity CLI binary (segments re-aligned)
├── ld.so         # private disposable glibc loader (self-update sacrifice / adopt source)
├── agy.bak       # last-good binary, kept when a self-update is adopted (rollback)
├── fix-align.py  # the p_align rewriter
├── fix_resolv.c  # DNS/env-scrub shim source (built once to $PREFIX/lib/claude-resolvfix.so)
└── launcher.sh   # ← $PREFIX/bin/agy symlinks here
```

## Files

- `install.sh` — one-command installer (pulls the glibc arm64 build from Google's release manifest, builds the shim, applies all four fixes)
- `launcher.sh` → `$PREFIX/bin/agy`
- `fix-align.py` — the `p_align` rewriter
- `fix_resolv.c` — the `LD_PRELOAD` DNS + env-scrub shim
- `uninstall.sh`

## Uninstall

```bash
bash uninstall.sh
```

## Part of the native-Termux CLI family

One-command **native, no-proot** installers for AI coding CLIs on Termux — same toolkit, one per agent:

- [claude-code-termux-native](https://github.com/Thr45hx/claude-code-termux-native) — Claude Code
- [antigravity-cli-termux-native](https://github.com/Thr45hx/antigravity-cli-termux-native) — Google Antigravity
- [grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native) — xAI Grok Build
- [opencode-termux-native](https://github.com/Thr45hx/opencode-termux-native) — OpenCode
- [copilot-cli-termux-native](https://github.com/Thr45hx/copilot-cli-termux-native) — GitHub Copilot

## Notes

- **AI-assisted:** built and reverse-engineered with AI help — a daily-driver, not a toy. Provided as-is.
- **Tested on:** Android 17, rooted **Pixel 9 Pro XL** (Tensor G4, aarch64).
- **Root / no-root:** both supported — no-root seeds a resolv file; rooted syncs DNS from a systemless resolv module.
- **License:** [MIT](./LICENSE).

---

Unofficial — not affiliated with Google. Provided as-is, no warranty. `agy` self-updates in the background; the private-loader + adopt mechanism keeps that safe and persistent.
