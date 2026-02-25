# AGENTS.md

## Cursor Cloud specific instructions

### Overview

TokTok Games is a client-side Haxe/Heaps.io WebGL game — no backend, no database, no external services. See `CLAUDE.md` for architecture details, build commands, and conventions.

### System Dependencies (pre-installed in VM snapshot)

- **Haxe 4.3.6** via `ppa:haxe/releases` (`/usr/bin/haxe`)
- **Heaps.io** installed via `haxelib git heaps https://github.com/HeapsIO/heaps.git` (with `format` dependency)
- **haxelib repo** at `/usr/share/haxe/lib`
- **HAXE_STD_PATH** set to `/usr/share/haxe/std` in `~/.bashrc`
- **Node.js** (pre-existing) for dev tooling only

### Running the App

- `npm run dev` starts both file watcher (auto-recompile on `.hx` changes) and `live-server` on port **8080**
- Alternatively: `haxe compile.hxml` to compile once, then `npx live-server . --port=8080 --no-browser` to serve
- No tests or linting are configured (per `CLAUDE.md`)

### Gotchas

- `HAXE_STD_PATH` must be set before running `haxe`. If compilation fails with "std not found", run `export HAXE_STD_PATH="/usr/share/haxe/std"`.
- The haxelib repository is at `/usr/share/haxe/lib` (not the default user-home location). If `haxelib list` returns empty, run `haxelib setup /usr/share/haxe/lib`.
- `live-server` opens a browser by default; use `--no-browser` flag in headless environments.
- The game renders on a WebGL canvas at 360x640 design resolution with LetterBox scaling. Use the Debug Menu (press **K**) to jump directly to specific minigames during testing.
