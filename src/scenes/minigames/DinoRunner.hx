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
	Infinite runner no estilo do dinossauro do Chrome (offline).
	Controles estilo Subway Surfers: swipe up = pular (ou levantar se abaixado);
	swipe down = abaixar por um tempo (ou acelerar pra baixo no ar).
	Cactos = pular por cima. Pássaros = abaixar por baixo.
**/
class DinoRunner implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRAVITY = 920;
	static var JUMP_STRENGTH = -400;
	static var FAST_FALL_VY = 620;
	static var GROUND_Y = 520;
	static var DINO_X = 72;
	static var DINO_W = 36;
	static var DINO_H = 44;
	static var DINO_DUCK_H = 26;
	static var RUN_SPEED = 280;
	static var SPAWN_INTERVAL_MIN = 1.0;
	static var SPAWN_INTERVAL_MAX = 2.2;
	static var GROUND_STRIP_W = 80;
	static var BIRD_Y = 472;
	static var BIRD_W = 32;
	static var BIRD_H = 22;
	static var HIGH_OBSTACLE_Y = 382;
	static var HIGH_OBSTACLE_W = 28;
	static var HIGH_OBSTACLE_H = 42;
	static var SWIPE_THRESHOLD_PX = 52;
	static var SWIPE_MAX_DURATION = 0.38;
	static var DUCK_DURATION = 0.75;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var groundG: Graphics;
	var dinoG: Graphics;
	var obstaclesG: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var dinoY: Float;
	var dinoVy: Float;
	var started: Bool;
	var score: Int;
	var obstacles: Array<Obstacle>;
	var spawnTimer: Float;
	var gameOver: Bool;
	var groundOffset: Float;
	var runFrame: Bool;
	var runAnimTimer: Float;
	var ducking: Bool;
	var duckTimer: Float;
	var fastFall: Bool;
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
		obstacles = [];

		// Céu desértico
		bg = new Graphics(contentObj);
		bg.beginFill(0xF7F7E8);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		// Nuvem sutil
		bg.beginFill(0xEDE8D8, 0.6);
		bg.drawEllipse(280, 120, 50, 25);
		bg.drawEllipse(100, 200, 40, 20);
		bg.endFill();

		groundG = new Graphics(contentObj);
		dinoG = new Graphics(contentObj);
		obstaclesG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 60;
		scoreText.y = 24;
		scoreText.scale(1.6);
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
			var isSwipeUp = dy < -SWIPE_THRESHOLD_PX && Math.abs(dy) >= Math.abs(dx);
			var isSwipeDown = dy > SWIPE_THRESHOLD_PX && Math.abs(dy) >= Math.abs(dx);

			if (isSwipeUp) {
				if (ducking) {
					ducking = false;
					duckTimer = 0;
				} else if (onGround()) {
					dinoVy = JUMP_STRENGTH;
				}
				e.propagate = false;
			} else if (isSwipeDown) {
				if (onGround()) {
					ducking = true;
					duckTimer = DUCK_DURATION;
				} else {
					fastFall = true;
				}
				e.propagate = false;
			}
		};
	}

	inline function onGround(): Bool {
		return dinoY >= GROUND_Y - DINO_H - 2;
	}

	function drawGround() {
		groundG.clear();
		var y = GROUND_Y;
		// Faixa de chão (marrom)
		groundG.beginFill(0x8B7355);
		groundG.drawRect(0, y + 4, designW + 20, 24);
		groundG.endFill();
		// Linha do chão com “tijolinhos” rolantes
		var ox = groundOffset % GROUND_STRIP_W;
		groundG.lineStyle(2, 0x6B5344);
		var x = -ox;
		while (x < designW + GROUND_STRIP_W) {
			groundG.moveTo(x, y);
			groundG.lineTo(x + GROUND_STRIP_W, y);
			x += GROUND_STRIP_W;
		}
		groundG.lineStyle(0);
	}

	function drawDino(y: Float) {
		dinoG.clear();
		var x = DINO_X;
		if (ducking) {
			// Dino abaixado: corpo alongado, cabeça na frente, pernas dobradas
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 2, y + 14, 32, 10);
			dinoG.endFill();
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 28, y + 10, 12, 10);
			dinoG.endFill();
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawRect(x + 34, y + 12, 3, 3);
			dinoG.endFill();
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x, y + 18, 6, 4);
			dinoG.endFill();
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 8, y + 20, 6, 4);
			dinoG.drawRect(x + 22, y + 20, 6, 4);
			dinoG.endFill();
		} else {
			// Corpo (cinza escuro, estilo Chrome)
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 4, y + 18, 22, 20);
			dinoG.endFill();
			// Cabeça
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 20, y + 8, 14, 14);
			dinoG.endFill();
			// Olho
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawRect(x + 28, y + 10, 4, 4);
			dinoG.endFill();
			// Pescoço
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x + 18, y + 14, 6, 8);
			dinoG.endFill();
			// Rabo
			dinoG.beginFill(0x535353);
			dinoG.drawRect(x, y + 24, 8, 6);
			dinoG.endFill();
			// Perna (animação correndo)
			dinoG.beginFill(0x535353);
			if (runFrame) {
				dinoG.drawRect(x + 8, y + 34, 6, 10);
				dinoG.drawRect(x + 20, y + 38, 8, 6);
			} else {
				dinoG.drawRect(x + 8, y + 38, 8, 6);
				dinoG.drawRect(x + 20, y + 34, 6, 10);
			}
			dinoG.endFill();
		}
	}

	function drawBird(ox: Float, oy: Float) {
		var g = obstaclesG;
		g.beginFill(0x4A4A4A);
		g.drawRect(ox, oy + 6, 20, 10);
		g.endFill();
		g.beginFill(0x4A4A4A);
		g.drawRect(ox + 16, oy + 4, 14, 8);
		g.endFill();
		g.beginFill(0x3D3D3D);
		g.drawRect(ox + 26, oy + 8, 6, 6);
		g.endFill();
		g.beginFill(0xFFFFFF);
		g.drawRect(ox + 28, oy + 9, 2, 2);
		g.endFill();
		g.lineStyle(1, 0x2D2D2D);
		g.drawRect(ox, oy + 6, 20, 10);
		g.drawRect(ox + 16, oy + 4, 14, 8);
		g.lineStyle(0);
	}

	function drawCactus(ox: Float, oy: Float, tall: Bool) {
		var g = obstaclesG;
		// Caule
		g.beginFill(0x2D5A27);
		g.drawRect(ox, oy, 18, tall ? 52 : 36);
		g.endFill();
		g.lineStyle(1, 0x1E3D1A);
		g.drawRect(ox, oy, 18, tall ? 52 : 36);
		g.lineStyle(0);
		// Braços
		g.beginFill(0x2D5A27);
		g.drawRect(ox + 14, oy + 12, 14, 8);
		g.drawRect(ox - 10, oy + 24, 14, 8);
		if (tall) g.drawRect(ox + 12, oy + 38, 12, 6);
		g.endFill();
		g.lineStyle(1, 0x1E3D1A);
		g.drawRect(ox + 14, oy + 12, 14, 8);
		g.drawRect(ox - 10, oy + 24, 14, 8);
		if (tall) g.drawRect(ox + 12, oy + 38, 12, 6);
		g.lineStyle(0);
	}

	function drawHighBar(ox: Float, oy: Float) {
		var g = obstaclesG;
		// Barra horizontal (te pega se estiver pulando)
		g.beginFill(0x5A4A3A);
		g.drawRect(ox, oy, HIGH_OBSTACLE_W, 12);
		g.endFill();
		g.beginFill(0x6B5A4A);
		g.drawRect(ox + 2, oy + 4, HIGH_OBSTACLE_W - 4, 6);
		g.endFill();
		g.lineStyle(2, 0x3D3228);
		g.drawRect(ox, oy, HIGH_OBSTACLE_W, 12);
		g.lineStyle(0);
		// "Pilares" curtos pra parecer estrutura
		g.beginFill(0x5A4A3A);
		g.drawRect(ox + 4, oy + 12, 4, HIGH_OBSTACLE_H - 12);
		g.drawRect(ox + HIGH_OBSTACLE_W - 8, oy + 12, 4, HIGH_OBSTACLE_H - 12);
		g.endFill();
	}

	function spawnObstacle() {
		var r = Math.random();
		if (r < 0.34) {
			// Chão: tem que pular
			var tall = Math.random() > 0.5;
			var h = tall ? 52 : 36;
			obstacles.push({
				x: designW + 20,
				y: GROUND_Y + 4 - h,
				w: 22,
				h: h,
				tall: tall,
				scored: false,
				isBird: false,
				isHigh: false
			});
		} else if (r < 0.67) {
			// Meio: tem que abaixar
			obstacles.push({
				x: designW + 20,
				y: BIRD_Y,
				w: BIRD_W,
				h: BIRD_H,
				tall: false,
				scored: false,
				isBird: true,
				isHigh: false
			});
		} else {
			// Alto: te pega se estiver pulando
			obstacles.push({
				x: designW + 20,
				y: HIGH_OBSTACLE_Y,
				w: HIGH_OBSTACLE_W,
				h: HIGH_OBSTACLE_H,
				tall: false,
				scored: false,
				isBird: false,
				isHigh: true
			});
		}
	}

	function drawObstacles() {
		obstaclesG.clear();
		for (o in obstacles) {
			if (o.isHigh) drawHighBar(o.x, o.y);
			else if (o.isBird) drawBird(o.x, o.y);
			else drawCactus(o.x, o.y, o.tall);
		}
	}

	function hitObstacle(): Bool {
		var dx = DINO_X + 6;
		var dw = DINO_W - 8;
		var dy: Float;
		var dh: Float;
		if (ducking) {
			dy = GROUND_Y - DINO_DUCK_H + 4;
			dh = DINO_DUCK_H - 8;
		} else {
			dy = dinoY + 10;
			dh = DINO_H - 16;
		}
		for (o in obstacles) {
			var ox = o.x + 2;
			var oy = o.y + 2;
			var ow = o.w - 4;
			var oh = o.h - 4;
			if (o.isBird) {
				if (ducking) continue;
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			} else if (o.isHigh) {
				// Barra alta: só acerta se estiver no ar (pulando)
				if (ducking) continue;
				if (onGround()) continue;
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			} else {
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			}
		}
		return false;
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		dinoY = GROUND_Y - DINO_H;
		dinoVy = 0;
		started = false;
		score = 0;
		gameOver = false;
		obstacles = [];
		spawnTimer = 0.5;
		groundOffset = 0;
		runFrame = false;
		runAnimTimer = 0;
		ducking = false;
		duckTimer = 0;
		fastFall = false;
		touchStartX = 0;
		touchStartY = 0;
		touchStartTime = 0;
		scoreText.text = "0";
		drawGround();
		drawDino(dinoY);
		drawObstacles();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		obstacles = [];
	}

	public function getMinigameId(): String return "dino-runner";
	public function getTitle(): String return "Dino Run";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;

		if (!started) {
			drawGround();
			drawDino(dinoY);
			return;
		}

		groundOffset += RUN_SPEED * dt;

		if (ducking) {
			duckTimer -= dt;
			if (duckTimer <= 0) {
				ducking = false;
				duckTimer = 0;
			}
			dinoY = GROUND_Y - DINO_DUCK_H;
			dinoVy = 0;
		} else {
			dinoVy += GRAVITY * dt;
			if (fastFall && dinoVy < FAST_FALL_VY)
				dinoVy = FAST_FALL_VY;
			dinoY += dinoVy * dt;
			if (dinoY >= GROUND_Y - DINO_H) {
				dinoY = GROUND_Y - DINO_H;
				dinoVy = 0;
				fastFall = false;
			}
		}

		runAnimTimer += dt;
		if (runAnimTimer >= 0.08) {
			runAnimTimer = 0;
			runFrame = !runFrame;
		}

		if (hitObstacle()) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		for (o in obstacles) o.x -= RUN_SPEED * dt;
		for (o in obstacles) {
			if (!o.scored && o.x + o.w < DINO_X) {
				o.scored = true;
				score++;
				scoreText.text = Std.string(score);
			}
		}
		while (obstacles.length > 0 && obstacles[0].x + 30 < 0) obstacles.shift();

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL_MIN + Math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN);
			spawnObstacle();
		}

		drawGround();
		drawDino(dinoY);
		drawObstacles();
	}
}

private typedef Obstacle = {
	var x: Float;
	var y: Float;
	var w: Float;
	var h: Float;
	var tall: Bool;
	var scored: Bool;
	var isBird: Bool;
	var isHigh: Bool;
}
