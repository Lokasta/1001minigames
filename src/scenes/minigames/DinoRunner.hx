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
	Dino Runner: swipe up = pular, swipe down = abaixar.
	Cactos = pular. Pássaros = abaixar. Tap também pula.
	Estilo Chrome Dino com parallax, speed ramp e day/night cycle.
**/
class DinoRunner implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRAVITY = 950;
	static var JUMP_STRENGTH = -410;
	static var FAST_FALL_VY = 650;
	static var GROUND_Y = 510;
	static var DINO_X = 68;
	static var DINO_W = 36;
	static var DINO_H = 44;
	static var DINO_DUCK_H = 26;
	static var SPEED_START = 260;
	static var SPEED_MAX = 480;
	static var SPEED_RAMP_TIME = 90.0;
	static var SPAWN_MIN = 0.9;
	static var SPAWN_MAX = 2.0;
	static var BIRD_Y = 468;
	static var BIRD_W = 34;
	static var BIRD_H = 22;
	static var HIGH_Y = 375;
	static var HIGH_W = 30;
	static var HIGH_H = 44;
	static var SWIPE_THRESHOLD = 40;
	static var SWIPE_MAX_DUR = 0.4;
	static var DUCK_DURATION = 0.7;
	static var DEATH_DUR = 0.55;
	static var MILESTONE = 50;

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var skyG:Graphics;
	var mountainsG:Graphics;
	var groundG:Graphics;
	var dinoG:Graphics;
	var obstaclesG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var hiText:Text;
	var instructText:Text;
	var milestoneText:Text;
	var interactive:Interactive;

	var dinoY:Float;
	var dinoVy:Float;
	var started:Bool;
	var score:Int;
	var hiScore:Int;
	var obstacles:Array<Obstacle>;
	var spawnTimer:Float;
	var gameOver:Bool;
	var deathTimer:Float;
	var groundOffset:Float;
	var mountainOff1:Float;
	var mountainOff2:Float;
	var runFrame:Bool;
	var runAnimTimer:Float;
	var ducking:Bool;
	var duckTimer:Float;
	var fastFall:Bool;
	var elapsed:Float;
	var milestoneTimer:Float;
	var touchStartX:Float;
	var touchStartY:Float;
	var touchStartTime:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		obstacles = [];
		hiScore = 0;

		skyG = new Graphics(contentObj);
		mountainsG = new Graphics(contentObj);
		groundG = new Graphics(contentObj);
		obstaclesG = new Graphics(contentObj);
		dinoG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "00000";
		scoreText.x = designW - 14;
		scoreText.y = 20;
		scoreText.scale(1.3);
		scoreText.textAlign = Right;
		scoreText.textColor = 0x535353;

		hiText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hiText.text = "";
		hiText.x = designW - 100;
		hiText.y = 20;
		hiText.scale(1.0);
		hiText.textAlign = Right;
		hiText.textColor = 0x999999;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Toque para pular";
		instructText.x = designW / 2;
		instructText.y = GROUND_Y - 100;
		instructText.scale(1.2);
		instructText.textAlign = Center;
		instructText.textColor = 0x777777;
		instructText.visible = true;

		milestoneText = new Text(hxd.res.DefaultFont.get(), contentObj);
		milestoneText.text = "";
		milestoneText.x = designW / 2;
		milestoneText.y = GROUND_Y - 140;
		milestoneText.scale(2.0);
		milestoneText.textAlign = Center;
		milestoneText.textColor = 0x535353;
		milestoneText.visible = false;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (ctx == null)
				return;
			if (gameOver)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchStartTime = haxe.Timer.stamp();
			if (onGround() && !ducking) {
				dinoVy = JUMP_STRENGTH;
			}
			e.propagate = false;
		};
		interactive.onRelease = function(e:Event) {
			if (gameOver || ctx == null || !started)
				return;
			var dt = haxe.Timer.stamp() - touchStartTime;
			if (dt > SWIPE_MAX_DUR)
				return;
			var dy = e.relY - touchStartY;
			var dx = e.relX - touchStartX;
			if (dy > SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (onGround()) {
					ducking = true;
					duckTimer = DUCK_DURATION;
				} else {
					fastFall = true;
				}
				e.propagate = false;
			}
		};
	}

	function currentSpeed():Float {
		var t = if (elapsed > SPEED_RAMP_TIME) 1.0 else elapsed / SPEED_RAMP_TIME;
		return SPEED_START + (SPEED_MAX - SPEED_START) * t;
	}

	inline function onGround():Bool
		return dinoY >= GROUND_Y - DINO_H - 2;

	function dayNightT():Float {
		var cycle = 40.0;
		var t = (elapsed % cycle) / cycle;
		return if (t < 0.5) 0.0 else (t - 0.5) * 2.0;
	}

	function lerpColor(a:Int, b:Int, t:Float):Int {
		var ra = (a >> 16) & 0xFF;
		var ga = (a >> 8) & 0xFF;
		var ba = a & 0xFF;
		var rb = (b >> 16) & 0xFF;
		var gb = (b >> 8) & 0xFF;
		var bb = b & 0xFF;
		return (Std.int(ra + (rb - ra) * t) << 16) | (Std.int(ga + (gb - ga) * t) << 8) | Std.int(ba + (bb - ba) * t);
	}

	function drawSky() {
		skyG.clear();
		var nt = dayNightT();
		var skyDay = 0xF7F7E8;
		var skyNight = 0x1a1a2e;
		var sky = lerpColor(skyDay, skyNight, nt);
		skyG.beginFill(sky);
		skyG.drawRect(0, 0, designW, designH);
		skyG.endFill();
		if (nt > 0.3) {
			var starAlpha = (nt - 0.3) / 0.7;
			skyG.beginFill(0xFFFFFF, starAlpha * 0.8);
			skyG.drawCircle(50, 80, 1.5);
			skyG.drawCircle(130, 50, 1);
			skyG.drawCircle(200, 90, 1.5);
			skyG.drawCircle(270, 40, 1);
			skyG.drawCircle(310, 100, 1.5);
			skyG.drawCircle(80, 130, 1);
			skyG.drawCircle(250, 70, 1);
			skyG.drawCircle(160, 110, 1.5);
			skyG.endFill();
			skyG.beginFill(0xEEEECC, starAlpha * 0.6);
			skyG.drawCircle(300, 60, 12);
			skyG.endFill();
			skyG.beginFill(sky);
			skyG.drawCircle(295, 55, 10);
			skyG.endFill();
		}
	}

	function drawMountains() {
		mountainsG.clear();
		var nt = dayNightT();
		var mtn1Day = 0xD4C8A8;
		var mtn1Night = 0x2a2a44;
		var mtn2Day = 0xC4B898;
		var mtn2Night = 0x222238;
		var c1 = lerpColor(mtn1Day, mtn1Night, nt);
		var c2 = lerpColor(mtn2Day, mtn2Night, nt);
		var baseY = GROUND_Y - 30;
		var ox1 = mountainOff1 % 200;
		var x = -ox1 - 100;
		mountainsG.beginFill(c1, 0.5);
		while (x < designW + 200) {
			mountainsG.moveTo(x, baseY);
			mountainsG.lineTo(x + 50, baseY - 60);
			mountainsG.lineTo(x + 100, baseY);
			x += 100;
		}
		mountainsG.endFill();
		var ox2 = mountainOff2 % 160;
		x = -ox2 - 80;
		mountainsG.beginFill(c2, 0.6);
		while (x < designW + 160) {
			mountainsG.moveTo(x, baseY);
			mountainsG.lineTo(x + 35, baseY - 35);
			mountainsG.lineTo(x + 70, baseY);
			x += 80;
		}
		mountainsG.endFill();
	}

	function drawGround() {
		groundG.clear();
		var nt = dayNightT();
		var lineDay = 0x535353;
		var lineNight = 0x888888;
		var lineC = lerpColor(lineDay, lineNight, nt);
		var groundDay = 0x8B7355;
		var groundNight = 0x3a3a50;
		var gC = lerpColor(groundDay, groundNight, nt);
		groundG.lineStyle(2, lineC);
		groundG.moveTo(0, GROUND_Y);
		groundG.lineTo(designW, GROUND_Y);
		groundG.lineStyle(0);
		groundG.beginFill(gC, 0.3);
		groundG.drawRect(0, GROUND_Y + 1, designW, 6);
		groundG.endFill();
		var ox = groundOffset % 40;
		groundG.beginFill(lineC, 0.15);
		var px = -ox;
		while (px < designW + 40) {
			var rw = 3 + (px * 7 % 5);
			groundG.drawRect(px, GROUND_Y + 3, rw, 2);
			px += 12 + (px * 3 % 8);
		}
		groundG.endFill();
	}

	function drawDino(y:Float) {
		dinoG.clear();
		var x = DINO_X;
		var nt = dayNightT();
		var bodyDay = 0x535353;
		var bodyNight = 0xCCCCCC;
		var body = lerpColor(bodyDay, bodyNight, nt);
		if (ducking) {
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x, y + 12, 36, 14, 3);
			dinoG.endFill();
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 28, y + 8, 14, 12, 2);
			dinoG.endFill();
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawCircle(x + 37, y + 12, 2.5);
			dinoG.endFill();
			dinoG.beginFill(0x000000);
			dinoG.drawCircle(x + 38, y + 12, 1.5);
			dinoG.endFill();
			dinoG.beginFill(body);
			if (runFrame) {
				dinoG.drawRect(x + 6, y + 24, 5, 6);
				dinoG.drawRect(x + 20, y + 22, 5, 4);
			} else {
				dinoG.drawRect(x + 6, y + 22, 5, 4);
				dinoG.drawRect(x + 20, y + 24, 5, 6);
			}
			dinoG.endFill();
		} else {
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 6, y + 16, 20, 22, 3);
			dinoG.endFill();
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 18, y + 4, 18, 16, 3);
			dinoG.endFill();
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawCircle(x + 30, y + 10, 3);
			dinoG.endFill();
			dinoG.beginFill(0x000000);
			dinoG.drawCircle(x + 31, y + 10, 1.8);
			dinoG.endFill();
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 16, y + 12, 6, 8, 1);
			dinoG.endFill();
			dinoG.beginFill(body);
			dinoG.drawRect(x, y + 22, 10, 7);
			dinoG.endFill();
			dinoG.beginFill(body);
			dinoG.drawRect(x + 8, y + 8, 4, 3);
			dinoG.drawRect(x + 4, y + 6, 4, 3);
			dinoG.endFill();
			dinoG.beginFill(body);
			if (runFrame) {
				dinoG.drawRect(x + 10, y + 36, 6, 10);
				dinoG.drawRect(x + 22, y + 36, 6, 6);
			} else {
				dinoG.drawRect(x + 10, y + 36, 6, 6);
				dinoG.drawRect(x + 22, y + 36, 6, 10);
			}
			dinoG.endFill();
		}
	}

	function drawPtero(ox:Float, oy:Float) {
		var g = obstaclesG;
		var nt = dayNightT();
		var c = lerpColor(0x5A5A5A, 0xBBBBBB, nt);
		g.beginFill(c);
		g.drawEllipse(ox + 15, oy + 12, 16, 8);
		g.endFill();
		g.beginFill(c);
		g.drawEllipse(ox + 28, oy + 10, 8, 6);
		g.endFill();
		g.beginFill(0xCC5533);
		g.drawRect(ox + 32, oy + 10, 8, 3);
		g.endFill();
		g.beginFill(0xFFFFFF);
		g.drawCircle(ox + 30, oy + 8, 2);
		g.endFill();
		g.beginFill(0x000000);
		g.drawCircle(ox + 31, oy + 8, 1);
		g.endFill();
		var wingPhase = Math.sin(haxe.Timer.stamp() * 12) * 0.5 + 0.5;
		var wingY = oy + 2 - wingPhase * 14;
		g.beginFill(c, 0.8);
		g.moveTo(ox + 8, oy + 8);
		g.lineTo(ox + 18, wingY);
		g.lineTo(ox + 28, oy + 8);
		g.endFill();
	}

	function drawCactus(ox:Float, oy:Float, tall:Bool) {
		var g = obstaclesG;
		var h = tall ? 52 : 36;
		g.beginFill(0x2D8B27);
		g.drawRoundedRect(ox + 2, oy, 14, h, 3);
		g.endFill();
		g.beginFill(0x1E7A1A);
		g.drawRoundedRect(ox + 4, oy + 2, 3, h - 4, 1);
		g.endFill();
		g.beginFill(0x2D8B27);
		g.drawRoundedRect(ox + 12, oy + 10, 12, 7, 2);
		g.drawRoundedRect(ox + 20, oy + 6, 6, 12, 2);
		g.endFill();
		g.beginFill(0x2D8B27);
		g.drawRoundedRect(ox - 8, oy + 18, 12, 7, 2);
		g.drawRoundedRect(ox - 8, oy + 14, 6, 12, 2);
		g.endFill();
		if (tall) {
			g.beginFill(0x2D8B27);
			g.drawRoundedRect(ox + 10, oy + 34, 10, 6, 2);
			g.drawRoundedRect(ox + 16, oy + 30, 6, 10, 2);
			g.endFill();
		}
	}

	function drawHighBar(ox:Float, oy:Float) {
		var g = obstaclesG;
		var nt = dayNightT();
		var c = lerpColor(0x6B5A4A, 0x8888AA, nt);
		g.beginFill(c);
		g.drawRect(ox, oy, HIGH_W, 10);
		g.endFill();
		g.lineStyle(1, lerpColor(0x3D3228, 0x666688, nt));
		g.drawRect(ox, oy, HIGH_W, 10);
		g.lineStyle(0);
		g.beginFill(c, 0.7);
		g.drawRect(ox + 3, oy + 10, 3, HIGH_H - 10);
		g.drawRect(ox + HIGH_W - 6, oy + 10, 3, HIGH_H - 10);
		g.endFill();
	}

	function spawnObstacle() {
		var r = Math.random();
		if (r < 0.38) {
			var tall = Math.random() > 0.5;
			var h = tall ? 52 : 36;
			obstacles.push({
				x: designW + 20, y: GROUND_Y - h, w: 22, h: h,
				tall: tall, scored: false, isBird: false, isHigh: false
			});
		} else if (r < 0.7) {
			obstacles.push({
				x: designW + 20, y: BIRD_Y, w: BIRD_W, h: BIRD_H,
				tall: false, scored: false, isBird: true, isHigh: false
			});
		} else {
			obstacles.push({
				x: designW + 20, y: HIGH_Y, w: HIGH_W, h: HIGH_H,
				tall: false, scored: false, isBird: false, isHigh: true
			});
		}
	}

	function drawObstacles() {
		obstaclesG.clear();
		for (o in obstacles) {
			if (o.isHigh)
				drawHighBar(o.x, o.y);
			else if (o.isBird)
				drawPtero(o.x, o.y);
			else
				drawCactus(o.x, o.y, o.tall);
		}
	}

	function hitObstacle():Bool {
		var dx = DINO_X + 8;
		var dw = DINO_W - 12;
		var dy:Float;
		var dh:Float;
		if (ducking) {
			dy = GROUND_Y - DINO_DUCK_H + 4;
			dh = DINO_DUCK_H - 8;
		} else {
			dy = dinoY + 10;
			dh = DINO_H - 14;
		}
		for (o in obstacles) {
			var ox = o.x + 3;
			var oy = o.y + 3;
			var ow = o.w - 6;
			var oh = o.h - 6;
			if (o.isBird) {
				if (ducking)
					continue;
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			} else if (o.isHigh) {
				if (ducking)
					continue;
				if (onGround())
					continue;
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			} else {
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			}
		}
		return false;
	}

	function formatScore(s:Int):String {
		var str = Std.string(s);
		while (str.length < 5)
			str = "0" + str;
		return str;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		dinoY = GROUND_Y - DINO_H;
		dinoVy = 0;
		started = false;
		score = 0;
		gameOver = false;
		deathTimer = -1;
		obstacles = [];
		spawnTimer = 1.0;
		groundOffset = 0;
		mountainOff1 = 0;
		mountainOff2 = 0;
		runFrame = false;
		runAnimTimer = 0;
		ducking = false;
		duckTimer = 0;
		fastFall = false;
		elapsed = 0;
		milestoneTimer = 0;
		scoreText.text = formatScore(0);
		hiText.text = if (hiScore > 0) "HI " + formatScore(hiScore) else "";
		instructText.visible = true;
		milestoneText.visible = false;
		flashG.clear();
		drawSky();
		drawMountains();
		drawGround();
		drawDino(dinoY);
		drawObstacles();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		obstacles = [];
	}

	public function getMinigameId():String
		return "dino-runner";

	public function getTitle():String
		return "Dino Run";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFFFFFF, (1 - t) * 0.4);
					flashG.drawRect(0, 0, designW, designH);
					flashG.endFill();
				} else {
					flashG.clear();
					if (score > hiScore)
						hiScore = score;
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (!started) {
			drawSky();
			drawMountains();
			drawGround();
			drawDino(dinoY);
			return;
		}

		elapsed += dt;
		var speed = currentSpeed();

		if (ducking) {
			duckTimer -= dt;
			if (duckTimer <= 0) {
				ducking = false;
				duckTimer = 0;
			}
			dinoY = GROUND_Y - DINO_DUCK_H;
			dinoVy = 0;
		} else {
			dinoVy += GRAVITY * dt;
			if (fastFall && dinoVy < FAST_FALL_VY)
				dinoVy = FAST_FALL_VY;
			dinoY += dinoVy * dt;
			if (dinoY >= GROUND_Y - DINO_H) {
				dinoY = GROUND_Y - DINO_H;
				dinoVy = 0;
				fastFall = false;
			}
		}

		runAnimTimer += dt;
		var animSpeed = 0.06 + (1 - speed / SPEED_MAX) * 0.04;
		if (runAnimTimer >= animSpeed) {
			runAnimTimer = 0;
			runFrame = !runFrame;
		}

		groundOffset += speed * dt;
		mountainOff1 += speed * 0.08 * dt;
		mountainOff2 += speed * 0.15 * dt;

		if (hitObstacle()) {
			gameOver = true;
			deathTimer = 0;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.3, 5);
			drawSky();
			drawMountains();
			drawGround();
			drawDino(dinoY);
			drawObstacles();
			return;
		}

		for (o in obstacles)
			o.x -= speed * dt;
		for (o in obstacles) {
			if (!o.scored && o.x + o.w < DINO_X) {
				o.scored = true;
				score++;
				scoreText.text = formatScore(score);
				if (score % MILESTONE == 0) {
					milestoneText.text = Std.string(score);
					milestoneText.visible = true;
					milestoneTimer = 1.2;
					milestoneText.alpha = 1;
				}
			}
		}
		while (obstacles.length > 0 && obstacles[0].x + 40 < 0)
			obstacles.shift();

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			var interval = SPAWN_MIN + Math.random() * (SPAWN_MAX - SPAWN_MIN);
			interval *= (SPEED_START / speed);
			spawnTimer = interval;
			spawnObstacle();
		}

		if (milestoneTimer > 0) {
			milestoneTimer -= dt;
			milestoneText.alpha = milestoneTimer / 1.2;
			milestoneText.y = GROUND_Y - 140 - (1 - milestoneTimer / 1.2) * 30;
			if (milestoneTimer <= 0)
				milestoneText.visible = false;
		}

		drawSky();
		drawMountains();
		drawGround();
		drawObstacles();
		drawDino(dinoY);
	}
}

private typedef Obstacle = {
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var tall:Bool;
	var scored:Bool;
	var isBird:Bool;
	var isHigh:Bool;
}
