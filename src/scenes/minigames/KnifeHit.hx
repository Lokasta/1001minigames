package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class KnifeHit implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var BOARD_CX = 180.0;
	static var BOARD_CY = 220.0;
	static var BOARD_RADIUS = 90.0;
	static var KNIFE_START_Y = 560.0;
	static var KNIFE_TARGET_Y = 220.0; // board center Y
	static var KNIFE_SPEED = 900.0;
	static var KNIFE_LENGTH = 40.0;
	static var KNIFE_STICK_DIST = 85.0; // distance from center where knife tip sticks
	static var ROTATION_SPEED_START = 1.8; // radians/sec
	static var ROTATION_SPEED_MAX = 4.5;
	static var SPEED_RAMP_TIME = 90.0;
	static var HIT_ANGLE_THRESHOLD = 0.18; // ~10 degrees tolerance for knife-knife collision
	static var HUMANOID_ANGLE_THRESHOLD = 0.28; // ~16 degrees for humanoid (bigger target)

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var boardG:Graphics;
	var knivesG:Graphics;
	var nextKnifeG:Graphics;
	var humanoidG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var totalTime:Float;

	// Board rotation
	var boardAngle:Float;
	var rotSpeed:Float;
	var rotDir:Int; // 1 or -1, changes periodically
	var dirChangeTimer:Float;
	var dirChangeInterval:Float;

	// Stuck knives: angles relative to board
	var stuckKnives:Array<Float>;

	// Humanoid position: angle on the board
	var humanoidAngle:Float;

	// Flying knife
	var knifeFlying:Bool;
	var knifeY:Float;

	// Hit feedback
	var hitFlashTimer:Float;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		// Dark gradient-ish bg
		bg.beginFill(0x1A0A1E);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		// Spotlight effect
		bg.beginFill(0x2A1A2E, 0.5);
		bg.drawCircle(BOARD_CX, BOARD_CY, 160);
		bg.endFill();

		boardG = new Graphics(contentObj);
		humanoidG = new Graphics(contentObj);
		knivesG = new Graphics(contentObj);
		nextKnifeG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 20;
		scoreText.scale(2.5);
		scoreText.textColor = 0xFFFFFF;
		scoreText.textAlign = Center;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Tap to throw! Don't hit the person!";
		instructText.x = DESIGN_W / 2;
		instructText.y = 600;
		instructText.scale(0.9);
		instructText.textColor = 0x666688;
		instructText.textAlign = Center;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(_) {
			if (gameOver || !started) return;
			if (!knifeFlying) {
				knifeFlying = true;
				knifeY = KNIFE_START_Y;
			}
		};

		rng = new hxd.Rand(42);
		stuckKnives = [];
		score = 0;
		gameOver = false;
		started = false;
		totalTime = 0;
		boardAngle = 0;
		rotSpeed = ROTATION_SPEED_START;
		rotDir = 1;
		dirChangeTimer = 0;
		dirChangeInterval = 3.0;
		humanoidAngle = 0;
		knifeFlying = false;
		knifeY = KNIFE_START_Y;
		hitFlashTimer = 0;
	}

	public function getMinigameId():String
		return "knife_hit";

	public function getTitle():String
		return "Knife Hit";

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start() {
		score = 0;
		gameOver = false;
		started = true;
		totalTime = 0;
		boardAngle = 0;
		rotSpeed = ROTATION_SPEED_START;
		rotDir = 1;
		dirChangeTimer = 0;
		dirChangeInterval = 3.0;
		stuckKnives = [];
		knifeFlying = false;
		knifeY = KNIFE_START_Y;
		hitFlashTimer = 0;
		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);
		humanoidAngle = Math.PI * 0.5; // starts at top
		scoreText.text = "0";
	}

	public function update(dt:Float) {
		if (!started || gameOver) return;

		totalTime += dt;

		// Speed ramp
		var t = Math.min(totalTime / SPEED_RAMP_TIME, 1.0);
		rotSpeed = ROTATION_SPEED_START + (ROTATION_SPEED_MAX - ROTATION_SPEED_START) * t;

		// Direction changes (more frequent at higher scores)
		dirChangeTimer += dt;
		if (dirChangeTimer >= dirChangeInterval) {
			dirChangeTimer = 0;
			rotDir = -rotDir;
			dirChangeInterval = 2.0 + rng.random(200) / 100.0; // 2-4 seconds
		}

		// Rotate board
		boardAngle += rotSpeed * rotDir * dt;

		// Flying knife
		if (knifeFlying) {
			knifeY -= KNIFE_SPEED * dt;
			// Check if knife reached the board
			if (knifeY <= BOARD_CY + KNIFE_STICK_DIST) {
				knifeFlying = false;
				// Calculate the angle where knife hits (coming from below = angle PI/2 in world, convert to board-local)
				var hitWorldAngle = Math.PI / 2; // knife comes from below, hits at bottom of board
				var hitBoardAngle = normalizeAngle(hitWorldAngle - boardAngle);

				// Check collision with humanoid
				var humanoidWorld = normalizeAngle(humanoidAngle);
				var diffHumanoid = angleDiff(hitBoardAngle, humanoidWorld);
				if (diffHumanoid < HUMANOID_ANGLE_THRESHOLD) {
					onHitHumanoid();
					return;
				}

				// Check collision with stuck knives
				for (ka in stuckKnives) {
					var diff = angleDiff(hitBoardAngle, ka);
					if (diff < HIT_ANGLE_THRESHOLD) {
						onHitKnife();
						return;
					}
				}

				// Success - stick knife
				stuckKnives.push(hitBoardAngle);
				score++;
				scoreText.text = Std.string(score);
				hitFlashTimer = 0.1;
				if (ctx != null) ctx.feedback.flash(0xFFFFFF, 0.05);
			}
		}

		if (hitFlashTimer > 0) hitFlashTimer -= dt;

		draw();
	}

	function onHitHumanoid() {
		gameOver = true;
		if (ctx != null) {
			ctx.feedback.flash(0xFF0000, 0.3);
			ctx.feedback.shake2D(0.4, 8);
			ctx.lose(score, getMinigameId());
		}
	}

	function onHitKnife() {
		gameOver = true;
		if (ctx != null) {
			ctx.feedback.flash(0xFF8800, 0.2);
			ctx.feedback.shake2D(0.3, 6);
			ctx.lose(score, getMinigameId());
		}
	}

	function normalizeAngle(a:Float):Float {
		while (a < -Math.PI)
			a += Math.PI * 2;
		while (a > Math.PI)
			a -= Math.PI * 2;
		return a;
	}

	function angleDiff(a:Float, b:Float):Float {
		var d = Math.abs(normalizeAngle(a - b));
		return d;
	}

	function draw() {
		boardG.clear();
		knivesG.clear();
		humanoidG.clear();
		nextKnifeG.clear();

		// Draw board (wooden circle)
		// Outer ring
		boardG.beginFill(0x8B5E3C);
		boardG.drawCircle(BOARD_CX, BOARD_CY, BOARD_RADIUS);
		boardG.endFill();
		// Inner ring
		boardG.beginFill(0xA0703C);
		boardG.drawCircle(BOARD_CX, BOARD_CY, BOARD_RADIUS - 6);
		boardG.endFill();
		// Wood grain rings
		boardG.beginFill(0x8B5E3C, 0.3);
		boardG.drawCircle(BOARD_CX, BOARD_CY, BOARD_RADIUS - 20);
		boardG.endFill();
		boardG.beginFill(0x7A4E2C, 0.2);
		boardG.drawCircle(BOARD_CX, BOARD_CY, BOARD_RADIUS - 40);
		boardG.endFill();
		// Center dot
		boardG.beginFill(0x6A3E1C);
		boardG.drawCircle(BOARD_CX, BOARD_CY, 5);
		boardG.endFill();

		// Draw humanoid on the board edge
		var hAngle = humanoidAngle + boardAngle;
		var hDist = BOARD_RADIUS - 15; // slightly inside edge
		var hx = BOARD_CX + Math.cos(hAngle) * hDist;
		var hy = BOARD_CY - Math.sin(hAngle) * hDist;
		drawHumanoid(humanoidG, hx, hy, hAngle);

		// Draw stuck knives
		for (ka in stuckKnives) {
			var worldAngle = ka + boardAngle;
			// Knife tip at board edge, handle pointing outward
			var tipX = BOARD_CX + Math.cos(worldAngle) * KNIFE_STICK_DIST;
			var tipY = BOARD_CY - Math.sin(worldAngle) * KNIFE_STICK_DIST;
			var handleX = BOARD_CX + Math.cos(worldAngle) * (KNIFE_STICK_DIST + KNIFE_LENGTH);
			var handleY = BOARD_CY - Math.sin(worldAngle) * (KNIFE_STICK_DIST + KNIFE_LENGTH);
			drawKnife(knivesG, tipX, tipY, handleX, handleY);
		}

		// Draw flying knife
		if (knifeFlying) {
			drawKnife(nextKnifeG, BOARD_CX, knifeY - KNIFE_LENGTH / 2, BOARD_CX, knifeY + KNIFE_LENGTH / 2);
		} else if (!gameOver) {
			// Next knife waiting at bottom
			drawKnife(nextKnifeG, BOARD_CX, KNIFE_START_Y - KNIFE_LENGTH / 2, BOARD_CX, KNIFE_START_Y + KNIFE_LENGTH / 2);
		}
	}

	function drawKnife(g:Graphics, tipX:Float, tipY:Float, handleX:Float, handleY:Float) {
		var dx = handleX - tipX;
		var dy = handleY - tipY;
		var len = Math.sqrt(dx * dx + dy * dy);
		if (len < 0.01) return;
		var nx = -dy / len;
		var ny = dx / len;

		// Blade (narrow triangle from tip to mid)
		var midX = tipX + dx * 0.5;
		var midY = tipY + dy * 0.5;
		var bladeW = 3.0;
		g.beginFill(0xCCCCDD);
		g.moveTo(tipX, tipY);
		g.lineTo(midX + nx * bladeW, midY + ny * bladeW);
		g.lineTo(midX - nx * bladeW, midY - ny * bladeW);
		g.endFill();
		// Blade highlight
		g.beginFill(0xEEEEFF, 0.5);
		g.moveTo(tipX, tipY);
		g.lineTo(midX + nx * 1, midY + ny * 1);
		g.lineTo(midX - nx * bladeW, midY - ny * bladeW);
		g.endFill();

		// Handle (rectangle from mid to handle end)
		var handleW = 4.0;
		g.beginFill(0x5A3520);
		g.moveTo(midX + nx * handleW, midY + ny * handleW);
		g.lineTo(handleX + nx * handleW, handleY + ny * handleW);
		g.lineTo(handleX - nx * handleW, handleY - ny * handleW);
		g.lineTo(midX - nx * handleW, midY - ny * handleW);
		g.endFill();
		// Handle accent
		g.beginFill(0x7A4E2C);
		var guardX = midX + dx * 0.05;
		var guardY = midY + dy * 0.05;
		g.moveTo(guardX + nx * 5, guardY + ny * 5);
		g.lineTo(guardX - nx * 5, guardY - ny * 5);
		g.lineTo(guardX - nx * 5 + dx * 0.05, guardY - ny * 5 + dy * 0.05);
		g.lineTo(guardX + nx * 5 + dx * 0.05, guardY + ny * 5 + dy * 0.05);
		g.endFill();
	}

	function drawHumanoid(g:Graphics, cx:Float, cy:Float, angle:Float) {
		// Simplified humanoid figure facing outward from board center
		// Angle determines rotation of the figure
		var cosA = Math.cos(angle);
		var sinA = -Math.sin(angle); // negate because Y is down

		// Helper: rotate point around (cx, cy)
		inline function rx(lx:Float, ly:Float):Float
			return cx + lx * sinA + ly * cosA;
		inline function ry(lx:Float, ly:Float):Float
			return cy + lx * cosA - ly * sinA;

		// Body color (skin tone)
		var skin = 0xFFCC99;
		var shirt = 0xDD4444;
		var pants = 0x3344AA;
		var hair = 0x442200;

		// Head
		g.beginFill(skin);
		g.drawCircle(rx(0, -2), ry(0, -2), 6);
		g.endFill();
		// Hair
		g.beginFill(hair);
		g.drawCircle(rx(0, -5), ry(0, -5), 5);
		g.endFill();
		// Eyes (two dots)
		g.beginFill(0x000000);
		g.drawCircle(rx(-2, -1), ry(-2, -1), 1);
		g.drawCircle(rx(2, -1), ry(2, -1), 1);
		g.endFill();
		// Mouth (surprised O)
		g.beginFill(0x000000);
		g.drawCircle(rx(0, 1.5), ry(0, 1.5), 1.5);
		g.endFill();

		// Body / shirt
		g.beginFill(shirt);
		g.moveTo(rx(-5, 3), ry(-5, 3));
		g.lineTo(rx(5, 3), ry(5, 3));
		g.lineTo(rx(4, 14), ry(4, 14));
		g.lineTo(rx(-4, 14), ry(-4, 14));
		g.endFill();

		// Arms spread out (tied to board)
		g.beginFill(skin);
		// Left arm
		g.moveTo(rx(-5, 4), ry(-5, 4));
		g.lineTo(rx(-16, 2), ry(-16, 2));
		g.lineTo(rx(-16, 5), ry(-16, 5));
		g.lineTo(rx(-5, 7), ry(-5, 7));
		g.endFill();
		// Right arm
		g.moveTo(rx(5, 4), ry(5, 4));
		g.lineTo(rx(16, 2), ry(16, 2));
		g.lineTo(rx(16, 5), ry(16, 5));
		g.lineTo(rx(5, 7), ry(5, 7));
		g.endFill();

		// Hands
		g.beginFill(skin);
		g.drawCircle(rx(-16, 3.5), ry(-16, 3.5), 3);
		g.drawCircle(rx(16, 3.5), ry(16, 3.5), 3);
		g.endFill();

		// Pants / legs
		g.beginFill(pants);
		// Left leg
		g.moveTo(rx(-4, 14), ry(-4, 14));
		g.lineTo(rx(-3, 24), ry(-3, 24));
		g.lineTo(rx(0, 24), ry(0, 24));
		g.lineTo(rx(0, 14), ry(0, 14));
		g.endFill();
		// Right leg
		g.moveTo(rx(0, 14), ry(0, 14));
		g.lineTo(rx(0, 24), ry(0, 24));
		g.lineTo(rx(3, 24), ry(3, 24));
		g.lineTo(rx(4, 14), ry(4, 14));
		g.endFill();

		// Shoes
		g.beginFill(0x222222);
		g.drawCircle(rx(-1.5, 25), ry(-1.5, 25), 3);
		g.drawCircle(rx(1.5, 25), ry(1.5, 25), 3);
		g.endFill();
	}

	public function dispose() {
		if (interactive != null) interactive.remove();
		if (boardG != null) boardG.remove();
		if (knivesG != null) knivesG.remove();
		if (nextKnifeG != null) nextKnifeG.remove();
		if (humanoidG != null) humanoidG.remove();
		if (scoreText != null) scoreText.remove();
		if (instructText != null) instructText.remove();
		if (bg != null) bg.remove();
		contentObj.removeChildren();
	}
}
