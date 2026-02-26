package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Flappy Bird: tap para bater asas, desvie dos canos.
	Score = quantos canos passou.
**/
class FlappyBird implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRAVITY = 820;
	static var FLAP_STRENGTH = -290;
	static var BIRD_R = 13;
	static var BIRD_X = 80;
	static var PIPE_W = 52;
	static var PIPE_CAP_W = 62;
	static var PIPE_CAP_H = 18;
	static var PIPE_GAP = 145;
	static var PIPE_GAP_MIN = 115;
	static var PIPE_SPEED_START = 140;
	static var PIPE_SPEED_MAX = 210;
	static var PIPE_SPAWN_INTERVAL = 1.9;
	static var FLOOR_H = 70;
	static var GRASS_H = 14;
	static var CEILING = 0;
	static var CLOUD_COUNT = 5;
	static var DEATH_DURATION = 0.5;

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var bg:Graphics;
	var cloudsG:Graphics;
	var pipesG:Graphics;
	var groundG:Graphics;
	var birdG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var birdY:Float;
	var birdVy:Float;
	var birdAngle:Float;
	var started:Bool;
	var score:Int;
	var pipes:Array<Pipe>;
	var spawnTimer:Float;
	var gameOver:Bool;
	var deathTimer:Float;
	var clouds:Array<{x:Float, y:Float, w:Float, speed:Float}>;
	var groundOffset:Float;
	var elapsed:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		pipes = [];
		clouds = [];

		bg = new Graphics(contentObj);
		cloudsG = new Graphics(contentObj);
		pipesG = new Graphics(contentObj);
		groundG = new Graphics(contentObj);
		birdG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW / 2;
		scoreText.y = 30;
		scoreText.scale(2.2);
		scoreText.textAlign = Center;
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Toque para voar";
		instructText.x = designW / 2;
		instructText.y = designH / 2 + 50;
		instructText.scale(1.3);
		instructText.textAlign = Center;
		instructText.textColor = 0xFFFFFF;
		instructText.visible = true;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onClick = function(_) {
			if (ctx == null)
				return;
			if (gameOver)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			birdVy = FLAP_STRENGTH;
		};
	}

	function currentSpeed():Float {
		var t = if (elapsed > 60) 1.0 else elapsed / 60.0;
		return PIPE_SPEED_START + (PIPE_SPEED_MAX - PIPE_SPEED_START) * t;
	}

	function currentGap():Float {
		var t = if (elapsed > 60) 1.0 else elapsed / 60.0;
		return PIPE_GAP + (PIPE_GAP_MIN - PIPE_GAP) * t;
	}

	function drawBackground() {
		bg.clear();
		var skyTop = 0x4EC5F1;
		var skyBot = 0xB0E0F6;
		var steps = 8;
		var stepH = (designH - FLOOR_H) / steps;
		for (i in 0...steps) {
			var t = i / (steps - 1);
			var r = Std.int(((skyTop >> 16) & 0xFF) * (1 - t) + ((skyBot >> 16) & 0xFF) * t);
			var g = Std.int(((skyTop >> 8) & 0xFF) * (1 - t) + ((skyBot >> 8) & 0xFF) * t);
			var b = Std.int((skyTop & 0xFF) * (1 - t) + (skyBot & 0xFF) * t);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, i * stepH, designW, stepH + 1);
			bg.endFill();
		}
	}

	function initClouds() {
		clouds = [];
		for (i in 0...CLOUD_COUNT) {
			clouds.push({
				x: Math.random() * designW,
				y: 30 + Math.random() * 180,
				w: 40 + Math.random() * 60,
				speed: 8 + Math.random() * 15
			});
		}
	}

	function drawClouds() {
		cloudsG.clear();
		for (c in clouds) {
			cloudsG.beginFill(0xFFFFFF, 0.6);
			cloudsG.drawEllipse(c.x, c.y, c.w, c.w * 0.35);
			cloudsG.endFill();
			cloudsG.beginFill(0xFFFFFF, 0.4);
			cloudsG.drawEllipse(c.x - c.w * 0.3, c.y + 4, c.w * 0.6, c.w * 0.25);
			cloudsG.drawEllipse(c.x + c.w * 0.25, c.y + 3, c.w * 0.5, c.w * 0.22);
			cloudsG.endFill();
		}
	}

	function drawGround() {
		groundG.clear();
		groundG.beginFill(0xDEB887);
		groundG.drawRect(0, designH - FLOOR_H, designW, FLOOR_H);
		groundG.endFill();
		groundG.beginFill(0x7CCD3A);
		groundG.drawRect(0, designH - FLOOR_H, designW, GRASS_H);
		groundG.endFill();
		groundG.beginFill(0x5EA828);
		groundG.drawRect(0, designH - FLOOR_H, designW, 3);
		groundG.endFill();
		var stripeW = 24.0;
		var off = groundOffset % (stripeW * 2);
		groundG.beginFill(0xD4A862, 0.3);
		var x = -off;
		while (x < designW) {
			groundG.drawRect(x, designH - FLOOR_H + GRASS_H, stripeW, FLOOR_H - GRASS_H);
			x += stripeW * 2;
		}
		groundG.endFill();
	}

	function drawBird(x:Float, y:Float) {
		birdG.clear();
		var angleDeg = birdAngle;
		var radA = angleDeg * Math.PI / 180;
		var cosA = Math.cos(radA);
		var sinA = Math.sin(radA);
		inline function rx(lx:Float, ly:Float):Float
			return x + lx * cosA - ly * sinA;
		inline function ry(lx:Float, ly:Float):Float
			return y + lx * sinA + ly * cosA;

		birdG.beginFill(0xF4D03F);
		birdG.drawEllipse(x, y, BIRD_R + 3, BIRD_R);
		birdG.endFill();

		birdG.beginFill(0xE67E22);
		var bx = rx(BIRD_R + 2, 2);
		var by = ry(BIRD_R + 2, 2);
		birdG.drawEllipse(bx, by, 8, 4);
		birdG.endFill();

		birdG.beginFill(0xFFFFFF);
		var ex = rx(4, -4);
		var ey = ry(4, -4);
		birdG.drawCircle(ex, ey, 5);
		birdG.endFill();
		birdG.beginFill(0x000000);
		birdG.drawCircle(ex + 1.5, ey, 2.5);
		birdG.endFill();

		var wingPhase = Math.sin(haxe.Timer.stamp() * 14) * 0.5 + 0.5;
		var wingY = -3 + wingPhase * 8;
		birdG.beginFill(0xE8C12F, 0.8);
		var wx = rx(-5, wingY);
		var wy = ry(-5, wingY);
		birdG.drawEllipse(wx, wy, 8, 5);
		birdG.endFill();
	}

	function spawnPipe() {
		var gapH = currentGap();
		var minGapY = 60;
		var maxGapY = designH - FLOOR_H - gapH - 40;
		var gapY = minGapY + Math.random() * (maxGapY - minGapY);
		pipes.push({
			x: designW + PIPE_W,
			gapY: gapY,
			gapH: gapH,
			scored: false
		});
	}

	function drawPipes() {
		pipesG.clear();
		for (p in pipes) {
			var capX = p.x - (PIPE_CAP_W - PIPE_W) / 2;
			pipesG.beginFill(0x5BBD3A);
			pipesG.drawRect(p.x, 0, PIPE_W, p.gapY - PIPE_CAP_H);
			pipesG.endFill();
			pipesG.beginFill(0x4AA82D);
			pipesG.drawRect(capX, p.gapY - PIPE_CAP_H, PIPE_CAP_W, PIPE_CAP_H);
			pipesG.endFill();
			pipesG.lineStyle(2, 0x3D8C24);
			pipesG.drawRect(capX, p.gapY - PIPE_CAP_H, PIPE_CAP_W, PIPE_CAP_H);
			pipesG.lineStyle(0);
			pipesG.beginFill(0x6DD44E, 0.3);
			pipesG.drawRect(p.x + 4, 0, 8, p.gapY - PIPE_CAP_H);
			pipesG.endFill();

			var bottomY = p.gapY + p.gapH;
			pipesG.beginFill(0x5BBD3A);
			pipesG.drawRect(p.x, bottomY + PIPE_CAP_H, PIPE_W, designH - bottomY - PIPE_CAP_H);
			pipesG.endFill();
			pipesG.beginFill(0x4AA82D);
			pipesG.drawRect(capX, bottomY, PIPE_CAP_W, PIPE_CAP_H);
			pipesG.endFill();
			pipesG.lineStyle(2, 0x3D8C24);
			pipesG.drawRect(capX, bottomY, PIPE_CAP_W, PIPE_CAP_H);
			pipesG.lineStyle(0);
			pipesG.beginFill(0x6DD44E, 0.3);
			pipesG.drawRect(p.x + 4, bottomY + PIPE_CAP_H, 8, designH - bottomY - PIPE_CAP_H);
			pipesG.endFill();
		}
	}

	function hitPipe():Bool {
		var bx = BIRD_X;
		var by = birdY;
		var r = BIRD_R - 2;
		for (p in pipes) {
			if (p.x + PIPE_W < bx - r)
				continue;
			if (p.x > bx + r)
				continue;
			if (by - r < p.gapY)
				return true;
			if (by + r > p.gapY + p.gapH)
				return true;
		}
		return false;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		birdY = designH / 2;
		birdVy = 0;
		birdAngle = 0;
		started = false;
		score = 0;
		gameOver = false;
		deathTimer = -1;
		pipes = [];
		spawnTimer = 1.0;
		elapsed = 0;
		groundOffset = 0;
		scoreText.text = "0";
		instructText.visible = true;
		flashG.clear();
		initClouds();
		drawBackground();
		drawClouds();
		drawBird(BIRD_X, birdY);
		drawPipes();
		drawGround();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		pipes = [];
	}

	public function getMinigameId():String
		return "flappy-bird";

	public function getTitle():String
		return "Flappy Bird";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DURATION;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFFFFFF, (1 - t) * 0.5);
					flashG.drawRect(0, 0, designW, designH);
					flashG.endFill();
					birdVy += GRAVITY * dt;
					birdY += birdVy * dt;
					birdAngle = 90;
					drawBird(BIRD_X, birdY);
				} else {
					flashG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (!started) {
			birdY = designH / 2 + Math.sin(haxe.Timer.stamp() * 3) * 8;
			birdAngle = 0;
			drawBird(BIRD_X, birdY);
			for (c in clouds)
				c.x -= c.speed * dt * 0.3;
			for (c in clouds) {
				if (c.x + c.w < 0)
					c.x = designW + c.w;
			}
			drawClouds();
			return;
		}

		elapsed += dt;
		var speed = currentSpeed();

		birdVy += GRAVITY * dt;
		birdY += birdVy * dt;

		var targetAngle = birdVy * 0.12;
		if (targetAngle < -25) targetAngle = -25;
		if (targetAngle > 70) targetAngle = 70;
		birdAngle += (targetAngle - birdAngle) * (1 - Math.exp(-10 * dt));

		if (birdY - BIRD_R < CEILING || birdY + BIRD_R > designH - FLOOR_H) {
			gameOver = true;
			deathTimer = 0;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.2, 4);
			return;
		}

		if (hitPipe()) {
			gameOver = true;
			deathTimer = 0;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.3, 5);
			return;
		}

		for (p in pipes)
			p.x -= speed * dt;
		for (p in pipes) {
			if (!p.scored && p.x + PIPE_W / 2 < BIRD_X) {
				p.scored = true;
				score++;
				scoreText.text = Std.string(score);
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.05, 1);
			}
		}
		while (pipes.length > 0 && pipes[0].x + PIPE_W < -10)
			pipes.shift();

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = PIPE_SPAWN_INTERVAL;
			spawnPipe();
		}

		groundOffset += speed * dt;

		for (c in clouds)
			c.x -= c.speed * dt;
		for (c in clouds) {
			if (c.x + c.w < 0)
				c.x = designW + c.w;
		}

		drawClouds();
		drawPipes();
		drawBird(BIRD_X, birdY);
		drawGround();
	}
}

private typedef Pipe = {
	var x:Float;
	var gapY:Float;
	var gapH:Float;
	var scored:Bool;
}
