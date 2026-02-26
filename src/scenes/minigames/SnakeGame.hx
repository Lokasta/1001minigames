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
	Cobrinha clássica com wrap, checkerboard, cobra estilizada e maçã pulsante.
	Perde se bater no próprio corpo. Controle por swipe. Velocidade aumenta com score.
**/
class SnakeGame implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var CELL = 20;
	static var GRID_W = 18;
	static var GRID_H = 30;
	static var GRID_OFFSET_Y = 40;
	static var TICK_BASE = 0.13;
	static var TICK_MIN = 0.06;
	static var SWIPE_THRESHOLD = 30;
	static var SWIPE_MAX_DUR = 0.4;
	static var DEATH_DUR = 0.5;
	static var EAT_FLASH_DUR = 0.15;

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var bg:Graphics;
	var snakeG:Graphics;
	var foodG:Graphics;
	var effectG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var body:Array<{x:Int, y:Int}>;
	var dir:{dx:Int, dy:Int};
	var nextDir:{dx:Int, dy:Int};
	var food:{x:Int, y:Int};
	var tickAcc:Float;
	var started:Bool;
	var score:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var eatFlashTimer:Float;
	var touchStartX:Float;
	var touchStartY:Float;
	var touchStartTime:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		snakeG = new Graphics(contentObj);
		foodG = new Graphics(contentObj);
		effectG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 14;
		scoreText.y = 12;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Deslize para mover";
		instructText.x = designW / 2;
		instructText.y = 12;
		instructText.scale(1.0);
		instructText.textAlign = Center;
		instructText.textColor = 0x88AA88;
		instructText.visible = true;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (ctx == null || gameOver)
				return;
			if (!started)
				started = true;
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchStartTime = haxe.Timer.stamp();
			e.propagate = false;
		};
		interactive.onRelease = function(e:Event) {
			if (gameOver || ctx == null || !started)
				return;
			var dt = haxe.Timer.stamp() - touchStartTime;
			if (dt > SWIPE_MAX_DUR)
				return;
			var dy = e.relY - touchStartY;
			var dx = e.relX - touchStartX;
			if (Math.abs(dy) >= SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (dy < 0)
					setDir(0, -1);
				else
					setDir(0, 1);
				e.propagate = false;
			} else if (Math.abs(dx) >= SWIPE_THRESHOLD && Math.abs(dx) >= Math.abs(dy)) {
				if (dx < 0)
					setDir(-1, 0);
				else
					setDir(1, 0);
				e.propagate = false;
			}
		};
	}

	inline function wrapX(x:Int):Int
		return ((x % GRID_W) + GRID_W) % GRID_W;

	inline function wrapY(y:Int):Int
		return ((y % GRID_H) + GRID_H) % GRID_H;

	function setDir(dx:Int, dy:Int) {
		if (body.length <= 1) {
			nextDir = {dx: dx, dy: dy};
			return;
		}
		var h = body[0];
		var n = body[1];
		if (wrapX(h.x + dx) == n.x && wrapY(h.y + dy) == n.y)
			return;
		nextDir = {dx: dx, dy: dy};
	}

	function currentTick():Float {
		var speedUp = score * 0.003;
		if (speedUp > TICK_BASE - TICK_MIN)
			speedUp = TICK_BASE - TICK_MIN;
		return TICK_BASE - speedUp;
	}

	function spawnFood() {
		var attempts = 0;
		do {
			food = {x: Std.random(GRID_W), y: Std.random(GRID_H)};
			attempts++;
		} while (bodyOccupied(food.x, food.y) && attempts < 200);
	}

	function bodyOccupied(gx:Int, gy:Int):Bool {
		for (s in body)
			if (s.x == gx && s.y == gy)
				return true;
		return false;
	}

	function cellX(gx:Int):Float
		return gx * CELL;

	function cellY(gy:Int):Float
		return gy * CELL + GRID_OFFSET_Y;

	function drawBackground() {
		bg.clear();
		bg.beginFill(0x1a2a1a);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		var dark = 0x1e2e1e;
		var light = 0x223222;
		for (gy in 0...GRID_H) {
			for (gx in 0...GRID_W) {
				var c = ((gx + gy) % 2 == 0) ? dark : light;
				bg.beginFill(c);
				bg.drawRect(cellX(gx), cellY(gy), CELL, CELL);
				bg.endFill();
			}
		}
		bg.beginFill(0x0d1a0d);
		bg.drawRect(0, 0, designW, GRID_OFFSET_Y);
		bg.endFill();
		bg.beginFill(0x0d1a0d);
		bg.drawRect(0, cellY(GRID_H), designW, designH - cellY(GRID_H));
		bg.endFill();
	}

	function drawSnake() {
		snakeG.clear();
		for (i in 0...body.length) {
			var s = body[i];
			var px = cellX(s.x);
			var py = cellY(s.y);
			var isHead = i == 0;
			var isTail = i == body.length - 1;

			if (isHead) {
				snakeG.beginFill(0x76EE00);
				snakeG.drawRoundedRect(px + 1, py + 1, CELL - 2, CELL - 2, 5);
				snakeG.endFill();
				snakeG.beginFill(0x8AFF1A, 0.4);
				snakeG.drawRoundedRect(px + 3, py + 3, CELL - 8, CELL - 8, 3);
				snakeG.endFill();
				var ex1x:Float;
				var ex1y:Float;
				var ex2x:Float;
				var ex2y:Float;
				if (dir.dx == 1) {
					ex1x = px + 14;
					ex1y = py + 5;
					ex2x = px + 14;
					ex2y = py + 13;
				} else if (dir.dx == -1) {
					ex1x = px + 5;
					ex1y = py + 5;
					ex2x = px + 5;
					ex2y = py + 13;
				} else if (dir.dy == 1) {
					ex1x = px + 5;
					ex1y = py + 14;
					ex2x = px + 13;
					ex2y = py + 14;
				} else {
					ex1x = px + 5;
					ex1y = py + 5;
					ex2x = px + 13;
					ex2y = py + 5;
				}
				snakeG.beginFill(0xFFFFFF);
				snakeG.drawCircle(ex1x, ex1y, 3);
				snakeG.drawCircle(ex2x, ex2y, 3);
				snakeG.endFill();
				snakeG.beginFill(0x111111);
				snakeG.drawCircle(ex1x + dir.dx, ex1y + dir.dy, 1.5);
				snakeG.drawCircle(ex2x + dir.dx, ex2y + dir.dy, 1.5);
				snakeG.endFill();
			} else if (isTail) {
				snakeG.beginFill(0x3D8B00);
				snakeG.drawRoundedRect(px + 2, py + 2, CELL - 4, CELL - 4, 6);
				snakeG.endFill();
			} else {
				var t = i / body.length;
				var r = Std.int(0x4C + (0x3D - 0x4C) * t);
				var g = Std.int(0xBB + (0x8B - 0xBB) * t);
				var b = 0x00;
				var c = (r << 16) | (g << 8) | b;
				snakeG.beginFill(c);
				snakeG.drawRoundedRect(px + 1, py + 1, CELL - 2, CELL - 2, 3);
				snakeG.endFill();
				if (i % 3 == 0) {
					snakeG.beginFill(0x5CCB00, 0.25);
					snakeG.drawRoundedRect(px + 3, py + 3, CELL - 6, CELL - 6, 2);
					snakeG.endFill();
				}
			}
		}
	}

	function drawFood() {
		foodG.clear();
		var px = cellX(food.x);
		var py = cellY(food.y);
		var cx = px + CELL / 2;
		var cy = py + CELL / 2;
		var pulse = Math.sin(haxe.Timer.stamp() * 4) * 0.12 + 1.0;
		var r = (CELL / 2 - 2) * pulse;
		foodG.beginFill(0xE74C3C);
		foodG.drawCircle(cx, cy, r);
		foodG.endFill();
		foodG.beginFill(0xFF6655, 0.5);
		foodG.drawCircle(cx - 2, cy - 2, r * 0.4);
		foodG.endFill();
		foodG.beginFill(0x2D8B27);
		foodG.drawRect(cx - 1, cy - r - 3, 2, 4);
		foodG.endFill();
		foodG.beginFill(0x3DAA37);
		foodG.drawEllipse(cx + 2, cy - r - 1, 4, 2);
		foodG.endFill();
	}

	function drawEffects() {
		effectG.clear();
		if (eatFlashTimer > 0) {
			var t = eatFlashTimer / EAT_FLASH_DUR;
			var h = body[0];
			var px = cellX(h.x) + CELL / 2;
			var py = cellY(h.y) + CELL / 2;
			var r = (1 - t) * 25;
			effectG.beginFill(0xFFFF00, t * 0.5);
			effectG.drawCircle(px, py, r);
			effectG.endFill();
		}
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		var cx = Std.int(GRID_W / 2);
		var cy = Std.int(GRID_H / 2);
		body = [{x: cx, y: cy}, {x: cx - 1, y: cy}, {x: cx - 2, y: cy}];
		dir = {dx: 1, dy: 0};
		nextDir = {dx: 1, dy: 0};
		tickAcc = 0;
		started = false;
		score = 0;
		gameOver = false;
		deathTimer = -1;
		eatFlashTimer = 0;
		scoreText.text = "0";
		instructText.visible = true;
		flashG.clear();
		spawnFood();
		drawBackground();
		drawSnake();
		drawFood();
		drawEffects();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		body = [];
	}

	public function getMinigameId():String
		return "snake";

	public function getTitle():String
		return "Cobrinha";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFF0000, (1 - t) * 0.35);
					flashG.drawRect(0, 0, designW, designH);
					flashG.endFill();
				} else {
					flashG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (!started) {
			drawSnake();
			drawFood();
			return;
		}

		if (eatFlashTimer > 0) {
			eatFlashTimer -= dt;
			drawEffects();
		}

		tickAcc += dt;
		var tick = currentTick();
		if (tickAcc < tick) {
			drawSnake();
			drawFood();
			return;
		}
		tickAcc -= tick;

		dir = nextDir;
		var h = body[0];
		var nx = wrapX(h.x + dir.dx);
		var ny = wrapY(h.y + dir.dy);

		for (i in 1...body.length) {
			if (body[i].x == nx && body[i].y == ny) {
				gameOver = true;
				deathTimer = 0;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.3, 4);
				drawSnake();
				return;
			}
		}

		body.unshift({x: nx, y: ny});

		if (nx == food.x && ny == food.y) {
			score++;
			scoreText.text = Std.string(score);
			eatFlashTimer = EAT_FLASH_DUR;
			instructText.visible = false;
			spawnFood();
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.04, 1);
		} else {
			body.pop();
		}

		drawSnake();
		drawFood();
		drawEffects();
	}
}
