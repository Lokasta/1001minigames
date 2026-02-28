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
	Golf Putt — mini golfe em 1 tacada.
	Arraste para mirar (seta de potência), solte para lançar.
	Bola com física 2D (fricção, colisão com paredes e obstáculos).
	Acerte o buraco em 1 tacada = máximo de pontos. Múltiplos holes progressivos.
**/
class GolfPutt implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var BALL_RADIUS = 7.0;
	static var HOLE_RADIUS = 12.0;
	// Subtask 1: Tuned physics constants
	static var MAX_POWER = 400.0;
	static var DRAG_SCALE = 2.0;
	static var FRICTION = 0.985;
	static var WALL_BOUNCE = 0.7;
	static var STOP_THRESHOLD = 5.0;
	static var SINK_SPEED_MAX = 280.0;
	static var MIN_DRAG = 15.0;

	// Course area
	static var COURSE_LEFT = 20;
	static var COURSE_RIGHT = 340;
	static var COURSE_TOP = 130;
	static var COURSE_BOTTOM = 570;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var courseG:Graphics;
	var ballG:Graphics;
	var aimG:Graphics;
	var obstacleG:Graphics;
	var uiG:Graphics;
	var confettiG:Graphics;
	var interactive:Interactive;

	var titleText:Text;
	var scoreText:Text;
	var holeText:Text;
	var strokeText:Text;
	var hintText:Text;
	var resultText:Text;
	var strokeLabel:Text;
	var powerText:Text;

	// Ball physics
	var ballX:Float;
	var ballY:Float;
	var ballVX:Float;
	var ballVY:Float;
	var ballMoving:Bool;

	// Hole
	var holeX:Float;
	var holeY:Float;

	// Obstacles (rectangles)
	var walls:Array<Wall>;

	// Drag/aim state
	var dragging:Bool;
	var dragStartX:Float;
	var dragStartY:Float;
	var dragCurrentX:Float;
	var dragCurrentY:Float;

	// Game state
	var gameOver:Bool;
	var score:Int;
	var hole:Int;
	var strokes:Int;
	var maxStrokes:Int;
	var ballSunk:Bool;
	var sinkAnimTimer:Float;
	var nextHoleTimer:Float;
	var totalTime:Float;
	var gameOverTimer:Float;

	// Trail
	var trail:Array<{x:Float, y:Float, age:Float}>;

	// Ball shadow/glow animation
	var ballPulse:Float;

	// Subtask 7: Ball roll angle
	var ballRollAngle:Float;

	// Subtask 9: Confetti particles
	var confetti:Array<{x:Float, y:Float, vx:Float, vy:Float, color:Int, life:Float, size:Float}>;

	// Subtask 10: Flag wave timer
	var flagWaveTimer:Float;

	// Subtask 10: Result text scale bounce
	var resultBounceTimer:Float;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		bg = new Graphics(contentObj);
		courseG = new Graphics(contentObj);
		obstacleG = new Graphics(contentObj);
		ballG = new Graphics(contentObj);
		aimG = new Graphics(contentObj);
		uiG = new Graphics(contentObj);
		confettiG = new Graphics(contentObj);

		// UI texts
		titleText = new Text(hxd.res.DefaultFont.get(), contentObj);
		titleText.text = "GOLF PUTT";
		titleText.textAlign = Center;
		titleText.x = DESIGN_W / 2;
		titleText.y = 12;
		titleText.scale(1.8);
		titleText.textColor = 0xFFFFFF;

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 45;
		scoreText.scale(2.2);
		scoreText.textColor = 0xFFDD44;

		holeText = new Text(hxd.res.DefaultFont.get(), contentObj);
		holeText.text = "Hole 1";
		holeText.textAlign = Left;
		holeText.x = 20;
		holeText.y = 80;
		holeText.textColor = 0x9BA4C4;

		strokeText = new Text(hxd.res.DefaultFont.get(), contentObj);
		strokeText.text = "";
		strokeText.textAlign = Right;
		strokeText.x = DESIGN_W - 20;
		strokeText.y = 80;
		strokeText.textColor = 0x9BA4C4;

		// Subtask 12: STROKES label
		strokeLabel = new Text(hxd.res.DefaultFont.get(), contentObj);
		strokeLabel.text = "STROKES";
		strokeLabel.textAlign = Left;
		strokeLabel.x = 20;
		strokeLabel.y = 100;
		strokeLabel.textColor = 0x667788;

		hintText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hintText.text = "Drag to aim, release to putt!";
		hintText.textAlign = Center;
		hintText.x = DESIGN_W / 2;
		hintText.y = DESIGN_H - 35;
		hintText.textColor = 0x667788;

		// Subtask 11: Power percentage text
		powerText = new Text(hxd.res.DefaultFont.get(), contentObj);
		powerText.text = "";
		powerText.textAlign = Center;
		powerText.x = DESIGN_W / 2;
		powerText.y = 580;
		powerText.textColor = 0xCCCCCC;
		powerText.alpha = 0;

		resultText = new Text(hxd.res.DefaultFont.get(), contentObj);
		resultText.text = "";
		resultText.textAlign = Center;
		resultText.x = DESIGN_W / 2;
		resultText.y = DESIGN_H * 0.35;
		resultText.scale(2.0);
		resultText.textColor = 0x44DD66;
		resultText.alpha = 0;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = onPush;
		interactive.onMove = onMove;
		interactive.onRelease = onRelease;
		interactive.onReleaseOutside = onRelease;

		walls = [];
		trail = [];
		confetti = [];

		gameOver = false;
		score = 0;
		hole = 0;
		strokes = 0;
		maxStrokes = 3;
		ballMoving = false;
		dragging = false;
		ballSunk = false;
		sinkAnimTimer = 0;
		nextHoleTimer = 0;
		totalTime = 0;
		ballPulse = 0;
		gameOverTimer = 0;
		ballRollAngle = 0;
		flagWaveTimer = 0;
		resultBounceTimer = 0;

		ballX = 0;
		ballY = 0;
		ballVX = 0;
		ballVY = 0;
		holeX = 0;
		holeY = 0;
		dragStartX = 0;
		dragStartY = 0;
		dragCurrentX = 0;
		dragCurrentY = 0;

		drawBackground();
	}

	function drawBackground():Void {
		bg.clear();
		var steps = 16;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(6 + t * 8);
			var g = Std.int(12 + t * 16);
			var b = Std.int(20 + t * 18);
			var color = (r << 16) | (g << 8) | b;
			var yStart = Std.int(DESIGN_H * t);
			var yEnd = Std.int(DESIGN_H * (t + 1.0 / steps)) + 1;
			bg.beginFill(color);
			bg.drawRect(0, yStart, DESIGN_W, yEnd - yStart);
			bg.endFill();
		}
	}

	function setupHole(holeNum:Int):Void {
		hole = holeNum;
		strokes = 0;
		ballSunk = false;
		ballMoving = false;
		dragging = false;
		sinkAnimTimer = 0;
		nextHoleTimer = 0;
		trail = [];
		walls = [];
		resultText.alpha = 0;
		// Subtask 13: Reset new state
		confetti = [];
		flagWaveTimer = 0;
		ballRollAngle = 0;
		resultBounceTimer = 0;

		maxStrokes = holeNum < 3 ? 3 : (holeNum < 6 ? 2 : 1);

		// Ball start position
		ballX = DESIGN_W / 2.0;
		ballY = COURSE_BOTTOM - 40.0;
		ballVX = 0;
		ballVY = 0;

		// Hole position
		var marginX = 60.0;
		var marginY = 40.0;
		holeX = marginX + rng.random(Std.int(COURSE_RIGHT - COURSE_LEFT - marginX * 2));
		holeX += COURSE_LEFT;
		holeY = COURSE_TOP + marginY + rng.random(Std.int((COURSE_BOTTOM - COURSE_TOP) * 0.35));

		// Subtask 4: Ensure minimum distance of 150px
		var dx = ballX - holeX;
		var dy = ballY - holeY;
		var dist = Math.sqrt(dx * dx + dy * dy);
		if (dist < 150) {
			holeY = ballY - 150;
			if (holeY < COURSE_TOP + marginY) holeY = COURSE_TOP + marginY;
		}

		generateObstacles(holeNum);
		updateStrokeDisplay();
	}

	function generateObstacles(holeNum:Int):Void {
		walls = [];
		if (holeNum == 0) return;

		var cw = COURSE_RIGHT - COURSE_LEFT;
		var ch = COURSE_BOTTOM - COURSE_TOP;
		var midX = (COURSE_LEFT + COURSE_RIGHT) / 2.0;
		var midY = (COURSE_TOP + COURSE_BOTTOM) / 2.0;

		if (holeNum == 1) {
			walls.push({x: midX - 60, y: midY, w: 120, h: 8});
		} else if (holeNum == 2) {
			walls.push({x: COURSE_LEFT, y: midY - 30, w: cw * 0.45, h: 8});
			walls.push({x: midX + 20, y: midY + 30, w: cw * 0.45, h: 8});
		} else if (holeNum == 3) {
			walls.push({x: midX - 50, y: midY - 40, w: 8, h: 80});
			walls.push({x: midX - 50, y: midY + 32, w: 70, h: 8});
		} else if (holeNum == 4) {
			walls.push({x: midX - 50, y: midY - 60, w: 8, h: 60});
			walls.push({x: midX + 42, y: midY, w: 8, h: 60});
		} else {
			// Subtask 4: Cap at 4 walls, add viable-path check
			var numWalls = 2 + Std.int(holeNum / 3);
			if (numWalls > 4) numWalls = 4;

			var attempts = 0;
			while (attempts < 3) {
				walls = [];
				for (i in 0...numWalls) {
					var horizontal = rng.random(2) == 0;
					var wx:Float, wy:Float, ww:Float, wh:Float;
					if (horizontal) {
						ww = 40 + rng.random(80);
						wh = 8;
						wx = COURSE_LEFT + 30 + rng.random(Std.int(cw - ww - 60));
						wy = COURSE_TOP + 50 + rng.random(Std.int(ch - 100));
					} else {
						ww = 8;
						wh = 40 + rng.random(70);
						wx = COURSE_LEFT + 30 + rng.random(Std.int(cw - 60));
						wy = COURSE_TOP + 50 + rng.random(Std.int(ch - wh - 100));
					}
					var distBall = Math.sqrt((wx - ballX) * (wx - ballX) + (wy - ballY) * (wy - ballY));
					var distHole = Math.sqrt((wx - holeX) * (wx - holeX) + (wy - holeY) * (wy - holeY));
					if (distBall > 50 && distHole > 50) {
						walls.push({x: wx, y: wy, w: ww, h: wh});
					}
				}
				if (hasViablePath()) break;
				attempts++;
			}
		}
	}

	// Subtask 4: Check that walls don't completely block the path
	function hasViablePath():Bool {
		var testPoints = 5;
		var passCount = 0;
		for (t in 0...testPoints) {
			var testX = COURSE_LEFT + 20 + (COURSE_RIGHT - COURSE_LEFT - 40) * t / (testPoints - 1);
			var blocked = false;
			for (w in walls) {
				if (testX >= w.x && testX <= w.x + w.w) {
					// Check if wall spans a Y range between ball and hole
					var minY = Math.min(ballY, holeY);
					var maxY = Math.max(ballY, holeY);
					if (w.y < maxY && w.y + w.h > minY) {
						blocked = true;
						break;
					}
				}
			}
			if (!blocked) passCount++;
		}
		return passCount >= 2;
	}

	function updateStrokeDisplay():Void {
		strokeText.text = strokes + " / " + maxStrokes;
		holeText.text = "Hole " + (hole + 1);
	}

	function onPush(e:Event):Void {
		if (gameOver || ballMoving || ballSunk) return;
		dragging = true;
		dragStartX = e.relX;
		dragStartY = e.relY;
		dragCurrentX = e.relX;
		dragCurrentY = e.relY;
	}

	function onMove(e:Event):Void {
		if (!dragging) return;
		dragCurrentX = e.relX;
		dragCurrentY = e.relY;
	}

	function onRelease(e:Event):Void {
		if (!dragging) return;
		dragging = false;

		var dx = dragStartX - dragCurrentX;
		var dy = dragStartY - dragCurrentY;
		var dist = Math.sqrt(dx * dx + dy * dy);

		// Subtask 1: Increased min drag from 10 to 15
		if (dist < MIN_DRAG) return;

		var power = Math.min(dist * DRAG_SCALE, MAX_POWER);
		var nx = dx / dist;
		var ny = dy / dist;

		ballVX = nx * power;
		ballVY = ny * power;
		ballMoving = true;
		strokes++;
		updateStrokeDisplay();
		hintText.alpha = 0;
		powerText.alpha = 0;
	}

	function drawCourse():Void {
		courseG.clear();

		// Outer border
		courseG.beginFill(0x0A2810, 0.9);
		courseG.drawRect(COURSE_LEFT - 4, COURSE_TOP - 4, COURSE_RIGHT - COURSE_LEFT + 8, COURSE_BOTTOM - COURSE_TOP + 8);
		courseG.endFill();

		// Subtask 5: Gradient green - darker edges to lighter center (3 layers)
		courseG.beginFill(0x164D1A);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, COURSE_RIGHT - COURSE_LEFT, COURSE_BOTTOM - COURSE_TOP);
		courseG.endFill();

		// Mid layer - slightly lighter
		var inset1 = 15;
		courseG.beginFill(0x1B5E20, 0.8);
		courseG.drawRect(COURSE_LEFT + inset1, COURSE_TOP + inset1, COURSE_RIGHT - COURSE_LEFT - inset1 * 2, COURSE_BOTTOM - COURSE_TOP - inset1 * 2);
		courseG.endFill();

		// Center layer - lightest
		var inset2 = 40;
		courseG.beginFill(0x1F6D25, 0.5);
		courseG.drawRect(COURSE_LEFT + inset2, COURSE_TOP + inset2, COURSE_RIGHT - COURSE_LEFT - inset2 * 2, COURSE_BOTTOM - COURSE_TOP - inset2 * 2);
		courseG.endFill();

		// Lighter green stripes
		var stripeW = 40;
		var sx = COURSE_LEFT;
		var stripe = false;
		while (sx < COURSE_RIGHT) {
			if (stripe) {
				courseG.beginFill(0x2E7D32, 0.2);
				var w = Math.min(stripeW, COURSE_RIGHT - sx);
				courseG.drawRect(sx, COURSE_TOP, w, COURSE_BOTTOM - COURSE_TOP);
				courseG.endFill();
			}
			sx += stripeW;
			stripe = !stripe;
		}

		// Subtask 5: Texture dots (grass grain)
		var dotSpacing = 20;
		var gx = COURSE_LEFT + 10;
		while (gx < COURSE_RIGHT - 10) {
			var gy = COURSE_TOP + 10;
			while (gy < COURSE_BOTTOM - 10) {
				courseG.beginFill(0x0A3A0E, 0.08);
				courseG.drawCircle(gx, gy, 1);
				courseG.endFill();
				gy += dotSpacing;
			}
			gx += dotSpacing;
		}

		// Subtask 5: Fringe border (rough grass edge)
		var fringeW = 3.0;
		courseG.beginFill(0x2E7D32, 0.4);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, COURSE_RIGHT - COURSE_LEFT, fringeW);
		courseG.endFill();
		courseG.beginFill(0x2E7D32, 0.4);
		courseG.drawRect(COURSE_LEFT, COURSE_BOTTOM - fringeW, COURSE_RIGHT - COURSE_LEFT, fringeW);
		courseG.endFill();
		courseG.beginFill(0x2E7D32, 0.4);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, fringeW, COURSE_BOTTOM - COURSE_TOP);
		courseG.endFill();
		courseG.beginFill(0x2E7D32, 0.4);
		courseG.drawRect(COURSE_RIGHT - fringeW, COURSE_TOP, fringeW, COURSE_BOTTOM - COURSE_TOP);
		courseG.endFill();

		// Edge shadow (inner)
		courseG.beginFill(0x000000, 0.15);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, COURSE_RIGHT - COURSE_LEFT, 6);
		courseG.endFill();
		courseG.beginFill(0x000000, 0.1);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, 4, COURSE_BOTTOM - COURSE_TOP);
		courseG.endFill();
		courseG.beginFill(0x000000, 0.1);
		courseG.drawRect(COURSE_RIGHT - 4, COURSE_TOP, 4, COURSE_BOTTOM - COURSE_TOP);
		courseG.endFill();

		// Border frame
		courseG.lineStyle(2, 0x3E2723, 0.8);
		courseG.drawRect(COURSE_LEFT, COURSE_TOP, COURSE_RIGHT - COURSE_LEFT, COURSE_BOTTOM - COURSE_TOP);
		courseG.lineStyle();

		// Corner dots
		var dotR = 3.0;
		var corners = [
			{x: COURSE_LEFT + 8.0, y: COURSE_TOP + 8.0},
			{x: COURSE_RIGHT - 8.0, y: COURSE_TOP + 8.0},
			{x: COURSE_LEFT + 8.0, y: COURSE_BOTTOM - 8.0},
			{x: COURSE_RIGHT - 8.0, y: COURSE_BOTTOM - 8.0},
		];
		for (c in corners) {
			courseG.beginFill(0x5D4037, 0.8);
			courseG.drawCircle(c.x, c.y, dotR);
			courseG.endFill();
		}
	}

	// Subtask 6: Improved obstacle visuals with rounded look and better shading
	function drawObstacles():Void {
		obstacleG.clear();
		for (w in walls) {
			var cornerR = 3.0;

			// Shadow (offset)
			obstacleG.beginFill(0x000000, 0.3);
			obstacleG.drawRect(w.x + 2, w.y + 2, w.w, w.h);
			obstacleG.endFill();

			// Main body
			obstacleG.beginFill(0x5D4037);
			obstacleG.drawRect(w.x, w.y, w.w, w.h);
			obstacleG.endFill();

			// Rounded corners (circle caps)
			obstacleG.beginFill(0x5D4037);
			obstacleG.drawCircle(w.x + cornerR, w.y + cornerR, cornerR);
			obstacleG.drawCircle(w.x + w.w - cornerR, w.y + cornerR, cornerR);
			obstacleG.drawCircle(w.x + cornerR, w.y + w.h - cornerR, cornerR);
			obstacleG.drawCircle(w.x + w.w - cornerR, w.y + w.h - cornerR, cornerR);
			obstacleG.endFill();

			// Top highlight (lighter brown)
			obstacleG.beginFill(0xA1887F, 0.6);
			obstacleG.drawRect(w.x, w.y, w.w, 2);
			obstacleG.endFill();

			// Bottom shadow (darker)
			obstacleG.beginFill(0x3E2723, 0.5);
			obstacleG.drawRect(w.x, w.y + w.h - 2, w.w, 2);
			obstacleG.endFill();
		}
	}

	function drawHole():Void {
		// Hole shadow ring
		courseG.beginFill(0x000000, 0.4);
		courseG.drawCircle(holeX, holeY, HOLE_RADIUS + 3);
		courseG.endFill();
		// Hole dark
		courseG.beginFill(0x0A0A0A);
		courseG.drawCircle(holeX, holeY, HOLE_RADIUS);
		courseG.endFill();
		// Inner ring
		courseG.beginFill(0x1A1A1A, 0.8);
		courseG.drawCircle(holeX, holeY, HOLE_RADIUS - 2);
		courseG.endFill();

		// Flag pole
		var flagX = holeX + 2;
		var flagBottom = holeY;
		var flagTop = holeY - 30;
		courseG.lineStyle(1.5, 0xCCCCCC, 0.9);
		courseG.moveTo(flagX, flagBottom);
		courseG.lineTo(flagX, flagTop);
		courseG.lineStyle();

		// Subtask 10: Flag wave animation
		var waveOffset = 0.0;
		if (flagWaveTimer > 0) {
			waveOffset = Math.sin(flagWaveTimer * 12) * 4;
		}

		// Flag triangle
		courseG.beginFill(0xFF3333);
		courseG.moveTo(flagX, flagTop);
		courseG.lineTo(flagX + 14 + waveOffset, flagTop + 5);
		courseG.lineTo(flagX, flagTop + 10);
		courseG.lineTo(flagX, flagTop);
		courseG.endFill();
	}

	function drawBall(dt:Float):Void {
		ballG.clear();
		if (ballSunk && sinkAnimTimer > 0.5) return;

		ballPulse += dt * 3.0;
		var pulse = Math.sin(ballPulse) * 0.5 + 0.5;

		var bx = ballX;
		var by = ballY;

		// Sink animation: ball shrinks into hole
		var scale = 1.0;
		if (ballSunk) {
			scale = Math.max(0, 1.0 - sinkAnimTimer * 2.0);
			bx = bx + (holeX - bx) * sinkAnimTimer * 2.0;
			by = by + (holeY - by) * sinkAnimTimer * 2.0;
		}

		var r = BALL_RADIUS * scale;
		if (r < 0.5) return;

		// Shadow
		ballG.beginFill(0x000000, 0.25);
		ballG.drawCircle(bx + 2, by + 2, r);
		ballG.endFill();

		// Ball body
		ballG.beginFill(0xF5F5F5);
		ballG.drawCircle(bx, by, r);
		ballG.endFill();

		// Highlight
		ballG.beginFill(0xFFFFFF, 0.8);
		ballG.drawCircle(bx - r * 0.25, by - r * 0.3, r * 0.4);
		ballG.endFill();

		// Subtask 7: Ball roll dimple
		var speed = Math.sqrt(ballVX * ballVX + ballVY * ballVY);
		if (speed > STOP_THRESHOLD && !ballSunk) {
			var dimpleX = bx + Math.cos(ballRollAngle) * r * 0.4;
			var dimpleY = by + Math.sin(ballRollAngle) * r * 0.4;
			ballG.beginFill(0xCCCCCC, 0.6);
			ballG.drawCircle(dimpleX, dimpleY, r * 0.2);
			ballG.endFill();
		}

		// Aiming glow when not moving
		if (!ballMoving && !ballSunk && !gameOver) {
			var glowAlpha = 0.15 + 0.1 * pulse;
			ballG.beginFill(0xFFDD44, glowAlpha);
			ballG.drawCircle(bx, by, r + 4 + pulse * 2);
			ballG.endFill();
		}
	}

	function drawAimLine():Void {
		aimG.clear();
		if (!dragging) {
			powerText.alpha = 0;
			return;
		}

		var dx = dragStartX - dragCurrentX;
		var dy = dragStartY - dragCurrentY;
		var dist = Math.sqrt(dx * dx + dy * dy);
		if (dist < MIN_DRAG) {
			powerText.alpha = 0;
			return;
		}

		var power = Math.min(dist * DRAG_SCALE, MAX_POWER);
		var powerRatio = power / MAX_POWER;
		var nx = dx / dist;
		var ny = dy / dist;

		// Subtask 3: Anchor ring on ball (pulsing)
		var anchorPulse = Math.sin(totalTime * 8) * 0.3 + 0.7;
		aimG.lineStyle(1.5, 0xFFDD44, 0.5 * anchorPulse);
		aimG.drawCircle(ballX, ballY, BALL_RADIUS + 6);
		aimG.lineStyle();

		// Subtask 3: Pull-back line (faint line from drag point to ball)
		aimG.lineStyle(1, 0xFFFFFF, 0.15);
		aimG.moveTo(dragCurrentX, dragCurrentY);
		aimG.lineTo(ballX, ballY);
		aimG.lineStyle();

		// Direction line (dotted)
		var lineLen = 30 + powerRatio * 80;
		var numDots = Std.int(lineLen / 8);
		for (i in 0...numDots) {
			var t = i / numDots;
			var px = ballX + nx * t * lineLen;
			var py = ballY + ny * t * lineLen;
			var dotAlpha = (1.0 - t) * 0.7;
			aimG.beginFill(0xFFFFFF, dotAlpha);
			aimG.drawCircle(px, py, 1.5);
			aimG.endFill();
		}

		// Power indicator (arrow head)
		var tipX = ballX + nx * lineLen;
		var tipY = ballY + ny * lineLen;
		var arrowSize = 5 + powerRatio * 4;
		var perpX = -ny;
		var perpY = nx;

		aimG.beginFill(powerColor(powerRatio), 0.8);
		aimG.moveTo(tipX, tipY);
		aimG.lineTo(tipX - nx * arrowSize * 2 + perpX * arrowSize, tipY - ny * arrowSize * 2 + perpY * arrowSize);
		aimG.lineTo(tipX - nx * arrowSize * 2 - perpX * arrowSize, tipY - ny * arrowSize * 2 - perpY * arrowSize);
		aimG.lineTo(tipX, tipY);
		aimG.endFill();

		// Subtask 11: Power bar at bottom of screen
		var barW = 200.0;
		var barH = 8.0;
		var barX = (DESIGN_W - barW) / 2;
		var barY2 = 585.0;

		// Background panel
		aimG.beginFill(0x000000, 0.5);
		aimG.drawRect(barX - 4, barY2 - 3, barW + 8, barH + 6);
		aimG.endFill();

		// Bar background
		aimG.beginFill(0x222222, 0.8);
		aimG.drawRect(barX, barY2, barW, barH);
		aimG.endFill();

		// Bar fill
		aimG.beginFill(powerColor(powerRatio), 0.9);
		aimG.drawRect(barX, barY2, barW * powerRatio, barH);
		aimG.endFill();

		// Subtask 11: Power percentage text
		var pct = Std.int(powerRatio * 100);
		powerText.text = pct + "%";
		powerText.alpha = 0.8;
	}

	function powerColor(ratio:Float):Int {
		if (ratio < 0.3) return 0x44DD66;
		if (ratio < 0.7) return 0xFFDD44;
		return 0xFF4444;
	}

	// Subtask 8: Improved trail with larger dots, longer lifetime, gradient sizing
	function drawTrail():Void {
		for (t in trail) {
			var lifeRatio = t.age / 0.6;
			var alpha = Math.max(0, 1.0 - lifeRatio) * 0.4;
			if (alpha > 0) {
				var size = BALL_RADIUS * 0.5 * (1.0 - lifeRatio);
				if (size > 0) {
					ballG.beginFill(0xFFFFFF, alpha);
					ballG.drawCircle(t.x, t.y, size);
					ballG.endFill();
				}
			}
		}
	}

	// Subtask 12: Improved stroke display with larger dots, label, background panel
	function drawUI():Void {
		uiG.clear();

		var barY = 105;
		var remaining = maxStrokes - strokes;

		// Background panel behind stroke info
		var panelW = maxStrokes * 20 + 70;
		uiG.beginFill(0x000000, 0.3);
		uiG.drawRect(14, barY - 6, panelW, 24);
		uiG.endFill();

		// Stroke dots (larger, radius 7)
		for (i in 0...maxStrokes) {
			var dotX = 22 + i * 20;
			var dotColor = i < remaining ? 0xFFDD44 : 0x333355;
			uiG.beginFill(dotColor, 0.9);
			uiG.drawCircle(dotX, barY + 5, 7);
			uiG.endFill();
			// Inner ring for used strokes
			if (i >= remaining) {
				uiG.lineStyle(1, 0x555577, 0.4);
				uiG.drawCircle(dotX, barY + 5, 7);
				uiG.lineStyle();
			}
		}

		// STROKES label position update
		strokeLabel.x = 22 + maxStrokes * 20 + 5;
		strokeLabel.y = barY - 2;
	}

	// Subtask 9: Spawn confetti particles
	function spawnConfetti(cx:Float, cy:Float, count:Int, intensity:Float):Void {
		var colors = [0xFFDD44, 0xFFFFFF, 0x44DD66, 0xFF3333];
		for (i in 0...count) {
			var angle = (rng.random(360)) * Math.PI / 180;
			var speed = (80 + rng.random(120)) * intensity;
			confetti.push({
				x: cx,
				y: cy,
				vx: Math.cos(angle) * speed,
				vy: -Math.abs(Math.sin(angle) * speed) - 50 * intensity,
				color: colors[rng.random(colors.length)],
				life: 1.0,
				size: 2 + rng.random(3)
			});
		}
	}

	// Subtask 9: Draw confetti particles
	function drawConfetti():Void {
		confettiG.clear();
		for (p in confetti) {
			if (p.life > 0) {
				confettiG.beginFill(p.color, p.life * 0.8);
				confettiG.drawRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
				confettiG.endFill();
			}
		}
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		gameOver = false;
		gameOverTimer = 0;
		score = 0;
		hole = 0;
		totalTime = 0;
		ballPulse = 0;
		ballRollAngle = 0;
		flagWaveTimer = 0;
		resultBounceTimer = 0;
		confetti = [];
		hintText.alpha = 1.0;
		powerText.alpha = 0;
		setupHole(0);
	}

	public function update(dt:Float):Void {
		if (ctx == null) return;
		totalTime += dt;

		// Ball physics
		if (ballMoving && !ballSunk) {
			trail.push({x: ballX, y: ballY, age: 0});

			ballX += ballVX * dt;
			ballY += ballVY * dt;

			// Friction
			ballVX *= Math.pow(FRICTION, dt * 60);
			ballVY *= Math.pow(FRICTION, dt * 60);

			// Wall collisions (course boundaries)
			if (ballX - BALL_RADIUS < COURSE_LEFT) {
				ballX = COURSE_LEFT + BALL_RADIUS;
				ballVX = Math.abs(ballVX) * WALL_BOUNCE;
			}
			if (ballX + BALL_RADIUS > COURSE_RIGHT) {
				ballX = COURSE_RIGHT - BALL_RADIUS;
				ballVX = -Math.abs(ballVX) * WALL_BOUNCE;
			}
			if (ballY - BALL_RADIUS < COURSE_TOP) {
				ballY = COURSE_TOP + BALL_RADIUS;
				ballVY = Math.abs(ballVY) * WALL_BOUNCE;
			}
			if (ballY + BALL_RADIUS > COURSE_BOTTOM) {
				ballY = COURSE_BOTTOM - BALL_RADIUS;
				ballVY = -Math.abs(ballVY) * WALL_BOUNCE;
			}

			// Obstacle collisions
			for (w in walls) {
				collideWall(w);
			}

			// Subtask 2: Hole gravity lip effect
			var hdx = holeX - ballX;
			var hdy = holeY - ballY;
			var distToHole = Math.sqrt(hdx * hdx + hdy * hdy);
			var speed = Math.sqrt(ballVX * ballVX + ballVY * ballVY);

			if (distToHole < HOLE_RADIUS * 2 && speed < 100 && distToHole > 0) {
				var pullStrength = 40.0;
				var ndx = hdx / distToHole;
				var ndy = hdy / distToHole;
				ballVX += ndx * pullStrength * dt;
				ballVY += ndy * pullStrength * dt;
			}

			// Subtask 7: Update ball roll angle
			if (speed > STOP_THRESHOLD) {
				ballRollAngle += speed * dt * 0.05;
			}

			// Check if ball is in the hole
			var dx = ballX - holeX;
			var dy = ballY - holeY;
			distToHole = Math.sqrt(dx * dx + dy * dy);
			speed = Math.sqrt(ballVX * ballVX + ballVY * ballVY);

			if (distToHole < HOLE_RADIUS - BALL_RADIUS * 0.3 && speed < SINK_SPEED_MAX) {
				// Ball sinks!
				ballSunk = true;
				ballMoving = false;
				sinkAnimTimer = 0;
				var holeScore = strokes == 1 ? 100 : (strokes == 2 ? 50 : 25);
				score += holeScore;

				// Subtask 10: Enhanced sink feedback
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.flash(0xFFDD44, 0.2);
					if (strokes == 1) {
						// Hole-in-one: bigger effects
						spawnConfetti(holeX, holeY, 25, 1.5);
						ctx.feedback.shake2D(0.3, 5);
						ctx.feedback.zoom2D(1.05, 0.15);
					} else {
						spawnConfetti(holeX, holeY, 15, 1.0);
						ctx.feedback.shake2D(0.2, 3);
					}
				}

				flagWaveTimer = 1.0;
				resultBounceTimer = 0.3;

				showResult(strokes == 1 ? "HOLE IN ONE!" : (strokes == 2 ? "NICE PUTT!" : "IN!"));
			}

			// Ball stops
			if (speed < STOP_THRESHOLD) {
				ballVX = 0;
				ballVY = 0;
				ballMoving = false;

				if (!ballSunk && strokes >= maxStrokes) {
					gameOver = true;
					showResult("OUT OF STROKES");
					resultText.textColor = 0xFF4444;
				}
			}
		}

		// Sink animation
		if (ballSunk) {
			sinkAnimTimer += dt;
			if (sinkAnimTimer > 1.2 && nextHoleTimer == 0) {
				nextHoleTimer = 0.01;
			}
		}

		// Next hole transition
		if (nextHoleTimer > 0) {
			nextHoleTimer += dt;
			if (nextHoleTimer > 0.5) {
				nextHoleTimer = 0;
				setupHole(hole + 1);
			}
		}

		// Game over delay
		if (gameOver) {
			gameOverTimer += dt;
			if (gameOverTimer > 1.5) {
				if (ctx != null) {
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
				return;
			}
		}

		// Subtask 10: Flag wave timer countdown
		if (flagWaveTimer > 0) {
			flagWaveTimer -= dt;
			if (flagWaveTimer < 0) flagWaveTimer = 0;
		}

		// Subtask 10: Result bounce timer
		if (resultBounceTimer > 0) {
			resultBounceTimer -= dt;
			if (resultBounceTimer < 0) resultBounceTimer = 0;
			var bounceScale = 2.0 + resultBounceTimer * 2.0;
			resultText.setScale(bounceScale);
		}

		// Subtask 9: Update confetti physics
		var ci = confetti.length - 1;
		while (ci >= 0) {
			var p = confetti[ci];
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vy += 300 * dt; // gravity
			p.life -= dt;
			if (p.life <= 0) {
				confetti.splice(ci, 1);
			}
			ci--;
		}

		// Subtask 8: Fade trail (0.6s lifetime)
		var i = trail.length - 1;
		while (i >= 0) {
			trail[i].age += dt;
			if (trail[i].age > 0.6) {
				trail.splice(i, 1);
			}
			i--;
		}

		// Result text animation
		if (resultText.alpha > 0 && resultText.alpha < 1.0) {
			resultText.alpha = Math.min(resultText.alpha + dt * 4.0, 1.0);
		}

		// Draw everything
		drawCourse();
		drawHole();
		drawObstacles();
		drawTrail();
		drawBall(dt);
		drawAimLine();
		drawUI();
		drawConfetti();

		scoreText.text = Std.string(score);

		// Hint fades
		if (strokes > 0 && hintText.alpha > 0) {
			hintText.alpha = Math.max(0, hintText.alpha - dt * 2);
		}
	}

	function collideWall(w:Wall):Void {
		var closestX = Math.max(w.x, Math.min(ballX, w.x + w.w));
		var closestY = Math.max(w.y, Math.min(ballY, w.y + w.h));
		var dx = ballX - closestX;
		var dy = ballY - closestY;
		var dist = Math.sqrt(dx * dx + dy * dy);

		if (dist < BALL_RADIUS) {
			if (dist == 0) {
				ballX = w.x - BALL_RADIUS;
				ballVX = -Math.abs(ballVX) * WALL_BOUNCE;
				return;
			}
			var overlap = BALL_RADIUS - dist;
			var nx = dx / dist;
			var ny = dy / dist;
			ballX += nx * overlap;
			ballY += ny * overlap;

			var dot = ballVX * nx + ballVY * ny;
			if (dot < 0) {
				ballVX -= 2 * dot * nx;
				ballVY -= 2 * dot * ny;
				ballVX *= WALL_BOUNCE;
				ballVY *= WALL_BOUNCE;
			}
		}
	}

	function showResult(text:String):Void {
		resultText.text = text;
		resultText.alpha = 0.01;
		resultText.textColor = 0x44DD66;
		resultText.setScale(2.0);
		if (text == "OUT OF STROKES") resultText.textColor = 0xFF4444;
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "golf-putt";

	public function getTitle():String
		return "Golf Putt";
}

private typedef Wall = {
	x:Float,
	y:Float,
	w:Float,
	h:Float,
};
