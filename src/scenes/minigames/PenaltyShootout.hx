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
	Pênalti: arraste da bola em direção ao gol para chutar. Continua batendo até o goleiro defender.
	Goleiro escolhe um lado (IA: aleatório 1/3 esquerda, centro, direita). Defendeu = você perde com o score atual.
**/
class PenaltyShootout implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GOAL_Y = 70;
	static var GOAL_W = 300;
	static var GOAL_H = 95;
	static var GOAL_LEFT = 30;
	static var BALL_START_X = 180;
	static var BALL_START_Y = 420;
	static var BALL_R = 14;
	static var KEEPER_W = 55;
	static var KEEPER_H = 38;
	static var BALL_SPEED = 680;
	static var KEEPER_DIVE_SPEED = 420;
	static var ZONE_W = 100;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var goalG: Graphics;
	var ballG: Graphics;
	var keeperG: Graphics;
	var aimG: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var ballX: Float;
	var ballY: Float;
	var ballVx: Float;
	var ballVy: Float;
	var keeperX: Float;
	var keeperTargetX: Float;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var state: PenaltyState;
	var aimStartX: Float;
	var aimStartY: Float;
	var aimEndX: Float;
	var aimEndY: Float;
	var ballTargetX: Float;
	var ballTargetY: Float;
	var keeperZone: Int;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x2d5016);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		bg.beginFill(0x1a3010, 0.6);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		goalG = new Graphics(contentObj);
		ballG = new Graphics(contentObj);
		keeperG = new Graphics(contentObj);
		aimG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 18;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			if (state != Idle) return;
			aimStartX = e.relX;
			aimStartY = e.relY;
			aimEndX = e.relX;
			aimEndY = e.relY;
			state = Aiming;
			e.propagate = false;
		};
		interactive.onMove = function(e: Event) {
			if (state != Aiming) return;
			aimEndX = e.relX;
			aimEndY = e.relY;
		};
		interactive.onRelease = function(e: Event) {
			if (state != Aiming) return;
			var dx = aimEndX - aimStartX;
			var dy = aimEndY - aimStartY;
			if (dx * dx + dy * dy < 400) {
				state = Idle;
				e.propagate = false;
				return;
			}
			launchShot();
			e.propagate = false;
		};
	}

	function launchShot() {
		var dirX = aimEndX - aimStartX;
		var dirY = aimEndY - aimStartY;
		var len = Math.sqrt(dirX * dirX + dirY * dirY);
		if (len < 1) len = 1;
		dirX /= len;
		dirY /= len;
		var goalLineY = GOAL_Y + GOAL_H * 0.5;
		var t = (goalLineY - BALL_START_Y) / dirY;
		if (t < 0) t = 0.5;
		ballTargetX = BALL_START_X + dirX * t * 0.98;
		ballTargetY = goalLineY;
		ballTargetX = ballTargetX < GOAL_LEFT ? GOAL_LEFT : (ballTargetX > GOAL_LEFT + GOAL_W ? GOAL_LEFT + GOAL_W : ballTargetX);

		keeperZone = Std.int(Math.random() * 3);
		keeperTargetX = GOAL_LEFT + keeperZone * ZONE_W + ZONE_W * 0.5 - KEEPER_W * 0.5;

		ballX = BALL_START_X;
		ballY = BALL_START_Y;
		var dist = Math.sqrt((ballTargetX - ballX) * (ballTargetX - ballX) + (ballTargetY - ballY) * (ballTargetY - ballY));
		var time = dist / BALL_SPEED;
		ballVx = (ballTargetX - ballX) / time;
		ballVy = (ballTargetY - ballY) / time;

		state = Shooting;
	}

	function drawGoal() {
		goalG.clear();
		goalG.lineStyle(5, 0xFFFFFF);
		goalG.drawRect(GOAL_LEFT, GOAL_Y, GOAL_W, GOAL_H);
		goalG.lineStyle(0);
		goalG.beginFill(0x111111, 0.5);
		goalG.drawRect(GOAL_LEFT + 4, GOAL_Y + 4, GOAL_W - 8, GOAL_H - 8);
		goalG.endFill();
		goalG.lineStyle(2, 0x333333);
		for (i in 1...3) {
			var x = GOAL_LEFT + i * ZONE_W;
			goalG.moveTo(x, GOAL_Y);
			goalG.lineTo(x, GOAL_Y + GOAL_H);
		}
		goalG.lineStyle(0);
	}

	function drawBall() {
		ballG.clear();
		ballG.beginFill(0xFFFFFF);
		ballG.drawCircle(ballX, ballY, BALL_R);
		ballG.endFill();
		ballG.lineStyle(2, 0xCCCCCC);
		ballG.drawCircle(ballX, ballY, BALL_R);
		ballG.lineStyle(0);
		ballG.beginFill(0x333333);
		ballG.drawCircle(ballX - 4, ballY - 4, 4);
		ballG.endFill();
	}

	function drawKeeper() {
		keeperG.clear();
		var kx = keeperX + KEEPER_W / 2;
		var ky = GOAL_Y + GOAL_H - 18;
		keeperG.beginFill(0x1a5fb4);
		keeperG.drawRoundedRect(keeperX, ky - KEEPER_H, KEEPER_W, KEEPER_H, 6);
		keeperG.endFill();
		keeperG.lineStyle(2, 0x0d3d7a);
		keeperG.drawRoundedRect(keeperX, ky - KEEPER_H, KEEPER_W, KEEPER_H, 6);
		keeperG.lineStyle(0);
		keeperG.beginFill(0xFFDBAC);
		keeperG.drawEllipse(kx, ky - KEEPER_H - 8, 12, 10);
		keeperG.endFill();
		keeperG.beginFill(0x000000);
		keeperG.drawCircle(kx - 3, ky - KEEPER_H - 9, 2);
		keeperG.drawCircle(kx + 3, ky - KEEPER_H - 9, 2);
		keeperG.endFill();
	}

	function drawAim() {
		aimG.clear();
		if (state != Aiming) return;
		aimG.lineStyle(4, 0xFFDD00, 0.9);
		aimG.moveTo(aimStartX, aimStartY);
		aimG.lineTo(aimEndX, aimEndY);
		aimG.lineStyle(0);
		aimG.beginFill(0xFFDD00, 0.6);
		aimG.drawCircle(aimEndX, aimEndY, 10);
		aimG.endFill();
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		ballX = BALL_START_X;
		ballY = BALL_START_Y;
		keeperX = GOAL_LEFT + GOAL_W / 2 - KEEPER_W / 2;
		keeperTargetX = keeperX;
		started = false;
		score = 0;
		gameOver = false;
		state = Idle;
		scoreText.text = "0";
		drawGoal();
		drawBall();
		drawKeeper();
		drawAim();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId(): String return "penalty-shootout";
	public function getTitle(): String return "Pênalti";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started) {
			drawGoal();
			drawBall();
			drawKeeper();
			drawAim();
			return;
		}

		if (state == Shooting) {
			ballX += ballVx * dt;
			ballY += ballVy * dt;
			keeperX += (keeperTargetX - keeperX) * Math.min(1, KEEPER_DIVE_SPEED * dt / 80);

			if (ballY <= GOAL_Y + GOAL_H) {
				var inGoal = ballX >= GOAL_LEFT && ballX <= GOAL_LEFT + GOAL_W;
				var margin = 18;
				var ballInKeeperZone = inGoal && ballX >= keeperX - margin && ballX <= keeperX + KEEPER_W + margin;
				if (ballInKeeperZone) {
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				}
				if (inGoal) {
					score++;
					scoreText.text = Std.string(score);
				}
				state = Idle;
				ballX = BALL_START_X;
				ballY = BALL_START_Y;
				keeperX = GOAL_LEFT + GOAL_W / 2 - KEEPER_W / 2;
				keeperTargetX = keeperX;
			} else if (ballY < GOAL_Y - 20) {
				state = Idle;
				ballX = BALL_START_X;
				ballY = BALL_START_Y;
				keeperX = GOAL_LEFT + GOAL_W / 2 - KEEPER_W / 2;
				keeperTargetX = keeperX;
			}
		}

		drawGoal();
		drawBall();
		drawKeeper();
		drawAim();
	}
}

private enum PenaltyState {
	Idle;
	Aiming;
	Shooting;
}
