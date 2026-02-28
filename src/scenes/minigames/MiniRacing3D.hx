package scenes.minigames;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;
import hxd.Event;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Mini Racing: corrida de kart top-down.
	Camera segue o jogador e rotaciona com ele (frente = cima).
	Tap esquerda = vira esquerda, tap direita = vira direita.
	Pistas grandes, 3 voltas, 6 karts, ultimo lugar = game over.
**/
class MiniRacing3D implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var ACCEL = 220.0;
	static var MAX_SPEED = 170.0;
	static var FRICTION = 0.988;
	static var OFFROAD_FRICTION = 0.95;
	static var STEER_RATE = 2.8;
	static var KART_RADIUS = 6.0;
	static var TRACK_HALF_W = 32.0;
	static var TOTAL_LAPS = 3;
	static var COUNTDOWN_TIME = 3.0;
	static var AI_COUNT = 5;
	static var CAM_ZOOM = 1.6;

	static var KART_COLORS:Array<Int> = [0xE74C3C, 0x2980B9, 0x27AE60, 0xF39C12, 0x8E44AD, 0x1ABC9C];

	final contentObj:h2d.Object;
	var ctx:MinigameContext;

	// Graphics layers
	var worldContainer:h2d.Object;
	var bgG:Graphics;
	var trackG:Graphics;
	var kartG:Graphics;
	var hudG:Graphics;
	var controlG:Graphics;
	var interactive:Interactive;

	// HUD texts
	var lapText:Text;
	var posText:Text;
	var countdownText:Text;
	var infoText:Text;
	var raceLabel:Text;

	// Track
	var trackPoints:Array<{x:Float, y:Float}>;
	var trackLen:Float;
	var segLengths:Array<Float>;
	var segCumLen:Array<Float>;
	var currentTrack:Int;

	// Karts
	var karts:Array<Kart>;

	// Camera
	var camX:Float;
	var camY:Float;
	var camAngle:Float;

	// Input
	var steerDir:Int; // -1 left, 0 none, 1 right

	// Game
	var score:Int;
	var started:Bool;
	var gameOver:Bool;
	var raceFinished:Bool;
	var countdown:Float;
	var raceTime:Float;
	var finishOrder:Array<Int>;
	var showResultTimer:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new h2d.Object();
		contentObj.visible = false;

		bgG = new Graphics(contentObj);
		trackG = new Graphics(contentObj);
		kartG = new Graphics(contentObj);
		hudG = new Graphics(contentObj);
		controlG = new Graphics(contentObj);

		lapText = new Text(hxd.res.DefaultFont.get(), contentObj);
		lapText.textAlign = Center;
		lapText.x = DESIGN_W / 2;
		lapText.y = 10;
		lapText.scale(1.3);
		lapText.textColor = 0xFFFFFF;

		posText = new Text(hxd.res.DefaultFont.get(), contentObj);
		posText.textAlign = Left;
		posText.x = 14;
		posText.y = 10;
		posText.scale(1.8);
		posText.textColor = 0xFFDD00;

		raceLabel = new Text(hxd.res.DefaultFont.get(), contentObj);
		raceLabel.textAlign = Right;
		raceLabel.x = DESIGN_W - 14;
		raceLabel.y = 12;
		raceLabel.scale(1.0);
		raceLabel.textColor = 0xAAAAAA;

		countdownText = new Text(hxd.res.DefaultFont.get(), contentObj);
		countdownText.textAlign = Center;
		countdownText.x = DESIGN_W / 2;
		countdownText.y = DESIGN_H / 2 - 60;
		countdownText.scale(7.0);
		countdownText.textColor = 0xFFFFFF;
		countdownText.visible = false;

		infoText = new Text(hxd.res.DefaultFont.get(), contentObj);
		infoText.textAlign = Center;
		infoText.x = DESIGN_W / 2;
		infoText.y = DESIGN_H / 2 - 20;
		infoText.scale(3.0);
		infoText.textColor = 0xFFFFFF;
		infoText.visible = false;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			if (e.relX < DESIGN_W / 2)
				steerDir = -1;
			else
				steerDir = 1;
			e.propagate = false;
		};
		interactive.onMove = function(e:Event) {
			if (steerDir != 0) {
				if (e.relX < DESIGN_W / 2)
					steerDir = -1;
				else
					steerDir = 1;
			}
		};
		interactive.onRelease = function(_:Event) {
			steerDir = 0;
		};
		interactive.onReleaseOutside = function(_:Event) {
			steerDir = 0;
		};

		trackPoints = [];
		segLengths = [];
		segCumLen = [];
		karts = [];
		finishOrder = [];
		steerDir = 0;
		camX = 0;
		camY = 0;
		camAngle = 0;
		score = 0;
		started = false;
		gameOver = false;
		raceFinished = false;
		countdown = COUNTDOWN_TIME;
		raceTime = 0;
		currentTrack = 0;
		trackLen = 0;
		showResultTimer = 0;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		score = 0;
		gameOver = false;
		currentTrack = 0;
		raceLabel.text = "Corrida 1";
		startRace();
	}

	function startRace() {
		raceFinished = false;
		started = false;
		countdown = COUNTDOWN_TIME;
		raceTime = 0;
		finishOrder = [];
		showResultTimer = 0;
		countdownText.visible = false;
		infoText.visible = false;
		steerDir = 0;

		buildTrack(currentTrack);
		buildKarts();
		updateCamera();
	}

	public function dispose() {
		ctx = null;
	}

	public function getMinigameId():String
		return "mini-racing-3d";

	public function getTitle():String
		return "Mini Racing";

	// --- Track Building ---

	function buildTrack(idx:Int) {
		trackPoints = [];
		switch (idx % 5) {
			case 0:
				buildGPCircuit();
			case 1:
				buildSnakeTrack();
			case 2:
				buildOvalLong();
			case 3:
				buildTechTrack();
			case 4:
				buildWideLoop();
		}
		computeTrackLengths();
	}

	function buildGPCircuit() {
		// Big GP-style circuit with hairpin, chicane, long straights
		// Scale: ~800x500 world units
		var pts:Array<{x:Float, y:Float}> = [];

		// Start/finish straight (bottom)
		addPts(pts, -200, 200, 200, 200, 10);
		// Turn 1 - wide right
		addArc(pts, 200, 200, 250, 120, -Math.PI / 2, 0, 10);
		// Short straight up-right
		addPts(pts, 250, 120, 250, -50, 6);
		// Hairpin right
		addArc(pts, 250, -50, 200, -120, 0, Math.PI * 0.8, 12);
		// Diagonal back
		addPts(pts, 200, -120, 80, -180, 6);
		// Chicane left-right
		addArc(pts, 80, -180, 30, -200, Math.PI * 0.3, Math.PI * 0.8, 6);
		addArc(pts, 30, -200, -30, -180, -Math.PI * 0.2, Math.PI * 0.3, 6);
		// Long back straight
		addPts(pts, -30, -180, -200, -180, 8);
		// Turn left sweeper
		addArc(pts, -200, -180, -280, -100, Math.PI / 2, Math.PI, 10);
		// Down straight
		addPts(pts, -280, -100, -280, 80, 6);
		// Final turn back to start
		addArc(pts, -280, 80, -200, 200, Math.PI, Math.PI * 1.5, 12);

		for (p in pts)
			trackPoints.push(p);
	}

	function buildSnakeTrack() {
		// S-curves snaking back and forth
		var pts:Array<{x:Float, y:Float}> = [];
		var y = 250.0;
		var dir = 1;

		// Start straight
		addPts(pts, -150, y, 150, y, 8);

		var sections = 4;
		var i = 0;
		while (i < sections) {
			var xEnd = dir * 150;
			y -= 100;
			// U-turn
			addArc(pts, Std.int(dir * 150), Std.int(y + 100), Std.int(dir * 200), Std.int(y + 50), if (dir > 0) - Math.PI / 2 else Math.PI / 2,
				if (dir > 0) Math.PI / 2 else -Math.PI / 2, 10);
			// Straight across
			addPts(pts, dir * 200, y, -dir * 150, y, 8);
			dir = -dir;
			i++;
		}

		// Close the loop back to start
		addArc(pts, Std.int(-dir * 150), Std.int(y), Std.int(-dir * 200), Std.int(y + 50), if (-dir > 0) Math.PI / 2 else -Math.PI / 2,
			if (-dir > 0) - Math.PI / 2 else Math.PI / 2, 10);
		addPts(pts, Std.int(-dir * 200), Std.int(y + 50), Std.int(-dir * 200), 250, 8);
		addArc(pts, Std.int(-dir * 200), 250, -150, 250, Math.PI, Math.PI * 1.5, 8);

		for (p in pts)
			trackPoints.push(p);
	}

	function buildOvalLong() {
		// Long oval / Indianapolis style
		var rx = 300.0;
		var ry = 120.0;
		var segments = 48;
		var i = 0;
		while (i < segments) {
			var angle = (i / segments) * Math.PI * 2;
			trackPoints.push({
				x: Math.cos(angle) * rx,
				y: Math.sin(angle) * ry
			});
			i++;
		}
	}

	function buildTechTrack() {
		// Technical track with tight turns and short straights
		var pts:Array<{x:Float, y:Float}> = [];
		addPts(pts, -100, 200, 100, 200, 6);
		addArc(pts, 100, 200, 180, 140, -Math.PI / 2, 0, 8);
		addPts(pts, 180, 140, 180, 40, 4);
		addArc(pts, 180, 40, 120, -20, 0, Math.PI / 2, 6);
		addPts(pts, 120, -20, 40, -20, 4);
		addArc(pts, 40, -20, -20, -80, Math.PI / 2, Math.PI, 6);
		addPts(pts, -20, -80, -20, -160, 4);
		addArc(pts, -20, -160, -80, -220, Math.PI, Math.PI * 1.3, 6);
		addPts(pts, -80, -220, -200, -200, 6);
		addArc(pts, -200, -200, -260, -140, Math.PI / 2, Math.PI, 8);
		addPts(pts, -260, -140, -260, 60, 6);
		addArc(pts, -260, 60, -200, 140, Math.PI, Math.PI * 1.5, 8);
		addPts(pts, -200, 140, -200, 200, 4);
		addArc(pts, -200, 200, -100, 200, Math.PI * 1.5, Math.PI * 2, 6);

		for (p in pts)
			trackPoints.push(p);
	}

	function buildWideLoop() {
		// Big irregular loop
		var pts:Array<{x:Float, y:Float}> = [];
		addPts(pts, -100, 250, 150, 250, 8);
		addArc(pts, 150, 250, 250, 150, -Math.PI / 2, 0, 8);
		addPts(pts, 250, 150, 280, -50, 6);
		addArc(pts, 280, -50, 220, -150, -Math.PI * 0.1, Math.PI * 0.4, 8);
		addPts(pts, 220, -150, 100, -220, 6);
		addArc(pts, 100, -220, -50, -250, Math.PI * 0.2, Math.PI * 0.7, 8);
		addPts(pts, -50, -250, -200, -200, 6);
		addArc(pts, -200, -200, -280, -100, Math.PI * 0.6, Math.PI, 8);
		addPts(pts, -280, -100, -250, 100, 6);
		addArc(pts, -250, 100, -180, 200, Math.PI, Math.PI * 1.4, 8);
		addPts(pts, -180, 200, -100, 250, 4);

		for (p in pts)
			trackPoints.push(p);
	}

	function addPts(pts:Array<{x:Float, y:Float}>, x1:Float, y1:Float, x2:Float, y2:Float, steps:Int) {
		var i = 0;
		while (i < steps) {
			var t = i / steps;
			pts.push({x: x1 + (x2 - x1) * t, y: y1 + (y2 - y1) * t});
			i++;
		}
	}

	function addArc(pts:Array<{x:Float, y:Float}>, x1:Float, y1:Float, x2:Float, y2:Float, a1:Float, a2:Float, segs:Int) {
		var cx = (x1 + x2) / 2;
		var cy = (y1 + y2) / 2;
		var rx = Math.abs(x2 - x1) / 2;
		var ry = Math.abs(y2 - y1) / 2;
		if (rx < 10)
			rx = 30;
		if (ry < 10)
			ry = 30;
		var i = 0;
		while (i <= segs) {
			var t = i / segs;
			var a = a1 + (a2 - a1) * t;
			pts.push({x: cx + Math.cos(a) * rx, y: cy + Math.sin(a) * ry});
			i++;
		}
	}

	function computeTrackLengths() {
		segLengths = [];
		segCumLen = [];
		trackLen = 0;
		var n = trackPoints.length;
		var i = 0;
		while (i < n) {
			var next = (i + 1) % n;
			var dx = trackPoints[next].x - trackPoints[i].x;
			var dy = trackPoints[next].y - trackPoints[i].y;
			var len = Math.sqrt(dx * dx + dy * dy);
			segLengths.push(len);
			segCumLen.push(trackLen);
			trackLen += len;
			i++;
		}
	}

	function getTrackPos(dist:Float):{x:Float, y:Float, angle:Float} {
		while (dist < 0)
			dist += trackLen;
		while (dist >= trackLen)
			dist -= trackLen;
		var n = trackPoints.length;
		var seg = 0;
		while (seg < n - 1 && segCumLen[seg + 1] <= dist)
			seg++;
		var segStart = segCumLen[seg];
		var t = if (segLengths[seg] > 0.01) (dist - segStart) / segLengths[seg] else 0.0;
		var next = (seg + 1) % n;
		var px = trackPoints[seg].x + (trackPoints[next].x - trackPoints[seg].x) * t;
		var py = trackPoints[seg].y + (trackPoints[next].y - trackPoints[seg].y) * t;
		var angle = Math.atan2(trackPoints[next].y - trackPoints[seg].y, trackPoints[next].x - trackPoints[seg].x);
		return {x: px, y: py, angle: angle};
	}

	function distToTrack(wx:Float, wy:Float):Float {
		var minDist = 99999.0;
		var n = trackPoints.length;
		var i = 0;
		while (i < n) {
			var next = (i + 1) % n;
			var d = ptSegDist(wx, wy, trackPoints[i].x, trackPoints[i].y, trackPoints[next].x, trackPoints[next].y);
			if (d < minDist)
				minDist = d;
			i++;
		}
		return minDist;
	}

	function ptSegDist(px:Float, py:Float, ax:Float, ay:Float, bx:Float, by:Float):Float {
		var dx = bx - ax;
		var dy = by - ay;
		var lenSq = dx * dx + dy * dy;
		if (lenSq < 0.01)
			return Math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
		var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var projX = ax + t * dx;
		var projY = ay + t * dy;
		return Math.sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));
	}

	// --- Karts ---

	function buildKarts() {
		karts = [];
		var startPos = getTrackPos(0);
		var perpA = startPos.angle + Math.PI / 2;
		var totalKarts = AI_COUNT + 1;
		var i = 0;
		while (i < totalKarts) {
			var row = Std.int(i / 2);
			var col = i % 2;
			var lateral = (col - 0.5) * 16;
			var longOffset = -row * 22.0;
			var sp = getTrackPos(longOffset < 0 ? trackLen + longOffset : longOffset);

			var kart:Kart = {
				x: sp.x + Math.cos(perpA) * lateral,
				y: sp.y + Math.sin(perpA) * lateral,
				angle: startPos.angle,
				speed: 0,
				lap: 0,
				dist: longOffset < 0 ? trackLen + longOffset : longOffset,
				prevDist: 0,
				color: KART_COLORS[i % KART_COLORS.length],
				isPlayer: i == 0,
				finished: false,
				aiTargetDist: 0,
				aiLateral: (Math.random() - 0.5) * 12,
				aiSkill: 0.72 + Math.random() * 0.22,
				aiNoise: Math.random() * 6.28
			};
			kart.prevDist = kart.dist;
			kart.aiTargetDist = kart.dist;
			karts.push(kart);
			i++;
		}
	}

	function getPlayerPosition():Int {
		if (karts.length == 0)
			return 1;
		var pLap = karts[0].lap;
		var pDist = karts[0].dist;
		var pos = 1;
		var i = 1;
		while (i < karts.length) {
			var k = karts[i];
			if (k.lap > pLap || (k.lap == pLap && k.dist > pDist))
				pos++;
			i++;
		}
		return pos;
	}

	// --- Update ---

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (dt > 0.05)
			dt = 0.05;

		if (!started) {
			updateCamera();
			drawAll();
			return;
		}

		// Countdown
		if (countdown > 0) {
			countdown -= dt;
			countdownText.visible = true;
			var num = Std.int(Math.ceil(countdown));
			if (num < 1) {
				countdownText.text = "GO!";
				countdownText.textColor = 0x44FF44;
			} else {
				countdownText.text = Std.string(num);
				countdownText.textColor = if (num > 1) 0xFF4444 else 0xFFDD00;
			}
			if (countdown <= -0.5)
				countdownText.visible = false;
			updateCamera();
			drawAll();
			if (countdown > 0)
				return;
		} else {
			countdownText.visible = false;
		}

		if (raceFinished) {
			showResultTimer += dt;
			if (showResultTimer >= 2.5) {
				var playerPos = getPlayerPosition();
				if (playerPos >= karts.length) {
					gameOver = true;
					if (ctx != null) {
						ctx.lose(score, getMinigameId());
						ctx = null;
					}
					return;
				}
				score++;
				currentTrack++;
				raceLabel.text = "Corrida " + (currentTrack + 1);
				startRace();
			}
			updateCamera();
			drawAll();
			return;
		}

		raceTime += dt;
		updatePlayerKart(dt);
		var i = 1;
		while (i < karts.length) {
			updateAIKart(karts[i], dt);
			i++;
		}
		resolveCollisions();
		checkLaps();
		updateCamera();
		drawAll();
	}

	function updatePlayerKart(dt:Float) {
		var k = karts[0];

		// Auto-accelerate
		k.speed += ACCEL * dt;
		if (k.speed > MAX_SPEED)
			k.speed = MAX_SPEED;

		// Steer
		var speedFactor = Math.min(k.speed / 80, 1.0);
		k.angle += steerDir * STEER_RATE * speedFactor * dt;

		// Move
		k.x += Math.cos(k.angle) * k.speed * dt;
		k.y += Math.sin(k.angle) * k.speed * dt;

		// Off-road friction
		var dist = distToTrack(k.x, k.y);
		if (dist > TRACK_HALF_W)
			k.speed *= OFFROAD_FRICTION;
		else
			k.speed *= FRICTION;

		updateKartDist(k);
	}

	function updateAIKart(k:Kart, dt:Float) {
		k.aiNoise += dt * 1.8;
		k.aiTargetDist += k.speed * dt;
		while (k.aiTargetDist >= trackLen)
			k.aiTargetDist -= trackLen;

		var lookAhead = 30 + k.speed * 0.15;
		var target = getTrackPos(k.aiTargetDist + lookAhead);
		var perpA = target.angle + Math.PI / 2;
		var noise = Math.sin(k.aiNoise) * k.aiLateral;
		var tx = target.x + Math.cos(perpA) * noise;
		var ty = target.y + Math.sin(perpA) * noise;

		var toTarget = Math.atan2(ty - k.y, tx - k.x);
		var angleDiff = toTarget - k.angle;
		while (angleDiff > Math.PI)
			angleDiff -= Math.PI * 2;
		while (angleDiff < -Math.PI)
			angleDiff += Math.PI * 2;

		var steer = angleDiff * 2.0 * k.aiSkill;
		if (steer > 1)
			steer = 1;
		if (steer < -1)
			steer = -1;

		var targetSpeed = MAX_SPEED * k.aiSkill * (0.88 + Math.sin(k.aiNoise * 0.3) * 0.08);
		if (Math.abs(angleDiff) > 0.4)
			targetSpeed *= 0.7;

		if (k.speed < targetSpeed)
			k.speed += ACCEL * 0.85 * dt;
		else
			k.speed *= 0.97;
		if (k.speed < 0)
			k.speed = 0;

		var speedFactor = Math.min(k.speed / 80, 1.0);
		k.angle += steer * STEER_RATE * speedFactor * dt;
		k.x += Math.cos(k.angle) * k.speed * dt;
		k.y += Math.sin(k.angle) * k.speed * dt;

		var dist = distToTrack(k.x, k.y);
		if (dist > TRACK_HALF_W)
			k.speed *= OFFROAD_FRICTION;
		else
			k.speed *= FRICTION;

		updateKartDist(k);
	}

	function updateKartDist(k:Kart) {
		var bestDist = 99999.0;
		var bestSegDist = 0.0;
		var n = trackPoints.length;
		var i = 0;
		while (i < n) {
			var next = (i + 1) % n;
			var ax = trackPoints[i].x;
			var ay = trackPoints[i].y;
			var bx = trackPoints[next].x;
			var by = trackPoints[next].y;
			var dx = bx - ax;
			var dy = by - ay;
			var lenSq = dx * dx + dy * dy;
			var t = if (lenSq > 0.01) ((k.x - ax) * dx + (k.y - ay) * dy) / lenSq else 0.0;
			if (t < 0)
				t = 0;
			if (t > 1)
				t = 1;
			var projX = ax + t * dx;
			var projY = ay + t * dy;
			var d = (k.x - projX) * (k.x - projX) + (k.y - projY) * (k.y - projY);
			if (d < bestDist) {
				bestDist = d;
				bestSegDist = segCumLen[i] + t * segLengths[i];
			}
			i++;
		}
		k.prevDist = k.dist;
		k.dist = bestSegDist;
	}

	function resolveCollisions() {
		var i = 0;
		while (i < karts.length) {
			var j = i + 1;
			while (j < karts.length) {
				var a = karts[i];
				var b = karts[j];
				var dx = b.x - a.x;
				var dy = b.y - a.y;
				var distSq = dx * dx + dy * dy;
				var minDist = KART_RADIUS * 2;
				if (distSq < minDist * minDist && distSq > 0.1) {
					var dist = Math.sqrt(distSq);
					var overlap = (minDist - dist) / 2;
					var nx = dx / dist;
					var ny = dy / dist;
					a.x -= nx * overlap;
					a.y -= ny * overlap;
					b.x += nx * overlap;
					b.y += ny * overlap;
					var relSpeed = (a.speed - b.speed) * 0.25;
					a.speed -= relSpeed;
					b.speed += relSpeed;
				}
				j++;
			}
			i++;
		}
	}

	function checkLaps() {
		for (k in karts) {
			if (k.finished)
				continue;
			if (k.prevDist > trackLen * 0.8 && k.dist < trackLen * 0.2) {
				k.lap++;
				if (k.lap >= TOTAL_LAPS) {
					k.finished = true;
					finishOrder.push(karts.indexOf(k));
					if (k.isPlayer && ctx != null && ctx.feedback != null) {
						var pos = finishOrder.length;
						if (pos == 1)
							ctx.feedback.flash(0xFFD700, 0.3);
						else
							ctx.feedback.flash(0x44AAFF, 0.15);
					}
					if (finishOrder.length >= karts.length || karts[0].finished) {
						raceFinished = true;
						showResultTimer = 0;
						var playerPos = 0;
						var pi = 0;
						while (pi < finishOrder.length) {
							if (finishOrder[pi] == 0)
								playerPos = pi + 1;
							pi++;
						}
						if (playerPos == 0)
							playerPos = finishOrder.length + 1;
						infoText.text = playerPos + "o lugar!";
						infoText.textColor = if (playerPos == 1) 0xFFD700 else if (playerPos <= 3) 0x44FF44 else 0xFF4444;
						infoText.visible = true;
					}
				}
			}
		}
	}

	function updateCamera() {
		if (karts.length == 0)
			return;
		var pk = karts[0];
		// Smooth follow
		camX += (pk.x - camX) * 0.15;
		camY += (pk.y - camY) * 0.15;
		// Rotate camera so player faces up
		var targetAngle = -pk.angle - Math.PI / 2;
		var angleDiff = targetAngle - camAngle;
		while (angleDiff > Math.PI)
			angleDiff -= Math.PI * 2;
		while (angleDiff < -Math.PI)
			angleDiff += Math.PI * 2;
		camAngle += angleDiff * 0.1;
	}

	// --- Drawing ---

	function worldToScreen(wx:Float, wy:Float):{sx:Float, sy:Float} {
		// Translate, rotate, scale
		var dx = wx - camX;
		var dy = wy - camY;
		var cosA = Math.cos(camAngle);
		var sinA = Math.sin(camAngle);
		var rx = dx * cosA - dy * sinA;
		var ry = dx * sinA + dy * cosA;
		return {
			sx: DESIGN_W / 2 + rx * CAM_ZOOM,
			sy: DESIGN_H / 2 + 60 + ry * CAM_ZOOM
		};
	}

	function drawAll() {
		drawBackground();
		drawTrack();
		drawKarts();
		drawHud();
		drawControls();
	}

	function drawBackground() {
		bgG.clear();
		// Grass green fill
		bgG.beginFill(0x2A7A2A);
		bgG.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bgG.endFill();

		// Grass texture dots (subtle)
		var i = 0;
		while (i < 30) {
			var wx = camX + (Math.sin(i * 37.7) * 300);
			var wy = camY + (Math.cos(i * 23.3) * 300);
			var s = worldToScreen(wx, wy);
			if (s.sx > -10 && s.sx < DESIGN_W + 10 && s.sy > -10 && s.sy < DESIGN_H + 10) {
				var shade = if (i % 2 == 0) 0x338833 else 0x226622;
				bgG.beginFill(shade, 0.4);
				bgG.drawCircle(s.sx, s.sy, 3 + (i % 3) * 2);
				bgG.endFill();
			}
			i++;
		}
	}

	function drawTrack() {
		trackG.clear();
		var n = trackPoints.length;
		if (n < 3)
			return;

		var trackWidth = TRACK_HALF_W * 2 * CAM_ZOOM;
		var edgeWidth = trackWidth + 8 * CAM_ZOOM;

		// Grass border (darker)
		trackG.lineStyle(Std.int(Math.max(1, edgeWidth + 6)), 0x1E6B1E);
		var sp = worldToScreen(trackPoints[0].x, trackPoints[0].y);
		trackG.moveTo(sp.sx, sp.sy);
		var i = 1;
		while (i <= n) {
			var pt = trackPoints[i % n];
			var s = worldToScreen(pt.x, pt.y);
			trackG.lineTo(s.sx, s.sy);
			i++;
		}

		// Rumble curb
		trackG.lineStyle(Std.int(Math.max(1, edgeWidth)), 0xCC3333);
		sp = worldToScreen(trackPoints[0].x, trackPoints[0].y);
		trackG.moveTo(sp.sx, sp.sy);
		i = 1;
		while (i <= n) {
			var pt = trackPoints[i % n];
			var s = worldToScreen(pt.x, pt.y);
			trackG.lineTo(s.sx, s.sy);
			i++;
		}

		// Track surface
		trackG.lineStyle(Std.int(Math.max(1, trackWidth)), 0x555555);
		sp = worldToScreen(trackPoints[0].x, trackPoints[0].y);
		trackG.moveTo(sp.sx, sp.sy);
		i = 1;
		while (i <= n) {
			var pt = trackPoints[i % n];
			var s = worldToScreen(pt.x, pt.y);
			trackG.lineTo(s.sx, s.sy);
			i++;
		}
		trackG.lineStyle(0);

		// Center dashes
		i = 0;
		while (i < n) {
			if (i % 4 < 2) {
				var pt = trackPoints[i];
				var s = worldToScreen(pt.x, pt.y);
				trackG.beginFill(0xFFFFFF, 0.25);
				trackG.drawCircle(s.sx, s.sy, Math.max(1, 1.5 * CAM_ZOOM));
				trackG.endFill();
			}
			i++;
		}

		// Start/finish line
		var s1 = getTrackPos(0);
		var perpA = s1.angle + Math.PI / 2;
		var hw = TRACK_HALF_W * 0.9;
		var checks = 8;
		var ci = 0;
		while (ci < checks) {
			var t1 = ci / checks;
			var t2 = (ci + 1) / checks;
			var lat1 = -hw + t1 * hw * 2;
			var lat2 = -hw + t2 * hw * 2;
			var p1 = worldToScreen(s1.x + Math.cos(perpA) * lat1, s1.y + Math.sin(perpA) * lat1);
			var p2 = worldToScreen(s1.x + Math.cos(perpA) * lat2, s1.y + Math.sin(perpA) * lat2);
			var color = if (ci % 2 == 0) 0xFFFFFF else 0x111111;
			trackG.lineStyle(Std.int(Math.max(2, 3 * CAM_ZOOM)), color);
			trackG.moveTo(p1.sx, p1.sy);
			trackG.lineTo(p2.sx, p2.sy);
			ci++;
		}
		trackG.lineStyle(0);
	}

	function drawKarts() {
		kartG.clear();

		for (k in karts) {
			var s = worldToScreen(k.x, k.y);
			// Check if on screen
			if (s.sx < -30 || s.sx > DESIGN_W + 30 || s.sy < -30 || s.sy > DESIGN_H + 30)
				continue;

			var size = KART_RADIUS * CAM_ZOOM;
			var halfW = size * 0.65;
			var halfH = size * 1.0;

			// Effective angle (kart angle + camera rotation)
			var effAngle = k.angle + camAngle;
			var cosA = Math.cos(effAngle);
			var sinA = Math.sin(effAngle);

			// Shadow
			kartG.beginFill(0x000000, 0.25);
			kartG.drawEllipse(s.sx + 1, s.sy + 2, halfW * 1.1, halfH * 0.8);
			kartG.endFill();

			// Body
			kartG.beginFill(k.color, 1.0);
			drawRotatedRect(kartG, s.sx, s.sy, halfW, halfH, cosA, sinA);
			kartG.endFill();

			// Cockpit
			var dr = (k.color >> 16 & 0xFF);
			var dg = (k.color >> 8 & 0xFF);
			var db = (k.color & 0xFF);
			var dark = (Std.int(dr * 0.55) << 16) | (Std.int(dg * 0.55) << 8) | Std.int(db * 0.55);
			kartG.beginFill(dark, 1.0);
			drawRotatedRect(kartG, s.sx - sinA * halfH * 0.1, s.sy + cosA * halfH * 0.1, halfW * 0.55, halfH * 0.3, cosA, sinA);
			kartG.endFill();

			// Front headlights
			var noseX = s.sx - sinA * halfH * 0.85;
			var noseY = s.sy + cosA * halfH * 0.85;
			kartG.beginFill(0xFFFFFF, 0.8);
			kartG.drawCircle(noseX - cosA * halfW * 0.4, noseY - sinA * halfW * 0.4, size * 0.12);
			kartG.drawCircle(noseX + cosA * halfW * 0.4, noseY + sinA * halfW * 0.4, size * 0.12);
			kartG.endFill();

			// Rear wheels
			var rearOff = halfH * 0.6;
			var wheelOff = halfW * 0.85;
			kartG.beginFill(0x222222, 1.0);
			kartG.drawCircle(s.sx + sinA * rearOff - cosA * wheelOff, s.sy - cosA * rearOff - sinA * wheelOff, size * 0.18);
			kartG.drawCircle(s.sx + sinA * rearOff + cosA * wheelOff, s.sy - cosA * rearOff + sinA * wheelOff, size * 0.18);
			kartG.endFill();

			// Player marker
			if (k.isPlayer) {
				var arrowY = -halfH * 1.6;
				var ax = s.sx - sinA * arrowY;
				var ay = s.sy + cosA * arrowY;
				kartG.beginFill(0xFFDD00, 0.9);
				kartG.drawCircle(ax, ay, size * 0.25);
				kartG.endFill();
				kartG.beginFill(0x000000, 0.6);
				kartG.drawCircle(ax, ay, size * 0.12);
				kartG.endFill();
			}
		}
	}

	function drawRotatedRect(g:Graphics, cx:Float, cy:Float, hw:Float, hh:Float, cosA:Float, sinA:Float) {
		var corners = [
			{dx: -hw, dy: -hh},
			{dx: hw, dy: -hh},
			{dx: hw, dy: hh},
			{dx: -hw, dy: hh}
		];
		g.moveTo(cx + corners[0].dx * cosA - corners[0].dy * sinA, cy + corners[0].dx * sinA + corners[0].dy * cosA);
		g.lineTo(cx + corners[1].dx * cosA - corners[1].dy * sinA, cy + corners[1].dx * sinA + corners[1].dy * cosA);
		g.lineTo(cx + corners[2].dx * cosA - corners[2].dy * sinA, cy + corners[2].dx * sinA + corners[2].dy * cosA);
		g.lineTo(cx + corners[3].dx * cosA - corners[3].dy * sinA, cy + corners[3].dx * sinA + corners[3].dy * cosA);
	}

	function drawHud() {
		hudG.clear();

		// Top bar
		hudG.beginFill(0x000000, 0.55);
		hudG.drawRect(0, 0, DESIGN_W, 36);
		hudG.endFill();

		// Position
		var pos = getPlayerPosition();
		posText.text = pos + "o";
		posText.textColor = if (pos == 1) 0xFFD700 else if (pos <= 3) 0x44FF44 else 0xFF8888;

		// Lap
		var playerLap = if (karts.length > 0) karts[0].lap + 1 else 1;
		if (playerLap > TOTAL_LAPS)
			playerLap = TOTAL_LAPS;
		lapText.text = "Volta " + playerLap + "/" + TOTAL_LAPS;

		// Minimap
		drawMinimap();
	}

	function drawMinimap() {
		// Small minimap in top-right corner
		var mapSize = 50.0;
		var mapX = DESIGN_W - mapSize - 8;
		var mapY = 42.0;

		hudG.beginFill(0x000000, 0.4);
		hudG.drawRoundedRect(mapX - 4, mapY - 4, mapSize + 8, mapSize + 8, 6);
		hudG.endFill();

		// Find track bounds
		var minTX = 99999.0;
		var maxTX = -99999.0;
		var minTY = 99999.0;
		var maxTY = -99999.0;
		for (p in trackPoints) {
			if (p.x < minTX)
				minTX = p.x;
			if (p.x > maxTX)
				maxTX = p.x;
			if (p.y < minTY)
				minTY = p.y;
			if (p.y > maxTY)
				maxTY = p.y;
		}
		var tw = maxTX - minTX;
		var th = maxTY - minTY;
		if (tw < 1)
			tw = 1;
		if (th < 1)
			th = 1;
		var scale = Math.min(mapSize / tw, mapSize / th) * 0.9;

		// Draw track on minimap
		hudG.lineStyle(2, 0x666666);
		var n = trackPoints.length;
		var sp = trackPoints[0];
		hudG.moveTo(mapX + ((sp.x - minTX) - tw / 2) * scale + mapSize / 2, mapY + ((sp.y - minTY) - th / 2) * scale + mapSize / 2);
		var i = 1;
		while (i <= n) {
			var pt = trackPoints[i % n];
			hudG.lineTo(mapX + ((pt.x - minTX) - tw / 2) * scale + mapSize / 2, mapY + ((pt.y - minTY) - th / 2) * scale + mapSize / 2);
			i++;
		}
		hudG.lineStyle(0);

		// Kart dots on minimap
		for (k in karts) {
			var mx = mapX + ((k.x - minTX) - tw / 2) * scale + mapSize / 2;
			var my = mapY + ((k.y - minTY) - th / 2) * scale + mapSize / 2;
			var dotSize = if (k.isPlayer) 3.0 else 2.0;
			hudG.beginFill(k.color, 1.0);
			hudG.drawCircle(mx, my, dotSize);
			hudG.endFill();
		}
	}

	function drawControls() {
		controlG.clear();

		// Left/right touch zones (subtle arrows at bottom)
		var arrowY = DESIGN_H - 50;
		var arrowSize = 14.0;
		var alpha = 0.2;

		// Left arrow
		var lAlpha = if (steerDir == -1) 0.5 else alpha;
		controlG.beginFill(0xFFFFFF, lAlpha);
		controlG.moveTo(50, arrowY);
		controlG.lineTo(50 + arrowSize, arrowY - arrowSize);
		controlG.lineTo(50 + arrowSize, arrowY + arrowSize);
		controlG.endFill();

		// Right arrow
		var rAlpha = if (steerDir == 1) 0.5 else alpha;
		controlG.beginFill(0xFFFFFF, rAlpha);
		controlG.moveTo(DESIGN_W - 50, arrowY);
		controlG.lineTo(DESIGN_W - 50 - arrowSize, arrowY - arrowSize);
		controlG.lineTo(DESIGN_W - 50 - arrowSize, arrowY + arrowSize);
		controlG.endFill();

		// Divider line (subtle)
		controlG.lineStyle(1, 0xFFFFFF, 0.08);
		controlG.moveTo(DESIGN_W / 2, DESIGN_H - 80);
		controlG.lineTo(DESIGN_W / 2, DESIGN_H - 20);
		controlG.lineStyle(0);
	}
}

private typedef Kart = {
	x:Float,
	y:Float,
	angle:Float,
	speed:Float,
	lap:Int,
	dist:Float,
	prevDist:Float,
	color:Int,
	isPlayer:Bool,
	finished:Bool,
	aiTargetDist:Float,
	aiLateral:Float,
	aiSkill:Float,
	aiNoise:Float
};
