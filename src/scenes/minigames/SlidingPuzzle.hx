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
	Sliding Puzzle (15-puzzle): organize os números deslizando peças.
	Grid 4x4, 15 peças + 1 espaço vazio. Toque na peça adjacente ao espaço para mover.
	Score = número de movimentos (menos = melhor). Timer conta o tempo.
	Game over quando completa o puzzle (ou desiste por timeout).
**/
class SlidingPuzzle implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRID = 4;
	static var TILE_SIZE = 74;
	static var TILE_GAP = 4;
	static var BOARD_PAD = 6;
	static var TIME_LIMIT = 120.0; // 2 min
	static var WIN_DELAY = 1.0;
	static var SWIPE_THRESHOLD = 15;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bgG:Graphics;
	var boardG:Graphics;
	var tilesG:Graphics;
	var uiG:Graphics;
	var flashG:Graphics;
	var movesText:Text;
	var timerText:Text;
	var titleText:Text;
	var hintText:Text;
	var winText:Text;
	var interactive:Interactive;

	// State
	var board:Array<Int>; // flat 16 cells, 0 = empty, 1-15 = tile number
	var emptyIdx:Int;
	var moves:Int;
	var elapsed:Float;
	var gameOver:Bool;
	var won:Bool;
	var winTimer:Float;
	var started:Bool;

	// Input
	var touchStartX:Float;
	var touchStartY:Float;
	var touchDown:Bool;

	// Board position
	var boardX:Float;
	var boardY:Float;
	var boardSize:Float;

	// Tile colors (gradient from blue to purple)
	static var TILE_COLORS:Array<Int> = [
		0x3498DB, 0x2980B9, 0x2471A3, 0x1F618D, // blues
		0x6C3483, 0x7D3C98, 0x8E44AD, 0x9B59B6, // purples
		0x1ABC9C, 0x16A085, 0x27AE60, 0x2ECC71, // greens
		0xE67E22, 0xD35400, 0xE74C3C // oranges/red
	];

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;
		board = [for (i in 0...16) 0];

		boardSize = GRID * TILE_SIZE + (GRID + 1) * TILE_GAP + BOARD_PAD * 2;
		boardX = (DESIGN_W - boardSize) / 2;
		boardY = 160;

		bgG = new Graphics(contentObj);
		boardG = new Graphics(contentObj);
		tilesG = new Graphics(contentObj);
		uiG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		titleText = new Text(hxd.res.DefaultFont.get(), contentObj);
		titleText.text = "Sliding Puzzle";
		titleText.x = DESIGN_W / 2;
		titleText.y = 25;
		titleText.scale(2.2);
		titleText.textAlign = Center;
		titleText.textColor = 0x2C3E50;

		movesText = new Text(hxd.res.DefaultFont.get(), contentObj);
		movesText.text = "Movimentos: 0";
		movesText.x = 20;
		movesText.y = 70;
		movesText.scale(1.1);
		movesText.textColor = 0x7F8C8D;

		timerText = new Text(hxd.res.DefaultFont.get(), contentObj);
		timerText.text = "2:00";
		timerText.x = DESIGN_W - 20;
		timerText.y = 70;
		timerText.scale(1.3);
		timerText.textAlign = Right;
		timerText.textColor = 0x2C3E50;

		hintText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hintText.text = "Toque nas peças para deslizar";
		hintText.x = DESIGN_W / 2;
		hintText.y = boardY + boardSize + 20;
		hintText.scale(0.95);
		hintText.textAlign = Center;
		hintText.textColor = 0x95A5A6;

		winText = new Text(hxd.res.DefaultFont.get(), contentObj);
		winText.text = "Completo!";
		winText.x = DESIGN_W / 2;
		winText.y = boardY + boardSize / 2 - 12;
		winText.scale(2.8);
		winText.textAlign = Center;
		winText.textColor = 0x27AE60;
		winText.visible = false;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver) return;
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchDown = true;
			e.propagate = false;
		};
		interactive.onRelease = onTouchEnd;
		interactive.onReleaseOutside = function(e:Event) { touchDown = false; };
	}

	function onTouchEnd(e:Event) {
		if (!touchDown || gameOver) return;
		touchDown = false;

		var dx = e.relX - touchStartX;
		var dy = e.relY - touchStartY;

		// Tap detection: find which tile was tapped
		if (Math.abs(dx) < SWIPE_THRESHOLD && Math.abs(dy) < SWIPE_THRESHOLD) {
			// Tap — find cell under touch
			var tx = e.relX;
			var ty = e.relY;
			var col = Std.int((tx - boardX - BOARD_PAD - TILE_GAP) / (TILE_SIZE + TILE_GAP));
			var row = Std.int((ty - boardY - BOARD_PAD - TILE_GAP) / (TILE_SIZE + TILE_GAP));
			if (col >= 0 && col < GRID && row >= 0 && row < GRID) {
				var idx = row * GRID + col;
				trySlide(idx);
			}
		} else {
			// Swipe — move tile into empty space from swipe direction
			if (Math.abs(dx) > Math.abs(dy)) {
				if (dx > 0) {
					// Swipe right → move tile from left of empty
					var emptyR = Std.int(emptyIdx / GRID);
					var emptyC = emptyIdx % GRID;
					if (emptyC > 0) trySlide(emptyR * GRID + (emptyC - 1));
				} else {
					// Swipe left → move tile from right of empty
					var emptyR = Std.int(emptyIdx / GRID);
					var emptyC = emptyIdx % GRID;
					if (emptyC < GRID - 1) trySlide(emptyR * GRID + (emptyC + 1));
				}
			} else {
				if (dy > 0) {
					// Swipe down → move tile from above empty
					var emptyR = Std.int(emptyIdx / GRID);
					var emptyC = emptyIdx % GRID;
					if (emptyR > 0) trySlide((emptyR - 1) * GRID + emptyC);
				} else {
					// Swipe up → move tile from below empty
					var emptyR = Std.int(emptyIdx / GRID);
					var emptyC = emptyIdx % GRID;
					if (emptyR < GRID - 1) trySlide((emptyR + 1) * GRID + emptyC);
				}
			}
		}
		e.propagate = false;
	}

	function trySlide(idx:Int) {
		if (board[idx] == 0) return; // tapped empty cell

		// Check if adjacent to empty
		var row = Std.int(idx / GRID);
		var col = idx % GRID;
		var eRow = Std.int(emptyIdx / GRID);
		var eCol = emptyIdx % GRID;

		var adjacent = (row == eRow && Math.abs(col - eCol) == 1) || (col == eCol && Math.abs(row - eRow) == 1);
		if (!adjacent) return;

		if (!started) started = true;

		// Swap
		board[emptyIdx] = board[idx];
		board[idx] = 0;
		emptyIdx = idx;
		moves++;
		movesText.text = "Movimentos: " + Std.string(moves);

		if (ctx != null && ctx.feedback != null)
			ctx.feedback.flash(0.03);

		// Check win
		if (isSolved()) {
			won = true;
			gameOver = true;
			winTimer = 0;
			winText.visible = true;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.2, 4);
		}

		drawTiles();
	}

	// ── Puzzle Logic ─────────────────────────────────────────────

	function initBoard() {
		// Start solved then shuffle with valid moves
		board = [for (i in 0...16) (i + 1) % 16]; // 1,2,...,15,0
		emptyIdx = 15;

		// Shuffle with random valid moves (ensures solvability)
		var shuffleMoves = 200 + Std.random(100);
		for (_ in 0...shuffleMoves) {
			var neighbors = getNeighbors(emptyIdx);
			var pick = neighbors[Std.random(neighbors.length)];
			board[emptyIdx] = board[pick];
			board[pick] = 0;
			emptyIdx = pick;
		}
	}

	function getNeighbors(idx:Int):Array<Int> {
		var r = Std.int(idx / GRID);
		var c = idx % GRID;
		var n:Array<Int> = [];
		if (r > 0) n.push((r - 1) * GRID + c);
		if (r < GRID - 1) n.push((r + 1) * GRID + c);
		if (c > 0) n.push(r * GRID + (c - 1));
		if (c < GRID - 1) n.push(r * GRID + (c + 1));
		return n;
	}

	function isSolved():Bool {
		for (i in 0...15) {
			if (board[i] != i + 1) return false;
		}
		return board[15] == 0;
	}

	// ── Drawing ──────────────────────────────────────────────────

	function drawAll() {
		drawBg();
		drawBoard();
		drawTiles();
	}

	function drawBg() {
		bgG.clear();
		// Light gradient background
		var steps = 10;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(236 + t * 10);
			var g = Std.int(240 + t * 5);
			var b = Std.int(241 + t * 8);
			var c = (r << 16) | (g << 8) | b;
			var yS = Std.int(DESIGN_H * t);
			var yE = Std.int(DESIGN_H * (t + 1.0 / steps)) + 1;
			bgG.beginFill(c);
			bgG.drawRect(0, yS, DESIGN_W, yE - yS);
			bgG.endFill();
		}
	}

	function drawBoard() {
		boardG.clear();
		// Board shadow
		boardG.beginFill(0x000000, 0.08);
		boardG.drawRoundedRect(boardX + 2, boardY + 3, boardSize, boardSize, 10);
		boardG.endFill();
		// Board background
		boardG.beginFill(0x2C3E50);
		boardG.drawRoundedRect(boardX, boardY, boardSize, boardSize, 10);
		boardG.endFill();
		// Inner board
		boardG.beginFill(0x34495E);
		boardG.drawRoundedRect(boardX + BOARD_PAD, boardY + BOARD_PAD, boardSize - BOARD_PAD * 2, boardSize - BOARD_PAD * 2, 6);
		boardG.endFill();

		// Empty cell slots
		for (r in 0...GRID) {
			for (c in 0...GRID) {
				var cx = boardX + BOARD_PAD + TILE_GAP + c * (TILE_SIZE + TILE_GAP);
				var cy = boardY + BOARD_PAD + TILE_GAP + r * (TILE_SIZE + TILE_GAP);
				boardG.beginFill(0x2C3E50);
				boardG.drawRoundedRect(cx, cy, TILE_SIZE, TILE_SIZE, 5);
				boardG.endFill();
			}
		}
	}

	function drawTiles() {
		tilesG.clear();
		while (tilesG.numChildren > 0)
			tilesG.getChildAt(0).remove();

		for (r in 0...GRID) {
			for (c in 0...GRID) {
				var idx = r * GRID + c;
				var val = board[idx];
				if (val == 0) continue;

				var cx = boardX + BOARD_PAD + TILE_GAP + c * (TILE_SIZE + TILE_GAP);
				var cy = boardY + BOARD_PAD + TILE_GAP + r * (TILE_SIZE + TILE_GAP);

				var color = TILE_COLORS[(val - 1) % TILE_COLORS.length];
				var isCorrect = (val == idx + 1);

				// Tile shadow
				tilesG.beginFill(0x000000, 0.12);
				tilesG.drawRoundedRect(cx + 1, cy + 2, TILE_SIZE, TILE_SIZE, 6);
				tilesG.endFill();

				// Tile body
				tilesG.beginFill(color);
				tilesG.drawRoundedRect(cx, cy, TILE_SIZE, TILE_SIZE, 6);
				tilesG.endFill();

				// Top highlight
				tilesG.beginFill(0xFFFFFF, 0.2);
				tilesG.drawRoundedRect(cx + 2, cy + 1, TILE_SIZE - 4, 4, 3);
				tilesG.endFill();

				// Bottom shadow
				tilesG.beginFill(0x000000, 0.1);
				tilesG.drawRoundedRect(cx + 2, cy + TILE_SIZE - 5, TILE_SIZE - 4, 4, 3);
				tilesG.endFill();

				// Correct position indicator (subtle glow)
				if (isCorrect) {
					tilesG.beginFill(0xFFFFFF, 0.08);
					tilesG.drawRoundedRect(cx - 1, cy - 1, TILE_SIZE + 2, TILE_SIZE + 2, 7);
					tilesG.endFill();
				}

				// Number
				var txt = new Text(hxd.res.DefaultFont.get(), tilesG);
				txt.text = Std.string(val);
				txt.textAlign = Center;
				txt.textColor = 0xFFFFFF;
				var sc = if (val >= 10) 2.0 else 2.4;
				txt.scale(sc);
				txt.x = cx + TILE_SIZE / 2;
				txt.y = cy + TILE_SIZE / 2 - 6 * sc;

				// Text shadow
				var shadow = new Text(hxd.res.DefaultFont.get(), tilesG);
				shadow.text = Std.string(val);
				shadow.textAlign = Center;
				shadow.textColor = 0x000000;
				shadow.alpha = 0.15;
				shadow.scale(sc);
				shadow.x = cx + TILE_SIZE / 2 + 1;
				shadow.y = cy + TILE_SIZE / 2 - 6 * sc + 1;
				// Move shadow behind number - swap draw order
				tilesG.addChildAt(shadow, tilesG.numChildren - 2);
			}
		}
	}

	function formatTime(t:Float):String {
		var secs = Std.int(t);
		var m = Std.int(secs / 60);
		var s = secs % 60;
		return Std.string(m) + ":" + (s < 10 ? "0" : "") + Std.string(s);
	}

	// ── Interface ────────────────────────────────────────────────

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		initBoard();
		moves = 0;
		elapsed = 0;
		gameOver = false;
		won = false;
		winTimer = -1;
		started = false;
		touchDown = false;
		flashG.clear();
		winText.visible = false;
		movesText.text = "Movimentos: 0";
		timerText.text = formatTime(TIME_LIMIT);
		drawAll();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "sliding-puzzle";

	public function getTitle():String
		return "Sliding Puzzle";

	public function update(dt:Float) {
		if (ctx == null) return;

		if (gameOver) {
			if (won) {
				winTimer += dt;
				winText.alpha = Math.min(winTimer / 0.3, 1.0);
				if (winTimer >= WIN_DELAY) {
					// Score: higher is better — reward fewer moves and more time left
					var timeLeft = TIME_LIMIT - elapsed;
					var finalScore = Std.int(Math.max(1000 - moves * 5 + timeLeft * 3, 10));
					ctx.lose(finalScore, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (started) {
			elapsed += dt;
			var remaining = TIME_LIMIT - elapsed;
			if (remaining <= 0) {
				remaining = 0;
				gameOver = true;
				winTimer = 0;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.3, 5);
				// Time's up — score based on how many tiles are correct
				var correct = 0;
				for (i in 0...15)
					if (board[i] == i + 1) correct++;
				var finalScore = correct * 20 + Std.int(Math.max(200 - moves, 0));
				ctx.lose(finalScore, getMinigameId());
				ctx = null;
				return;
			}
			timerText.text = formatTime(remaining);

			// Timer color change when low
			if (remaining < 15)
				timerText.textColor = 0xE74C3C;
			else if (remaining < 30)
				timerText.textColor = 0xE67E22;
			else
				timerText.textColor = 0x2C3E50;
		}
	}
}
