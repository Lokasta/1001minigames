package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class SkipRope implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;

	// Rope physics
	static var ROPE_SPEED_START = 2.2; // radians per second
	static var ROPE_SPEED_MAX = 6.0;
	static var ROPE_SPEED_RAMP = 120.0; // seconds to reach max
	static var ROPE_CENTER_Y = 420.0; // pivot Y for rope holders
	static var ROPE_RADIUS = 100.0; // rope arc radius

	// Player
	static var PLAYER_X = 180.0;
	static var GROUND_Y = 500.0;
	static var JUMP_VEL = -420.0;
	static var GRAVITY = 1200.0;
	static var PLAYER_W = 24.0;
	static var PLAYER_H = 44.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var ropeG:Graphics;
	var playerG:Graphics;
	var holdersG:Graphics;
	var shadowG:Graphics;
	var particleG:Graphics;
	var uiG:Graphics;
	var scoreText:Text;
	var comboText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var score:Int;
	var combo:Int;
	var bestCombo:Int;
	var gameOver:Bool;
	var started:Bool;
	var totalTime:Float;

	// Rope angle: 0 = top, PI = bottom (danger zone)
	var ropeAngle:Float;
	var ropeSpeed:Float;
	var ropeDir:Int; // 1 = forward, for visual direction

	// Player
	var playerY:Float;
	var playerVY:Float;
	var isJumping:Bool;
	var squash:Float;
	var playerFeetY:Float;

	// Hit detection
	var lastRopeBottom:Bool; // was rope at bottom last frame
	var jumpedThisSwing:Bool; // successfully jumped this swing
	var missWindow:Bool; // in the danger zone

	// Particles
	var particles:Array<{x:Float, y:Float, vx:Float, vy:Float, life:Float, maxLife:Float, color:Int, size:Float}>;

	// Visual
	var flashTimer:Float;
	var shakeTimer:Float;
	var shakeIntensity:Float;
	var holderBobL:Float;
	var holderBobR:Float;

	public var content(get, never):Object;

	function get_content():Object
		return contentObj;

	public function new() {
		contentObj = new Object();

		bg = new Graphics(contentObj);
		shadowG = new Graphics(contentObj);
		holdersG = new Graphics(contentObj);
		ropeG = new Graphics(contentObj);
		playerG = new Graphics(contentObj);
		particleG = new Graphics(contentObj);
		uiG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.textAlign = Center;
		scoreText.scale(3);
		scoreText.textColor = 0xFFFFFF;

		comboText = new Text(hxd.res.DefaultFont.get(), contentObj);
		comboText.textAlign = Center;
		comboText.scale(1.8);
		comboText.textColor = 0xFFD700;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.textAlign = Center;
		instructText.scale(1.5);
		instructText.textColor = 0xFFFFFF;
		instructText.text = "TAP TO JUMP!";

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(_) onTap();

		score = 0;
		combo = 0;
		bestCombo = 0;
		gameOver = false;
		started = false;
		totalTime = 0;

		ropeAngle = 0; // start at top
		ropeSpeed = ROPE_SPEED_START;
		ropeDir = 1;

		playerY = GROUND_Y;
		playerVY = 0;
		isJumping = false;
		squash = 1.0;
		playerFeetY = GROUND_Y;

		lastRopeBottom = false;
		jumpedThisSwing = false;
		missWindow = false;

		particles = [];
		flashTimer = 0;
		shakeTimer = 0;
		shakeIntensity = 0;
		holderBobL = 0;
		holderBobR = 0;

		layoutUI();
		drawBg();
	}

	function layoutUI() {
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 40;

		comboText.x = DESIGN_W / 2;
		comboText.y = 85;
		comboText.visible = false;

		instructText.x = DESIGN_W / 2;
		instructText.y = 280;
	}

	function drawBg() {
		bg.clear();

		// Sky gradient
		var skyColors = [0x87CEEB, 0xB0E0FF, 0xE8F4FD];
		for (i in 0...3) {
			var y0 = Std.int(i * DESIGN_H / 3);
			var y1 = Std.int((i + 1) * DESIGN_H / 3);
			bg.beginFill(skyColors[i]);
			bg.drawRect(0, y0, DESIGN_W, y1 - y0);
			bg.endFill();
		}

		// Ground
		bg.beginFill(0x7BC67E);
		bg.drawRect(0, GROUND_Y, DESIGN_W, DESIGN_H - GROUND_Y);
		bg.endFill();

		// Ground detail - darker stripe
		bg.beginFill(0x6AB36D);
		bg.drawRect(0, GROUND_Y, DESIGN_W, 4);
		bg.endFill();

		// Grass tufts
		bg.beginFill(0x5DA660);
		var rng = new hxd.Rand(42);
		for (i in 0...20) {
			var gx = rng.random(DESIGN_W);
			var gy = GROUND_Y + 8 + rng.random(Std.int(DESIGN_H - GROUND_Y - 16));
			bg.drawRect(gx, gy, 3, 2);
		}

		// Clouds
		bg.beginFill(0xFFFFFF, 0.6);
		drawCloud(bg, 60, 80, 30);
		drawCloud(bg, 220, 50, 25);
		drawCloud(bg, 300, 110, 20);
	}

	function drawCloud(g:Graphics, cx:Float, cy:Float, r:Float) {
		g.drawCircle(cx, cy, r);
		g.drawCircle(cx - r * 0.7, cy + r * 0.2, r * 0.7);
		g.drawCircle(cx + r * 0.7, cy + r * 0.2, r * 0.7);
		g.drawCircle(cx - r * 0.3, cy - r * 0.3, r * 0.6);
		g.drawCircle(cx + r * 0.3, cy - r * 0.3, r * 0.6);
	}

	function onTap() {
		if (gameOver) return;
		if (!started) {
			started = true;
			instructText.visible = false;
		}
		if (!isJumping && playerY >= GROUND_Y - 1) {
			playerVY = JUMP_VEL;
			isJumping = true;
			squash = 0.6; // squash on takeoff
			// Dust particles
			spawnDust(PLAYER_X, GROUND_Y, 6);
		}
	}

	function spawnDust(x:Float, y:Float, count:Int) {
		for (i in 0...count) {
			var angle = Math.random() * Math.PI;
			var speed = 30 + Math.random() * 60;
			particles.push({
				x: x + (Math.random() - 0.5) * 20,
				y: y,
				vx: Math.cos(angle) * speed * (Math.random() > 0.5 ? 1 : -1),
				vy: -Math.random() * 30,
				life: 0.3 + Math.random() * 0.3,
				maxLife: 0.6,
				color: 0xC8B88A,
				size: 2 + Math.random() * 3
			});
		}
	}

	function spawnJumpStar(x:Float, y:Float) {
		for (i in 0...8) {
			var angle = (i / 8) * Math.PI * 2;
			var speed = 60 + Math.random() * 40;
			particles.push({
				x: x,
				y: y,
				vx: Math.cos(angle) * speed,
				vy: Math.sin(angle) * speed,
				life: 0.4 + Math.random() * 0.2,
				maxLife: 0.6,
				color: combo > 5 ? 0xFFD700 : 0xFFFFFF,
				size: 2 + Math.random() * 2
			});
		}
	}

	public function setOnLose(ctx:MinigameContext) {
		this.ctx = ctx;
	}

	public function start() {}

	public function update(dt:Float) {
		if (gameOver) return;
		if (!started) {
			// Animate instruction text
			instructText.alpha = 0.6 + 0.4 * Math.sin(totalTime * 4);
			totalTime += dt;
			return;
		}

		totalTime += dt;

		// Rope speed ramp
		var t = Math.min(totalTime / ROPE_SPEED_RAMP, 1.0);
		ropeSpeed = ROPE_SPEED_START + (ROPE_SPEED_MAX - ROPE_SPEED_START) * t;

		// Update rope angle (0 = top, PI = bottom pass, 2PI = back to top)
		var prevAngle = ropeAngle;
		ropeAngle += ropeSpeed * dt;

		// Check if rope completed a full rotation
		if (ropeAngle >= Math.PI * 2) {
			ropeAngle -= Math.PI * 2;
		}

		// Detect rope passing through bottom (danger zone ~PI ± tolerance)
		var dangerStart = Math.PI - 0.4;
		var dangerEnd = Math.PI + 0.4;
		var inDanger = ropeAngle > dangerStart && ropeAngle < dangerEnd;

		// Check rope at very bottom for hit detection
		var ropeAtBottom = ropeAngle > (Math.PI - 0.15) && ropeAngle < (Math.PI + 0.15);

		// If rope just passed bottom
		if (ropeAtBottom && !lastRopeBottom) {
			// Check if player is on ground (not jumping) = HIT
			playerFeetY = playerY;
			if (playerFeetY >= GROUND_Y - 15) {
				// Hit by rope!
				triggerGameOver();
				lastRopeBottom = ropeAtBottom;
				return;
			} else {
				// Successfully jumped!
				if (!jumpedThisSwing) {
					jumpedThisSwing = true;
					score++;
					combo++;
					if (combo > bestCombo) bestCombo = combo;
					spawnJumpStar(PLAYER_X, playerY);
					if (ctx != null && ctx.feedback != null) {
						ctx.feedback.flash(0xFFFFFF, 0.1);
					}
				}
			}
		}

		// Reset swing tracker when rope passes top
		if (prevAngle > Math.PI && ropeAngle < Math.PI) {
			jumpedThisSwing = false;
		}
		// Also reset when wrapping around
		if (ropeAngle < 0.5 && prevAngle > Math.PI * 1.5) {
			jumpedThisSwing = false;
		}

		lastRopeBottom = ropeAtBottom;

		// Player physics
		if (isJumping || playerY < GROUND_Y) {
			playerVY += GRAVITY * dt;
			playerY += playerVY * dt;

			if (playerY >= GROUND_Y) {
				playerY = GROUND_Y;
				playerVY = 0;
				isJumping = false;
				squash = 1.4; // stretch on landing
				spawnDust(PLAYER_X, GROUND_Y, 4);
			}
		}

		// Squash/stretch recovery
		squash += (1.0 - squash) * 8 * dt;

		// Holder bob animation
		holderBobL = Math.sin(totalTime * 3) * 3;
		holderBobR = Math.sin(totalTime * 3 + 0.5) * 3;

		// Update particles
		var i = particles.length;
		while (i-- > 0) {
			var p = particles[i];
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vy += 60 * dt;
			p.life -= dt;
			if (p.life <= 0) particles.splice(i, 1);
		}

		// Timers
		if (flashTimer > 0) flashTimer -= dt;
		if (shakeTimer > 0) shakeTimer -= dt;

		// Draw everything
		draw();
	}

	function triggerGameOver() {
		gameOver = true;
		combo = 0;

		// Screen shake
		shakeTimer = 0.4;
		shakeIntensity = 6;

		if (ctx != null && ctx.feedback != null) {
			ctx.feedback.flash(0xFF0000, 0.3);
			ctx.feedback.shake2D(0.3, 5);
		}

		// Red flash particles
		for (i in 0...12) {
			var angle = Math.random() * Math.PI * 2;
			var speed = 40 + Math.random() * 80;
			particles.push({
				x: PLAYER_X,
				y: playerY - PLAYER_H / 2,
				vx: Math.cos(angle) * speed,
				vy: Math.sin(angle) * speed,
				life: 0.5,
				maxLife: 0.5,
				color: 0xFF4444,
				size: 3
			});
		}

		// Delay before showing score
		haxe.Timer.delay(function() {
			if (ctx != null) ctx.lose(score, getMinigameId());
		}, 800);
	}

	function draw() {
		var shakeX = 0.0;
		var shakeY = 0.0;
		if (shakeTimer > 0) {
			shakeX = (Math.random() - 0.5) * shakeIntensity * 2;
			shakeY = (Math.random() - 0.5) * shakeIntensity * 2;
		}

		// Holder positions
		var holderLX = PLAYER_X - 90;
		var holderRX = PLAYER_X + 90;
		var holderY = ROPE_CENTER_Y;

		// --- Draw shadow under player ---
		shadowG.clear();
		var shadowScale = 1.0;
		if (playerY < GROUND_Y) {
			shadowScale = Math.max(0.3, 1.0 - (GROUND_Y - playerY) / 150);
		}
		shadowG.beginFill(0x000000, 0.2 * shadowScale);
		shadowG.drawEllipse(PLAYER_X + shakeX, GROUND_Y + 4 + shakeY, 16 * shadowScale, 4 * shadowScale);
		shadowG.endFill();

		// --- Draw rope holders (two people) ---
		holdersG.clear();
		drawHolder(holdersG, holderLX + shakeX, holderY + holderBobL + shakeY, true);
		drawHolder(holdersG, holderRX + shakeX, holderY + holderBobR + shakeY, false);

		// --- Draw rope ---
		ropeG.clear();

		// Rope is an arc that rotates. The rope endpoints are at the holders' hands.
		// The rope sags into an arc. As ropeAngle goes 0→2PI, the rope swings.
		// At angle 0 (top), rope is above player. At PI (bottom), rope is below (on ground).

		var handLX = holderLX + 12;
		var handRX = holderRX - 12;
		var handY = holderY - 20;

		// Rope visual: draw as a catenary curve that rotates in the vertical plane
		// The "depth" of the rope depends on the angle
		var ropeSegments = 20;
		var ropeSag = ROPE_RADIUS;

		// The rope rotates: at angle 0, the sag is upward; at PI, sag is downward
		var sagDir = -Math.cos(ropeAngle); // -1 at top, +1 at bottom

		// Draw rope with thickness
		ropeG.lineStyle(3, 0x8B4513);
		for (seg in 0...ropeSegments + 1) {
			var t2 = seg / ropeSegments;
			var rx = handLX + (handRX - handLX) * t2;
			// Parabolic sag
			var sag = 4 * t2 * (1 - t2); // 0 at ends, 1 at middle
			var ry = handY + sag * ropeSag * sagDir;

			// Add slight horizontal wave based on rope speed
			ry += Math.sin(t2 * Math.PI * 2 + totalTime * 8) * 2;

			rx += shakeX;
			ry += shakeY;

			if (seg == 0)
				ropeG.moveTo(rx, ry);
			else
				ropeG.lineTo(rx, ry);
		}
		ropeG.lineStyle();

		// Draw rope shadow on ground when rope is near bottom
		if (sagDir > 0.3) {
			var alpha = (sagDir - 0.3) * 0.3;
			ropeG.beginFill(0x000000, alpha);
			for (seg in 0...ropeSegments + 1) {
				var t2 = seg / ropeSegments;
				var rx = handLX + (handRX - handLX) * t2 + shakeX;
				var sag = 4 * t2 * (1 - t2);
				ropeG.drawCircle(rx, GROUND_Y + 3 + shakeY, 1.5 * sag);
			}
			ropeG.endFill();
		}

		// --- Draw player ---
		playerG.clear();
		var px = PLAYER_X + shakeX;
		var py = playerY + shakeY;

		var sw = squash; // width multiplier
		var sh = 2.0 - squash; // height multiplier (inverse)
		var hw = PLAYER_W / 2 * sw;
		var hh = PLAYER_H * sh;

		// Body
		var bodyColor = gameOver ? 0xCC3333 : 0x4488DD;
		playerG.beginFill(bodyColor);
		playerG.drawRoundedRect(px - hw, py - hh, hw * 2, hh * 0.65, 4);
		playerG.endFill();

		// Shorts
		playerG.beginFill(0x333366);
		playerG.drawRoundedRect(px - hw * 0.9, py - hh * 0.35, hw * 1.8, hh * 0.2, 2);
		playerG.endFill();

		// Legs
		var legW = hw * 0.35;
		playerG.beginFill(0xFFCBA4);
		playerG.drawRect(px - hw * 0.5 - legW / 2, py - hh * 0.15, legW, hh * 0.15);
		playerG.drawRect(px + hw * 0.5 - legW / 2, py - hh * 0.15, legW, hh * 0.15);
		playerG.endFill();

		// Shoes
		playerG.beginFill(0xDD4444);
		playerG.drawRoundedRect(px - hw * 0.5 - legW / 2 - 2, py - 4, legW + 4, 4, 2);
		playerG.drawRoundedRect(px + hw * 0.5 - legW / 2 - 2, py - 4, legW + 4, 4, 2);
		playerG.endFill();

		// Head
		var headR = hw * 0.6;
		var headY2 = py - hh - headR + 2;
		playerG.beginFill(0xFFCBA4);
		playerG.drawCircle(px, headY2, headR);
		playerG.endFill();

		// Hair
		playerG.beginFill(0x442200);
		playerG.drawCircle(px, headY2 - headR * 0.3, headR * 0.9);
		playerG.endFill();

		// Eyes
		var eyeOff = headR * 0.3;
		playerG.beginFill(0xFFFFFF);
		playerG.drawCircle(px - eyeOff, headY2, headR * 0.25);
		playerG.drawCircle(px + eyeOff, headY2, headR * 0.25);
		playerG.endFill();
		playerG.beginFill(0x222222);
		playerG.drawCircle(px - eyeOff, headY2, headR * 0.12);
		playerG.drawCircle(px + eyeOff, headY2, headR * 0.12);
		playerG.endFill();

		// Mouth - smile or :O
		if (isJumping) {
			// Open mouth (effort)
			playerG.beginFill(0xDD6666);
			playerG.drawCircle(px, headY2 + headR * 0.4, headR * 0.15);
			playerG.endFill();
		} else if (!gameOver) {
			// Smile
			playerG.lineStyle(1, 0x884444);
			var smileY = headY2 + headR * 0.35;
			playerG.moveTo(px - headR * 0.2, smileY);
			playerG.lineTo(px, smileY + 2);
			playerG.lineTo(px + headR * 0.2, smileY);
			playerG.lineStyle();
		}

		// Arms - bounce with jump
		var armAngle = isJumping ? -0.5 : 0.3 + Math.sin(totalTime * 6) * 0.15;
		var armLen = hh * 0.35;
		playerG.lineStyle(3, 0xFFCBA4);
		// Left arm
		playerG.moveTo(px - hw, py - hh * 0.55);
		playerG.lineTo(px - hw - Math.cos(armAngle) * armLen, py - hh * 0.55 + Math.sin(armAngle) * armLen);
		// Right arm
		playerG.moveTo(px + hw, py - hh * 0.55);
		playerG.lineTo(px + hw + Math.cos(armAngle) * armLen, py - hh * 0.55 + Math.sin(armAngle) * armLen);
		playerG.lineStyle();

		// --- Draw particles ---
		particleG.clear();
		for (p in particles) {
			var alpha = p.life / p.maxLife;
			particleG.beginFill(p.color, alpha);
			particleG.drawCircle(p.x + shakeX, p.y + shakeY, p.size * alpha);
			particleG.endFill();
		}

		// --- UI ---
		uiG.clear();

		// Score
		scoreText.text = Std.string(score);

		// Combo
		if (combo >= 3 && !gameOver) {
			comboText.visible = true;
			comboText.text = combo + "x COMBO!";
			comboText.alpha = 0.7 + 0.3 * Math.sin(totalTime * 8);
			if (combo >= 10) comboText.textColor = 0xFF6600;
			else if (combo >= 5) comboText.textColor = 0xFFD700;
			else comboText.textColor = 0xAADDFF;
		} else {
			comboText.visible = false;
		}

		// Speed indicator bar
		var barW = 80.0;
		var barH = 6.0;
		var barX = DESIGN_W / 2 - barW / 2;
		var barY = 30.0;
		uiG.beginFill(0x000000, 0.3);
		uiG.drawRoundedRect(barX, barY, barW, barH, 3);
		uiG.endFill();
		var fill = (ropeSpeed - ROPE_SPEED_START) / (ROPE_SPEED_MAX - ROPE_SPEED_START);
		var fillColor = fill < 0.5 ? 0x44DD44 : (fill < 0.8 ? 0xDDDD44 : 0xDD4444);
		uiG.beginFill(fillColor);
		uiG.drawRoundedRect(barX, barY, barW * fill, barH, 3);
		uiG.endFill();

		// "SPEED" label
		uiG.beginFill(0x000000, 0.0);
	}

	function drawHolder(g:Graphics, x:Float, y:Float, isLeft:Bool) {
		var dir = isLeft ? 1.0 : -1.0;

		// Body
		g.beginFill(0xDD6644);
		g.drawRoundedRect(x - 10, y - 40, 20, 30, 4);
		g.endFill();

		// Pants
		g.beginFill(0x444488);
		g.drawRoundedRect(x - 9, y - 10, 18, 14, 2);
		g.endFill();

		// Legs
		g.beginFill(0xFFCBA4);
		g.drawRect(x - 7, y + 4, 5, 10);
		g.drawRect(x + 2, y + 4, 5, 10);
		g.endFill();

		// Shoes
		g.beginFill(0x553322);
		g.drawRect(x - 8, y + 14, 7, 3);
		g.drawRect(x + 1, y + 14, 7, 3);
		g.endFill();

		// Head
		g.beginFill(0xFFCBA4);
		g.drawCircle(x, y - 48, 9);
		g.endFill();

		// Hair
		g.beginFill(isLeft ? 0x663300 : 0x222222);
		g.drawCircle(x, y - 51, 7);
		g.endFill();

		// Eyes
		g.beginFill(0x222222);
		g.drawCircle(x - 3 * dir, y - 48, 1.5);
		g.drawCircle(x + 2 * dir, y - 48, 1.5);
		g.endFill();

		// Arm holding rope (extended toward center)
		g.lineStyle(3, 0xFFCBA4);
		var handX = x + dir * 12;
		g.moveTo(x + dir * 8, y - 32);
		g.lineTo(handX, y - 20);
		g.lineStyle();
	}

	public function getMinigameId():String
		return "skip_rope";

	public function getTitle():String
		return "Skip Rope";

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
	}
}
