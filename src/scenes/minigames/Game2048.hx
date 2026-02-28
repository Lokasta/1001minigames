package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import hxd.Event;
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
	static var SWIPE_THRESHOLD = 20;
	static var ANIM_DURATION = 0.10;
	static var SPAWN_ANIM_DUR = 0.12;
	static var MERGE_POP_DUR = 0.10;
	static var DEATH_DUR = 0.6;

	final contentObj:Object;
	var ctx:MinigameContext;

	// Graphics
	var bgG:Graphics;
	var boardG:Graphics;
	var tilesG:Graphics;
	var uiG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var bestText:Text;
	var titleText:Text;
	var gameOverText:Text;
	var interactive:Interactive;

	// Grid state
	var grid:Array<Array<Int>>; // 4x4, 0 = empty
	var score:Int;
	var bestScore:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var moved:Bool;

	// Input
	var touchStartX:Float;
	var touchStartY:Float;
	var touchDown:Bool;

	// Animation
	var animating:Bool;

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

		boardSize = GRID_SIZE * TILE_SIZE + (GRID_SIZE + 1) * TILE_GAP + BOARD_PAD * 2;
		boardX = (DESIGN_W - boardSize) / 2;
		boardY = 180;

		bgG = new Graphics(contentObj);
		boardG = new Graphics(contentObj);
		tilesG = new Graphics(contentObj);
		uiG = new Graphics(contentObj);
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
		scoreText.scale(1.4);
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
	}

	function onTouchEnd(e:Event) {
		if (!touchDown || gameOver || animating) return;
		touchDown = false;
		var dx = e.relX - touchStartX;
		var dy = e.relY - touchStartY;
		if (Math.abs(dx) < SWIPE_THRESHOLD && Math.abs(dy) < SWIPE_THRESHOLD) return;

		var dir:Int; // 0=up, 1=right, 2=down, 3=left
		if (Math.abs(dx) > Math.abs(dy)) {
			dir = dx > 0 ? 1 : 3;
		} else {
			dir = dy > 0 ? 2 : 0;
		}
		tryMove(dir);
		e.propagate = false;
	}

	// ── Grid Logic ───────────────────────────────────────────────

	function tryMove(dir:Int) {
		// Save old grid for animation
		var oldGrid = [for (r in 0...GRID_SIZE) [for (c in 0...GRID_SIZE) grid[r][c]]];
		var mergedScore = doMove(dir);

		// Check if anything changed
		var changed = false;
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] != oldGrid[r][c]) changed = true;

		if (!changed) return;

		score += mergedScore;
		scoreText.text = Std.string(score);

		// Feedback on merge
		if (mergedScore > 0 && ctx != null && ctx.feedback != null) {
			if (mergedScore >= 64)
				ctx.feedback.shake2D(0.12, 3);
		}

		// Spawn new tile
		spawnRandomTile();

		// Check game over
		if (!hasMovesLeft()) {
			gameOver = true;
			deathTimer = 0;
			gameOverText.visible = true;
		}

		drawAll();
	}

	function doMove(dir:Int):Int {
		var mergedScore = 0;
		// Process each line in the direction of movement
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
				case 0: line.push(grid[j][index]); // up: column top to bottom
				case 1: line.push(grid[index][GRID_SIZE - 1 - j]); // right: row right to left
				case 2: line.push(grid[GRID_SIZE - 1 - j][index]); // down: column bottom to top
				case 3: line.push(grid[index][j]); // left: row left to right
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
		// Remove zeros
		var nonZero:Array<Int> = [];
		for (v in line)
			if (v != 0) nonZero.push(v);

		// Merge adjacent equal values
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

		// Pad with zeros
		while (merged.length < GRID_SIZE)
			merged.push(0);

		return {line: merged, score: mergeScore};
	}

	function spawnRandomTile() {
		var empty:Array<{r:Int, c:Int}> = [];
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] == 0) empty.push({r: r, c: c});

		if (empty.length == 0) return;
		var cell = empty[Std.random(empty.length)];
		grid[cell.r][cell.c] = Math.random() < 0.9 ? 2 : 4;
	}

	function hasMovesLeft():Bool {
		// Any empty cell?
		for (r in 0...GRID_SIZE)
			for (c in 0...GRID_SIZE)
				if (grid[r][c] == 0) return true;
		// Any adjacent equal cells?
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var v = grid[r][c];
				if (c + 1 < GRID_SIZE && grid[r][c + 1] == v) return true;
				if (r + 1 < GRID_SIZE && grid[r + 1][c] == v) return true;
			}
		}
		return false;
	}

	// ── Drawing ──────────────────────────────────────────────────

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
			default: 0x3C3A32; // super tiles
		};
	}

	function textColor(val:Int):Int {
		return if (val <= 4) 0x776E65 else 0xFFFFF8;
	}

	function textScale(val:Int):Float {
		if (val < 100) return 1.8;
		if (val < 1000) return 1.4;
		return 1.1;
	}

	function drawAll() {
		drawBg();
		drawBoard();
		drawTiles();
		drawUI();
	}

	function drawBg() {
		bgG.clear();
		// Warm background
		bgG.beginFill(0xFAF8EF);
		bgG.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bgG.endFill();

		// Subtle pattern
		bgG.beginFill(0xF0E8D8, 0.3);
		var y = 0;
		while (y < DESIGN_H) {
			bgG.drawRect(0, y, DESIGN_W, 1);
			y += 4;
		}
		bgG.endFill();
	}

	function drawBoard() {
		boardG.clear();
		// Board background with rounded corners
		boardG.beginFill(0xBBADA0);
		boardG.drawRoundedRect(boardX, boardY, boardSize, boardSize, 8);
		boardG.endFill();

		// Empty cell slots
		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var cx = boardX + BOARD_PAD + TILE_GAP + c * (TILE_SIZE + TILE_GAP);
				var cy = boardY + BOARD_PAD + TILE_GAP + r * (TILE_SIZE + TILE_GAP);
				boardG.beginFill(0xCDC1B4);
				boardG.drawRoundedRect(cx, cy, TILE_SIZE, TILE_SIZE, 5);
				boardG.endFill();
			}
		}
	}

	function drawTiles() {
		tilesG.clear();
		// Remove old text children (keep tilesG itself)
		while (tilesG.numChildren > 0)
			tilesG.getChildAt(0).remove();

		for (r in 0...GRID_SIZE) {
			for (c in 0...GRID_SIZE) {
				var val = grid[r][c];
				if (val == 0) continue;

				var cx = boardX + BOARD_PAD + TILE_GAP + c * (TILE_SIZE + TILE_GAP);
				var cy = boardY + BOARD_PAD + TILE_GAP + r * (TILE_SIZE + TILE_GAP);

				// Tile shadow
				tilesG.beginFill(0x000000, 0.06);
				tilesG.drawRoundedRect(cx + 1, cy + 2, TILE_SIZE, TILE_SIZE, 5);
				tilesG.endFill();

				// Tile background
				tilesG.beginFill(tileColor(val));
				tilesG.drawRoundedRect(cx, cy, TILE_SIZE, TILE_SIZE, 5);
				tilesG.endFill();

				// Highlight on top edge
				tilesG.beginFill(0xFFFFFF, 0.12);
				tilesG.drawRoundedRect(cx + 2, cy + 1, TILE_SIZE - 4, 3, 2);
				tilesG.endFill();

				// Number text
				var txt = new Text(hxd.res.DefaultFont.get(), tilesG);
				txt.text = Std.string(val);
				txt.textAlign = Center;
				txt.textColor = textColor(val);
				var sc = textScale(val);
				txt.scale(sc);
				txt.x = cx + TILE_SIZE / 2;
				txt.y = cy + TILE_SIZE / 2 - 5 * sc;
			}
		}
	}

	function drawUI() {
		uiG.clear();

		// Score box
		var boxW = 80.0;
		var boxH = 45.0;
		var boxX = DESIGN_W - boxW - 15;
		var boxY = 20.0;
		uiG.beginFill(0xBBADA0);
		uiG.drawRoundedRect(boxX, boxY, boxW, boxH, 5);
		uiG.endFill();

		// "SCORE" label
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

		// Best score box
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

		// Instruction hint below board
		var hintY = boardY + boardSize + 15;
		var hint = new Text(hxd.res.DefaultFont.get(), uiG);
		hint.text = "Deslize para mover os blocos";
		hint.x = DESIGN_W / 2;
		hint.y = hintY;
		hint.scale(0.9);
		hint.textAlign = Center;
		hint.textColor = 0xBBADA0;

		// Combine hint
		var hint2 = new Text(hxd.res.DefaultFont.get(), uiG);
		hint2.text = "Combine iguais para chegar ao 2048!";
		hint2.x = DESIGN_W / 2;
		hint2.y = hintY + 18;
		hint2.scale(0.85);
		hint2.textAlign = Center;
		hint2.textColor = 0xCDC1B4;
	}

	// ── Interface ────────────────────────────────────────────────

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
		gameOverText.visible = false;
		flashG.clear();
		scoreText.text = "0";
		bestText.text = if (bestScore > 0) Std.string(bestScore) else "";

		// Spawn 2 initial tiles
		spawnRandomTile();
		spawnRandomTile();

		drawAll();
	}

	public function dispose() {
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

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					// Fade overlay
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
