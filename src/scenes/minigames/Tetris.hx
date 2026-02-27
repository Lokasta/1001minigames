package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class Tetris implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var COLS = 10;
	static var ROWS = 20;
	static var TILE = 24;
	// Board area: 240x480, centered horizontally
	static var BOARD_X = 60; // (360 - 240) / 2
	static var BOARD_Y = 100;
	// Drop timing
	static var DROP_INTERVAL_START = 0.8;
	static var DROP_INTERVAL_MIN = 0.25;
	static var SPEED_RAMP_TIME = 120.0; // seconds to reach min interval
	static var LOCK_DELAY = 0.4;
	// Swipe thresholds
	static var SWIPE_MIN = 15.0;
	static var TAP_MAX = 10.0;

	// Tetromino shapes: [rotation][row][col] — 4 rotations each
	// I, O, T, S, Z, L, J
	static var SHAPES:Array<Array<Array<Array<Int>>>> = [
		// I
		[
			[[0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]],
			[[0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0]],
			[[0, 0, 0, 0], [0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0]],
			[[0, 1, 0, 0], [0, 1, 0, 0], [0, 1, 0, 0], [0, 1, 0, 0]]
		],
		// O
		[
			[[0, 1, 1, 0], [0, 1, 1, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
			[[0, 1, 1, 0], [0, 1, 1, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
			[[0, 1, 1, 0], [0, 1, 1, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
			[[0, 1, 1, 0], [0, 1, 1, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
		],
		// T
		[
			[[0, 1, 0], [1, 1, 1], [0, 0, 0]],
			[[0, 1, 0], [0, 1, 1], [0, 1, 0]],
			[[0, 0, 0], [1, 1, 1], [0, 1, 0]],
			[[0, 1, 0], [1, 1, 0], [0, 1, 0]]
		],
		// S
		[
			[[0, 1, 1], [1, 1, 0], [0, 0, 0]],
			[[0, 1, 0], [0, 1, 1], [0, 0, 1]],
			[[0, 0, 0], [0, 1, 1], [1, 1, 0]],
			[[1, 0, 0], [1, 1, 0], [0, 1, 0]]
		],
		// Z
		[
			[[1, 1, 0], [0, 1, 1], [0, 0, 0]],
			[[0, 0, 1], [0, 1, 1], [0, 1, 0]],
			[[0, 0, 0], [1, 1, 0], [0, 1, 1]],
			[[0, 1, 0], [1, 1, 0], [1, 0, 0]]
		],
		// L
		[
			[[0, 0, 1], [1, 1, 1], [0, 0, 0]],
			[[0, 1, 0], [0, 1, 0], [0, 1, 1]],
			[[0, 0, 0], [1, 1, 1], [1, 0, 0]],
			[[1, 1, 0], [0, 1, 0], [0, 1, 0]]
		],
		// J
		[
			[[1, 0, 0], [1, 1, 1], [0, 0, 0]],
			[[0, 1, 1], [0, 1, 0], [0, 1, 0]],
			[[0, 0, 0], [1, 1, 1], [0, 0, 1]],
			[[0, 1, 0], [0, 1, 0], [1, 1, 0]]
		]
	];

	static var COLORS:Array<Int> = [
		0x00FFFF, // I - cyan
		0xFFFF00, // O - yellow
		0xAA00FF, // T - purple
		0x00FF00, // S - green
		0xFF0000, // Z - red
		0xFF8800, // L - orange
		0x0044FF  // J - blue
	];

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var ghostG:Graphics;
	var nextG:Graphics;
	var scoreText:Text;
	var linesText:Text;
	var instructText:Text;
	var interactive:Interactive;

	// Board: 0 = empty, >0 = color index + 1
	var board:Array<Array<Int>>;

	// Current piece
	var curType:Int;
	var curRot:Int;
	var curX:Int;
	var curY:Int;

	// Next piece
	var nextType:Int;

	var score:Int;
	var lines:Int;
	var gameOver:Bool;
	var started:Bool;
	var dropTimer:Float;
	var totalTime:Float;
	var lockTimer:Float;
	var locking:Bool;

	// Input
	var touchStartX:Float;
	var touchStartY:Float;
	var touching:Bool;
	var lastMoveX:Float;
	var softDrop:Bool;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		// Background
		bg = new Graphics(contentObj);
		var bgTop = 0x08081a;
		var bgBot = 0x0c0c28;
		var bSteps = 5;
		var bStepH = DESIGN_H / bSteps;
		for (i in 0...bSteps) {
			var t = i / (bSteps - 1);
			var r = Std.int(((bgTop >> 16) & 0xFF) * (1 - t) + ((bgBot >> 16) & 0xFF) * t);
			var g = Std.int(((bgTop >> 8) & 0xFF) * (1 - t) + ((bgBot >> 8) & 0xFF) * t);
			var b = Std.int((bgTop & 0xFF) * (1 - t) + (bgBot & 0xFF) * t);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, i * bStepH, DESIGN_W, bStepH + 1);
			bg.endFill();
		}

		// Board area
		bg.beginFill(0x0a0a22);
		bg.drawRect(BOARD_X, BOARD_Y, COLS * TILE, ROWS * TILE);
		bg.endFill();
		for (c in 0...COLS + 1) {
			bg.beginFill(0x14143a, 0.5);
			bg.drawRect(BOARD_X + c * TILE, BOARD_Y, 1, ROWS * TILE);
			bg.endFill();
		}
		for (r2 in 0...ROWS + 1) {
			bg.beginFill(0x14143a, 0.5);
			bg.drawRect(BOARD_X, BOARD_Y + r2 * TILE, COLS * TILE, 1);
			bg.endFill();
		}
		bg.lineStyle(2, 0x3344AA, 0.6);
		bg.drawRect(BOARD_X - 2, BOARD_Y - 2, COLS * TILE + 4, ROWS * TILE + 4);
		bg.lineStyle();

		// Ghost piece layer (drawn behind current piece)
		ghostG = new Graphics(contentObj);

		// Game graphics (board cells + current piece)
		gameG = new Graphics(contentObj);

		// Next piece preview
		nextG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = 14;
		scoreText.y = 15;
		scoreText.scale(1.8);
		scoreText.textColor = 0xFFFFFF;

		linesText = new Text(hxd.res.DefaultFont.get(), contentObj);
		linesText.text = "Linhas: 0";
		linesText.x = 14;
		linesText.y = 50;
		linesText.scale(1.0);
		linesText.textColor = 0x8888CC;

		var nextLabel = new Text(hxd.res.DefaultFont.get(), contentObj);
		nextLabel.text = "NEXT";
		nextLabel.x = BOARD_X + COLS * TILE + 12;
		nextLabel.y = BOARD_Y + 5;
		nextLabel.scale(1.0);
		nextLabel.textColor = 0x6666AA;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Arraste: mover | Toque: girar";
		instructText.x = DESIGN_W / 2;
		instructText.y = BOARD_Y + ROWS * TILE + 12;
		instructText.scale(0.85);
		instructText.textColor = 0x555577;
		instructText.textAlign = Center;

		// Interactive
		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) {
			if (gameOver) return;
			touchStartX = e.relX;
			touchStartY = e.relY;
			lastMoveX = e.relX;
			touching = true;
			softDrop = false;
		};
		interactive.onRelease = function(e) {
			onTouchEnd(e.relX, e.relY);
		};
		interactive.onReleaseOutside = function(e) {
			onTouchEnd(e.relX, e.relY);
		};
		interactive.onMove = function(e) {
			if (!touching || gameOver || !started) return;
			// Horizontal drag movement: each TILE distance moves piece one column
			var dx = e.relX - lastMoveX;
			if (dx > TILE * 0.7) {
				tryMove(1, 0);
				lastMoveX = e.relX;
			} else if (dx < -TILE * 0.7) {
				tryMove(-1, 0);
				lastMoveX = e.relX;
			}
			// Detect downward drag for soft drop
			var dy = e.relY - touchStartY;
			if (dy > TILE * 2) {
				softDrop = true;
			}
		};

		rng = new hxd.Rand(42);
		board = [];
		for (r in 0...ROWS) {
			board.push([for (_ in 0...COLS) 0]);
		}

		curType = 0;
		curRot = 0;
		curX = 0;
		curY = 0;
		nextType = 0;
		score = 0;
		lines = 0;
		gameOver = false;
		started = false;
		dropTimer = 0;
		totalTime = 0;
		lockTimer = 0;
		locking = false;
		touching = false;
		touchStartX = 0;
		touchStartY = 0;
		lastMoveX = 0;
		softDrop = false;
	}

	function onTouchEnd(ex:Float, ey:Float) {
		if (!touching || gameOver || !started) {
			touching = false;
			return;
		}
		touching = false;
		var dx = ex - touchStartX;
		var dy = ey - touchStartY;
		var dist = Math.sqrt(dx * dx + dy * dy);

		if (softDrop) {
			// Hard drop
			hardDrop();
		} else if (dist < TAP_MAX) {
			// Tap = rotate
			tryRotate();
		}
		softDrop = false;
	}

	public function getMinigameId():String
		return "tetris";

	public function getTitle():String
		return "Tetris";

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start() {
		// Reset board
		for (r in 0...ROWS)
			for (c in 0...COLS)
				board[r][c] = 0;

		score = 0;
		lines = 0;
		gameOver = false;
		started = true;
		dropTimer = 0;
		totalTime = 0;
		lockTimer = 0;
		locking = false;
		touching = false;
		softDrop = false;

		scoreText.text = "0";
		linesText.text = "Lines: 0";

		nextType = rng.random(7);
		spawnPiece();
	}

	function spawnPiece() {
		curType = nextType;
		nextType = rng.random(7);
		curRot = 0;
		var shape = SHAPES[curType][0];
		var size = shape.length;
		curX = Std.int((COLS - size) / 2);
		curY = -1;

		if (!fits(curType, curRot, curX, curY)) {
			gameOver = true;
			lockTimer = 0;
			if (ctx != null && ctx.feedback != null) {
				ctx.feedback.flash(0xFF0000, 0.2);
				ctx.feedback.shake2D(0.3, 6);
			}
		}
		locking = false;
		lockTimer = 0;
	}

	function getShape(type:Int, rot:Int):Array<Array<Int>> {
		return SHAPES[type][rot];
	}

	function fits(type:Int, rot:Int, px:Int, py:Int):Bool {
		var shape = getShape(type, rot);
		var size = shape.length;
		for (r in 0...size) {
			for (c in 0...size) {
				if (shape[r][c] == 0) continue;
				var bx = px + c;
				var by = py + r;
				if (bx < 0 || bx >= COLS) return false;
				if (by >= ROWS) return false;
				// Allow above board (by < 0)
				if (by >= 0 && board[by][bx] != 0) return false;
			}
		}
		return true;
	}

	function tryMove(dx:Int, dy:Int):Bool {
		if (fits(curType, curRot, curX + dx, curY + dy)) {
			curX += dx;
			curY += dy;
			if (dy > 0) {
				// Reset lock timer if moving down
				lockTimer = 0;
				locking = false;
			}
			return true;
		}
		return false;
	}

	function tryRotate() {
		var newRot = (curRot + 1) % 4;
		if (fits(curType, newRot, curX, curY)) {
			curRot = newRot;
			lockTimer = 0; // Reset lock on rotation
			return;
		}
		// Wall kick: try left, right, up
		for (kick in [{x: -1, y: 0}, {x: 1, y: 0}, {x: 0, y: -1}, {x: -2, y: 0}, {x: 2, y: 0}]) {
			if (fits(curType, newRot, curX + kick.x, curY + kick.y)) {
				curX += kick.x;
				curY += kick.y;
				curRot = newRot;
				lockTimer = 0;
				return;
			}
		}
	}

	function hardDrop() {
		var dropped = 0;
		while (fits(curType, curRot, curX, curY + 1)) {
			curY++;
			dropped++;
		}
		score += dropped * 2;
		lockPiece();
	}

	function lockPiece() {
		var shape = getShape(curType, curRot);
		var size = shape.length;
		for (r in 0...size) {
			for (c in 0...size) {
				if (shape[r][c] == 0) continue;
				var bx = curX + c;
				var by = curY + r;
				if (by >= 0 && by < ROWS && bx >= 0 && bx < COLS) {
					board[by][bx] = curType + 1;
				}
			}
		}
		clearLines();
		spawnPiece();
	}

	function clearLines() {
		var cleared = 0;
		var r = ROWS - 1;
		while (r >= 0) {
			var full = true;
			for (c in 0...COLS) {
				if (board[r][c] == 0) {
					full = false;
					break;
				}
			}
			if (full) {
				cleared++;
				// Shift everything down
				var sr = r;
				while (sr > 0) {
					for (c in 0...COLS)
						board[sr][c] = board[sr - 1][c];
					sr--;
				}
				for (c in 0...COLS)
					board[0][c] = 0;
				// Don't decrement r — check same row again
			} else {
				r--;
			}
		}
		if (cleared > 0) {
			lines += cleared;
			// Scoring: 100, 300, 500, 800 for 1-4 lines
			var pts = switch (cleared) {
				case 1: 100;
				case 2: 300;
				case 3: 500;
				case _: 800;
			};
			score += pts;
			scoreText.text = Std.string(score);
			linesText.text = "Linhas: " + Std.string(lines);

			if (ctx != null) {
				ctx.feedback.flash(0xFFFFFF, 0.1);
				if (cleared >= 4) ctx.feedback.shake2D(0.3, 5);
			}
		}
	}

	function getDropInterval():Float {
		var t = Math.min(totalTime / SPEED_RAMP_TIME, 1.0);
		return DROP_INTERVAL_START + (DROP_INTERVAL_MIN - DROP_INTERVAL_START) * t;
	}

	function getGhostY():Int {
		var gy = curY;
		while (fits(curType, curRot, curX, gy + 1))
			gy++;
		return gy;
	}

	public function update(dt:Float) {
		if (gameOver) {
			if (lockTimer >= 0) {
				lockTimer += dt;
				if (lockTimer >= 0.5 && ctx != null) {
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}
		if (!started) return;

		totalTime += dt;

		var interval = getDropInterval();
		if (softDrop && touching) interval *= 0.1; // Fast soft drop

		dropTimer += dt;
		if (dropTimer >= interval) {
			dropTimer = 0;
			if (!tryMove(0, 1)) {
				// Can't move down — start lock delay
				if (!locking) {
					locking = true;
					lockTimer = 0;
				}
			} else {
				locking = false;
				lockTimer = 0;
				if (softDrop && touching) score += 1; // Soft drop bonus
			}
		}

		// Lock delay
		if (locking) {
			lockTimer += dt;
			if (lockTimer >= LOCK_DELAY) {
				lockPiece();
			}
		}

		draw();
	}

	function draw() {
		gameG.clear();
		ghostG.clear();

		// Draw locked board cells
		for (r in 0...ROWS) {
			for (c in 0...COLS) {
				if (board[r][c] != 0) {
					var color = COLORS[board[r][c] - 1];
					drawTile(gameG, c, r, color, 1.0);
				}
			}
		}

		if (!gameOver) {
			// Draw ghost piece
			var gy = getGhostY();
			var shape = getShape(curType, curRot);
			var size = shape.length;
			for (r in 0...size) {
				for (c in 0...size) {
					if (shape[r][c] == 0) continue;
					var bx = curX + c;
					var by = gy + r;
					if (by >= 0 && by < ROWS) {
						drawTile(ghostG, bx, by, COLORS[curType], 0.2);
					}
				}
			}

			// Draw current piece
			for (r in 0...size) {
				for (c in 0...size) {
					if (shape[r][c] == 0) continue;
					var bx = curX + c;
					var by = curY + r;
					if (by >= 0 && by < ROWS) {
						drawTile(gameG, bx, by, COLORS[curType], 1.0);
					}
				}
			}
		}

		nextG.clear();
		var nShape = getShape(nextType, 0);
		var nSize = nShape.length;
		var previewTile = 14;
		var previewX = BOARD_X + COLS * TILE + 12;
		var previewY = BOARD_Y + 25;
		nextG.lineStyle(1, 0x333366, 0.4);
		nextG.drawRect(previewX - 2, previewY - 2, nSize * previewTile + 4, nSize * previewTile + 4);
		nextG.lineStyle();
		for (r in 0...nSize) {
			for (c in 0...nSize) {
				if (nShape[r][c] == 0) continue;
				var px = previewX + c * previewTile;
				var py = previewY + r * previewTile;
				nextG.beginFill(COLORS[nextType]);
				nextG.drawRoundedRect(px + 1, py + 1, previewTile - 2, previewTile - 2, 2);
				nextG.endFill();
			}
		}

		scoreText.text = Std.string(score);
	}

	function drawTile(g:Graphics, col:Int, row:Int, color:Int, alpha:Float) {
		var px = BOARD_X + col * TILE;
		var py = BOARD_Y + row * TILE;

		g.beginFill(color, alpha);
		g.drawRoundedRect(px + 1, py + 1, TILE - 2, TILE - 2, 3);
		g.endFill();

		if (alpha >= 0.9) {
			var hi = brighten(color, 50);
			g.beginFill(hi, 0.45);
			g.drawRoundedRect(px + 2, py + 2, TILE - 4, Std.int(TILE / 2) - 2, 2);
			g.endFill();

			var sh = darken(color, 60);
			g.beginFill(sh, 0.35);
			g.drawRect(px + 2, py + TILE - 4, TILE - 4, 2);
			g.drawRect(px + TILE - 4, py + 2, 2, TILE - 4);
			g.endFill();
		}
	}

	function brighten(color:Int, amount:Int):Int {
		var r = Std.int(Math.min(255, ((color >> 16) & 0xFF) + amount));
		var g = Std.int(Math.min(255, ((color >> 8) & 0xFF) + amount));
		var b = Std.int(Math.min(255, (color & 0xFF) + amount));
		return (r << 16) | (g << 8) | b;
	}

	function darken(color:Int, amount:Int):Int {
		var r = Std.int(Math.max(0, ((color >> 16) & 0xFF) - amount));
		var g = Std.int(Math.max(0, ((color >> 8) & 0xFF) - amount));
		var b = Std.int(Math.max(0, (color & 0xFF) - amount));
		return (r << 16) | (g << 8) | b;
	}

	public function dispose() {
		if (interactive != null) interactive.remove();
		if (gameG != null) gameG.remove();
		if (ghostG != null) ghostG.remove();
		if (nextG != null) nextG.remove();
		if (bg != null) bg.remove();
		if (scoreText != null) scoreText.remove();
		if (linesText != null) linesText.remove();
		if (instructText != null) instructText.remove();
		contentObj.removeChildren();
	}
}
