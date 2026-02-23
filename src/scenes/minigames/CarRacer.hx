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
	Corridinha: arraste na tela para dar steer no carro (esquerda/direita). Controle contínuo com física suave.
	Obstáculos em posições contínuas na pista; colisão por sobreposição.
**/
class CarRacer implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var ROAD_SPEED = 280;
	static var SPAWN_INTERVAL = 0.95;
	static var PLAYER_Y = 520;
	static var HIT_MARGIN_Y = 36;
	static var LANE_LEFT_BOTTOM = 72;
	static var LANE_RIGHT_BOTTOM = 288;
	static var LANE_LEFT_TOP = 100;
	static var LANE_RIGHT_TOP = 260;
	static var STEER_SENSITIVITY = 0.0022;
	static var STEER_SMOOTH = 8.0;
	static var CAR_HALF_NORM = 0.078;
	static var OBSTACLE_HALF_NORM = 0.075;
	static var CAMERA_FOLLOW_MAX = 42.0;
	static var CAMERA_FOLLOW_SPEED = 4.0;
	static var CAMERA_TILT_MAX = 0.028;
	static var EXPLOSION_DURATION = 0.45;

	final contentObj: Object;
	var gameWorld: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var roadG: Graphics;
	var obstaclesG: Graphics;
	var playerG: Graphics;
	var explosionG: Graphics;
	var scoreBg: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var carX: Float;
	var targetCarX: Float;
	var cameraOffsetX: Float;
	var obstacles: Array<{ x: Float, y: Float }>;
	var spawnTimer: Float;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var exploding: Bool;
	var explosionT: Float;
	var explosionX: Float;
	var explosionY: Float;
	var lastDragX: Float;
	var dragging: Bool;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		gameWorld = new Object(contentObj);

		roadG = new Graphics(gameWorld);
		obstaclesG = new Graphics(gameWorld);
		playerG = new Graphics(gameWorld);
		explosionG = new Graphics(gameWorld);
		scoreBg = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 54;
		scoreText.y = 18;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			lastDragX = e.relX;
			dragging = true;
			e.propagate = false;
		};
		interactive.onMove = function(e: Event) {
			if (!dragging || gameOver) return;
			var dx = e.relX - lastDragX;
			targetCarX += dx * STEER_SENSITIVITY;
			if (targetCarX < 0) targetCarX = 0;
			if (targetCarX > 1) targetCarX = 1;
			lastDragX = e.relX;
			e.propagate = false;
		};
		interactive.onRelease = function(e: Event) {
			dragging = false;
			e.propagate = false;
		};
	}

	inline function leftAtY(y: Float): Float {
		var t = y / designH;
		return LANE_LEFT_TOP + (LANE_LEFT_BOTTOM - LANE_LEFT_TOP) * t;
	}
	inline function rightAtY(y: Float): Float {
		var t = y / designH;
		return LANE_RIGHT_TOP + (LANE_RIGHT_BOTTOM - LANE_RIGHT_TOP) * t;
	}
	inline function roadXAt(y: Float, normX: Float): Float {
		var left = leftAtY(y);
		var right = rightAtY(y);
		return left + normX * (right - left);
	}

	inline function scaleAtY(y: Float): Float {
		return 0.5 + 0.5 * (y / designH);
	}

	function drawRoad() {
		roadG.clear();
		// Céu em gradiente (mais claro no topo)
		roadG.beginFill(0x5DADE2);
		roadG.drawRect(0, 0, designW, designH);
		roadG.endFill();
		roadG.beginFill(0x85C1E9, 0.6);
		roadG.drawRect(0, 0, designW, designH * 0.55);
		roadG.endFill();
		// Grama fundo (mais escura, sensação de distância)
		var lTop = LANE_LEFT_TOP - 28;
		var rTop = LANE_RIGHT_TOP + 28;
		var lBot = LANE_LEFT_BOTTOM - 45;
		var rBot = LANE_RIGHT_BOTTOM + 45;
		roadG.beginFill(0x1e8449);
		roadG.moveTo(0, 0);
		roadG.lineTo(designW, 0);
		roadG.lineTo(designW, designH);
		roadG.lineTo(0, designH);
		roadG.lineTo(0, 0);
		roadG.endFill();
		roadG.beginFill(0x27ae60);
		roadG.moveTo(lTop, 0);
		roadG.lineTo(rTop, 0);
		roadG.lineTo(rBot, designH);
		roadG.lineTo(lBot, designH);
		roadG.lineTo(lTop, 0);
		roadG.endFill();
		// Borda da estrada (asfalto escuro)
		roadG.lineStyle(8, 0x2c3e50);
		roadG.moveTo(lTop, 0);
		roadG.lineTo(rTop, 0);
		roadG.lineTo(rBot, designH);
		roadG.lineTo(lBot, designH);
		roadG.lineTo(lTop, 0);
		roadG.lineStyle(0);
		// Asfalto principal
		roadG.beginFill(0x2c3e50);
		roadG.moveTo(lTop + 4, 4);
		roadG.lineTo(rTop - 4, 4);
		roadG.lineTo(rBot - 4, designH - 4);
		roadG.lineTo(lBot + 4, designH - 4);
		roadG.lineTo(lTop + 4, 4);
		roadG.endFill();
		roadG.beginFill(0x34495e);
		roadG.moveTo(lTop + 6, 6);
		roadG.lineTo(rTop - 6, 6);
		roadG.lineTo(rBot - 6, designH - 6);
		roadG.lineTo(lBot + 6, designH - 6);
		roadG.lineTo(lTop + 6, 6);
		roadG.endFill();
		// Faixas tracejadas (3 linhas)
		for (i in 1...4) {
			var norm = i / 4;
			var x0 = roadXAt(0, norm);
			var x1 = roadXAt(designH, norm);
			roadG.lineStyle(4, 0x2c3e50);
			roadG.moveTo(x0, 0);
			roadG.lineTo(x1, designH);
			roadG.lineStyle(3, 0xF1C40F);
			roadG.moveTo(x0, 0);
			roadG.lineTo(x1, designH);
			roadG.lineStyle(0);
		}
		// Fundo do score
		scoreBg.clear();
		scoreBg.beginFill(0x000000, 0.35);
		scoreBg.drawRoundedRect(designW - 68, 14, 56, 26, 8);
		scoreBg.endFill();
	}

	function drawPlayer() {
		playerG.clear();
		var x = roadXAt(PLAYER_Y, carX);
		var w = 36;
		var h = 22;
		// Sombra no chão
		playerG.beginFill(0x000000, 0.25);
		playerG.drawEllipse(x, PLAYER_Y + 4, w * 0.55, 6);
		playerG.endFill();
		// Corpo do carro
		playerG.beginFill(0xC0392B);
		playerG.drawRoundedRect(x - w / 2, PLAYER_Y - h / 2, w, h, 4);
		playerG.endFill();
		playerG.beginFill(0xE74C3C);
		playerG.drawRoundedRect(x - w / 2 + 2, PLAYER_Y - h / 2 + 2, w - 4, h - 6, 3);
		playerG.endFill();
		// Faixa de destaque no capô
		playerG.beginFill(0xEC7063, 0.6);
		playerG.drawRoundedRect(x - 8, PLAYER_Y - 10, 16, 4, 1);
		playerG.endFill();
		playerG.lineStyle(2, 0xA93226);
		playerG.drawRoundedRect(x - w / 2, PLAYER_Y - h / 2, w, h, 4);
		playerG.lineStyle(0);
		// Para-brisas
		playerG.beginFill(0x1a1a1a);
		playerG.drawRoundedRect(x - 10, PLAYER_Y - 14, 8, 6, 1);
		playerG.drawRoundedRect(x + 2, PLAYER_Y - 14, 8, 6, 1);
		playerG.endFill();
		playerG.beginFill(0x3498DB, 0.85);
		playerG.drawRoundedRect(x - 9, PLAYER_Y - 13, 6, 4, 1);
		playerG.drawRoundedRect(x + 3, PLAYER_Y - 13, 6, 4, 1);
		playerG.endFill();
		playerG.beginFill(0xFFFFFF, 0.4);
		playerG.drawRect(x - 8, PLAYER_Y - 12, 2, 1.5);
		playerG.drawRect(x + 5, PLAYER_Y - 12, 2, 1.5);
		playerG.endFill();
	}

	function drawObstacle(normX: Float, y: Float) {
		var x = roadXAt(y, normX);
		var s = scaleAtY(y);
		var w = 32 * s;
		var h = 18 * s;
		// Sombra
		obstaclesG.beginFill(0x000000, 0.2);
		obstaclesG.drawEllipse(x, y + h * 0.3, w * 0.5, 4 * s);
		obstaclesG.endFill();
		// Corpo
		obstaclesG.beginFill(0x5D6D7E);
		obstaclesG.drawRoundedRect(x - w / 2, y - h / 2, w, h, 3);
		obstaclesG.endFill();
		obstaclesG.beginFill(0x7F8C8D);
		obstaclesG.drawRoundedRect(x - w / 2 + 1.5 * s, y - h / 2 + 1.5 * s, w - 3 * s, h - 4 * s, 2);
		obstaclesG.endFill();
		obstaclesG.lineStyle(1.5, 0x4a5f6f);
		obstaclesG.drawRoundedRect(x - w / 2, y - h / 2, w, h, 3);
		obstaclesG.lineStyle(0);
		obstaclesG.beginFill(0x1a1a1a);
		obstaclesG.drawRoundedRect(x - 8 * s, y - 10 * s, 6 * s, 5 * s, 1);
		obstaclesG.drawRoundedRect(x + 2 * s, y - 10 * s, 6 * s, 5 * s, 1);
		obstaclesG.endFill();
	}

	function drawObstacles() {
		obstaclesG.clear();
		for (o in obstacles)
			drawObstacle(o.x, o.y);
	}

	function spawnObstacle() {
		var baseY = -30;
		obstacles.push({ x: 0.15 + Math.random() * 0.7, y: baseY });
		if (Math.random() < 0.35) {
			var otherX = Math.random();
			if (Math.abs(otherX - obstacles[obstacles.length - 1].x) < 0.25) otherX = otherX < 0.5 ? otherX + 0.35 : otherX - 0.35;
			if (otherX < 0.1) otherX = 0.15;
			if (otherX > 0.9) otherX = 0.85;
			obstacles.push({ x: otherX, y: baseY - 25 });
		}
	}

	function hitTest(): Bool {
		for (o in obstacles) {
			if (o.y < PLAYER_Y - HIT_MARGIN_Y || o.y > PLAYER_Y + HIT_MARGIN_Y) continue;
			var dx = Math.abs(o.x - carX);
			if (dx < (CAR_HALF_NORM + OBSTACLE_HALF_NORM))
				return true;
		}
		return false;
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	function drawExplosion() {
		explosionG.clear();
		if (explosionT <= 0 || explosionT >= EXPLOSION_DURATION) return;
		var t = explosionT / EXPLOSION_DURATION;
		var radius = 25 + t * 55;
		var alpha = 1 - t * t;
		var parts = 8;
		for (i in 0...parts) {
			var a = (i / parts) * Math.PI * 2 + explosionT * 3;
			var px = explosionX + Math.cos(a) * radius * 0.6;
			var py = explosionY + Math.sin(a) * radius * 0.4;
			explosionG.beginFill(0xFF6600, alpha * 0.9);
			explosionG.drawCircle(px, py, 12 + t * 20);
			explosionG.endFill();
			explosionG.beginFill(0xFFAA00, alpha * 0.6);
			explosionG.drawCircle(explosionX, explosionY, radius * 0.5);
			explosionG.endFill();
		}
		explosionG.beginFill(0xFF4400, alpha);
		explosionG.drawCircle(explosionX, explosionY, radius * 0.3);
		explosionG.endFill();
	}

	public function start() {
		carX = 0.5;
		targetCarX = 0.5;
		cameraOffsetX = 0;
		obstacles = [];
		spawnTimer = 0.4;
		started = false;
		gameOver = false;
		exploding = false;
		explosionT = -1;
		dragging = false;
		score = 0;
		scoreText.text = "0";
		drawRoad();
		drawPlayer();
		drawObstacles();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		obstacles = [];
	}

	public function getMinigameId(): String return "car-racer";
	public function getTitle(): String return "Corrida";

	public function update(dt: Float) {
		if (ctx == null) return;
		if (exploding) {
			explosionT += dt;
			drawRoad();
			drawObstacles();
			drawPlayer();
			drawExplosion();
			if (explosionT >= EXPLOSION_DURATION) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			return;
		}
		if (gameOver) return;
		if (!started) {
			drawRoad();
			drawPlayer();
			drawObstacles();
			return;
		}

		carX += (targetCarX - carX) * (1 - Math.exp(-STEER_SMOOTH * dt));
		var targetCam = (0.5 - carX) * CAMERA_FOLLOW_MAX;
		cameraOffsetX += (targetCam - cameraOffsetX) * (1 - Math.exp(-CAMERA_FOLLOW_SPEED * dt));
		gameWorld.x = cameraOffsetX;
		gameWorld.rotation = (0.5 - carX) * CAMERA_TILT_MAX;

		for (o in obstacles) o.y += ROAD_SPEED * dt;

		var i = obstacles.length - 1;
		while (i >= 0) {
			if (obstacles[i].y > designH + 40) {
				obstacles.splice(i, 1);
				score++;
				scoreText.text = Std.string(score);
			}
			i--;
		}

		if (hitTest()) {
			gameOver = true;
			exploding = true;
			explosionT = 0;
			explosionX = roadXAt(PLAYER_Y, carX);
			explosionY = PLAYER_Y;
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			spawnObstacle();
		}

		drawRoad();
		drawObstacles();
		drawPlayer();
	}
}
