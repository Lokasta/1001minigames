# 1001 Minigames

A TikTok-style collection of bite-sized minigames. Swipe up, play, repeat.

Built with **Haxe** + **Heaps.io** -- runs on HTML5 and Android.

---

## Minigames

| Game | Type | Description |
|------|------|-------------|
| Flappy Bird | 2D | Tap to fly through pipes |
| Dino Runner | 2D | Jump over cacti, endless runner |
| Snake | 2D | Classic snake -- eat and grow |
| Guitar Hero | 2D | Hit the notes in rhythm |
| Fruit Ninja | 3D | Slash falling fruits with your finger |
| Penalty Shootout | 3D | Aim and kick to score goals |
| Car Racer | 3D | Dodge traffic on the highway |
| Whack-a-Mole | 2D | Smash the moles before they hide |
| Simon Says | 2D | Memorize and repeat the color sequence |
| Subway Surfers | 3D | Run, dodge trains, collect coins |

...and more coming!

---

## How It Works

The game is a vertical **feed of slides** -- like a social media feed but with games:

1. **Start screen** -- swipe up to begin
2. **Random minigame** starts instantly
3. **Lose** -- see your score, swipe up for the next one
4. Repeat forever

Each minigame implements a simple interface (`IMinigameScene`) and gets dropped into the feed automatically.

---

## Quick Start

### Prerequisites

- [Haxe 4.3+](https://haxe.org/download/)
- [Node.js](https://nodejs.org/) (for the dev server with hot reload)

### Setup

```bash
# Install Heaps engine
haxelib git heaps https://github.com/HeapsIO/heaps.git

# Install Node dependencies (dev server)
npm install
```

On macOS, you may need to set the Haxe std path:
```bash
export HAXE_STD_PATH="/opt/homebrew/lib/haxe/std"
```

### Build & Run (HTML5)

```bash
# One-shot compile
haxe compile.hxml

# Or dev mode with hot reload
npm run dev
```

Open **http://localhost:8080** and start playing.

### Build (Android)

```bash
haxe compile_android.hxml
cd android && ./gradlew assembleDebug
```

See [docs/ANDROID.md](docs/ANDROID.md) for the full setup guide.

### Deploy to itch.io

```bash
ITCH_PROJECT=youruser/1001minigames npm run deploy:itch
```

See [docs/ITCH.md](docs/ITCH.md) for details.

---

## Adding a New Minigame

1. Create `src/scenes/minigames/YourGame.hx`
2. Implement `IMinigameScene` (and optionally `IMinigameUpdatable`, `IMinigame3D`, `IMinigameSceneWithLose`)
3. Register in `Main.hx`:
   ```haxe
   gameFlow.registerMinigame("Your Game", function() return new scenes.minigames.YourGame());
   ```

That's it. It shows up in the feed rotation and the debug menu.

---

## Project Structure

```
src/
  Main.hx                    # Entry point, registers all minigames
  core/                      # GameFlow (feed engine), swipe detection, contracts
    GameFlow.hx              # Feed of slides: Start -> Play -> Score -> repeat
    FeedbackManager.hx       # Camera shake, zoom, flash, fade effects
    IMinigameScene.hx        # Interface every minigame implements
  scenes/
    StartScreen.hx           # Initial swipe-up screen
    ScoreScreen.hx           # Post-game score display
    minigames/               # All minigame implementations
  shared/                    # Easing functions, utilities
```

See [docs/ARQUITETURA.md](docs/ARQUITETURA.md) for the full architecture doc.

---

## Debug

Press **K** to open the debug menu and jump directly to any minigame.

---

## Tech Stack

- **[Haxe](https://haxe.org/)** -- typed, cross-platform language
- **[Heaps.io](https://heaps.io/)** -- high-performance 2D/3D game engine
- **Targets**: HTML5 (WebGL), Android (native via HashLink)

## License

MIT -- open source, have fun with it!
