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
	Pong neon: rebata a bolinha contra a IA. Estética neon com trails e glow.
**/
class Pong implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var PADDLE_W = 68;
	static var PADDLE_H = 12;
	static var PADDLE_R = 6;
	static var BALL_R = 6;
	static var BALL_SPEED = 280.0;
	static var BALL_ACCEL = 12.0;
	static var AI_SPEED = 190.0;
	static var AI_ACCEL = 8.0;
	static var PADDLE_MARGIN = 50;
	static var TRAIL_LEN = 8;
	static var HIT_FLASH_DUR = 0.15;
	static var DEATH_DUR = 0.5;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var trailG:Graphics;
	var effectG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var aiScoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var playerX:Float;
	var aiX:Float;
	var ballX:Float;
	var ballY:Float;
	var ballVx:Float;
	var ballVy:Float;
	var trail:Array<{x:Float, y:Float}>;
	var score:Int;
	var aiScore:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var started:Bool;
	var targetX:Float;
	var elapsed:Float;
	var hitFlashTimer:Float;
	var hitFlashX:Float;
	var hitFlashY:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;
		trail = [];

		bg = new Graphics(contentObj);
		trailG = new Graphics(contentObj);
		gameG = new Graphics(contentObj);
		effectG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2;
		scoreText.y = DESIGN_H / 2 + 30;
		scoreText.scale(2.5);
		scoreText.textAlign = Center;
		scoreText.textColor = 0x3498DB;
		scoreText.alpha = 0.4;

		aiScoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		aiScoreText.text = "0";
		aiScoreText.x = DESIGN_W / 2;
		aiScoreText.y = DESIGN_H / 2 - 55;
		aiScoreText.scale(2.5);
		aiScoreText.textAlign = Center;
		aiScoreText.textColor = 0xE74C3C;
		aiScoreText.alpha = 0.4;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Mova para rebater";
		instructText.x = DESIGN_W / 2;
		instructText.y = DESIGN_H - 90;
		instructText.scale(1.1);
		instructText.textAlign = Center;
		instructText.textColor = 0x6688AA;
		instructText.visible = true;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onMove = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			targetX = e.relX;
		};
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			targetX = e.relX;
		};
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		playerX = DESIGN_W / 2;
		aiX = DESIGN_W / 2;
		targetX = DESIGN_W / 2;
		score = 0;
		aiScore = 0;
		gameOver = false;
		deathTimer = -1;
		started = false;
		elapsed = 0;
		hitFlashTimer = 0;
		trail = [];
		scoreText.text = "0";
		aiScoreText.text = "0";
		instructText.visible = true;
		flashG.clear();
		drawBackground();
		resetBall();
		draw();
	}

	function currentBallSpeed():Float
		return BALL_SPEED + elapsed * BALL_ACCEL;

	function currentAiSpeed():Float
		return AI_SPEED + elapsed * AI_ACCEL;

	function resetBall() {
		ballX = DESIGN_W / 2;
		ballY = DESIGN_H / 2;
		var angle = (Math.random() * 0.5 + 0.25) * Math.PI;
		var speed = currentBallSpeed();
		ballVx = Math.cos(angle) * speed * (Math.random() > 0.5 ? 1 : -1);
		ballVy = Math.abs(Math.sin(angle)) * speed;
		trail = [];
	}

	function drawBackground() {
		bg.clear();
		var top = 0x0a0a18;
		var bot = 0x12122a;
		var steps = 5;
		var stepH = DESIGN_H / steps;
		for (i in 0...steps) {
			var t = i / (steps - 1);
			var r = Std.int(((top >> 16) & 0xFF) * (1 - t) + ((bot >> 16) & 0xFF) * t);
			var g = Std.int(((top >> 8) & 0xFF) * (1 - t) + ((bot >> 8) & 0xFF) * t);
			var b = Std.int((top & 0xFF) * (1 - t) + (bot & 0xFF) * t);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, i * stepH, DESIGN_W, stepH + 1);
			bg.endFill();
		}
		var dashW = 12.0;
		var dashH = 4.0;
		var dashGap = 14.0;
		var y = 0.0;
		bg.beginFill(0x222244, 0.5);
		while (y < DESIGN_H) {
			bg.drawRect(DESIGN_W / 2 - dashW / 2, y, dashW, dashH);
			y += dashH + dashGap;
		}
		bg.endFill();
		bg.lineStyle(1, 0x1a1a3a, 0.3);
		bg.moveTo(0, DESIGN_H / 2);
		bg.lineTo(DESIGN_W, DESIGN_H / 2);
		bg.lineStyle(0);
	}

	function triggerHitFlash(x:Float, y:Float) {
		hitFlashTimer = HIT_FLASH_DUR;
		hitFlashX = x;
		hitFlashY = y;
	}

	function drawTrail() {
		trailG.clear();
		if (trail.length < 2)
			return;
		for (i in 0...trail.length) {
			var t = i / trail.length;
			var alpha = t * 0.35;
			var r = BALL_R * (0.3 + t * 0.7);
			trailG.beginFill(0xFFFFFF, alpha);
			trailG.drawCircle(trail[i].x, trail[i].y, r);
			trailG.endFill();
		}
	}

	function draw() {
		gameG.clear();
		var playerY = DESIGN_H - PADDLE_MARGIN;
		var aiY = PADDLE_MARGIN;

		gameG.beginFill(0x3498DB, 0.15);
		gameG.drawRoundedRect(playerX - PADDLE_W / 2 - 4, playerY - PADDLE_H / 2 - 4, PADDLE_W + 8, PADDLE_H + 8, PADDLE_R + 2);
		gameG.endFill();
		gameG.beginFill(0x3498DB);
		gameG.drawRoundedRect(playerX - PADDLE_W / 2, playerY - PADDLE_H / 2, PADDLE_W, PADDLE_H, PADDLE_R);
		gameG.endFill();
		gameG.beginFill(0x5DADE2, 0.4);
		gameG.drawRoundedRect(playerX - PADDLE_W / 2 + 4, playerY - PADDLE_H / 2 + 2, PADDLE_W - 8, PADDLE_H / 2, PADDLE_R - 2);
		gameG.endFill();

		gameG.beginFill(0xE74C3C, 0.15);
		gameG.drawRoundedRect(aiX - PADDLE_W / 2 - 4, aiY - PADDLE_H / 2 - 4, PADDLE_W + 8, PADDLE_H + 8, PADDLE_R + 2);
		gameG.endFill();
		gameG.beginFill(0xE74C3C);
		gameG.drawRoundedRect(aiX - PADDLE_W / 2, aiY - PADDLE_H / 2, PADDLE_W, PADDLE_H, PADDLE_R);
		gameG.endFill();
		gameG.beginFill(0xF1948A, 0.4);
		gameG.drawRoundedRect(aiX - PADDLE_W / 2 + 4, aiY - PADDLE_H / 2 + 2, PADDLE_W - 8, PADDLE_H / 2, PADDLE_R - 2);
		gameG.endFill();

		gameG.beginFill(0xFFFFFF, 0.2);
		gameG.drawCircle(ballX, ballY, BALL_R + 4);
		gameG.endFill();
		gameG.beginFill(0xFFFFFF);
		gameG.drawCircle(ballX, ballY, BALL_R);
		gameG.endFill();
		gameG.beginFill(0xFFFFFF, 0.5);
		gameG.drawCircle(ballX - 1.5, ballY - 1.5, BALL_R * 0.4);
		gameG.endFill();
	}

	function drawEffects() {
		effectG.clear();
		if (hitFlashTimer > 0) {
			var t = hitFlashTimer / HIT_FLASH_DUR;
			var r = 15 + (1 - t) * 20;
			effectG.beginFill(0xFFFFFF, t * 0.6);
			effectG.drawCircle(hitFlashX, hitFlashY, r);
			effectG.endFill();
			for (i in 0...4) {
				var angle = i * Math.PI / 2 + (1 - t) * 0.5;
				var dist = (1 - t) * 18;
				effectG.beginFill(0xFFDD00, t * 0.5);
				effectG.drawCircle(hitFlashX + Math.cos(angle) * dist, hitFlashY + Math.sin(angle) * dist, 3);
				effectG.endFill();
			}
		}
	}

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFF2222, (1 - t) * 0.35);
					flashG.drawRect(0, 0, DESIGN_W, DESIGN_H);
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
			ballY = DESIGN_H / 2 + Math.sin(haxe.Timer.stamp() * 3) * 8;
			draw();
			return;
		}

		elapsed += dt;

		playerX = targetX;
		if (playerX < PADDLE_W / 2)
			playerX = PADDLE_W / 2;
		if (playerX > DESIGN_W - PADDLE_W / 2)
			playerX = DESIGN_W - PADDLE_W / 2;

		var aiSpeed = currentAiSpeed();
		var diff = ballX - aiX;
		if (diff > 0)
			aiX += Math.min(diff, aiSpeed * dt);
		else
			aiX += Math.max(diff, -aiSpeed * dt);
		if (aiX < PADDLE_W / 2)
			aiX = PADDLE_W / 2;
		if (aiX > DESIGN_W - PADDLE_W / 2)
			aiX = DESIGN_W - PADDLE_W / 2;

		ballX += ballVx * dt;
		ballY += ballVy * dt;

		trail.push({x: ballX, y: ballY});
		if (trail.length > TRAIL_LEN)
			trail.shift();

		if (ballX - BALL_R <= 0) {
			ballX = BALL_R;
			ballVx = -ballVx;
		}
		if (ballX + BALL_R >= DESIGN_W) {
			ballX = DESIGN_W - BALL_R;
			ballVx = -ballVx;
		}

		var playerY = DESIGN_H - PADDLE_MARGIN;
		var aiY = PADDLE_MARGIN;

		if (ballVy > 0 && ballY + BALL_R >= playerY - PADDLE_H / 2 && ballY - BALL_R <= playerY + PADDLE_H / 2) {
			if (ballX >= playerX - PADDLE_W / 2 - 2 && ballX <= playerX + PADDLE_W / 2 + 2) {
				ballY = playerY - PADDLE_H / 2 - BALL_R;
				var offset = (ballX - playerX) / (PADDLE_W / 2);
				var speed = currentBallSpeed();
				var angle = offset * Math.PI / 4;
				ballVx = Math.sin(angle) * speed;
				ballVy = -Math.cos(angle) * speed;
				score++;
				scoreText.text = Std.string(score);
				triggerHitFlash(ballX, playerY - PADDLE_H / 2);
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.08, 2);
			}
		}

		if (ballVy < 0 && ballY - BALL_R <= aiY + PADDLE_H / 2 && ballY + BALL_R >= aiY - PADDLE_H / 2) {
			if (ballX >= aiX - PADDLE_W / 2 - 2 && ballX <= aiX + PADDLE_W / 2 + 2) {
				ballY = aiY + PADDLE_H / 2 + BALL_R;
				var offset = (ballX - aiX) / (PADDLE_W / 2);
				var speed = currentBallSpeed();
				var angle = offset * Math.PI / 4;
				ballVx = Math.sin(angle) * speed;
				ballVy = Math.cos(angle) * speed;
			}
		}

		if (ballY - BALL_R > DESIGN_H) {
			gameOver = true;
			deathTimer = 0;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.3, 4);
			return;
		}

		if (ballY + BALL_R < 0) {
			aiScore++;
			aiScoreText.text = Std.string(aiScore);
			resetBall();
		}

		if (hitFlashTimer > 0)
			hitFlashTimer -= dt;

		drawTrail();
		draw();
		drawEffects();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "pong";

	public function getTitle():String
		return "Pong";
}
