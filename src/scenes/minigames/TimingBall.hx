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
	var scoreBg:Graphics;
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

	var trail:Array<{x:Float, y:Float, alpha:Float}>;
	// Pass burst particles (when clearing a bar)
	var passParticles:Array<{x:Float, y:Float, vx:Float, vy:Float, life:Float}>;
	static var PASS_PARTICLE_COUNT = 10;

	public var content(get, never):Object;

	function get_content():Object
		return contentObj;

	public function new() {
		contentObj = new Object();
		rng = new hxd.Rand(42);

		bg = new Graphics(contentObj);
		scoreBg = new Graphics(contentObj);
		obsG = new Graphics(contentObj);
		ballG = new Graphics(contentObj);

		var font = hxd.res.DefaultFont.get();
		scoreText = new Text(font, contentObj);
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 30;
		scoreText.scale(2.5);
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(font, contentObj);
		instructText.textAlign = Center;
		instructText.x = DESIGN_W / 2;
		instructText.y = 480;
		instructText.scale(1.0);
		instructText.textColor = 0xAAFFDD;
		instructText.text = "TAP left or right to bounce & dodge!";
		instructText.alpha = 0;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) onTap(e.relX);

		obstacles = [];
		trail = [];
		passParticles = [];
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
		passParticles = [];

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

	function drawScorePill():Void {
		scoreBg.clear();
		scoreBg.beginFill(0x000000, 0.45);
		scoreBg.drawRoundedRect(DESIGN_W / 2 - 44, 12, 88, 40, 20);
		scoreBg.endFill();
		scoreBg.beginFill(0x44AAFF, 0.18);
		scoreBg.drawRoundedRect(DESIGN_W / 2 - 44, 12, 88, 40, 20);
		scoreBg.endFill();
	}

	function spawnPassParticles(gapCenterX:Float, barY:Float):Void {
		for (_ in 0...PASS_PARTICLE_COUNT) {
			var angle = rng.rand() * Math.PI * 2;
			var speed = 40 + rng.rand() * 80;
			passParticles.push({
				x: gapCenterX,
				y: barY,
				vx: Math.cos(angle) * speed,
				vy: -Math.abs(Math.sin(angle)) * speed - 30,
				life: 0.2 + rng.rand() * 0.15
			});
		}
	}

	function drawBg():Void {
		bg.clear();
		bg.beginFill(0x0A0E1A);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		bg.beginFill(0x0F1628);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		// Soft center band (play area)
		bg.beginFill(0x1A2440, 0.4);
		bg.drawRect(0, 120, DESIGN_W, 420);
		bg.endFill();
		// Vignette
		bg.beginFill(0x000000, 0.4);
		bg.drawRect(0, 0, DESIGN_W, 70);
		bg.drawRect(0, DESIGN_H - 120, DESIGN_W, 120);
		bg.drawRect(0, 0, 45, DESIGN_H);
		bg.drawRect(DESIGN_W - 45, 0, 45, DESIGN_H);
		bg.endFill();

		// Floor: gradient + reflection strip
		bg.beginFill(0x151C30);
		bg.drawRect(0, FLOOR_Y, DESIGN_W, DESIGN_H - FLOOR_Y);
		bg.endFill();
		bg.beginFill(0x1E2840);
		bg.drawRect(0, FLOOR_Y, DESIGN_W, 50);
		bg.endFill();
		bg.beginFill(0x2A3560, 0.8);
		bg.drawRect(0, FLOOR_Y, DESIGN_W, 3);
		bg.endFill();
		bg.beginFill(0x44AAFF, 0.08);
		bg.drawRect(0, FLOOR_Y + 3, DESIGN_W, 12);
		bg.endFill();
	}

	function drawBall():Void {
		ballG.clear();

		// Trail (gradient fade, slight glow)
		for (p in trail) {
			var tr = BALL_RADIUS * p.alpha * 0.7;
			ballG.beginFill(0x66BBFF, p.alpha * 0.15);
			ballG.drawCircle(p.x, p.y, tr + 4);
			ballG.endFill();
			ballG.beginFill(0x44AAFF, p.alpha * 0.5);
			ballG.drawCircle(p.x, p.y, tr);
			ballG.endFill();
		}

		// Shadow on floor (circle = safe cross‑platform)
		var shadowDist = (FLOOR_Y - ballY) / FLOOR_Y;
		var shadowR = BALL_RADIUS * (1.0 - shadowDist * 0.4);
		var shadowA = 0.35 - shadowDist * 0.15;
		ballG.beginFill(0x000000, shadowA);
		ballG.drawCircle(ballX, FLOOR_Y + 6, shadowR);
		ballG.endFill();

		// Ball with squash/stretch (ellipse for stretch)
		var sx = 1.0 / ballSquash;
		var sy = ballSquash;
		var rx = BALL_RADIUS * sx;
		var ry = BALL_RADIUS * sy;

		// Outer rim (dark)
		ballG.beginFill(0x2A6A9A);
		ballG.drawEllipse(ballX, ballY, rx * 1.05, ry * 1.05);
		ballG.endFill();
		// Main
		ballG.beginFill(0x3399DD);
		ballG.drawEllipse(ballX, ballY, rx, ry);
		ballG.endFill();
		// Highlight
		ballG.beginFill(0x88DDFF, 0.85);
		ballG.drawEllipse(ballX - rx * 0.3, ballY - ry * 0.35, rx * 0.45, ry * 0.4);
		ballG.endFill();
		// Tiny specular
		ballG.beginFill(0xFFFFFF, 0.6);
		ballG.drawCircle(ballX - rx * 0.2, ballY - ry * 0.4, rx * 0.2);
		ballG.endFill();

		if (deathFlash > 0) {
			ballG.beginFill(0xFF4466, deathFlash);
			ballG.drawEllipse(ballX, ballY, rx, ry);
			ballG.endFill();
		}
	}

	function drawObstacles():Void {
		obsG.clear();

		for (obs in obstacles) {
			var barY = obs.y;
			if (barY < -20 || barY > DESIGN_H + 20) continue;

			var halfT = OBS_THICKNESS / 2;
			if (obs.barType == 1) {
				// Left bar (safe zone = right)
				var barW = DESIGN_W / 2 - 14;
				obsG.beginFill(0x000000, 0.25);
				obsG.drawRect(2, barY - halfT + 2, barW, OBS_THICKNESS);
				obsG.endFill();
				obsG.beginFill(0x8B2A2A);
				obsG.drawRect(0, barY - halfT, barW, OBS_THICKNESS - 3);
				obsG.endFill();
				obsG.beginFill(0xB83A3A);
				obsG.drawRect(0, barY - halfT, barW, 4);
				obsG.endFill();
				obsG.beginFill(0xE05050, 0.8);
				obsG.drawRect(barW - 4, barY - halfT, 4, OBS_THICKNESS);
				obsG.endFill();
				// Safe side glow
				obsG.beginFill(0x44DD88, 0.35);
				obsG.drawRect(DESIGN_W / 2, barY - halfT - 2, DESIGN_W / 2, OBS_THICKNESS + 4);
				obsG.endFill();
				obsG.beginFill(0x66FFAA, 0.5);
				obsG.drawRect(DESIGN_W / 2 + 4, barY - 3, 24, 6);
				obsG.endFill();
			} else {
				var barX = DESIGN_W / 2 + 14;
				var barW = DESIGN_W - barX;
				obsG.beginFill(0x000000, 0.25);
				obsG.drawRect(barX - 2, barY - halfT + 2, barW + 2, OBS_THICKNESS);
				obsG.endFill();
				obsG.beginFill(0x8B2A2A);
				obsG.drawRect(barX, barY - halfT, barW, OBS_THICKNESS - 3);
				obsG.endFill();
				obsG.beginFill(0xB83A3A);
				obsG.drawRect(barX, barY - halfT, barW, 4);
				obsG.endFill();
				obsG.beginFill(0xE05050, 0.8);
				obsG.drawRect(barX, barY - halfT, 4, OBS_THICKNESS);
				obsG.endFill();
				obsG.beginFill(0x44DD88, 0.35);
				obsG.drawRect(0, barY - halfT - 2, DESIGN_W / 2, OBS_THICKNESS + 4);
				obsG.endFill();
				obsG.beginFill(0x66FFAA, 0.5);
				obsG.drawRect(DESIGN_W / 2 - 28, barY - 3, 24, 6);
				obsG.endFill();
			}

			if (obs.passed && flashTimer > 0) {
				obsG.beginFill(0xFFFFFF, flashTimer * 0.4);
				obsG.drawRect(0, barY - halfT - 4, DESIGN_W, OBS_THICKNESS + 8);
				obsG.endFill();
			}
		}

		// Pass burst particles
		for (p in passParticles) {
			var a = p.life * 5;
			if (a > 1) a = 1;
			obsG.beginFill(0xAAFFDD, a);
			obsG.drawCircle(p.x, p.y, 3);
			obsG.endFill();
			obsG.beginFill(0xFFFFFF, a * 0.7);
			obsG.drawCircle(p.x, p.y, 1.5);
			obsG.endFill();
		}
	}

	function onTap(touchX:Float):Void {
		if (gameOver) return;

		if (!started) {
			started = true;
		}
		instructText.alpha = 0;

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
			ballVY += GRAVITY * dt;
			ballY += ballVY * dt;
			if (ballY >= FLOOR_Y - BALL_RADIUS) {
				ballY = FLOOR_Y - BALL_RADIUS;
				ballVY = BOUNCE_VEL * 0.6;
				ballSquash = 1.3;
			}
			ballSquash += (1.0 - ballSquash) * 8.0 * dt;
			drawScorePill();
			drawBall();
			return;
		}

		if (gameOver) {
			deathFlash -= dt * 3.0;
			if (deathFlash < 0) deathFlash = 0;
			ballVY += GRAVITY * dt;
			ballY += ballVY * dt;
			drawScorePill();
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
		if (trail.length > 14) trail.splice(0, trail.length - 14);

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
						ctx.feedback.shake2D(0.35, 10);
						ctx.feedback.flash(0xFF2244, 0.3);
					}
					if (ctx != null) ctx.lose(score, getMinigameId());
					drawBall();
					drawObstacles();
					return;
				}
			}

			if (!obs.passed && obs.y - OBS_THICKNESS / 2 > ballY + BALL_RADIUS) {
				obs.passed = true;
				score++;
				scoreText.text = Std.string(score);
				flashTimer = 0.35;
				var gapX = obs.barType == 1 ? (DESIGN_W / 2 + DESIGN_W) / 2 : DESIGN_W / 4;
				spawnPassParticles(gapX, obs.y);
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(0.08, 2);
					ctx.feedback.flash(0xFFFFFF, 0.06);
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

		if (flashTimer > 0) flashTimer -= dt;

		// Pass particles
		var i = 0;
		while (i < passParticles.length) {
			var p = passParticles[i];
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.life -= dt;
			if (p.life <= 0)
				passParticles.splice(i, 1);
			else
				i++;
		}

		drawScorePill();
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
