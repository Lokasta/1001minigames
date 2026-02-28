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
	Dino Runner: swipe up = pular, swipe down = abaixar (segura).
	Cactos, pássaros, barras altas. Speed ramp, parallax, day/night, particles.
**/
class DinoRunner implements IMinigameSceneWithLose implements IMinigameUpdatable {
	// Design
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;

	// Physics
	static var GRAVITY = 1100;
	static var JUMP_VY = -440;
	static var FAST_FALL_VY = 700;
	static var GROUND_Y = 500;

	// Dino
	static var DINO_X = 60;
	static var DINO_W = 36;
	static var DINO_H = 44;
	static var DINO_DUCK_H = 24;

	// Speed ramp
	static var SPEED_START = 220.0;
	static var SPEED_MAX = 520.0;
	static var SPEED_RAMP_TIME = 120.0;

	// Spawn
	static var SPAWN_MIN = 0.7;
	static var SPAWN_MAX = 2.2;

	// Obstacle dimensions
	static var BIRD_W = 34;
	static var BIRD_H = 22;
	static var HIGH_W = 30;
	static var HIGH_H = 44;

	// Input
	static var SWIPE_THRESHOLD = 15;
	static var SWIPE_MAX_DUR = 0.5;

	// Timing
	static var DUCK_DURATION = 0.6;
	static var DEATH_DUR = 0.55;
	static var MILESTONE = 100;
	static var DAY_CYCLE = 45.0;

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	// Graphics layers (back to front)
	var skyG:Graphics;
	var cloudsG:Graphics;
	var mountainsG:Graphics;
	var groundG:Graphics;
	var particlesG:Graphics;
	var obstaclesG:Graphics;
	var dinoG:Graphics;
	var uiG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var hiText:Text;
	var instructText:Text;
	var milestoneText:Text;
	var interactive:Interactive;

	// State
	var dinoY:Float;
	var dinoVy:Float;
	var started:Bool;
	var score:Float;
	var displayScore:Int;
	var hiScore:Int;
	var obstacles:Array<Obstacle>;
	var spawnTimer:Float;
	var gameOver:Bool;
	var deathTimer:Float;
	var groundOffset:Float;
	var cloudOffset:Float;
	var mountainOff1:Float;
	var mountainOff2:Float;
	var runFrame:Bool;
	var runAnimTimer:Float;
	var ducking:Bool;
	var duckTimer:Float;
	var fastFall:Bool;
	var elapsed:Float;
	var milestoneTimer:Float;
	var lastMilestone:Int;

	// Input tracking
	var touchStartX:Float;
	var touchStartY:Float;
	var touchStartTime:Float;
	var touchDown:Bool;
	var swipeProcessed:Bool;

	// Particles
	var dustParticles:Array<Dust>;

	// Clouds
	var clouds:Array<Cloud>;

	// Landing squash
	var wasInAir:Bool;
	var landSquash:Float;

	// Near-miss flash
	var nearMissTimer:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		obstacles = [];
		dustParticles = [];
		clouds = [];
		hiScore = 0;

		skyG = new Graphics(contentObj);
		cloudsG = new Graphics(contentObj);
		mountainsG = new Graphics(contentObj);
		groundG = new Graphics(contentObj);
		particlesG = new Graphics(contentObj);
		obstaclesG = new Graphics(contentObj);
		dinoG = new Graphics(contentObj);
		uiG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "00000";
		scoreText.x = designW - 14;
		scoreText.y = 18;
		scoreText.scale(1.4);
		scoreText.textAlign = Right;
		scoreText.textColor = 0x535353;

		hiText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hiText.text = "";
		hiText.x = designW - 110;
		hiText.y = 18;
		hiText.scale(1.1);
		hiText.textAlign = Right;
		hiText.textColor = 0x888888;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Deslize pra cima: pular\nDeslize pra baixo: abaixar";
		instructText.x = designW / 2;
		instructText.y = GROUND_Y - 120;
		instructText.scale(1.1);
		instructText.textAlign = Center;
		instructText.textColor = 0x777777;
		instructText.visible = true;

		milestoneText = new Text(hxd.res.DefaultFont.get(), contentObj);
		milestoneText.text = "";
		milestoneText.x = designW / 2;
		milestoneText.y = GROUND_Y - 160;
		milestoneText.scale(2.2);
		milestoneText.textAlign = Center;
		milestoneText.textColor = 0x535353;
		milestoneText.visible = false;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = onTouchStart;
		interactive.onRelease = onTouchEnd;
		interactive.onReleaseOutside = onTouchEnd;
	}

	function onTouchStart(e:Event) {
		if (ctx == null || gameOver)
			return;
		touchStartX = e.relX;
		touchStartY = e.relY;
		touchStartTime = haxe.Timer.stamp();
		touchDown = true;
		swipeProcessed = false;
		e.propagate = false;
	}

	function onTouchEnd(e:Event) {
		if (gameOver || ctx == null)
			return;
		touchDown = false;
		// Check swipe
		var dur = haxe.Timer.stamp() - touchStartTime;
		if (!swipeProcessed && dur < SWIPE_MAX_DUR) {
			var dy = e.relY - touchStartY;
			var dx = e.relX - touchStartX;
			if (Math.abs(dy) > SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (dy < 0) {
					// Swipe UP → start game (if needed) + jump
					if (!started) {
						started = true;
						instructText.visible = false;
					}
					if (onGround() && !ducking) {
						dinoVy = JUMP_VY;
						spawnJumpDust();
					}
				} else {
					// Swipe DOWN → duck or fast fall
					if (!started) {
						started = true;
						instructText.visible = false;
					}
					if (onGround()) {
						ducking = true;
						duckTimer = DUCK_DURATION;
					} else {
						fastFall = true;
					}
				}
				swipeProcessed = true;
				e.propagate = false;
				return;
			}
		}
		e.propagate = false;
	}

	function currentSpeed():Float {
		var t = if (elapsed > SPEED_RAMP_TIME) 1.0 else elapsed / SPEED_RAMP_TIME;
		// Ease-out curve for smoother ramp
		t = 1.0 - (1.0 - t) * (1.0 - t);
		return SPEED_START + (SPEED_MAX - SPEED_START) * t;
	}

	inline function onGround():Bool
		return dinoY >= GROUND_Y - DINO_H - 1;

	function dayNightT():Float {
		var t = (elapsed % DAY_CYCLE) / DAY_CYCLE;
		// smooth sine wave: 0=day, 1=night
		return (1.0 - Math.cos(t * Math.PI * 2)) * 0.5;
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

	// ── Drawing ──────────────────────────────────────────────────

	function drawSky() {
		skyG.clear();
		var nt = dayNightT();
		var topDay = 0xE8F0FF;
		var botDay = 0xFFF5E6;
		var topNight = 0x0A0A1E;
		var botNight = 0x1A1A32;
		var topC = lerpColor(topDay, topNight, nt);
		var botC = lerpColor(botDay, botNight, nt);

		// Gradient sky
		var steps = 12;
		for (i in 0...steps) {
			var st = i / steps;
			var c = lerpColor(topC, botC, st);
			var yStart = Std.int(GROUND_Y * st);
			var yEnd = Std.int(GROUND_Y * (st + 1.0 / steps)) + 1;
			skyG.beginFill(c);
			skyG.drawRect(0, yStart, designW, yEnd - yStart);
			skyG.endFill();
		}
		// Below ground fill
		skyG.beginFill(botC);
		skyG.drawRect(0, GROUND_Y, designW, designH - GROUND_Y);
		skyG.endFill();

		// Stars at night
		if (nt > 0.3) {
			var sa = (nt - 0.3) / 0.7;
			var twinkle = Math.sin(elapsed * 3.0) * 0.2 + 0.8;
			skyG.beginFill(0xFFFFFF, sa * 0.7 * twinkle);
			skyG.drawCircle(45, 75, 1.5);
			skyG.drawCircle(125, 45, 1.2);
			skyG.drawCircle(195, 85, 1.5);
			skyG.drawCircle(265, 35, 1.0);
			skyG.drawCircle(305, 95, 1.5);
			skyG.drawCircle(75, 125, 1.2);
			skyG.drawCircle(245, 65, 1.0);
			skyG.drawCircle(155, 105, 1.5);
			skyG.drawCircle(330, 55, 1.0);
			skyG.drawCircle(20, 110, 1.2);
			skyG.endFill();
			// Moon
			skyG.beginFill(0xEEEECC, sa * 0.7);
			skyG.drawCircle(295, 55, 14);
			skyG.endFill();
			skyG.beginFill(topC);
			skyG.drawCircle(289, 49, 12);
			skyG.endFill();
		}

		// Sun during day
		if (nt < 0.4) {
			var sunA = (0.4 - nt) / 0.4;
			// Sun glow
			skyG.beginFill(0xFFDD44, sunA * 0.08);
			skyG.drawCircle(60, 70, 35);
			skyG.endFill();
			skyG.beginFill(0xFFEE66, sunA * 0.5);
			skyG.drawCircle(60, 70, 14);
			skyG.endFill();
			skyG.beginFill(0xFFF8CC, sunA * 0.8);
			skyG.drawCircle(60, 70, 10);
			skyG.endFill();
		}
	}

	function drawClouds() {
		cloudsG.clear();
		var nt = dayNightT();
		var cDay = 0xFFFFFF;
		var cNight = 0x333355;
		var c = lerpColor(cDay, cNight, nt);
		var alpha = if (nt > 0.5) 0.15 else 0.35;

		for (cl in clouds) {
			cloudsG.beginFill(c, alpha * cl.alpha);
			cloudsG.drawEllipse(cl.x, cl.y, cl.w, cl.h);
			cloudsG.drawEllipse(cl.x - cl.w * 0.4, cl.y + 3, cl.w * 0.7, cl.h * 0.8);
			cloudsG.drawEllipse(cl.x + cl.w * 0.3, cl.y + 2, cl.w * 0.6, cl.h * 0.7);
			cloudsG.endFill();
		}
	}

	function drawMountains() {
		mountainsG.clear();
		var nt = dayNightT();
		var baseY = GROUND_Y - 20;

		// Far mountains (slow parallax)
		var c1 = lerpColor(0xD8D0C0, 0x1E1E38, nt);
		var ox1 = mountainOff1 % 240;
		var x = -ox1 - 120.0;
		mountainsG.beginFill(c1, 0.4);
		while (x < designW + 240) {
			mountainsG.moveTo(x, baseY);
			mountainsG.lineTo(x + 60, baseY - 70);
			mountainsG.lineTo(x + 120, baseY);
			x += 120;
		}
		mountainsG.endFill();

		// Near mountains (faster parallax)
		var c2 = lerpColor(0xC8B8A0, 0x282848, nt);
		var ox2 = mountainOff2 % 180;
		x = -ox2 - 90;
		mountainsG.beginFill(c2, 0.5);
		while (x < designW + 180) {
			mountainsG.moveTo(x, baseY);
			mountainsG.lineTo(x + 40, baseY - 40);
			mountainsG.lineTo(x + 80, baseY);
			x += 90;
		}
		mountainsG.endFill();
	}

	function drawGround() {
		groundG.clear();
		var nt = dayNightT();
		var lineC = lerpColor(0x8B7B65, 0x666688, nt);
		var sandC = lerpColor(0xD4C4A8, 0x2A2A44, nt);
		var darkSand = lerpColor(0xBBA888, 0x222238, nt);

		// Ground fill
		groundG.beginFill(sandC, 0.4);
		groundG.drawRect(0, GROUND_Y, designW, designH - GROUND_Y);
		groundG.endFill();

		// Ground line
		groundG.lineStyle(2, lineC);
		groundG.moveTo(0, GROUND_Y);
		groundG.lineTo(designW, GROUND_Y);
		groundG.lineStyle(0);

		// Ground texture: pebbles and dashes
		var ox = groundOffset % 50;
		groundG.beginFill(lineC, 0.2);
		var px = -ox;
		var seed = 0;
		while (px < designW + 50) {
			seed = Std.int(Math.abs(px + 1000));
			var rw = 2 + (seed * 7) % 5;
			var ry = GROUND_Y + 3 + (seed * 3) % 4;
			groundG.drawRect(px, ry, rw, 2);
			px += 10 + (seed * 11) % 8;
		}
		groundG.endFill();

		// Deeper ground texture
		groundG.beginFill(darkSand, 0.15);
		px = -ox * 0.7;
		while (px < designW + 50) {
			seed = Std.int(Math.abs(px + 500));
			var rw = 1 + (seed * 5) % 3;
			groundG.drawRect(px, GROUND_Y + 8 + (seed * 7) % 6, rw, 1);
			px += 8 + (seed * 13) % 10;
		}
		groundG.endFill();
	}

	function drawDino(y:Float) {
		dinoG.clear();
		var x:Float = DINO_X;
		var nt = dayNightT();
		var body = lerpColor(0x4A4A4A, 0xDDDDDD, nt);
		var belly = lerpColor(0x5A5A5A, 0xCCCCCC, nt);
		var outline = lerpColor(0x333333, 0xEEEEEE, nt);

		// Landing squash effect
		var sy = 1.0;
		var sx = 1.0;
		if (landSquash > 0) {
			sy = 1.0 - landSquash * 0.15;
			sx = 1.0 + landSquash * 0.1;
		}

		if (ducking) {
			var duckY = GROUND_Y - DINO_DUCK_H;
			// Flat body
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x, duckY + 6, 40, 16, 4);
			dinoG.endFill();
			// Belly
			dinoG.beginFill(belly);
			dinoG.drawRoundedRect(x + 4, duckY + 12, 32, 8, 2);
			dinoG.endFill();
			// Head
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 30, duckY + 2, 16, 14, 3);
			dinoG.endFill();
			// Eye
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawCircle(x + 40, duckY + 7, 3);
			dinoG.endFill();
			dinoG.beginFill(0x111111);
			dinoG.drawCircle(x + 41, duckY + 7, 1.8);
			dinoG.endFill();
			// Legs (animated)
			dinoG.beginFill(body);
			if (runFrame) {
				dinoG.drawRect(x + 8, duckY + 20, 5, 5);
				dinoG.drawRect(x + 24, duckY + 18, 5, 3);
			} else {
				dinoG.drawRect(x + 8, duckY + 18, 5, 3);
				dinoG.drawRect(x + 24, duckY + 20, 5, 5);
			}
			dinoG.endFill();
			// Tail
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x - 8, duckY + 8, 12, 8, 2);
			dinoG.endFill();
		} else {
			var baseY = y;
			if (landSquash > 0) {
				baseY = y + DINO_H * (1 - sy);
			}
			// Tail (behind body)
			dinoG.beginFill(body);
			var tailWag = Math.sin(elapsed * 8) * 3;
			dinoG.drawRoundedRect(x - 6, baseY + 16 + tailWag, 14, 8, 3);
			dinoG.drawRoundedRect(x - 12, baseY + 14 + tailWag * 1.3, 10, 6, 3);
			dinoG.endFill();

			// Body
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 4 - (sx - 1) * 10, baseY + 12, Std.int(24 * sx), Std.int(26 * sy), 5);
			dinoG.endFill();

			// Belly (lighter)
			dinoG.beginFill(belly);
			dinoG.drawRoundedRect(x + 8, baseY + 18, 14, Std.int(16 * sy), 3);
			dinoG.endFill();

			// Arms
			var armAngle = Math.sin(elapsed * 10) * 4;
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 16, baseY + 18 + armAngle, 10, 4, 2);
			dinoG.endFill();

			// Head
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 16, baseY + 2, 20, 16, 4);
			dinoG.endFill();

			// Mouth
			dinoG.beginFill(body);
			dinoG.drawRoundedRect(x + 30, baseY + 8, 10, 6, 2);
			dinoG.endFill();

			// Eye (white + pupil)
			dinoG.beginFill(0xFFFFFF);
			dinoG.drawCircle(x + 30, baseY + 8, 3.5);
			dinoG.endFill();
			dinoG.beginFill(0x111111);
			dinoG.drawCircle(x + 31, baseY + 8, 2);
			dinoG.endFill();

			// Spikes on back
			dinoG.beginFill(body);
			dinoG.drawRect(x + 10, baseY + 10, 3, 4);
			dinoG.drawRect(x + 6, baseY + 8, 3, 4);
			dinoG.endFill();

			// Legs
			dinoG.beginFill(body);
			var legBase = baseY + Std.int(36 * sy);
			var legH = GROUND_Y - legBase;
			if (legH < 4) legH = 4;
			if (onGround()) {
				if (runFrame) {
					dinoG.drawRect(x + 8, legBase, 6, legH);
					dinoG.drawRect(x + 20, legBase, 6, legH - 3);
				} else {
					dinoG.drawRect(x + 8, legBase, 6, legH - 3);
					dinoG.drawRect(x + 20, legBase, 6, legH);
				}
			} else {
				// Tucked legs in air
				dinoG.drawRect(x + 10, legBase, 5, 6);
				dinoG.drawRect(x + 19, legBase, 5, 6);
			}
			dinoG.endFill();
		}
	}

	function drawPtero(ox:Float, oy:Float) {
		var g = obstaclesG;
		var nt = dayNightT();
		var c = lerpColor(0x5A4A3A, 0xBBAACC, nt);
		var beak = lerpColor(0xCC5533, 0xFF7755, nt);

		// Body
		g.beginFill(c);
		g.drawEllipse(ox + 15, oy + 12, 16, 8);
		g.endFill();
		// Head
		g.beginFill(c);
		g.drawEllipse(ox + 28, oy + 10, 8, 6);
		g.endFill();
		// Beak
		g.beginFill(beak);
		g.moveTo(ox + 34, oy + 8);
		g.lineTo(ox + 42, oy + 11);
		g.lineTo(ox + 34, oy + 13);
		g.endFill();
		// Eye
		g.beginFill(0xFFFFFF);
		g.drawCircle(ox + 30, oy + 8, 2.5);
		g.endFill();
		g.beginFill(0x111111);
		g.drawCircle(ox + 31, oy + 8, 1.2);
		g.endFill();
		// Wings (animated)
		var wingPhase = Math.sin(elapsed * 10) * 0.5 + 0.5;
		var wingY = oy + 2 - wingPhase * 16;
		g.beginFill(c, 0.85);
		g.moveTo(ox + 6, oy + 8);
		g.lineTo(ox + 15, wingY);
		g.lineTo(ox + 26, oy + 8);
		g.endFill();
		// Wing tip highlight
		g.beginFill(lerpColor(0x7A6A5A, 0xDDCCEE, nt), 0.4);
		g.moveTo(ox + 10, oy + 5);
		g.lineTo(ox + 15, wingY);
		g.lineTo(ox + 22, oy + 5);
		g.endFill();
	}

	function drawCactus(ox:Float, oy:Float, tall:Bool) {
		var g = obstaclesG;
		var h = tall ? 52 : 36;
		var darkGreen = 0x1E7A1A;
		var midGreen = 0x2D8B27;
		var lightGreen = 0x3A9E33;

		// Shadow
		g.beginFill(0x000000, 0.08);
		g.drawEllipse(ox + 9, GROUND_Y + 1, 14, 3);
		g.endFill();

		// Main trunk
		g.beginFill(midGreen);
		g.drawRoundedRect(ox + 2, oy, 14, h, 4);
		g.endFill();
		// Darker stripe
		g.beginFill(darkGreen);
		g.drawRoundedRect(ox + 4, oy + 3, 3, h - 6, 1);
		g.endFill();
		// Light stripe
		g.beginFill(lightGreen, 0.4);
		g.drawRoundedRect(ox + 10, oy + 3, 3, h - 6, 1);
		g.endFill();

		// Right arm
		g.beginFill(midGreen);
		g.drawRoundedRect(ox + 12, oy + 10, 12, 7, 3);
		g.drawRoundedRect(ox + 20, oy + 5, 6, 13, 3);
		g.endFill();
		// Left arm
		g.beginFill(midGreen);
		g.drawRoundedRect(ox - 8, oy + 18, 12, 7, 3);
		g.drawRoundedRect(ox - 8, oy + 13, 6, 13, 3);
		g.endFill();

		if (tall) {
			// Extra arm for tall cactus
			g.beginFill(midGreen);
			g.drawRoundedRect(ox + 10, oy + 32, 10, 6, 3);
			g.drawRoundedRect(ox + 16, oy + 28, 6, 12, 3);
			g.endFill();
		}

		// Spines (dots)
		g.beginFill(0x4AAA44, 0.5);
		g.drawCircle(ox + 1, oy + 8, 1);
		g.drawCircle(ox + 17, oy + 14, 1);
		g.drawCircle(ox + 1, oy + 22, 1);
		g.drawCircle(ox + 17, oy + 28, 1);
		g.endFill();
	}

	function drawHighBar(ox:Float, oy:Float) {
		var g = obstaclesG;
		var nt = dayNightT();
		var c = lerpColor(0x7B6A5A, 0x9999BB, nt);
		var dark = lerpColor(0x4D3E2E, 0x666688, nt);
		var stripe = lerpColor(0xFF4444, 0xFF6666, nt);

		// Shadow
		g.beginFill(0x000000, 0.06);
		g.drawEllipse(ox + HIGH_W / 2, GROUND_Y + 1, 16, 3);
		g.endFill();

		// Poles
		g.beginFill(c);
		g.drawRect(ox + 2, oy, 4, HIGH_H);
		g.drawRect(ox + HIGH_W - 6, oy, 4, HIGH_H);
		g.endFill();
		// Bar on top with stripes
		g.beginFill(c);
		g.drawRect(ox, oy, HIGH_W, 8);
		g.endFill();
		// Red/white danger stripes
		g.beginFill(stripe, 0.6);
		g.drawRect(ox + 2, oy + 1, 6, 6);
		g.drawRect(ox + 14, oy + 1, 6, 6);
		g.endFill();
		// Outline
		g.lineStyle(1, dark, 0.5);
		g.drawRect(ox, oy, HIGH_W, 8);
		g.lineStyle(0);
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

	function drawParticles() {
		particlesG.clear();
		for (p in dustParticles) {
			if (p.life <= 0) continue;
			var alpha = p.life / p.maxLife * 0.5;
			var nt = dayNightT();
			var c = lerpColor(0x9B8B75, 0x666688, nt);
			particlesG.beginFill(c, alpha);
			particlesG.drawCircle(p.x, p.y, p.size * (p.life / p.maxLife));
			particlesG.endFill();
		}
	}

	function drawUI() {
		uiG.clear();
		var nt = dayNightT();
		// Score background
		uiG.beginFill(lerpColor(0xFFFFFF, 0x111122, nt), 0.3);
		uiG.drawRoundedRect(designW - 90, 12, 82, 22, 6);
		uiG.endFill();

		if (hiScore > 0) {
			uiG.beginFill(lerpColor(0xFFFFFF, 0x111122, nt), 0.2);
			uiG.drawRoundedRect(designW - 190, 12, 90, 22, 6);
			uiG.endFill();
		}

		// Score text color update
		scoreText.textColor = lerpColor(0x535353, 0xDDDDDD, nt);
		hiText.textColor = lerpColor(0x888888, 0x999999, nt);
	}

	// ── Particles ────────────────────────────────────────────────

	function spawnJumpDust() {
		for (i in 0...6) {
			dustParticles.push({
				x: DINO_X + 15 + Math.random() * 10,
				y: GROUND_Y - 2,
				vx: -20 - Math.random() * 40,
				vy: -15 - Math.random() * 25,
				size: 2 + Math.random() * 3,
				life: 0.3 + Math.random() * 0.3,
				maxLife: 0.3 + Math.random() * 0.3
			});
		}
	}

	function spawnLandDust() {
		for (i in 0...5) {
			dustParticles.push({
				x: DINO_X + 10 + Math.random() * 16,
				y: GROUND_Y - 1,
				vx: (Math.random() - 0.5) * 50,
				vy: -10 - Math.random() * 20,
				size: 2 + Math.random() * 2.5,
				life: 0.25 + Math.random() * 0.2,
				maxLife: 0.25 + Math.random() * 0.2
			});
		}
	}

	function spawnRunDust() {
		if (Math.random() > 0.3) return;
		dustParticles.push({
			x: DINO_X + 12 + Math.random() * 6,
			y: GROUND_Y - 1,
			vx: -15 - Math.random() * 20,
			vy: -5 - Math.random() * 10,
			size: 1.5 + Math.random() * 1.5,
			life: 0.2 + Math.random() * 0.15,
			maxLife: 0.2 + Math.random() * 0.15
		});
	}

	function updateParticles(dt:Float) {
		var i = dustParticles.length;
		while (i-- > 0) {
			var p = dustParticles[i];
			p.life -= dt;
			if (p.life <= 0) {
				dustParticles.splice(i, 1);
				continue;
			}
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vy += 50 * dt; // gravity on particles
		}
	}

	// ── Clouds ───────────────────────────────────────────────────

	function initClouds() {
		clouds = [];
		for (i in 0...5) {
			clouds.push({
				x: Math.random() * designW,
				y: 30 + Math.random() * 120,
				w: 25 + Math.random() * 30,
				h: 8 + Math.random() * 8,
				speed: 8 + Math.random() * 15,
				alpha: 0.4 + Math.random() * 0.4
			});
		}
	}

	function updateClouds(dt:Float, speed:Float) {
		for (cl in clouds) {
			cl.x -= (cl.speed + speed * 0.02) * dt;
			if (cl.x + cl.w * 2 < 0) {
				cl.x = designW + cl.w;
				cl.y = 30 + Math.random() * 120;
				cl.w = 25 + Math.random() * 30;
				cl.h = 8 + Math.random() * 8;
				cl.alpha = 0.4 + Math.random() * 0.4;
			}
		}
	}

	// ── Spawning ─────────────────────────────────────────────────

	function spawnObstacle() {
		var speed = currentSpeed();
		var difficulty = Math.min(elapsed / SPEED_RAMP_TIME, 1.0);
		var r = Math.random();

		// More variety as difficulty increases
		var birdChance = 0.25 + difficulty * 0.15;
		var highChance = 0.1 + difficulty * 0.15;
		var doubleChance = difficulty * 0.3;

		if (r < birdChance) {
			// Bird at varying heights
			var birdY = 460 - Std.int(Math.random() * 50 * difficulty);
			obstacles.push({
				x: designW + 20.0, y: birdY, w: BIRD_W, h: BIRD_H,
				tall: false, scored: false, isBird: true, isHigh: false
			});
		} else if (r < birdChance + highChance && elapsed > 15) {
			var highY = 365 + Std.int(Math.random() * 20);
			obstacles.push({
				x: designW + 20.0, y: highY, w: HIGH_W, h: HIGH_H,
				tall: false, scored: false, isBird: false, isHigh: true
			});
		} else {
			var tall = Math.random() > 0.45;
			var h = tall ? 52 : 36;
			obstacles.push({
				x: designW + 20.0, y: GROUND_Y - h, w: 22, h: h,
				tall: tall, scored: false, isBird: false, isHigh: false
			});
			// Double cactus cluster at higher difficulty
			if (Math.random() < doubleChance) {
				var gap = 25 + Math.random() * 15;
				var tall2 = Math.random() > 0.6;
				var h2 = tall2 ? 52 : 36;
				obstacles.push({
					x: designW + 20.0 + gap, y: GROUND_Y - h2, w: 22, h: h2,
					tall: tall2, scored: false, isBird: false, isHigh: false
				});
			}
		}
	}

	// ── Collision ────────────────────────────────────────────────

	function hitObstacle():Bool {
		var dx = DINO_X + 8;
		var dw = DINO_W - 14;
		var dy:Float;
		var dh:Float;
		if (ducking) {
			dy = GROUND_Y - DINO_DUCK_H + 4;
			dh = DINO_DUCK_H - 8;
		} else {
			dy = dinoY + 8;
			dh = DINO_H - 12;
		}
		for (o in obstacles) {
			var ox = o.x + 4;
			var oy = o.y + 4;
			var ow = o.w - 8;
			var oh = o.h - 8;
			if (o.isBird) {
				if (ducking)
					continue;
				if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh)
					return true;
			} else if (o.isHigh) {
				if (ducking || onGround())
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

	function checkNearMiss() {
		var dx = DINO_X + 4;
		var dw = DINO_W - 4;
		var dy = if (ducking) GROUND_Y - DINO_DUCK_H else dinoY;
		var dh = if (ducking) DINO_DUCK_H else DINO_H;
		var margin = 12.0;
		for (o in obstacles) {
			if (o.scored) continue;
			// Near miss = within margin but not colliding
			var ox = o.x - margin;
			var ow = o.w + margin * 2;
			var oy = o.y - margin;
			var oh = o.h + margin * 2;
			if (dx + dw > ox && dx < ox + ow && dy + dh > oy && dy < oy + oh) {
				if (!hitObstacle()) {
					nearMissTimer = 0.15;
					return;
				}
			}
		}
	}

	// ── Format ───────────────────────────────────────────────────

	function formatScore(s:Int):String {
		var str = Std.string(s);
		while (str.length < 5)
			str = "0" + str;
		return str;
	}

	// ── Interface ────────────────────────────────────────────────

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		dinoY = GROUND_Y - DINO_H;
		dinoVy = 0;
		started = false;
		score = 0;
		displayScore = 0;
		gameOver = false;
		deathTimer = -1;
		obstacles = [];
		dustParticles = [];
		spawnTimer = 1.2;
		groundOffset = 0;
		cloudOffset = 0;
		mountainOff1 = 0;
		mountainOff2 = 0;
		runFrame = false;
		runAnimTimer = 0;
		ducking = false;
		duckTimer = 0;
		fastFall = false;
		elapsed = 0;
		milestoneTimer = 0;
		lastMilestone = 0;
		touchDown = false;
		swipeProcessed = false;
		wasInAir = false;
		landSquash = 0;
		nearMissTimer = 0;
		scoreText.text = formatScore(0);
		hiText.text = if (hiScore > 0) "HI " + formatScore(hiScore) else "";
		instructText.visible = true;
		milestoneText.visible = false;
		flashG.clear();
		initClouds();
		drawSky();
		drawClouds();
		drawMountains();
		drawGround();
		drawDino(dinoY);
		drawObstacles();
		drawParticles();
		drawUI();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		obstacles = [];
		dustParticles = [];
		clouds = [];
	}

	public function getMinigameId():String
		return "dino-runner";

	public function getTitle():String
		return "Dino Run";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		// Death animation
		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFFFFFF, (1 - t) * 0.5);
					flashG.drawRect(0, 0, designW, designH);
					flashG.endFill();
				} else {
					flashG.clear();
					if (displayScore > hiScore)
						hiScore = displayScore;
					ctx.lose(displayScore, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		// Waiting to start
		if (!started) {
			// Breathing animation on instruction text
			instructText.alpha = 0.5 + 0.3 * Math.sin(elapsed * 2);
			elapsed += dt;
			drawSky();
			drawClouds();
			drawMountains();
			drawGround();
			drawDino(dinoY);
			return;
		}

		elapsed += dt;
		var speed = currentSpeed();

		// Score by distance
		score += speed * dt * 0.04;
		displayScore = Std.int(score);
		scoreText.text = formatScore(displayScore);

		// Milestone check
		var currentMilestone = Std.int(displayScore / MILESTONE) * MILESTONE;
		if (currentMilestone > lastMilestone && currentMilestone > 0) {
			lastMilestone = currentMilestone;
			milestoneText.text = Std.string(currentMilestone);
			milestoneText.visible = true;
			milestoneTimer = 1.5;
			milestoneText.alpha = 1;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.flash(0.08);
		}

		// Ducking: timer-based
		if (ducking) {
			duckTimer -= dt;
			if (duckTimer <= 0) {
				ducking = false;
				duckTimer = 0;
			}
		}

		// Physics
		if (ducking) {
			dinoY = GROUND_Y - DINO_DUCK_H;
			dinoVy = 0;
		} else {
			dinoVy += GRAVITY * dt;
			if (fastFall && dinoVy < FAST_FALL_VY)
				dinoVy = FAST_FALL_VY;
			dinoY += dinoVy * dt;
			if (dinoY >= GROUND_Y - DINO_H) {
				dinoY = GROUND_Y - DINO_H;
				if (wasInAir) {
					spawnLandDust();
					landSquash = 1.0;
				}
				dinoVy = 0;
				fastFall = false;
			}
		}

		// Track air state
		var inAir = !onGround() && !ducking;
		wasInAir = inAir;

		// Landing squash decay
		if (landSquash > 0) {
			landSquash -= dt * 6;
			if (landSquash < 0) landSquash = 0;
		}

		// Run animation
		if (onGround() && !ducking) {
			runAnimTimer += dt;
			var animSpeed = 0.07 + (1 - speed / SPEED_MAX) * 0.05;
			if (runAnimTimer >= animSpeed) {
				runAnimTimer = 0;
				runFrame = !runFrame;
			}
			spawnRunDust();
		} else if (ducking) {
			runAnimTimer += dt;
			if (runAnimTimer >= 0.08) {
				runAnimTimer = 0;
				runFrame = !runFrame;
			}
		}

		// Near miss check
		if (nearMissTimer > 0) {
			nearMissTimer -= dt;
		} else {
			checkNearMiss();
		}

		// Scroll
		groundOffset += speed * dt;
		mountainOff1 += speed * 0.06 * dt;
		mountainOff2 += speed * 0.12 * dt;
		updateClouds(dt, speed);
		updateParticles(dt);

		// Collision
		if (hitObstacle()) {
			gameOver = true;
			deathTimer = 0;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.35, 6);
			drawSky();
			drawClouds();
			drawMountains();
			drawGround();
			drawDino(dinoY);
			drawObstacles();
			drawParticles();
			drawUI();
			return;
		}

		// Move obstacles
		for (o in obstacles)
			o.x -= speed * dt;
		// Score from passing obstacles (bonus)
		for (o in obstacles) {
			if (!o.scored && o.x + o.w < DINO_X) {
				o.scored = true;
			}
		}
		while (obstacles.length > 0 && obstacles[0].x + 50 < 0)
			obstacles.shift();

		// Spawn
		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			var interval = SPAWN_MIN + Math.random() * (SPAWN_MAX - SPAWN_MIN);
			interval *= (SPEED_START / speed);
			spawnTimer = interval;
			spawnObstacle();
		}

		// Milestone text fade
		if (milestoneTimer > 0) {
			milestoneTimer -= dt;
			milestoneText.alpha = milestoneTimer / 1.5;
			milestoneText.y = GROUND_Y - 160 - (1 - milestoneTimer / 1.5) * 30;
			if (milestoneTimer <= 0)
				milestoneText.visible = false;
		}

		// Draw everything
		drawSky();
		drawClouds();
		drawMountains();
		drawGround();
		drawParticles();
		drawObstacles();
		drawDino(dinoY);
		drawUI();
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

private typedef Dust = {
	var x:Float;
	var y:Float;
	var vx:Float;
	var vy:Float;
	var size:Float;
	var life:Float;
	var maxLife:Float;
}

private typedef Cloud = {
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var speed:Float;
	var alpha:Float;
}
