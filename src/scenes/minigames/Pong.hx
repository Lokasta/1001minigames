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
	Pong: rebata a bolinha contra a IA.
	Score = quantas vezes voce rebateu a bola.
**/
class Pong implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var PADDLE_W = 60;
	static var PADDLE_H = 10;
	static var BALL_SIZE = 8;
	static var BALL_SPEED = 300.0;
	static var BALL_ACCEL = 15.0; // pixels/sec gained per second of play
	static var AI_SPEED = 200.0;
	static var AI_ACCEL = 10.0; // AI speed gain per second of play
	static var PADDLE_MARGIN = 40;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var scoreText:Text;
	var interactive:Interactive;

	var playerX:Float;
	var aiX:Float;
	var ballX:Float;
	var ballY:Float;
	var ballVx:Float;
	var ballVy:Float;
	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var targetX:Float;
	var elapsed:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x1A1A2E);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		// Center line
		bg.beginFill(0x333355);
		bg.drawRect(0, DESIGN_H / 2 - 1, DESIGN_W, 2);
		bg.endFill();

		gameG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2 - 20;
		scoreText.y = DESIGN_H / 2 + 20;
		scoreText.scale(1.8);

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onMove = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			targetX = e.relX;
		};
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
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
		gameOver = false;
		started = false;
		elapsed = 0;
		scoreText.text = "0";
		resetBall();
		draw();
	}

	function currentBallSpeed():Float {
		return BALL_SPEED + elapsed * BALL_ACCEL;
	}

	function currentAiSpeed():Float {
		return AI_SPEED + elapsed * AI_ACCEL;
	}

	function resetBall() {
		ballX = DESIGN_W / 2;
		ballY = DESIGN_H / 2;
		var angle = (Math.random() * 0.5 + 0.25) * Math.PI; // 45-135 degrees (toward player)
		var speed = currentBallSpeed();
		ballVx = Math.cos(angle) * speed * (Math.random() > 0.5 ? 1 : -1);
		ballVy = Math.abs(Math.sin(angle)) * speed; // Always toward player (positive Y = down)
	}

	function draw() {
		gameG.clear();
		var playerY = DESIGN_H - PADDLE_MARGIN;
		var aiY = PADDLE_MARGIN;

		// AI paddle
		gameG.beginFill(0xE74C3C);
		gameG.drawRect(aiX - PADDLE_W / 2, aiY - PADDLE_H / 2, PADDLE_W, PADDLE_H);
		gameG.endFill();

		// Player paddle
		gameG.beginFill(0x3498DB);
		gameG.drawRect(playerX - PADDLE_W / 2, playerY - PADDLE_H / 2, PADDLE_W, PADDLE_H);
		gameG.endFill();

		// Ball
		gameG.beginFill(0xFFFFFF);
		gameG.drawCircle(ballX, ballY, BALL_SIZE / 2);
		gameG.endFill();
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;

		if (!started) {
			ballY = DESIGN_H / 2 + Math.sin(haxe.Timer.stamp() * 3) * 8;
			draw();
			return;
		}

		elapsed += dt;

		// Player paddle follows touch/mouse
		playerX = targetX;
		if (playerX < PADDLE_W / 2)
			playerX = PADDLE_W / 2;
		if (playerX > DESIGN_W - PADDLE_W / 2)
			playerX = DESIGN_W - PADDLE_W / 2;

		// AI paddle tracks ball with limited speed (ramps over time)
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

		// Move ball
		ballX += ballVx * dt;
		ballY += ballVy * dt;

		// Wall bounce (left/right)
		if (ballX - BALL_SIZE / 2 <= 0) {
			ballX = BALL_SIZE / 2;
			ballVx = -ballVx;
		}
		if (ballX + BALL_SIZE / 2 >= DESIGN_W) {
			ballX = DESIGN_W - BALL_SIZE / 2;
			ballVx = -ballVx;
		}

		var playerY = DESIGN_H - PADDLE_MARGIN;
		var aiY = PADDLE_MARGIN;

		// Player paddle collision (ball moving down)
		if (ballVy > 0 && ballY + BALL_SIZE / 2 >= playerY - PADDLE_H / 2 && ballY - BALL_SIZE / 2 <= playerY + PADDLE_H / 2) {
			if (ballX >= playerX - PADDLE_W / 2 && ballX <= playerX + PADDLE_W / 2) {
				ballY = playerY - PADDLE_H / 2 - BALL_SIZE / 2;
				var offset = (ballX - playerX) / (PADDLE_W / 2); // -1 to 1
				var speed = currentBallSpeed();
				var angle = offset * Math.PI / 4; // max 45 degrees
				ballVx = Math.sin(angle) * speed;
				ballVy = -Math.cos(angle) * speed;
				score++;
				scoreText.text = Std.string(score);
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.1, 2);
			}
		}

		// AI paddle collision (ball moving up)
		if (ballVy < 0 && ballY - BALL_SIZE / 2 <= aiY + PADDLE_H / 2 && ballY + BALL_SIZE / 2 >= aiY - PADDLE_H / 2) {
			if (ballX >= aiX - PADDLE_W / 2 && ballX <= aiX + PADDLE_W / 2) {
				ballY = aiY + PADDLE_H / 2 + BALL_SIZE / 2;
				var offset = (ballX - aiX) / (PADDLE_W / 2);
				var speed = currentBallSpeed();
				var angle = offset * Math.PI / 4;
				ballVx = Math.sin(angle) * speed;
				ballVy = Math.cos(angle) * speed;
			}
		}

		// Ball past player (bottom) = game over
		if (ballY - BALL_SIZE / 2 > DESIGN_H) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		// Ball past AI (top) = reset ball (AI "loses" but game continues)
		if (ballY + BALL_SIZE / 2 < 0) {
			resetBall();
		}

		draw();
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
