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
	Cobrinha clássica com wrap: atravessa as bordas (sai à direita = entra à esquerda).
	Perde só se bater no próprio corpo. Controle por swipe (cima/baixo/esquerda/direita).
**/
class SnakeGame implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var CELL = 20;
	static var GRID_W = 18;
	static var GRID_H = 32;
	static var TICK_INTERVAL = 0.12;
	static var SWIPE_THRESHOLD_PX = 40;
	static var SWIPE_MAX_DURATION = 0.35;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var snakeG: Graphics;
	var foodG: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var body: Array<{ x: Int, y: Int }>;
	var dir: { dx: Int, dy: Int };
	var nextDir: { dx: Int, dy: Int };
	var food: { x: Int, y: Int };
	var tickAcc: Float;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var touchStartX: Float;
	var touchStartY: Float;
	var touchStartTime: Float;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x1a2a1a);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		// Grade sutil
		bg.lineStyle(1, 0x2a3a2a, 0.4);
		for (gx in 0...GRID_W + 1) {
			bg.moveTo(gx * CELL, 0);
			bg.lineTo(gx * CELL, designH);
		}
		for (gy in 0...GRID_H + 1) {
			bg.moveTo(0, gy * CELL);
			bg.lineTo(designW, gy * CELL);
		}
		bg.lineStyle(0);

		snakeG = new Graphics(contentObj);
		foodG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 8;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchStartTime = haxe.Timer.stamp();
		};
		interactive.onRelease = function(e: Event) {
			if (gameOver || ctx == null) return;
			var dt = haxe.Timer.stamp() - touchStartTime;
			if (dt > SWIPE_MAX_DURATION) return;
			var dy = e.relY - touchStartY;
			var dx = e.relX - touchStartX;
			if (Math.abs(dy) >= SWIPE_THRESHOLD_PX && Math.abs(dy) >= Math.abs(dx)) {
				if (dy < 0) setDir(0, -1);
				else setDir(0, 1);
				e.propagate = false;
			} else if (Math.abs(dx) >= SWIPE_THRESHOLD_PX && Math.abs(dx) >= Math.abs(dy)) {
				if (dx < 0) setDir(-1, 0);
				else setDir(1, 0);
				e.propagate = false;
			}
		};
	}

	inline function wrapX(x: Int): Int {
		return ((x % GRID_W) + GRID_W) % GRID_W;
	}
	inline function wrapY(y: Int): Int {
		return ((y % GRID_H) + GRID_H) % GRID_H;
	}

	function setDir(dx: Int, dy: Int) {
		if (body.length <= 1) {
			nextDir = { dx: dx, dy: dy };
			return;
		}
		var h = body[0];
		var n = body[1];
		if (h.x + dx == n.x && h.y + dy == n.y) return;
		nextDir = { dx: dx, dy: dy };
	}

	function spawnFood() {
		do {
			food = { x: Std.random(GRID_W), y: Std.random(GRID_H) };
		} while (bodyOccupied(food.x, food.y));
	}

	function bodyOccupied(gx: Int, gy: Int): Bool {
		for (s in body)
			if (s.x == gx && s.y == gy) return true;
		return false;
	}

	function drawSnake() {
		snakeG.clear();
		for (i in 0...body.length) {
			var s = body[i];
			var px = s.x * CELL;
			var py = s.y * CELL;
			var isHead = i == 0;
			snakeG.beginFill(isHead ? 0x7CFC00 : 0x5CB800);
			snakeG.drawRect(px + 1, py + 1, CELL - 2, CELL - 2);
			snakeG.endFill();
			if (isHead) {
				snakeG.beginFill(0x1a2a1a);
				var ex = px + CELL * 0.5;
				var ey = py + CELL * 0.5;
				if (dir.dx == 1) { snakeG.drawRect(ex + 2, ey - 2, 4, 4); }
				else if (dir.dx == -1) { snakeG.drawRect(ex - 6, ey - 2, 4, 4); }
				else if (dir.dy == 1) { snakeG.drawRect(ex - 2, ey + 2, 4, 4); }
				else { snakeG.drawRect(ex - 2, ey - 6, 4, 4); }
				snakeG.endFill();
			}
		}
	}

	function drawFood() {
		foodG.clear();
		foodG.beginFill(0xE74C3C);
		foodG.drawRect(food.x * CELL + 2, food.y * CELL + 2, CELL - 4, CELL - 4);
		foodG.endFill();
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		var cx = Std.int(GRID_W / 2);
		var cy = Std.int(GRID_H / 2);
		body = [
			{ x: cx, y: cy },
			{ x: cx - 1, y: cy },
			{ x: cx - 2, y: cy }
		];
		dir = { dx: 1, dy: 0 };
		nextDir = { dx: 1, dy: 0 };
		tickAcc = 0;
		started = false;
		score = 0;
		gameOver = false;
		scoreText.text = "0";
		spawnFood();
		drawSnake();
		drawFood();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		body = [];
	}

	public function getMinigameId(): String return "snake";
	public function getTitle(): String return "Snake";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started) {
			drawSnake();
			drawFood();
			return;
		}

		tickAcc += dt;
		if (tickAcc < TICK_INTERVAL) {
			drawSnake();
			drawFood();
			return;
		}
		tickAcc -= TICK_INTERVAL;

		dir = nextDir;
		var h = body[0];
		var nx = wrapX(h.x + dir.dx);
		var ny = wrapY(h.y + dir.dy);

		for (i in 1...body.length)
			if (body[i].x == nx && body[i].y == ny) {
				gameOver = true;
				ctx.lose(score, getMinigameId());
				ctx = null;
				return;
			}

		body.unshift({ x: nx, y: ny });

		if (nx == food.x && ny == food.y) {
			score++;
			scoreText.text = Std.string(score);
			spawnFood();
		} else {
			body.pop();
		}

		drawSnake();
		drawFood();
	}
}
