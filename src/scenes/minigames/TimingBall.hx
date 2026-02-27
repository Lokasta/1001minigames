package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class TimingBall implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var BALL_LEFT_X = 90.0;
	static var BALL_RIGHT_X = 270.0;
	static var BALL_RADIUS = 14.0;
	static var GRAVITY = 800.0;
	static var BOUNCE_VEL = -380.0;
	static var FLOOR_Y = 540.0;

	// Obstacles: solid horizontal bars scrolling down
	static var OBS_SPEED_START = 100.0;
	static var OBS_SPEED_MAX = 220.0;
	static var OBS_SPEED_RAMP = 60.0; // seconds to max
	static var OBS_SPACING_START = 200.0;
	static var OBS_SPACING_MIN = 120.0;
	static var OBS_THICKNESS = 12.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var obsG:Graphics;
	var ballG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var totalTime:Float;

	// Ball physics
	var ballX:Float;
	var ballTargetX:Float;
	var ballY:Float;
	var ballVY:Float;
	var ballSquash:Float; // squash/stretch animation

	// Obstacles: horizontal bars at certain Y, some have safe zones
	// type: 0 = full bar (dodge by being above/below), 1 = left half, 2 = right half
	var obstacles:Array<{y:Float, barType:Int, passed:Bool}>;

	var rng:hxd.Rand;

	// Flash
	var flashTimer:Float;
	var deathFlash:Float;

	// Trail particles
	var trail:Array<{x:Float, y:Float, alpha:Float}>;

	public var content(get, never):Object;

	function get_content():Object
		return contentObj;

	public function new() {
		contentObj = new Object();
		rng = new hxd.Rand(42);

		bg = new Graphics(contentObj);
		obsG = new Graphics(contentObj);
		ballG = new Graphics(contentObj);

		var font = hxd.res.DefaultFont.get();
		scoreText = new Text(font, contentObj);
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 30;
		scoreText.scale(2.5);
		scoreText.color = h3d.Vector4.fromColor(0xFFFFFFFF);

		instructText = new Text(font, contentObj);
		instructText.textAlign = Center;
		instructText.x = DESIGN_W / 2;
		instructText.y = 460;
		instructText.scale(1.2);
		instructText.color = h3d.Vector4.fromColor(0xFFFFFFFF);
		instructText.text = "TAP LEFT/RIGHT TO DODGE";
		instructText.alpha = 0;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) onTap(e.relX);

		obstacles = [];
		trail = [];
		score = 0;
		gameOver = true;
		started = false;
		totalTime = 0;
		flashTimer = 0;
		deathFlash = 0;
		ballSquash = 1.0;
	}

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start():Void {
		score = 0;
		gameOver = false;
		started = false;
		totalTime = 0;
		flashTimer = 0;
		deathFlash = 0;
		ballSquash = 1.0;
		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		ballX = BALL_LEFT_X;
		ballTargetX = BALL_LEFT_X;
		ballY = FLOOR_Y - BALL_RADIUS;
		ballVY = 0;

		obstacles = [];
		trail = [];

		// Pre-spawn obstacles above screen
		var y = -20.0;
		for (i in 0...4) {
			spawnObstacle(y);
			y -= getSpacing();
		}

		scoreText.text = "0";
		instructText.alpha = 1.0;

		drawBg();
		drawBall();
		drawObstacles();
	}

	function getSpacing():Float {
		var t = Math.min(totalTime / 90.0, 1.0);
		return OBS_SPACING_START + (OBS_SPACING_MIN - OBS_SPACING_START) * t;
	}

	function spawnObstacle(y:Float):Void {
		// barType: 1 = left half (ball safe on right), 2 = right half (ball safe on left)
		var barType = rng.random(2) + 1;
		obstacles.push({y: y, barType: barType, passed: false});
	}

	function getObsSpeed():Float {
		var t = Math.min(totalTime / OBS_SPEED_RAMP, 1.0);
		return OBS_SPEED_START + (OBS_SPEED_MAX - OBS_SPEED_START) * t;
	}

	function drawBg():Void {
		bg.clear();
		// Dark gradient
		for (y in 0...32) {
			var t = y / 31.0;
			var r = Std.int(8 + t * 10);
			var g = Std.int(12 + t * 8);
			var b = Std.int(30 + t * 20);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, y * 20, DESIGN_W, 20);
			bg.endFill();
		}

		// Floor
		bg.beginFill(0x2A2A4A);
		bg.drawRect(0, FLOOR_Y, DESIGN_W, DESIGN_H - FLOOR_Y);
		bg.endFill();
		// Floor line
		bg.beginFill(0x4A4A7A);
		bg.drawRect(0, FLOOR_Y, DESIGN_W, 2);
		bg.endFill();
	}

	function drawBall():Void {
		ballG.clear();

		// Trail
		for (p in trail) {
			ballG.beginFill(0x44AAFF, p.alpha * 0.3);
			var tr = BALL_RADIUS * p.alpha * 0.6;
			ballG.drawCircle(p.x, p.y, tr);
			ballG.endFill();
		}

		// Shadow on floor
		var shadowDist = (FLOOR_Y - ballY) / FLOOR_Y;
		var shadowScale = 1.0 - shadowDist * 0.5;
		ballG.beginFill(0x000000, 0.2);
		ballG.drawEllipse(ballX, FLOOR_Y + 4, BALL_RADIUS * shadowScale, 4 * shadowScale);
		ballG.endFill();

		// Ball with squash/stretch
		var sx = 1.0 / ballSquash;
		var sy = ballSquash;
		var rx = BALL_RADIUS * sx;
		var ry = BALL_RADIUS * sy;

		// Main ball
		ballG.beginFill(0x44AAFF);
		ballG.drawEllipse(ballX, ballY, rx, ry);
		ballG.endFill();

		// Highlight
		ballG.beginFill(0x88CCFF, 0.6);
		ballG.drawEllipse(ballX - rx * 0.25, ballY - ry * 0.3, rx * 0.4, ry * 0.35);
		ballG.endFill();

		// Death flash overlay
		if (deathFlash > 0) {
			ballG.beginFill(0xFF4444, deathFlash);
			ballG.drawEllipse(ballX, ballY, rx, ry);
			ballG.endFill();
		}
	}

	function drawObstacles():Void {
		obsG.clear();

		for (obs in obstacles) {
			var barY = obs.y;
			if (barY < -20 || barY > DESIGN_H + 20) continue;

			if (obs.barType == 1) {
				// Left half bar: covers left side, gap on right
				// Main bar
				obsG.beginFill(0xCC4444);
				obsG.drawRect(0, barY - OBS_THICKNESS / 2, DESIGN_W / 2 - 10, OBS_THICKNESS);
				obsG.endFill();
				// Highlight top
				obsG.beginFill(0xEE6666, 0.5);
				obsG.drawRect(0, barY - OBS_THICKNESS / 2, DESIGN_W / 2 - 10, 3);
				obsG.endFill();
				// Edge glow (right end)
				obsG.beginFill(0xFF8888, 0.7);
				obsG.drawRect(DESIGN_W / 2 - 13, barY - OBS_THICKNESS / 2, 3, OBS_THICKNESS);
				obsG.endFill();
				// Arrow hint: small triangle pointing to safe side
				obsG.beginFill(0x44FF88, 0.4);
				obsG.drawRect(DESIGN_W / 2 + 10, barY - 2, 20, 4);
				obsG.endFill();
			} else {
				// Right half bar: covers right side, gap on left
				obsG.beginFill(0xCC4444);
				obsG.drawRect(DESIGN_W / 2 + 10, barY - OBS_THICKNESS / 2, DESIGN_W / 2 - 10, OBS_THICKNESS);
				obsG.endFill();
				obsG.beginFill(0xEE6666, 0.5);
				obsG.drawRect(DESIGN_W / 2 + 10, barY - OBS_THICKNESS / 2, DESIGN_W / 2 - 10, 3);
				obsG.endFill();
				// Edge glow (left end)
				obsG.beginFill(0xFF8888, 0.7);
				obsG.drawRect(DESIGN_W / 2 + 10, barY - OBS_THICKNESS / 2, 3, OBS_THICKNESS);
				obsG.endFill();
				// Arrow hint
				obsG.beginFill(0x44FF88, 0.4);
				obsG.drawRect(DESIGN_W / 2 - 30, barY - 2, 20, 4);
				obsG.endFill();
			}

			// Score flash on pass
			if (obs.passed && flashTimer > 0) {
				obsG.beginFill(0xFFFFFF, flashTimer * 0.3);
				obsG.drawRect(0, barY - OBS_THICKNESS / 2 - 2, DESIGN_W, OBS_THICKNESS + 4);
				obsG.endFill();
			}
		}
	}

	function onTap(touchX:Float):Void {
		if (gameOver) return;

		if (!started) {
			started = true;
			instructText.alpha = 0;
		}

		// Tap left side → move ball left, tap right side → move ball right
		if (touchX < DESIGN_W / 2) {
			ballTargetX = BALL_LEFT_X;
		} else {
			ballTargetX = BALL_RIGHT_X;
		}

		// Also bounce!
		ballVY = BOUNCE_VEL;
		ballSquash = 0.7;
	}

	public function update(dt:Float):Void {
		if (gameOver && !started) {
			if (instructText.alpha < 1.0) {
				instructText.alpha = Math.min(1.0, instructText.alpha + dt * 2.0);
			}
			// Idle bounce animation
			ballVY += GRAVITY * dt;
			ballY += ballVY * dt;
			if (ballY >= FLOOR_Y - BALL_RADIUS) {
				ballY = FLOOR_Y - BALL_RADIUS;
				ballVY = BOUNCE_VEL * 0.6;
				ballSquash = 1.3;
			}
			ballSquash += (1.0 - ballSquash) * 8.0 * dt;
			drawBall();
			return;
		}

		if (gameOver) {
			// Death animation
			deathFlash -= dt * 3.0;
			if (deathFlash < 0) deathFlash = 0;
			ballVY += GRAVITY * dt;
			ballY += ballVY * dt;
			drawBall();
			return;
		}

		totalTime += dt;

		// Ball physics
		ballVY += GRAVITY * dt;
		ballY += ballVY * dt;

		// Floor bounce
		if (ballY >= FLOOR_Y - BALL_RADIUS) {
			ballY = FLOOR_Y - BALL_RADIUS;
			ballVY = BOUNCE_VEL;
			ballSquash = 1.3; // squash on land
		}

		// Ceiling clamp
		if (ballY < BALL_RADIUS + 60) {
			ballY = BALL_RADIUS + 60;
			if (ballVY < 0) ballVY = 0;
		}

		// Horizontal movement (smooth lerp)
		ballX += (ballTargetX - ballX) * 12.0 * dt;

		// Squash/stretch recovery
		ballSquash += (1.0 - ballSquash) * 8.0 * dt;

		// Trail
		trail.push({x: ballX, y: ballY, alpha: 1.0});
		var i = trail.length - 1;
		while (i >= 0) {
			trail[i].alpha -= dt * 4.0;
			if (trail[i].alpha <= 0) {
				trail.splice(i, 1);
			}
			i--;
		}
		if (trail.length > 8) trail.splice(0, trail.length - 8);

		// Move obstacles down
		var speed = getObsSpeed();
		var toRemove:Array<Int> = [];

		for (idx in 0...obstacles.length) {
			var obs = obstacles[idx];
			obs.y += speed * dt;

			// Check collision: ball overlaps bar vertically?
			if (!obs.passed && ballY + BALL_RADIUS > obs.y - OBS_THICKNESS / 2 && ballY - BALL_RADIUS < obs.y + OBS_THICKNESS / 2) {
				// Check if ball is on the bar side (not the gap side)
				var hit = false;
				if (obs.barType == 1) {
					// Left half bar: safe on right side
					if (ballX < DESIGN_W / 2) hit = true;
				} else {
					// Right half bar: safe on left side
					if (ballX > DESIGN_W / 2) hit = true;
				}

				if (hit) {
					gameOver = true;
					deathFlash = 1.0;
					if (ctx != null && ctx.feedback != null) {
						ctx.feedback.shake2D(6, 0.3);
						ctx.feedback.flash(0xFF0000, 0.3);
					}
					if (ctx != null) ctx.lose(score, getMinigameId());
					drawBall();
					drawObstacles();
					return;
				}
			}

			// Passed the ball?
			if (!obs.passed && obs.y - OBS_THICKNESS / 2 > ballY + BALL_RADIUS) {
				obs.passed = true;
				score++;
				scoreText.text = Std.string(score);
				flashTimer = 0.3;
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(2, 0.08);
				}
			}

			// Remove if off screen
			if (obs.y > DESIGN_H + 40) {
				toRemove.push(idx);
			}
		}

		// Remove off-screen obstacles (reverse order)
		var ri = toRemove.length - 1;
		while (ri >= 0) {
			obstacles.splice(toRemove[ri], 1);
			ri--;
		}

		// Spawn new obstacles at top
		var topY:Float = 0;
		for (obs in obstacles) {
			if (obs.y < topY) topY = obs.y;
		}
		if (topY > -20) {
			spawnObstacle(topY - getSpacing());
		}

		// Flash decay
		if (flashTimer > 0) flashTimer -= dt;

		drawBall();
		drawObstacles();
	}

	public function dispose():Void {
		contentObj.remove();
	}

	public function getMinigameId():String
		return "timing_ball";

	public function getTitle():String
		return "Timing Ball";
}
