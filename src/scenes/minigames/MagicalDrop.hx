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
	Magical Drop: grid no topo, player embaixo.
	Puxe gemas da parte de baixo da coluna, jogue pra cima pra fazer matches.
	← → mover | ↓ puxar | ↑ lançar | 3+ match = pop + chain.
**/
class MagicalDrop implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var COLS = 7;
	static var ROWS = 10;
	static var GEM_S = 42;
	static var GAP = 3;
	static var BOARD_TOP = 45; // grid starts near top
	static var NUM_COLORS = 5;

	static var PUSH_START = 5.5;
	static var PUSH_MIN = 1.8;
	static var PUSH_RAMP = 150.0;
	static var POP_DELAY = 0.18;
	static var THROW_SPEED = 900.0;
	static var DEATH_DUR = 0.7;
	static var SWIPE_TH = 18;

	static var COLORS:Array<Int> = [0xE8364F, 0x2B8FE8, 0xF5C842, 0x3DD674, 0xAA55DD];
	static var LIGHT:Array<Int> = [0xFF6B7F, 0x5BB4FF, 0xFFE066, 0x66F09A, 0xCC88FF];
	static var DARK:Array<Int> = [0xB01030, 0x1A60AA, 0xC8A020, 0x20A850, 0x7733AA];

	final contentObj:Object;
	var ctx:MinigameContext;

	// Layers
	var bgG:Graphics;
	var boardG:Graphics;
	var gemsG:Graphics;
	var fxG:Graphics;
	var playerG:Graphics;
	var heldG:Graphics;
	var overlayG:Graphics;
	var scoreText:Text;
	var scoreLbl:Text;
	var chainText:Text;
	var hintText:Text;
	var pushBarG:Graphics;
	var interactive:Interactive;

	// Grid: grid[col][row], row 0 = top. -1=empty, 0..4=color
	// Gems are compacted UPWARD (toward row 0). Gravity = UP.
	var grid:Array<Array<Int>>;
	var playerCol:Int;
	var heldGems:Array<Int>;
	var holding:Bool;

	var score:Int;
	var chain:Int;
	var elapsed:Float;
	var pushTimer:Float;
	var gameOver:Bool;
	var deathTimer:Float;
	var popping:Bool;
	var popTimer:Float;
	var popCells:Array<{c:Int, r:Int}>;
	var throwing:Bool;
	var throwCol:Int;
	var throwGems:Array<Int>;
	var throwY:Float;
	var throwTargetY:Float;
	var chainTimer:Float;

	// Effects
	var pops:Array<{x:Float, y:Float, color:Int, t:Float}>;
	var sparks:Array<{x:Float, y:Float, vx:Float, vy:Float, life:Float, color:Int, size:Float}>;

	// Input
	var tStartX:Float;
	var tStartY:Float;
	var tDown:Bool;

	// Cached layout
	var brdX:Float;
	var brdW:Float;
	var boardBottom:Float;
	var playerY:Float;

	public var content(get, never):Object;
	inline function get_content() return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;
		grid = [for (_ in 0...COLS) [for (_ in 0...ROWS) -1]];
		heldGems = [];
		popCells = [];
		throwGems = [];
		pops = [];
		sparks = [];

		brdW = COLS * (GEM_S + GAP) - GAP;
		brdX = (DESIGN_W - brdW) / 2;
		boardBottom = BOARD_TOP + ROWS * (GEM_S + GAP) - GAP + GEM_S;
		playerY = boardBottom + 55; // player sits below the grid

		bgG = new Graphics(contentObj);
		boardG = new Graphics(contentObj);
		gemsG = new Graphics(contentObj);
		fxG = new Graphics(contentObj);
		playerG = new Graphics(contentObj);
		heldG = new Graphics(contentObj);
		pushBarG = new Graphics(contentObj);
		overlayG = new Graphics(contentObj);

		scoreLbl = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreLbl.text = "SCORE";
		scoreLbl.x = DESIGN_W - 12;
		scoreLbl.y = 8;
		scoreLbl.scale(0.75);
		scoreLbl.textAlign = Right;
		scoreLbl.textColor = 0x8888CC;

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W - 12;
		scoreText.y = 20;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		chainText = new Text(hxd.res.DefaultFont.get(), contentObj);
		chainText.text = "";
		chainText.x = DESIGN_W / 2;
		chainText.y = DESIGN_H / 2;
		chainText.scale(3.5);
		chainText.textAlign = Center;
		chainText.textColor = 0xFFDD44;
		chainText.visible = false;

		hintText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hintText.text = "<> mover  v puxar  ^ lancar";
		hintText.x = DESIGN_W / 2;
		hintText.y = playerY + 55;
		hintText.scale(0.8);
		hintText.textAlign = Center;
		hintText.textColor = 0x6666AA;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || popping || throwing) return;
			tStartX = e.relX;
			tStartY = e.relY;
			tDown = true;
			e.propagate = false;
		};
		interactive.onRelease = onSwipe;
		interactive.onReleaseOutside = function(e:Event) { tDown = false; };
	}

	function onSwipe(e:Event) {
		if (!tDown || gameOver || popping || throwing) return;
		tDown = false;
		var dx = e.relX - tStartX;
		var dy = e.relY - tStartY;
		var ax = Math.abs(dx);
		var ay = Math.abs(dy);

		if (ax < SWIPE_TH && ay < SWIPE_TH) {
			e.propagate = false;
			return;
		}

		if (ax > ay) {
			// Move 1 column
			if (dx > 0 && playerCol < COLS - 1) playerCol++;
			else if (dx < 0 && playerCol > 0) playerCol--;
		} else if (dy > 0) {
			// Swipe down → grab from bottom of column
			if (!holding) grabGems();
		} else {
			// Swipe up → throw gems into column
			if (holding && heldGems.length > 0) startThrow();
		}
		e.propagate = false;
	}

	// ── Layout helpers ───────────────────────────────────────────

	inline function cx(col:Int):Float return brdX + col * (GEM_S + GAP);
	inline function ry(row:Int):Float return BOARD_TOP + row * (GEM_S + GAP);

	// ── Grab & Throw ─────────────────────────────────────────────

	// Find the bottom-most filled row in a column (highest row index with a gem)
	function bottomGem(col:Int):Int {
		var bot = -1;
		for (r in 0...ROWS) if (grid[col][r] != -1) bot = r;
		return bot;
	}

	// Find the top-most filled row in a column (lowest row index with a gem)
	function topGem(col:Int):Int {
		for (r in 0...ROWS) if (grid[col][r] != -1) return r;
		return -1;
	}

	function grabGems() {
		var c = playerCol;
		var bot = bottomGem(c);
		if (bot < 0) return;

		var color = grid[c][bot];
		heldGems = [];
		var r = bot;
		// Grab consecutive same-color gems from bottom upward
		while (r >= 0 && grid[c][r] == color) {
			heldGems.push(color);
			grid[c][r] = -1;
			r--;
		}
		holding = true;
		hintText.visible = false;

		// Spawn grab sparkles
		for (i in 0...heldGems.length) {
			var gx = cx(c) + GEM_S / 2;
			var gy = ry(bot - i) + GEM_S / 2;
			for (_ in 0...3) {
				sparks.push({
					x: gx, y: gy,
					vx: (Math.random() - 0.5) * 80,
					vy: 30 + Math.random() * 40, // sparkles fall down (toward player)
					life: 0.25 + Math.random() * 0.15,
					color: LIGHT[color],
					size: 2 + Math.random() * 2
				});
			}
		}
	}

	function startThrow() {
		throwing = true;
		throwCol = playerCol;
		throwGems = heldGems.copy();
		heldGems = [];
		holding = false;

		// Target: gems land below the existing bottom gem, stacking downward
		var bot = bottomGem(throwCol);
		var landRow:Int;
		if (bot < 0) {
			// Column empty — land at row 0
			landRow = 0;
		} else {
			// Land just below existing bottom
			landRow = bot + 1;
		}
		// Clamp
		if (landRow + throwGems.length > ROWS) landRow = ROWS - throwGems.length;
		if (landRow < 0) landRow = 0;

		throwTargetY = ry(landRow);
		throwY = playerY - 20; // start from player position
	}

	function finishThrow() {
		var c = throwCol;
		var bot = bottomGem(c);
		var startRow:Int;
		if (bot < 0) {
			startRow = 0;
		} else {
			startRow = bot + 1;
		}

		// Place gems below existing ones
		for (i in 0...throwGems.length) {
			var r = startRow + i;
			if (r >= ROWS) {
				// Overflow = death
				gameOver = true;
				deathTimer = 0;
				throwing = false;
				throwGems = [];
				return;
			}
			grid[c][r] = throwGems[i];
		}
		throwing = false;
		throwGems = [];
		chain = 0;
		checkMatches();
	}

	// ── Match Logic ──────────────────────────────────────────────

	function checkMatches() {
		popCells = [];
		var inSet = new haxe.ds.StringMap<Bool>();

		// Vertical
		for (c in 0...COLS) {
			var r = 0;
			while (r < ROWS) {
				var v = grid[c][r];
				if (v == -1) { r++; continue; }
				var end = r + 1;
				while (end < ROWS && grid[c][end] == v) end++;
				if (end - r >= 3)
					for (i in r...end) { var k = c + "," + i; if (!inSet.exists(k)) { inSet.set(k, true); popCells.push({c: c, r: i}); } }
				r = end;
			}
		}
		// Horizontal
		for (r in 0...ROWS) {
			var c = 0;
			while (c < COLS) {
				var v = grid[c][r];
				if (v == -1) { c++; continue; }
				var end = c + 1;
				while (end < COLS && grid[end][r] == v) end++;
				if (end - c >= 3)
					for (i in c...end) { var k = i + "," + r; if (!inSet.exists(k)) { inSet.set(k, true); popCells.push({c: i, r: r}); } }
				c = end;
			}
		}

		if (popCells.length > 0) {
			popping = true;
			popTimer = POP_DELAY;
			chain++;

			var n = popCells.length;
			var bonus = chain * chain;
			score += n * 10 * bonus;
			scoreText.text = Std.string(score);

			if (chain >= 2) {
				chainText.text = "x" + Std.string(chain) + " CHAIN!";
				chainText.visible = true;
				chainTimer = 1.0;
				chainText.y = DESIGN_H / 2 - 20;
				chainText.alpha = 1;
			}

			if (ctx != null && ctx.feedback != null) {
				if (chain >= 3) ctx.feedback.shake2D(0.18, 5);
				else if (chain >= 2) ctx.feedback.shake2D(0.1, 3);
				if (n >= 5) ctx.feedback.flash(0.08);
			}

			// Spawn effects
			for (cell in popCells) {
				var color = grid[cell.c][cell.r];
				if (color < 0) continue;
				var px = cx(cell.c) + GEM_S / 2;
				var py = ry(cell.r) + GEM_S / 2;
				pops.push({x: px, y: py, color: COLORS[color], t: 0.35});
				for (_ in 0...5)
					sparks.push({
						x: px, y: py,
						vx: (Math.random() - 0.5) * 200,
						vy: -50 - Math.random() * 150,
						life: 0.3 + Math.random() * 0.4,
						color: LIGHT[color],
						size: 2 + Math.random() * 3
					});
			}
		} else {
			popping = false;
			chain = 0;
		}
	}

	function executePop() {
		for (cell in popCells) grid[cell.c][cell.r] = -1;
		popCells = [];
		popping = false;
		applyGravity();
		checkMatches();
	}

	// Compact gems UPWARD — gems float to the top, gaps below get removed.
	// After gravity, all gems in a column are contiguous starting from some row, no gaps.
	function applyGravity() {
		for (c in 0...COLS) {
			// Collect all non-empty values top to bottom
			var vals:Array<Int> = [];
			for (r in 0...ROWS) {
				if (grid[c][r] != -1) vals.push(grid[c][r]);
			}
			// Place them starting at row 0
			for (r in 0...ROWS) {
				grid[c][r] = if (r < vals.length) vals[r] else -1;
			}
		}
	}

	// New row pushes from TOP — insert at row 0, shift everything down
	function pushNewRow() {
		// Check if bottom row is occupied (would overflow)
		for (c in 0...COLS) if (grid[c][ROWS - 1] != -1) { gameOver = true; deathTimer = 0; return; }

		// Shift everything down by 1
		for (c in 0...COLS) {
			var r = ROWS - 1;
			while (r > 0) { grid[c][r] = grid[c][r - 1]; r--; }
			// New gem at row 0
			grid[c][0] = Std.random(NUM_COLORS);
		}
	}

	// ── Drawing ──────────────────────────────────────────────────

	function drawBg() {
		bgG.clear();
		// Rich dark gradient
		var steps = 16;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(8 + t * 12);
			var g = Std.int(6 + t * 10);
			var b = Std.int(28 + t * 30);
			bgG.beginFill((r << 16) | (g << 8) | b);
			var y0 = Std.int(DESIGN_H * t);
			bgG.drawRect(0, y0, DESIGN_W, Std.int(DESIGN_H / steps) + 1);
			bgG.endFill();
		}

		// Ambient glow circles
		bgG.beginFill(0x3322AA, 0.04);
		bgG.drawCircle(80, 150, 100);
		bgG.endFill();
		bgG.beginFill(0x2244CC, 0.03);
		bgG.drawCircle(280, 350, 80);
		bgG.endFill();

		// Column guides (subtle lines from board to player)
		for (c in 0...COLS) {
			var x = cx(c) + GEM_S / 2;
			bgG.beginFill(0xFFFFFF, 0.015);
			bgG.drawRect(x - 0.5, BOARD_TOP, 1, boardBottom - BOARD_TOP);
			bgG.endFill();
		}

		// Death line at BOTTOM of grid (pulsing red)
		var pulse = 0.1 + 0.05 * Math.sin(elapsed * 3);
		bgG.beginFill(0xFF2222, pulse);
		bgG.drawRect(brdX - 4, boardBottom - 2, brdW + 8, 2);
		bgG.endFill();
		// Danger zone gradient below death line
		for (i in 0...8) {
			bgG.beginFill(0xFF2222, pulse * 0.3 * (1 - i / 8.0));
			bgG.drawRect(brdX - 4, boardBottom + i * 3, brdW + 8, 3);
			bgG.endFill();
		}

		// Player zone background
		bgG.beginFill(0x0A0A1E, 0.6);
		bgG.drawRoundedRect(brdX - 10, playerY - 30, brdW + 20, 75, 10);
		bgG.endFill();
		bgG.lineStyle(1, 0x4444AA, 0.15);
		bgG.drawRoundedRect(brdX - 10, playerY - 30, brdW + 20, 75, 10);
		bgG.lineStyle(0);
	}

	function drawBoard() {
		boardG.clear();
		// Board outline
		boardG.lineStyle(1, 0x3333AA, 0.12);
		boardG.drawRoundedRect(brdX - 5, BOARD_TOP - 5, brdW + 10, boardBottom - BOARD_TOP + 5, 6);
		boardG.lineStyle(0);

		// Subtle grid cells
		for (c in 0...COLS) {
			for (r in 0...ROWS) {
				boardG.beginFill(0xFFFFFF, 0.01);
				boardG.drawRoundedRect(cx(c), ry(r), GEM_S, GEM_S, 4);
				boardG.endFill();
			}
		}
	}

	function drawGem(g:Graphics, x:Float, y:Float, color:Int, size:Float, ?a:Float) {
		if (a == null) a = 1.0;
		var col = COLORS[color];
		var lt = LIGHT[color];
		var dk = DARK[color];

		// Shadow
		g.beginFill(0x000000, 0.25 * a);
		g.drawRoundedRect(x + 2, y + 3, size, size, 8);
		g.endFill();

		// Body
		g.beginFill(col, a);
		g.drawRoundedRect(x, y, size, size, 8);
		g.endFill();

		// Top gradient highlight
		g.beginFill(lt, 0.45 * a);
		g.drawRoundedRect(x + 2, y + 1, size - 4, size * 0.45, 6);
		g.endFill();

		// Glossy shine
		g.beginFill(0xFFFFFF, 0.4 * a);
		g.drawRoundedRect(x + 5, y + 3, size - 10, 5, 3);
		g.endFill();

		// Bottom dark
		g.beginFill(dk, 0.5 * a);
		g.drawRoundedRect(x + 2, y + size - 7, size - 4, 5, 4);
		g.endFill();

		// Inner border glow
		g.lineStyle(1, lt, 0.2 * a);
		g.drawRoundedRect(x + 1, y + 1, size - 2, size - 2, 7);
		g.lineStyle(0);

		// Center emblem
		var mx = x + size / 2;
		var my = y + size / 2 + 1;
		g.beginFill(0xFFFFFF, 0.55 * a);
		switch (color) {
			case 0: // Diamond
				g.moveTo(mx, my - 7); g.lineTo(mx + 7, my); g.lineTo(mx, my + 7); g.lineTo(mx - 7, my); g.lineTo(mx, my - 7);
			case 1: // Circle
				g.drawCircle(mx, my, 7);
			case 2: // Star/triangle
				g.moveTo(mx, my - 8); g.lineTo(mx + 7, my + 5); g.lineTo(mx - 7, my + 5); g.lineTo(mx, my - 8);
			case 3: // Cross
				g.drawRect(mx - 2, my - 7, 4, 14); g.drawRect(mx - 7, my - 2, 14, 4);
			case 4: // Moon
				g.drawCircle(mx, my, 7);
				g.endFill();
				g.beginFill(col, a);
				g.drawCircle(mx + 3, my - 2, 6);
			default:
		}
		g.endFill();
	}

	function drawGems() {
		gemsG.clear();
		for (c in 0...COLS) {
			for (r in 0...ROWS) {
				var v = grid[c][r];
				if (v < 0) continue;
				var x = cx(c);
				var y = ry(r);

				var isPop = false;
				for (pc in popCells) if (pc.c == c && pc.r == r) { isPop = true; break; }

				if (isPop) {
					var flash = 0.5 + 0.5 * Math.sin(elapsed * 35);
					var sc = 1.0 + flash * 0.1;
					var off = GEM_S * (sc - 1) * 0.5;
					drawGem(gemsG, x - off, y - off, v, GEM_S * sc, flash);
					gemsG.beginFill(0xFFFFFF, (1 - flash) * 0.4);
					gemsG.drawRoundedRect(x - off, y - off, GEM_S * sc, GEM_S * sc, 8);
					gemsG.endFill();
				} else {
					drawGem(gemsG, x, y, v, GEM_S);
				}
			}
		}

		// Throwing animation — gems fly upward
		if (throwing && throwGems.length > 0) {
			for (i in 0...throwGems.length) {
				var x = cx(throwCol);
				var y = throwY + i * (GEM_S + GAP); // stack downward from throwY
				// Trail effect
				gemsG.beginFill(COLORS[throwGems[i]], 0.2);
				gemsG.drawRoundedRect(x + 4, y + GEM_S * 0.3, GEM_S - 8, GEM_S * 0.8, 4);
				gemsG.endFill();
				drawGem(gemsG, x, y, throwGems[i], GEM_S);
			}
		}
	}

	function drawPlayer() {
		playerG.clear();
		var x = cx(playerCol) + GEM_S / 2;
		var py = playerY;

		// Platform
		playerG.beginFill(0x4444CC, 0.3);
		playerG.drawRoundedRect(x - 22, py + 18, 44, 6, 3);
		playerG.endFill();

		// Body
		playerG.beginFill(0x4488FF);
		playerG.drawRoundedRect(x - 12, py + 2, 24, 18, 6);
		playerG.endFill();
		playerG.beginFill(0x66AAFF, 0.5);
		playerG.drawRoundedRect(x - 8, py + 3, 16, 8, 4);
		playerG.endFill();

		// Head
		playerG.beginFill(0xFFDDAA);
		playerG.drawCircle(x, py - 6, 11);
		playerG.endFill();
		// Cheeks
		playerG.beginFill(0xFFAA88, 0.3);
		playerG.drawCircle(x - 7, py - 3, 3);
		playerG.drawCircle(x + 7, py - 3, 3);
		playerG.endFill();

		// Eyes
		var eyeOff = holding ? -1 : 0;
		playerG.beginFill(0xFFFFFF);
		playerG.drawEllipse(x - 4, py - 7 + eyeOff, 3.5, 4);
		playerG.drawEllipse(x + 4, py - 7 + eyeOff, 3.5, 4);
		playerG.endFill();
		playerG.beginFill(0x111133);
		playerG.drawCircle(x - 3.5, py - 7 + eyeOff, 2);
		playerG.drawCircle(x + 4.5, py - 7 + eyeOff, 2);
		playerG.endFill();
		playerG.beginFill(0xFFFFFF);
		playerG.drawCircle(x - 3, py - 8 + eyeOff, 0.8);
		playerG.drawCircle(x + 5, py - 8 + eyeOff, 0.8);
		playerG.endFill();

		// Mouth
		if (holding) {
			playerG.beginFill(0xDD5544);
			playerG.drawCircle(x, py - 2, 2.5);
			playerG.endFill();
		} else {
			playerG.lineStyle(1.5, 0xDD6644);
			playerG.moveTo(x - 3, py - 2);
			playerG.lineTo(x, py);
			playerG.lineTo(x + 3, py - 2);
			playerG.lineStyle(0);
		}

		// Crown
		playerG.beginFill(0xFFCC00);
		playerG.moveTo(x - 8, py - 14);
		playerG.lineTo(x - 5, py - 22);
		playerG.lineTo(x, py - 17);
		playerG.lineTo(x + 5, py - 22);
		playerG.lineTo(x + 8, py - 14);
		playerG.endFill();
		playerG.beginFill(0xFF3333);
		playerG.drawCircle(x - 5, py - 20, 1.5);
		playerG.endFill();
		playerG.beginFill(0x3333FF);
		playerG.drawCircle(x + 5, py - 20, 1.5);
		playerG.endFill();
		playerG.beginFill(0xFFFFFF);
		playerG.drawCircle(x, py - 17, 1.5);
		playerG.endFill();

		// Arms
		if (holding) {
			playerG.beginFill(0xFFDDAA);
			playerG.drawRoundedRect(x - 17, py - 10, 6, 14, 3);
			playerG.drawRoundedRect(x + 11, py - 10, 6, 14, 3);
			playerG.endFill();
		} else {
			playerG.beginFill(0xFFDDAA);
			playerG.drawRoundedRect(x - 16, py + 2, 5, 10, 2);
			playerG.drawRoundedRect(x + 11, py + 2, 5, 10, 2);
			playerG.endFill();
		}

		// Arrow pointing up (toward grid)
		var arrowPulse = 0.4 + 0.3 * Math.sin(elapsed * 4);
		playerG.beginFill(0x88AAFF, arrowPulse);
		playerG.moveTo(x - 6, py - 28);
		playerG.lineTo(x, py - 36);
		playerG.lineTo(x + 6, py - 28);
		playerG.endFill();
	}

	function drawHeld() {
		heldG.clear();
		if (!holding || heldGems.length == 0) return;

		var x = cx(playerCol);
		for (i in 0...heldGems.length) {
			// Show held gems above the player, stacking upward
			var gy = playerY - 42 - i * (GEM_S * 0.55 + 2);
			var bob = Math.sin(elapsed * 7 + i * 0.6) * 2;
			drawGem(heldG, x + 4, gy + bob, heldGems[i], GEM_S * 0.75, 0.9);
		}
	}

	function drawPushBar() {
		pushBarG.clear();
		var interval = PUSH_START + (PUSH_MIN - PUSH_START) * Math.min(elapsed / PUSH_RAMP, 1.0);
		var pct = 1.0 - pushTimer / interval;
		if (pct < 0) pct = 0;
		if (pct > 1) pct = 1;

		// Bar at top of grid
		var barW = brdW;
		var barH = 4.0;
		var barX = brdX;
		var barY = BOARD_TOP - 10;
		pushBarG.beginFill(0x222244);
		pushBarG.drawRoundedRect(barX, barY, barW, barH, 2);
		pushBarG.endFill();

		var fillColor = if (pct > 0.8) 0xFF4444 else if (pct > 0.5) 0xFFAA33 else 0x44FF66;
		pushBarG.beginFill(fillColor, 0.8);
		pushBarG.drawRoundedRect(barX, barY, barW * pct, barH, 2);
		pushBarG.endFill();
	}

	function drawEffects() {
		fxG.clear();
		for (p in pops) {
			var t = 1 - p.t / 0.35;
			var r = 8 + t * 25;
			var a = (1 - t) * 0.5;
			fxG.beginFill(p.color, a);
			fxG.drawCircle(p.x, p.y, r);
			fxG.endFill();
			fxG.beginFill(0xFFFFFF, a * 0.6);
			fxG.drawCircle(p.x, p.y, r * 0.4);
			fxG.endFill();
			fxG.lineStyle(2, p.color, a * 0.4);
			fxG.drawCircle(p.x, p.y, r * 1.3);
			fxG.lineStyle(0);
		}
		for (s in sparks) {
			if (s.life <= 0) continue;
			var a = s.life * 1.5;
			if (a > 1) a = 1;
			fxG.beginFill(s.color, a);
			fxG.drawCircle(s.x, s.y, s.size * a);
			fxG.endFill();
			fxG.beginFill(0xFFFFFF, a * 0.4);
			fxG.drawCircle(s.x, s.y, s.size * a * 0.4);
			fxG.endFill();
		}
	}

	function drawAll() {
		drawBg();
		drawBoard();
		drawGems();
		drawEffects();
		drawPlayer();
		drawHeld();
		drawPushBar();
	}

	// ── Init ─────────────────────────────────────────────────────

	function initBoard() {
		grid = [for (_ in 0...COLS) [for (_ in 0...ROWS) -1]];
		// Fill rows 0..4 at the top — gems start at the top, grow downward
		for (r in 0...5) {
			for (c in 0...COLS) {
				var color:Int;
				var att = 0;
				do { color = Std.random(NUM_COLORS); att++; }
				while (att < 30 && wouldMatch(c, r, color));
				grid[c][r] = color;
			}
		}
	}

	function wouldMatch(col:Int, row:Int, color:Int):Bool {
		if (row >= 2 && grid[col][row - 1] == color && grid[col][row - 2] == color) return true;
		if (col >= 2 && grid[col - 1][row] == color && grid[col - 2][row] == color) return true;
		return false;
	}

	// ── Interface ────────────────────────────────────────────────

	public function setOnLose(c:MinigameContext) { ctx = c; }

	public function start() {
		initBoard();
		playerCol = 3;
		heldGems = [];
		holding = false;
		score = 0;
		chain = 0;
		elapsed = 0;
		pushTimer = PUSH_START;
		gameOver = false;
		deathTimer = -1;
		popping = false;
		popTimer = 0;
		popCells = [];
		throwing = false;
		throwGems = [];
		throwY = 0;
		chainTimer = 0;
		tDown = false;
		pops = [];
		sparks = [];
		overlayG.clear();
		chainText.visible = false;
		hintText.visible = true;
		scoreText.text = "0";
		drawAll();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String return "magical-drop";
	public function getTitle():String return "Magical Drop";

	public function update(dt:Float) {
		if (ctx == null) return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					overlayG.clear();
					overlayG.beginFill(0x000000, t * 0.6);
					overlayG.drawRect(0, 0, DESIGN_W, DESIGN_H);
					overlayG.endFill();
				} else {
					overlayG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		elapsed += dt;

		// Update effects
		var i = pops.length;
		while (i-- > 0) { pops[i].t -= dt; if (pops[i].t <= 0) pops.splice(i, 1); }
		i = sparks.length;
		while (i-- > 0) {
			var s = sparks[i];
			s.life -= dt;
			if (s.life <= 0) { sparks.splice(i, 1); continue; }
			s.x += s.vx * dt;
			s.y += s.vy * dt;
			s.vy += 250 * dt;
		}

		if (popping) {
			popTimer -= dt;
			if (popTimer <= 0) executePop();
			drawAll();
			return;
		}

		if (throwing) {
			throwY -= THROW_SPEED * dt; // flying upward
			if (throwY <= throwTargetY || throwY < BOARD_TOP - 50) {
				throwY = throwTargetY;
				finishThrow();
			}
			drawAll();
			return;
		}

		// Push timer — new row from top
		var interval = PUSH_START + (PUSH_MIN - PUSH_START) * Math.min(elapsed / PUSH_RAMP, 1.0);
		pushTimer -= dt;
		if (pushTimer <= 0) {
			pushTimer = interval;
			pushNewRow();
			if (gameOver) { drawAll(); return; }
		}

		// Chain text
		if (chainText.visible) {
			chainTimer -= dt;
			chainText.alpha = Math.max(chainTimer / 1.0, 0);
			chainText.y = DESIGN_H / 2 - 20 - (1.0 - chainTimer) * 25;
			if (chainTimer <= 0) chainText.visible = false;
		}

		if (elapsed > 4) hintText.visible = false;

		drawAll();
	}
}
