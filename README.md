# antigravity-cli-termux-native

Run **Google's Antigravity CLI (`agy`) fully native on Termux** (Android · aarch64) — **no proot, no chroot, no container.**

Google ships Antigravity CLI only as a **glibc-dynamic Go binary** for `linux_arm64`. On Termux (bionic) it normally can't run at all — it `SIGSEGV`s in the loader before `main()`. This installer gets it running natively, sign-in and streaming models included.

> Runtime only — no account data. First `agy` run does the Google sign-in; creds live in `~/.gemini/antigravity-cli/`.

## Why it's hard — and the four fixes

| # | Problem | Fix |
|---|---------|-----|
| 1 | **2 MB-aligned segments.** Go ships `PT_LOAD` segments with `p_align = 0x200000`; Termux's glibc loader can't map them → `SIGSEGV` at *"generating link map"*. | `fix-align.py` rewrites the oversized `p_align` fields down to page size (`0x1000`). Safe: 2 MB-congruent ⇒ page-congruent. |
| 2 | **patchelf corrupts Go binaries.** The usual "patchelf the interpreter to Termux's glibc loader" trick crashes the Go binary. | Don't patchelf. Invoke the glibc loader **directly**: `ld.so --library-path … ./agy`, leaving the bytes untouched. |
| 3 | **Self-update bricks the system.** `agy` self-updates by overwriting `/proc/self/exe`. Run via `ld.so agy`, that's the *loader* → an update overwrites `ld-linux-aarch64.so.1` and bricks **every** glibc program. | Run `agy` through a **private, disposable copy** of the loader (`~/agents/antigravity/ld.so`). A self-update clobbers the throwaway; the launcher heals it next run. |
| 4 | **DNS + TLS fail.** Go's pure resolver reads `/etc/resolv.conf` via a raw syscall (absent on Termux) → dead `[::1]:53`; and Go can't find CA certs. | `GODEBUG=netdns=cgo` forces glibc's resolver, whose `resolv.conf` read an `LD_PRELOAD` shim redirects to `$PREFIX/etc/resolv.conf`. `SSL_CERT_FILE` points TLS at Termux's CA bundle. |

## Requirements

- Termux on **aarch64 / arm64**
- Internet on first run

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

## Install layout

```
~/agents/antigravity/
├── agy           # Antigravity CLI binary (segments re-aligned)
├── ld.so         # private disposable glibc loader (self-update sacrifice)
├── fix-align.py
└── launcher.sh   # ← $PREFIX/bin/agy symlinks here
$PREFIX/lib/claude-resolvfix.so   # DNS shim (shared)
```

## Files

- `install.sh` — one-command installer (pulls the glibc arm64 build from Google's release manifest, applies all four fixes)
- `launcher.sh` → `$PREFIX/bin/agy` — runtime wrapper (align-heal + private loader + cgo DNS + CA)
- `fix-align.py` — the `p_align` rewriter (idempotent; runs each launch to survive self-updates)
- `fix_resolv.c` — the `/etc/resolv.conf` `LD_PRELOAD` shim, shared with [claude-code-termux-native](https://github.com/Thr45hx/claude-code-termux-native)
- `uninstall.sh`

## Cleaner DNS (optional, rooted)

The `cgo` + shim DNS is a userland workaround. On a **Magisk**-rooted device, a systemless `/system/etc/resolv.conf` (since `/etc → /system/etc`) provides a real `/etc/resolv.conf` — then Go's default resolver works with **zero** shim/`GODEBUG`, on the pristine binary.

## Uninstall

```bash
bash uninstall.sh
```

---

Unofficial — not affiliated with Google. Provided as-is, no warranty. `agy` self-updates in the background; the private-loader mechanism keeps that safe.
