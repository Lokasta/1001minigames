package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import hxd.Event;
import hxd.Key;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	2048: deslize os números, combine até morrer.
	Swipe em qualquer direção, tiles iguais se fundem.
	Score = soma de todos os merges.
**/
class Game2048 implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRID_SIZE = 4;
	static var TILE_SIZE = 72;
	static var TILE_GAP = 6;
	static var BOARD_PAD = 8;
	static var SWIPE_THRESHOLD = 32;
	static var ANIM_DURATION = 0.12;
	static var SPAWN_ANIM_DUR = 0.15;
	static var MERGE_POP_DUR = 0.15;
	static var DEATH_DUR = 0.6;
	static var DEATH_DELAY = 0.3;
	static var MAX_PARTICLES = 50;
	static var FLOAT_TEXT_POOL = 4;

	final contentObj:Object;
	var ctx:MinigameContext;

	// Graphics layers
	var bgG:Graphics;
	var boardG:Graphics;
	var tilesContainer:Object;
	var particlesG:Object;
	var uiG:Graphics;
	var flashG:Graphics;
	var floatTextsG:Object;
	var scoreText:Text;
	var bestText:Text;
	var titleText:Text;
	var gameOverText:Text;
	var interactive:Interactive;

	// Grid state
	var grid:Array<Array<Int>>;
	var score:Int;
	var bestScore:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	// Persistent tile objects: tileObjects[r][c] = {obj, gfx, txt} or null
	var tileObjects:Array<Array<TileObj>>;

	// Input
	var touchStartX:Float;
	var touchStartY:Float;
	var touchDown:Bool;

	// Animation
	var animating:Bool;
	var animPhase:AnimPhase;
	var slideAnims:Array<SlideAnim>;
	var popAnims:Array<PopAnim>;
	var pendingMerges:Array<MergeInfo>;
	var pendingSpawn:{r:Int, c:Int};
	var pendingGameOver:Bool;
	var pendingMergeScore:Int;

	// Particles
	var particles:Array<ParticleData>;
	var particlePool:Array<Graphics>;

	// Floating score texts
	var floatingTexts:Array<FloatText>;
	var floatTextPool:Array<Text>;

	// Score pulse
	var scorePulseTimer:Float;
	var scoreBaseScale:Float;

	// Invalid shake
	var invalidShakeTimer:Float;

	// Board position
	var boardX:Float;
	var boardY:Float;
	var boardSize:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;
		grid = [for (_ in 0...GRID_SIZE) [for (_ in 0...GRID_SIZE) 0]];
		bestScore = 0;
		scoreBaseScale = 1.4;

		boardSize = GRID_SIZE * TILE_SIZE + (GRID_SIZE + 1) * TILE_GAP + BOARD_PAD * 2;
		boardX = (DESIGN_W - boardSize) / 2;
		boardY = 180;

		bgG = new Graphics(contentObj);
		boardG = new Graphics(contentObj);
		tilesContainer = new Object(contentObj);
		particlesG = new Object(contentObj);
		uiG = new Graphics(contentObj);
		floatTextsG = new Object(contentObj);
		flashG = new Graphics(contentObj);

		titleText = new Text(hxd.res.DefaultFont.get(), contentObj);
		titleText.text = "2048";
		titleText.x = 20;
		titleText.y = 30;
		titleText.scale(3.0);
		titleText.textColor = 0x776E65;

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W - 20;
		scoreText.y = 35;
		scoreText.scale(scoreBaseScale);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xEEE4DA;

		bestText = new Text(hxd.res.DefaultFont.get(), contentObj);
		bestText.text = "";
		bestText.x = DESIGN_W - 20;
		bestText.y = 55;
		bestText.scale(1.0);
		bestText.textAlign = Right;
		bestText.textColor = 0xEEE4DA;

		gameOverText = new Text(hxd.res.DefaultFont.get(), contentObj);
		gameOverText.text = "Game Over!";
		gameOverText.x = DESIGN_W / 2;
		gameOverText.y = boardY + boardSize / 2 - 10;
		gameOverText.scale(2.5);
		gameOverText.textAlign = Center;
		gameOverText.textColor = 0x776E65;
		gameOverText.visible = false;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || animating) return;
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchDown = true;
			e.propagate = false;
		};
		interactive.onRelease = onTouchEnd;
		interactive.onReleaseOutside = onTouchEnd;

		// Init tile objects array
		tileObjects = [for (_ in 0...GRID_SIZE) [for (_ in 0...GRID_SIZE) null]];

		// Init animation arrays
		slideAnims = [];
		popAnims = [];
		pendingMerges = [];
		animPhase = Idle;

		// Init particles
		particles = [];
		particlePool = [];
		for (_ in 0...MAX_PARTICLES) {
			var g = new Graphics(particlesG);
			g.visible = false;
			particlePool.push(g);
		}

		// Init floating texts
		floatingTexts = [];
		floatTextPool = [];
		for (_ in 0...FLOAT_TEXT_POOL) {
			var t = new Text(hxd.res.DefaultFont.get(), floatTextsG);
			t.visible = false;
			t.textAlign = Center;
			floatTextPool.push(t);
		}

		scorePulseTimer = -1;
		invalidShakeTimer = -1;
	}

	function onTouchEnd(e:Event) {
		if (!touchDown || gameOver || animating) return;
		touchDown = false;
		var dx = e.relX - touchStartX;
		var dy = e.relY - touchStartY;
		if (Math.abs(dx) < SWIPE_THRESHOLD && Math.abs(dy) < SWIPE_THRESHOLD) return;

		var dir:Int;
		if (Math.abs(dx) > Math.abs(dy)) {
			dir = dx > 0 ? 1 : 3;
		} else {
			dir = dy > 0 ? 2 : 0;
		}
		tryMove(dir);
		e.propagate = false;
	}

	// ── Grid Logic (UNCHANGED) ──────────────────────────────────

	function doMove(dir:Int):Int {
		var mergedScore = 0;
		for (i in 0...GRID_SIZE) {
			var line = getLine(i, dir);
			var result = mergeLine(line);
			mergedScore += result.score;
			setLine(i, dir, result.line);
		}
		return mergedScore;
	}

	function getLine(index:Int, dir:Int):Array<Int> {
		var line = [];
		for (j in 0...GRID_SIZE) {
			switch (dir) {
				case 0: line.push(grid[j][index]);
				case 1: line.push(grid[index][GRID_SIZE - 1 - j]);
				case 2: line.push(grid[GRID_SIZE - 1 - j][index]);
				case 3: line.push(grid[index][j]);
				default:
			}
		}
		return line;
	}

	function setLine(index:Int, dir:Int, line:Array<Int>) {
		for (j in 0...GRID_SIZE) {
			switch (dir) {
				case 0: grid[j][index] = line[j];
				case 1: grid[index][GRID_SIZE - 1 - j] = line[j];
				case 2: grid[GRID_SIZE - 1 - j][index] = line[j];
				case 3: grid[index][j] = line[j];
				default:
			}
		}
	}

	function mergeLine(line:Array<Int>):{line:Array<Int>, score:Int} {
		var nonZero:Array<Int> = [];
		for (v in line)
			if (v != 0) nonZero.push(v);

		var merged:Array<Int> = [];
		var mergeScore = 0;
		var i = 0;
		while (i < nonZero.length) {
			if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
				var val = nonZero[i] * 2;
				merged.push(val);
				mergeScore += val;
				i += 2;
			} else {
				merged.push(nonZero[i]);
				i++;
			}
		}

		while (merged.length < GRID_SIZE)
			merged.push(0);

		return {line: merged, score: mergeScore};
	}

	function spawnRandomTile():{r:Int, c:Int} {
		var empty:Array<{r:Int, c:Int}> = [];
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] == 0) empty.push({r: r, c: c});

		if (empty.length == 0) return null;
		var cell = empty[Std.random(empty.length)];
		grid[cell.r][cell.c] = Math.random() < 0.9 ? 2 : 4;
		return cell;
	}

	function hasMovesLeft():Bool {
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] == 0) return true;
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var v = grid[r][c];
				if (c + 1 < GRID_SIZE && grid[r][c + 1] == v) return true;
				if (r + 1 < GRID_SIZE && grid[r + 1][c] == v) return true;
			}
		}
		return false;
	}

	// ── Move with animation tracking ────────────────────────────

	function tryMove(dir:Int) {
		var oldGrid = [for (r in 0...GRID_SIZE) [for (c in 0...GRID_SIZE) grid[r][c]]];
		var mergedScore = doMove(dir);

		var changed = false;
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] != oldGrid[r][c]) changed = true;

		if (!changed) {
			// Invalid move — shake feedback
			invalidShakeTimer = 0;
			return;
		}

		score += mergedScore;
		scoreText.text = Std.string(score);

		// Score pulse
		if (mergedScore > 0) {
			scorePulseTimer = 0;
		}

		// Feedback on merge
		if (mergedScore > 0 && ctx != null && ctx.feedback != null) {
			if (mergedScore >= 64)
				ctx.feedback.shake2D(0.12, 3);
			if (mergedScore >= 256)
				ctx.feedback.flash(0xFFFFFF, 0.08);
		}

		// Compute move results for animation by comparing old to new grid
		var moveInfos = computeMoveResults(oldGrid, dir);
		pendingMerges = moveInfos.merges;
		pendingMergeScore = mergedScore;

		// Spawn new tile
		var spawned = spawnRandomTile();
		pendingSpawn = spawned;

		// Check game over (after spawn)
		pendingGameOver = !hasMovesLeft();

		// Start slide animations
		startSlideAnimations(oldGrid, moveInfos.slides);
	}

	function computeMoveResults(oldGrid:Array<Array<Int>>, dir:Int):{slides:Array<SlideInfo>, merges:Array<MergeInfo>} {
		var slides:Array<SlideInfo> = [];
		var merges:Array<MergeInfo> = [];

		for (lineIdx in 0...GRID_SIZE) {
			// Get old line with positions
			var oldLine:Array<{val:Int, r:Int, c:Int}> = [];
			for (j in 0...GRID_SIZE) {
				var r = 0;
				var c = 0;
				switch (dir) {
					case 0: r = j; c = lineIdx;
					case 1: r = lineIdx; c = GRID_SIZE - 1 - j;
					case 2: r = GRID_SIZE - 1 - j; c = lineIdx;
					case 3: r = lineIdx; c = j;
					default:
				}
				if (oldGrid[r][c] != 0) {
					oldLine.push({val: oldGrid[r][c], r: r, c: c});
				}
			}

			// Process merges (same as mergeLine but with position tracking)
			var i = 0;
			var destIdx = 0;
			while (i < oldLine.length) {
				// Compute destination position for destIdx in this line direction
				var dr = 0;
				var dc = 0;
				switch (dir) {
					case 0: dr = destIdx; dc = lineIdx;
					case 1: dr = lineIdx; dc = GRID_SIZE - 1 - destIdx;
					case 2: dr = GRID_SIZE - 1 - destIdx; dc = lineIdx;
					case 3: dr = lineIdx; dc = destIdx;
					default:
				}

				if (i + 1 < oldLine.length && oldLine[i].val == oldLine[i + 1].val) {
					// Merge: both tiles slide to dest
					slides.push({fromR: oldLine[i].r, fromC: oldLine[i].c, toR: dr, toC: dc, val: oldLine[i].val});
					slides.push({fromR: oldLine[i + 1].r, fromC: oldLine[i + 1].c, toR: dr, toC: dc, val: oldLine[i + 1].val});
					merges.push({r: dr, c: dc, val: oldLine[i].val * 2});
					i += 2;
				} else {
					// Slide only
					if (oldLine[i].r != dr || oldLine[i].c != dc) {
						slides.push({fromR: oldLine[i].r, fromC: oldLine[i].c, toR: dr, toC: dc, val: oldLine[i].val});
					}
					i++;
				}
				destIdx++;
			}
		}

		return {slides: slides, merges: merges};
	}

	function startSlideAnimations(oldGrid:Array<Array<Int>>, slides:Array<SlideInfo>) {
		animating = true;
		animPhase = Sliding;
		slideAnims = [];

		// Remove all current tile objects — we'll rebuild after animation
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				if (tileObjects[r][c] != null) {
					tileObjects[r][c].obj.remove();
					tileObjects[r][c] = null;
				}
			}
		}

		if (slides.length == 0) {
			// No slides, skip to pop phase
			onSlidesComplete();
			return;
		}

		// Create static tiles FIRST (lower z-order) for cells that didn't move
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				if (oldGrid[r][c] == 0) continue;
				var didMove = false;
				for (s in slides) {
					if (s.fromR == r && s.fromC == c) {
						didMove = true;
						break;
					}
				}
				if (!didMove) {
					var obj = createTileObj(oldGrid[r][c], r, c);
					var pos = cellScreenPos(r, c);
					obj.x = pos.x + TILE_SIZE / 2;
					obj.y = pos.y + TILE_SIZE / 2;
				}
			}
		}

		// Create sliding tile objects AFTER (higher z-order, render on top)
		for (s in slides) {
			var obj = createTileObj(s.val, s.fromR, s.fromC);
			var fromPos = cellScreenPos(s.fromR, s.fromC);
			var toPos = cellScreenPos(s.toR, s.toC);
			obj.x = fromPos.x + TILE_SIZE / 2;
			obj.y = fromPos.y + TILE_SIZE / 2;
			slideAnims.push({
				obj: obj,
				fromX: fromPos.x + TILE_SIZE / 2,
				fromY: fromPos.y + TILE_SIZE / 2,
				toX: toPos.x + TILE_SIZE / 2,
				toY: toPos.y + TILE_SIZE / 2,
				progress: 0,
				duration: ANIM_DURATION
			});
		}
	}

	function onSlidesComplete() {
		// Clean up all temporary tile objects from tilesContainer
		while (tilesContainer.numChildren > 0)
			tilesContainer.getChildAt(0).remove();

		// Rebuild tile objects from current grid state
		syncTileVisuals();

		// Start merge pops + spawn + floating texts
		animPhase = Popping;
		popAnims = [];

		// Merge pop animations
		for (m in pendingMerges) {
			var to = tileObjects[m.r][m.c];
			if (to != null) {
				popAnims.push({
					obj: to.obj,
					progress: 0,
					duration: MERGE_POP_DUR,
					type: MergePop
				});
			}
			// Emit particles at merge location
			var pos = cellScreenPos(m.r, m.c);
			var cx = pos.x + TILE_SIZE / 2;
			var cy = pos.y + TILE_SIZE / 2;
			var color = tileColor(m.val);
			var count = if (m.val >= 512) 10 else if (m.val >= 128) 7 else 5;
			emitParticles(cx, cy, color, count);

			// Floating +N
			showFloatingScore(cx, cy, m.val, color);
		}

		// Spawn scale-in animation
		if (pendingSpawn != null) {
			var to = tileObjects[pendingSpawn.r][pendingSpawn.c];
			if (to != null) {
				to.obj.scaleX = 0;
				to.obj.scaleY = 0;
				popAnims.push({
					obj: to.obj,
					progress: 0,
					duration: SPAWN_ANIM_DUR,
					type: SpawnScale
				});
			}
		}

		if (popAnims.length == 0) {
			onPopsComplete();
		}
	}

	function onPopsComplete() {
		animPhase = Idle;
		animating = false;

		if (pendingGameOver) {
			gameOver = true;
			deathTimer = -DEATH_DELAY;
			gameOverText.text = "Game Over! Score: " + Std.string(score);
			gameOverText.visible = true;
		}
	}

	// ── Tile Object Management ──────────────────────────────────

	function cellScreenPos(r:Int, c:Int):{x:Float, y:Float} {
		return {
			x: boardX + BOARD_PAD + TILE_GAP + c * (TILE_SIZE + TILE_GAP),
			y: boardY + BOARD_PAD + TILE_GAP + r * (TILE_SIZE + TILE_GAP)
		};
	}

	function createTileObj(val:Int, r:Int, c:Int):Object {
		var obj = new Object(tilesContainer);

		var gfx = new Graphics(obj);

		// For tiles >= 512, draw glow
		if (val >= 512) {
			gfx.beginFill(0xEDC22E, 0.15);
			gfx.drawRoundedRect(-TILE_SIZE / 2 - 2, -TILE_SIZE / 2 - 2, TILE_SIZE + 4, TILE_SIZE + 4, 7);
			gfx.endFill();
		}

		// Shadow
		gfx.beginFill(0x000000, 0.06);
		gfx.drawRoundedRect(-TILE_SIZE / 2 + 1, -TILE_SIZE / 2 + 2, TILE_SIZE, TILE_SIZE, 5);
		gfx.endFill();

		// Background
		gfx.beginFill(tileColor(val));
		gfx.drawRoundedRect(-TILE_SIZE / 2, -TILE_SIZE / 2, TILE_SIZE, TILE_SIZE, 5);
		gfx.endFill();

		// Highlight
		gfx.beginFill(0xFFFFFF, 0.12);
		gfx.drawRoundedRect(-TILE_SIZE / 2 + 2, -TILE_SIZE / 2 + 1, TILE_SIZE - 4, 3, 2);
		gfx.endFill();

		// Text shadow for readability on values >= 8
		if (val >= 8) {
			var shadow = new Text(hxd.res.DefaultFont.get(), obj);
			shadow.text = Std.string(val);
			shadow.textAlign = Center;
			shadow.textColor = 0x000000;
			var sc = textScale(val);
			shadow.scale(sc);
			shadow.x = 1;
			shadow.y = -5 * sc + 1;
			shadow.alpha = 0.15;
		}

		// Number
		var txt = new Text(hxd.res.DefaultFont.get(), obj);
		txt.text = Std.string(val);
		txt.textAlign = Center;
		txt.textColor = textColor(val);
		var sc = textScale(val);
		txt.scale(sc);
		txt.x = 0;
		txt.y = -5 * sc;

		return obj;
	}

	function syncTileVisuals() {
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var val = grid[r][c];
				if (val == 0) {
					if (tileObjects[r][c] != null) {
						tileObjects[r][c].obj.remove();
						tileObjects[r][c] = null;
					}
				} else {
					// Always recreate for simplicity (values may have changed from merge)
					if (tileObjects[r][c] != null) {
						tileObjects[r][c].obj.remove();
					}
					var obj = createTileObj(val, r, c);
					var pos = cellScreenPos(r, c);
					obj.x = pos.x + TILE_SIZE / 2;
					obj.y = pos.y + TILE_SIZE / 2;
					tileObjects[r][c] = {obj: obj, val: val};
				}
			}
		}
	}

	// ── Particles ───────────────────────────────────────────────

	function emitParticles(cx:Float, cy:Float, color:Int, count:Int) {
		for (_ in 0...count) {
			if (particles.length >= MAX_PARTICLES) break;

			var g:Graphics = null;
			// Find unused from pool
			for (pg in particlePool) {
				if (!pg.visible) {
					g = pg;
					break;
				}
			}
			if (g == null) break;

			g.clear();
			g.beginFill(color);
			g.drawRect(-2, -2, 4, 4);
			g.endFill();
			g.x = cx;
			g.y = cy;
			g.alpha = 1;
			g.visible = true;

			var angle = Math.random() * Math.PI * 2;
			var speed = 60 + Math.random() * 80;
			particles.push({
				g: g,
				vx: Math.cos(angle) * speed,
				vy: Math.sin(angle) * speed,
				life: 0.3,
				maxLife: 0.3
			});
		}
	}

	// ── Floating Score Texts ────────────────────────────────────

	function showFloatingScore(cx:Float, cy:Float, val:Int, color:Int) {
		var txt:Text = null;
		for (t in floatTextPool) {
			if (!t.visible) {
				txt = t;
				break;
			}
		}
		if (txt == null) return;

		txt.text = "+" + Std.string(val);
		txt.textColor = 0xFFFFFF;
		txt.x = cx;
		txt.y = cy - 15;
		txt.alpha = 1;
		txt.visible = true;
		txt.scale(1.2);

		floatingTexts.push({
			txt: txt,
			vy: -75.0,
			life: 0.4,
			maxLife: 0.4
		});
	}

	// ── Drawing (static elements) ───────────────────────────────

	function tileColor(val:Int):Int {
		return switch (val) {
			case 2: 0xEEE4DA;
			case 4: 0xEDE0C8;
			case 8: 0xF2B179;
			case 16: 0xF59563;
			case 32: 0xF67C5F;
			case 64: 0xF65E3B;
			case 128: 0xEDCF72;
			case 256: 0xEDCC61;
			case 512: 0xEDC850;
			case 1024: 0xEDC53F;
			case 2048: 0xEDC22E;
			default: 0x3C3A32;
		};
	}

	function textColor(val:Int):Int {
		return if (val <= 4) 0x776E65 else 0xFFFFF8;
	}

	function textScale(val:Int):Float {
		if (val < 100) return 1.8;
		if (val < 1000) return 1.4;
		if (val < 10000) return 1.0;
		return 0.85;
	}

	function drawStaticBg() {
		bgG.clear();
		bgG.beginFill(0xFAF8EF);
		bgG.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bgG.endFill();

		bgG.beginFill(0xF0E8D8, 0.3);
		var y = 0;
		while (y < DESIGN_H) {
			bgG.drawRect(0, y, DESIGN_W, 1);
			y += 4;
		}
		bgG.endFill();
	}

	function drawStaticBoard() {
		boardG.clear();
		boardG.beginFill(0xBBADA0);
		boardG.drawRoundedRect(boardX, boardY, boardSize, boardSize, 8);
		boardG.endFill();

		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var pos = cellScreenPos(r, c);
				boardG.beginFill(0xCDC1B4);
				boardG.drawRoundedRect(pos.x, pos.y, TILE_SIZE, TILE_SIZE, 5);
				boardG.endFill();
			}
		}
	}

	function drawUI() {
		uiG.clear();
		while (uiG.numChildren > 0)
			uiG.getChildAt(0).remove();

		var boxW = 80.0;
		var boxH = 45.0;
		var boxX = DESIGN_W - boxW - 15;
		var boxY = 20.0;
		uiG.beginFill(0xBBADA0);
		uiG.drawRoundedRect(boxX, boxY, boxW, boxH, 5);
		uiG.endFill();

		var lbl = new Text(hxd.res.DefaultFont.get(), uiG);
		lbl.text = "SCORE";
		lbl.x = boxX + boxW / 2;
		lbl.y = boxY + 3;
		lbl.scale(0.7);
		lbl.textAlign = Center;
		lbl.textColor = 0xEEE4DA;

		scoreText.x = boxX + boxW / 2 + 2;
		scoreText.y = boxY + 16;
		scoreText.textAlign = Center;

		if (bestScore > 0) {
			var bx = boxX - boxW - 8;
			uiG.beginFill(0xBBADA0);
			uiG.drawRoundedRect(bx, boxY, boxW, boxH, 5);
			uiG.endFill();
			var blbl = new Text(hxd.res.DefaultFont.get(), uiG);
			blbl.text = "BEST";
			blbl.x = bx + boxW / 2;
			blbl.y = boxY + 3;
			blbl.scale(0.7);
			blbl.textAlign = Center;
			blbl.textColor = 0xEEE4DA;
			bestText.x = bx + boxW / 2 + 2;
			bestText.y = boxY + 16;
			bestText.textAlign = Center;
			bestText.text = Std.string(bestScore);
		}

		var hintY = boardY + boardSize + 15;
		var hint = new Text(hxd.res.DefaultFont.get(), uiG);
		hint.text = "Deslize para mover os blocos";
		hint.x = DESIGN_W / 2;
		hint.y = hintY;
		hint.scale(0.9);
		hint.textAlign = Center;
		hint.textColor = 0xBBADA0;

		var hint2 = new Text(hxd.res.DefaultFont.get(), uiG);
		hint2.text = "Combine iguais para chegar ao 2048!";
		hint2.x = DESIGN_W / 2;
		hint2.y = hintY + 18;
		hint2.scale(0.85);
		hint2.textAlign = Center;
		hint2.textColor = 0xCDC1B4;
	}

	// ── Easing Functions ────────────────────────────────────────

	static function easeOutCubic(t:Float):Float {
		var t1 = 1 - t;
		return 1 - t1 * t1 * t1;
	}

	static function easeOutBack(t:Float):Float {
		var c1 = 1.70158;
		var c3 = c1 + 1;
		return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
	}

	// ── Interface ───────────────────────────────────────────────

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		grid = [for (_ in 0...GRID_SIZE) [for (_ in 0...GRID_SIZE) 0]];
		score = 0;
		gameOver = false;
		deathTimer = -1;
		touchDown = false;
		animating = false;
		animPhase = Idle;
		pendingGameOver = false;
		pendingMergeScore = 0;
		gameOverText.visible = false;
		flashG.clear();
		scoreText.text = "0";
		scoreText.scale(scoreBaseScale);
		bestText.text = if (bestScore > 0) Std.string(bestScore) else "";
		scorePulseTimer = -1;
		invalidShakeTimer = -1;

		// Clear animations
		slideAnims = [];
		popAnims = [];
		pendingMerges = [];
		floatingTexts = [];

		// Clear tiles
		while (tilesContainer.numChildren > 0)
			tilesContainer.getChildAt(0).remove();
		tileObjects = [for (_ in 0...GRID_SIZE) [for (_ in 0...GRID_SIZE) null]];

		// Clear particles
		for (p in particles)
			p.g.visible = false;
		particles = [];

		// Clear floating texts
		for (ft in floatTextPool)
			ft.visible = false;

		// Spawn 2 initial tiles
		spawnRandomTile();
		spawnRandomTile();

		// Draw static elements once
		drawStaticBg();
		drawStaticBoard();
		drawUI();

		// Build initial tile visuals
		syncTileVisuals();
	}

	public function dispose() {
		// Clear all animations
		slideAnims = [];
		popAnims = [];
		pendingMerges = [];
		floatingTexts = [];
		for (p in particles)
			p.g.visible = false;
		particles = [];

		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "2048";

	public function getTitle():String
		return "2048";

	public function update(dt:Float) {
		if (ctx == null) return;

		// Keyboard input
		if (!gameOver && !animating) {
			if (Key.isPressed(Key.LEFT)) tryMove(3);
			else if (Key.isPressed(Key.RIGHT)) tryMove(1);
			else if (Key.isPressed(Key.UP)) tryMove(0);
			else if (Key.isPressed(Key.DOWN)) tryMove(2);
		}

		// Update slide animations
		if (animPhase == Sliding) {
			var allDone = true;
			for (sa in slideAnims) {
				sa.progress += dt / sa.duration;
				if (sa.progress >= 1) {
					sa.progress = 1;
				} else {
					allDone = false;
				}
				var t = easeOutCubic(sa.progress);
				sa.obj.x = sa.fromX + (sa.toX - sa.fromX) * t;
				sa.obj.y = sa.fromY + (sa.toY - sa.fromY) * t;
			}
			if (allDone) {
				onSlidesComplete();
			}
		}

		// Update pop animations
		if (animPhase == Popping) {
			var allDone = true;
			for (pa in popAnims) {
				pa.progress += dt / pa.duration;
				if (pa.progress >= 1) {
					pa.progress = 1;
				} else {
					allDone = false;
				}

				switch (pa.type) {
					case MergePop:
						var t = pa.progress;
						var s = if (t < 0.5) 1.0 + 0.25 * easeOutCubic(t * 2) else 1.25 - 0.25 * easeOutCubic((t - 0.5) * 2);
						pa.obj.scaleX = s;
						pa.obj.scaleY = s;
					case SpawnScale:
						var t = easeOutBack(pa.progress);
						pa.obj.scaleX = t;
						pa.obj.scaleY = t;
				}
			}
			if (allDone) {
				// Reset scales
				for (pa in popAnims) {
					pa.obj.scaleX = 1;
					pa.obj.scaleY = 1;
				}
				onPopsComplete();
			}
		}

		// Update particles
		var i = particles.length - 1;
		while (i >= 0) {
			var p = particles[i];
			p.life -= dt;
			if (p.life <= 0) {
				p.g.visible = false;
				particles.splice(i, 1);
			} else {
				p.g.x += p.vx * dt;
				p.g.y += p.vy * dt;
				p.g.alpha = p.life / p.maxLife;
			}
			i--;
		}

		// Update floating texts
		var fi = floatingTexts.length - 1;
		while (fi >= 0) {
			var ft = floatingTexts[fi];
			ft.life -= dt;
			if (ft.life <= 0) {
				ft.txt.visible = false;
				floatingTexts.splice(fi, 1);
			} else {
				ft.txt.y += ft.vy * dt;
				ft.txt.alpha = ft.life / ft.maxLife;
			}
			fi--;
		}

		// Score pulse animation
		if (scorePulseTimer >= 0) {
			scorePulseTimer += dt;
			var t = scorePulseTimer / 0.2;
			if (t >= 1) {
				scorePulseTimer = -1;
				scoreText.scale(scoreBaseScale);
			} else {
				var s = if (t < 0.5) scoreBaseScale + 0.4 * easeOutCubic(t * 2) else scoreBaseScale + 0.4 * (1 - easeOutCubic((t - 0.5) * 2));
				scoreText.scale(s);
			}
		}

		// Invalid shake
		if (invalidShakeTimer >= 0) {
			invalidShakeTimer += dt;
			if (invalidShakeTimer >= 0.08) {
				invalidShakeTimer = -1;
				tilesContainer.x = 0;
			} else {
				var t = invalidShakeTimer / 0.08;
				tilesContainer.x = Math.sin(t * Math.PI * 4) * 2;
			}
		}

		// Game over
		if (gameOver) {
			if (deathTimer >= -DEATH_DELAY) {
				deathTimer += dt;
				if (deathTimer < 0) return; // delay phase
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFAF8EF, t * 0.6);
					flashG.drawRect(0, 0, DESIGN_W, DESIGN_H);
					flashG.endFill();
					gameOverText.alpha = t;
				} else {
					flashG.clear();
					if (score > bestScore) bestScore = score;
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}
	}
}

// ── Type Definitions ────────────────────────────────────────

typedef TileObj = {
	obj:Object,
	val:Int
};

typedef SlideInfo = {
	fromR:Int,
	fromC:Int,
	toR:Int,
	toC:Int,
	val:Int
};

typedef MergeInfo = {
	r:Int,
	c:Int,
	val:Int
};

typedef SlideAnim = {
	obj:Object,
	fromX:Float,
	fromY:Float,
	toX:Float,
	toY:Float,
	progress:Float,
	duration:Float
};

typedef PopAnim = {
	obj:Object,
	progress:Float,
	duration:Float,
	type:PopType
};

typedef ParticleData = {
	g:Graphics,
	vx:Float,
	vy:Float,
	life:Float,
	maxLife:Float
};

typedef FloatText = {
	txt:Text,
	vy:Float,
	life:Float,
	maxLife:Float
};

enum PopType {
	MergePop;
	SpawnScale;
}

enum AnimPhase {
	Idle;
	Sliding;
	Popping;
}
