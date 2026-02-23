# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TokTok Games is a TikTok-style feed of minigames built with **Haxe** and **Heaps.io** (2D/3D game engine). The app presents minigames in a vertical swipeable feed: Start Screen → Minigame → Score Screen → swipe up → next Minigame.

Design resolution: **360x640** (mobile portrait, LetterBox scale mode).

## Build & Run Commands

- **Compile (HTML5):** `haxe compile.hxml` — outputs `hello.js`
- **Dev mode (hot reload):** `npm run dev` — watches `src/` files, recompiles, serves at `http://localhost:8080`
- **Compile (Android/C):** `haxe compile_android.hxml` — outputs C to `android/app/src/main/cpp/out/`
- **Android APK:** `cd android && ./gradlew assembleDebug`

There are no tests or linting configured.

## Architecture

### Feed System (core/)

`GameFlow` is the central state machine with three states: **Start**, **Playing**, **Score**. It manages slide transitions (swipe up to advance), random minigame selection, and the render loop.

- `SwipeDetector` — handles swipe gesture detection on a transparent Interactive overlay
- `FeedbackManager` — reusable visual effects system (camera shake, zoom, flash, fade, FOV, clipping) accessed by minigames via `ctx.feedback`
- `DebugMenu` — dev overlay (press **K** to toggle, **Esc** to close) for jumping directly to any minigame
- `MinigameContext` — passed to minigames; provides `lose(score, id)` callback and access to `feedback`

### Minigame Contracts (interfaces)

Every minigame implements one or more of these:

| Interface | Purpose |
|-----------|---------|
| `IMinigameScene` | Required. Provides `content: Object`, `start()`, `dispose()`, `getMinigameId()`, `getTitle()` |
| `IMinigameSceneWithLose` | Has `setOnLose(ctx)` — minigame calls `ctx.lose(score, id)` on game over |
| `IMinigameUpdatable` | Has `update(dt)` — called every frame by GameFlow |
| `IMinigame3D` | Has `setScene3D(s3d)` — for minigames that use the 3D scene |

### Rendering

`Main.render()` renders 2D first (`s2d`), then 3D (`s3d`). For 3D minigames, the 3D viewport is clipped to the letterbox area via `setRenderZone`.

### Adding a New Minigame

1. Create `src/scenes/minigames/NewGame.hx` implementing `IMinigameSceneWithLose` (and optionally `IMinigameUpdatable`, `IMinigame3D`)
2. Build all visuals as children of `contentObj: Object` (created in constructor)
3. Register in `Main.init()`: `gameFlow.registerMinigame("Name", function() return new scenes.minigames.NewGame());`
4. Call `ctx.lose(score, getMinigameId())` when the player loses

See `ExampleMinigame.hx` for the simplest reference implementation.

## Key Conventions

- Language is **Haxe** — use Haxe idioms, not Java/C# patterns
- All coordinates use the 360x640 design space (LetterBox handles scaling)
- Minigames are fully self-contained scenes; shared utilities go in `shared/`
- Resources go in `res/` (currently empty — all graphics are procedural via `h2d.Graphics`)
- Documentation in `docs/` is in Portuguese (ARQUITETURA.md, CONCEITO_TIKTOK_GAMES.md, etc.)

## Environment Requirements

- Haxe 4+ (`brew install haxe`)
- Heaps library (`haxelib git heaps https://github.com/HeapsIO/heaps.git`)
- `HAXE_STD_PATH="/opt/homebrew/lib/haxe/std"` must be set
- Node.js only needed for `npm run dev` (hot reload via nodemon + live-server)
