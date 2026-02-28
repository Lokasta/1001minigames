# Changelog

## 2026-02-28
- **Feature**: Sliding Puzzle minigame — classic 15-puzzle, 4x4 grid, tap adjacent tile or swipe to slide, colored numbered tiles with correct-position glow, 2-min timer, score based on moves + time left
- **Feature**: 2048 minigame — 4x4 grid, swipe to slide tiles, equal tiles merge, score = sum of merges, warm color palette matching original 2048, game over when no moves left
- **UI**: Dino Runner full polish — swipe up to jump, swipe down to duck (timer-based 0.6s), dust particles on jump/land/run, parallax clouds, gradient sky with sun/moon, better dino with tail/arms/spikes, cactus shadows & spines, double cactus clusters at high difficulty, distance-based scoring, near-miss detection, landing squash, speed ramp with ease-out curve
- **UI**: Start Screen visual overhaul — gradient background, pulsing glow rings, floating particles, animated chevrons, title shadow, subtitle decorative line
- **UI**: Score Screen & Penalty 3D visual polish
- **Feature**: Generic hash-based minigame launcher (e.g. #dino, #knife, #3) for testing
- **Feature**: Native iOS build - Haxe/HashLink/C pipeline with SDL2 2.30.11, CMake + Xcode, runs on real iOS devices
- **DevOps**: iOS setup script (`scripts/setup-ios.sh`) downloads SDL2 & HashLink source, patches for iOS, generates Xcode project
- **DevOps**: Updated .gitignore to exclude large iOS/Android deps and build artifacts (open-source safe)

## 2026-02-27
- **Feature**: Red Light Green Light minigame - Round 6 style, hold to run forward, release on red light, doll turns around on red (menacing eyes), traffic light (green/yellow/red), rival NPCs running alongside, reach finish line for bonus + new round with harder timing, speed increases each round
- **Feature**: Timing Ball minigame - bouncing ball with gravity, tap to bounce upward, red obstacle bars scroll down with gaps to pass through, gap shrinks over time (80→50px), speed ramp (100→220 px/s), squash/stretch ball animation, trail particles, floor shadow
- **Feature**: Stack minigame - sliding blocks, tap to stack perfectly, cut piece falls off with gravity, perfect placement streak bonus (width grows back), 8-color cycling palette, camera scrolls up as stack grows, speed ramp 120→320 px/s over 40 blocks
- **Feature**: Knife Hit minigame - rotating wooden board with humanoid target (circus style), tap to throw knives, avoid hitting the person or other stuck knives, rotation speed ramp + direction changes, knife blade/handle rendering
- **Feature**: Tap the Color minigame - Stroop test: color word displayed in different ink color, tap the button matching the INK color, 6 colors, 4 options per round, timer shrinks as score increases (3s→1s), wrong tap or timeout = game over
- **Feature**: Tetris minigame - 10x20 board, 7 tetrominoes with wall kicks, ghost piece preview, next piece display, drag to move/tap to rotate/swipe down to hard drop, line clear scoring (100/300/500/800), speed ramp, lock delay

## 2026-02-24
- **Feature**: Penalty 3D game feel overhaul — swipe power affects shot speed, gravity arc, after-touch to bend ball mid-flight, post/crossbar/keeper collision with bouncing, ball flies into distance on miss
- **Fix**: FeedbackManager shake2D no longer clobbers 3D camera on shake end
- **Fix**: Penalty 3D camera now consistent — full goal, keeper, and ball always visible on init and restart
- **Feature**: Pac-Man minigame - compact maze, swipe to change direction, eat dots & power pellets, 3 ghosts with chase/scared AI, tunnel wrapping, score = dots eaten + ghost bonuses
- **Feature**: Asteroids minigame - virtual joystick controls (hold+drag to thrust/rotate, tap to shoot), asteroids split on hit (large→2 medium→2 small), ship wraps edges, drift physics
- **UI**: DebugMenu now scrollable with drag-to-scroll and scrollbar (supports 13+ minigames)
- **Feature**: Debug menu activatable on mobile via 3-finger hold for 3 seconds

## 2026-02-23
- **Feature**: Space Invaders minigame - 5x3 alien grid, player ship shoots upward, aliens shoot back, speed increases as aliens die
- **Feature**: Pong minigame - paddle do jogador embaixo, IA em cima, bola acelera com o tempo
- **Fix**: Renomeia "Aca-mou" para "Whack-a-Mole" no menu de minigames
- **Docs**: Mobile-first note no CLAUDE.md, marca Pong como implementado no GAMES_TODO
- **Fix**: Fruit Ninja - corrige camera 3D (up vector degenerado causava inversao do eixo X) e sistema de colisao do slash (colisao continua, trail aging, splash colorido)
- **Feature**: CLAUDE.md criado com guia de build, arquitetura e convencoes do projeto

## 2026-02-22
- **Feature**: Estado atual do jogo: feed de slides, minigames (Flappy Bird, Dino Runner, Cobrinha, Guitar Hero, Fruit Ninja, Penalti 3D, Corrida, Whack-a-Mole, Simon Says, Subway Surfers 3D), setup Android

## 2026-02-21
- **Feature**: Initial Heaps.io project: git, Haxe/Heaps setup, Hello World HTML5
