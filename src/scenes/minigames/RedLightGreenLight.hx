package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class RedLightGreenLight implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;

	// Track
	static var TRACK_LEFT = 30.0;
	static var TRACK_RIGHT = 330.0;
	static var TRACK_TOP = 100.0;
	static var TRACK_BOTTOM = 540.0;
	static var FINISH_Y = 120.0;

	// Player
	static var PLAYER_START_Y = 520.0;
	static var RUN_SPEED = 120.0; // px/s while holding

	// Light timing
	static var GREEN_MIN = 1.5;
	static var GREEN_MAX = 4.0;
	static var RED_MIN = 1.5;
	static var RED_MAX = 3.0;
	static var WARNING_TIME = 0.6; // yellow warning before red

	// Doll
	static var DOLL_X = 180.0;
	static var DOLL_Y = 80.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var scoreBg:Graphics;
	var trackG:Graphics;
	var playerG:Graphics;
	var dollG:Graphics;
	var lightG:Graphics;
	var rivalG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var totalTime:Float;

	// Player state
	var playerY:Float;
	var holding:Bool; // is the player pressing/holding?
	var moving:Bool; // is the player actually moving? (animation state)

	// Light state: 0=green, 1=yellow(warning), 2=red
	var lightState:Int;
	var lightTimer:Float;
	var lightDuration:Float;

	// Death animation
	var deathTimer:Float;
	var caughtMoving:Bool;

	// Rivals (NPCs that run alongside)
	var rivals:Array<{y:Float, speed:Float, alive:Bool, deathTimer:Float}>;

	// Round tracking
	var roundsCompleted:Int;
	var playerSpeed:Float;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	function get_content():Object
		return contentObj;

	public function new() {
		contentObj = new Object();
		rng = new hxd.Rand(42);

		bg = new Graphics(contentObj);
		scoreBg = new Graphics(contentObj);
		trackG = new Graphics(contentObj);
		rivalG = new Graphics(contentObj);
		playerG = new Graphics(contentObj);
		dollG = new Graphics(contentObj);
		lightG = new Graphics(contentObj);

		var font = hxd.res.DefaultFont.get();
		scoreText = new Text(font, contentObj);
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 18;
		scoreText.scale(2.2);
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(font, contentObj);
		instructText.textAlign = Center;
		instructText.x = DESIGN_W / 2;
		instructText.y = 590;
		instructText.scale(0.95);
		instructText.textColor = 0xFFEEDD;
		instructText.text = "HOLD to run · RELEASE on RED!";
		instructText.alpha = 0;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(_) onPress();
		interactive.onRelease = function(_) onRelease();
		interactive.onReleaseOutside = function(_) onRelease();

		rivals = [];
		score = 0;
		gameOver = true;
		started = false;
		totalTime = 0;
		holding = false;
		moving = false;
		deathTimer = 0;
		caughtMoving = false;
		roundsCompleted = 0;
		playerSpeed = RUN_SPEED;
	}

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start():Void {
		score = 0;
		gameOver = false;
		started = false;
		totalTime = 0;
		holding = false;
		moving = false;
		deathTimer = 0;
		caughtMoving = false;
		roundsCompleted = 0;
		playerSpeed = RUN_SPEED;
		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		playerY = PLAYER_START_Y;

		// Start with green light
		lightState = 0;
		lightDuration = GREEN_MIN + rng.random(Std.int((GREEN_MAX - GREEN_MIN) * 10)) / 10.0;
		lightTimer = lightDuration;

		// Spawn rivals
		rivals = [];
		for (i in 0...5) {
			var rx = TRACK_LEFT + 30 + i * 55;
			rivals.push({
				y: PLAYER_START_Y + rng.random(20) - 10,
				speed: 60.0 + rng.random(60),
				alive: true,
				deathTimer: 0
			});
		}

		scoreText.text = "0";
		instructText.alpha = 1.0;

		drawBg();
		drawAll();
	}

	function drawBg():Void {
		bg.clear();
		// Sky gradient (warm stadium feel)
		bg.beginFill(0x1A2840);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		bg.beginFill(0x2A3850);
		bg.drawRect(0, 0, DESIGN_W, 180);
		bg.endFill();
		bg.beginFill(0x3D4A60, 0.9);
		bg.drawRect(0, 0, DESIGN_W, 120);
		bg.endFill();
		bg.beginFill(0x5A6A80, 0.4);
		bg.drawRect(0, 0, DESIGN_W, 60);
		bg.endFill();
		// Grass strips (sides)
		bg.beginFill(0x1A3D1A);
		bg.drawRect(0, 90, DESIGN_W, DESIGN_H - 90);
		bg.endFill();
		bg.beginFill(0x2A5A2A);
		bg.drawRect(0, 90, TRACK_LEFT, DESIGN_H - 90);
		bg.drawRect(TRACK_RIGHT, 90, DESIGN_W - TRACK_RIGHT, DESIGN_H - 90);
		bg.endFill();
		// Track (running lane) - dark strip
		bg.beginFill(0x252A20);
		bg.drawRect(TRACK_LEFT, TRACK_TOP, TRACK_RIGHT - TRACK_LEFT, TRACK_BOTTOM - TRACK_TOP);
		bg.endFill();
		bg.beginFill(0x353A30);
		bg.drawRect(TRACK_LEFT + 4, TRACK_TOP, TRACK_RIGHT - TRACK_LEFT - 8, TRACK_BOTTOM - TRACK_TOP);
		bg.endFill();
		// Lane lines (horizontal)
		bg.beginFill(0x4A5540, 0.8);
		for (ly in 0...10) {
			var laneY = TRACK_TOP + 20 + ly * 44;
			if (laneY < TRACK_BOTTOM - 5)
				bg.drawRect(TRACK_LEFT + 8, Std.int(laneY), TRACK_RIGHT - TRACK_LEFT - 16, 2);
		}
		bg.endFill();
		// Finish line: checkered + glow
		var cs = 12;
		var fy = Std.int(FINISH_Y);
		bg.beginFill(0x000000, 0.3);
		bg.drawRect(0, fy - 2, DESIGN_W, cs * 2 + 4);
		bg.endFill();
		for (cx in 0...Std.int(DESIGN_W / cs) + 1) {
			for (cy in 0...2) {
				var isWhite = (cx + cy) % 2 == 0;
				bg.beginFill(isWhite ? 0xFFFFFF : 0x1A1A1A);
				bg.drawRect(cx * cs, fy + cy * cs, cs, cs);
				bg.endFill();
			}
		}
		bg.beginFill(0xFFFFFF, 0.15);
		bg.drawRect(0, fy + cs * 2, DESIGN_W, 8);
		bg.endFill();
		// Vignette
		bg.beginFill(0x000000, 0.35);
		bg.drawRect(0, 0, DESIGN_W, 50);
		bg.drawRect(0, DESIGN_H - 80, DESIGN_W, 80);
		bg.drawRect(0, 0, 45, DESIGN_H);
		bg.drawRect(DESIGN_W - 45, 0, 45, DESIGN_H);
		bg.endFill();
	}

	function drawAll():Void {
		drawDoll();
		drawLight();
		drawRivals();
		drawPlayer();
	}

	function drawScorePill():Void {
		scoreBg.clear();
		scoreBg.beginFill(0x000000, 0.45);
		scoreBg.drawRoundedRect(DESIGN_W / 2 - 40, 8, 80, 36, 18);
		scoreBg.endFill();
		scoreBg.beginFill(0x3388DD, 0.2);
		scoreBg.drawRoundedRect(DESIGN_W / 2 - 40, 8, 80, 36, 18);
		scoreBg.endFill();
	}

	function drawDoll():Void {
		dollG.clear();
		var dx = DOLL_X;
		var dy = DOLL_Y;

		// Shadow under doll
		dollG.beginFill(0x000000, 0.25);
		dollG.drawCircle(dx, dy + 28, 18);
		dollG.endFill();

		if (lightState == 2) {
			// RED LIGHT — facing you (front)
			// Dress: body + shine
			dollG.beginFill(0x994422);
			dollG.drawRect(dx - 16, dy - 8, 32, 32);
			dollG.endFill();
			dollG.beginFill(0xCC6633);
			dollG.drawRect(dx - 15, dy - 7, 30, 30);
			dollG.endFill();
			dollG.beginFill(0xE08044, 0.6);
			dollG.drawRect(dx - 14, dy - 6, 10, 28);
			dollG.endFill();
			// Head
			dollG.beginFill(0xE8B898);
			dollG.drawCircle(dx, dy - 20, 13);
			dollG.endFill();
			// Hair (black bob + buns)
			dollG.beginFill(0x1A1A1A);
			dollG.drawRect(dx - 13, dy - 33, 26, 12);
			dollG.drawCircle(dx - 15, dy - 24, 6);
			dollG.drawCircle(dx + 15, dy - 24, 6);
			dollG.endFill();
			// Eyes: menacing + red glow
			dollG.beginFill(0xFF2222, 0.5);
			dollG.drawCircle(dx - 5, dy - 20, 6);
			dollG.drawCircle(dx + 5, dy - 20, 6);
			dollG.endFill();
			dollG.beginFill(0x000000);
			dollG.drawCircle(dx - 5, dy - 20, 2.5);
			dollG.drawCircle(dx + 5, dy - 20, 2.5);
			dollG.endFill();
			dollG.beginFill(0xFF4444, 0.25);
			dollG.drawCircle(dx, dy - 20, 20);
			dollG.endFill();
		} else {
			// GREEN — back view
			dollG.beginFill(0x994422);
			dollG.drawRect(dx - 16, dy - 8, 32, 32);
			dollG.endFill();
			dollG.beginFill(0xCC6633);
			dollG.drawRect(dx - 15, dy - 7, 30, 30);
			dollG.endFill();
			dollG.beginFill(0xAA5522, 0.5);
			dollG.drawRect(dx + 4, dy - 6, 10, 28);
			dollG.endFill();
			// Back of head (hair)
			dollG.beginFill(0x1A1A1A);
			dollG.drawCircle(dx, dy - 20, 13);
			dollG.drawCircle(dx - 15, dy - 24, 6);
			dollG.drawCircle(dx + 15, dy - 24, 6);
			dollG.endFill();
		}

		// Legs (same both sides)
		dollG.beginFill(0xE8B898);
		dollG.drawRect(dx - 9, dy + 22, 6, 14);
		dollG.drawRect(dx + 3, dy + 22, 6, 14);
		dollG.endFill();
		dollG.beginFill(0xCC9966);
		dollG.drawRect(dx - 9, dy + 22, 6, 4);
		dollG.drawRect(dx + 3, dy + 22, 6, 4);
		dollG.endFill();
	}

	function drawLight():Void {
		lightG.clear();
		var lx = 308.0;
		var ly = 18.0;

		// Housing: rounded dark + bevel
		lightG.beginFill(0x1A1A1A);
		lightG.drawRoundedRect(lx - 16, ly - 2, 32, 56, 6);
		lightG.endFill();
		lightG.beginFill(0x2A2A2A);
		lightG.drawRoundedRect(lx - 15, ly - 1, 30, 54, 5);
		lightG.endFill();
		lightG.beginFill(0x333333);
		lightG.drawRoundedRect(lx - 14, ly, 28, 50, 4);
		lightG.endFill();

		// Red bulb
		lightG.beginFill(lightState == 2 ? 0x661111 : 0x220808);
		lightG.drawCircle(lx, ly + 12, 9);
		lightG.endFill();
		lightG.beginFill(lightState == 2 ? 0xFF3333 : 0x441111);
		lightG.drawCircle(lx, ly + 12, 8);
		lightG.endFill();
		if (lightState == 2) {
			lightG.beginFill(0xFF6666, 0.5);
			lightG.drawCircle(lx, ly + 12, 12);
			lightG.endFill();
			lightG.beginFill(0xFFAAAA, 0.4);
			lightG.drawCircle(lx - 2, ly + 10, 3);
			lightG.endFill();
		}

		// Yellow
		lightG.beginFill(lightState == 1 ? 0x665500 : 0x221100);
		lightG.drawCircle(lx, ly + 28, 9);
		lightG.endFill();
		lightG.beginFill(lightState == 1 ? 0xFFDD00 : 0x443300);
		lightG.drawCircle(lx, ly + 28, 8);
		lightG.endFill();
		if (lightState == 1) {
			var pulse = 0.5 + Math.sin(totalTime * 12) * 0.15;
			lightG.beginFill(0xFFEE44, pulse);
			lightG.drawCircle(lx, ly + 28, 12);
			lightG.endFill();
		}

		// Green
		lightG.beginFill(lightState == 0 ? 0x115511 : 0x081808);
		lightG.drawCircle(lx, ly + 44, 9);
		lightG.endFill();
		lightG.beginFill(lightState == 0 ? 0x44FF44 : 0x113311);
		lightG.drawCircle(lx, ly + 44, 8);
		lightG.endFill();
		if (lightState == 0) {
			lightG.beginFill(0x88FF88, 0.4);
			lightG.drawCircle(lx, ly + 44, 12);
			lightG.endFill();
			lightG.beginFill(0xCCFFCC, 0.35);
			lightG.drawCircle(lx - 2, ly + 42, 3);
			lightG.endFill();
		}

		// State bar (pill at bottom)
		var barY = DESIGN_H - 52;
		var barH = 36;
		var barW = DESIGN_W - 40;
		var barX = 20;
		var barColor = lightState == 0 ? 0x22AA22 : (lightState == 1 ? 0xCC9900 : 0xCC2222);
		var barDark = lightState == 0 ? 0x116611 : (lightState == 1 ? 0x664400 : 0x661111);
		lightG.beginFill(0x000000, 0.35);
		lightG.drawRoundedRect(barX - 2, barY - 2, barW + 4, barH + 4, 20);
		lightG.endFill();
		lightG.beginFill(barDark);
		lightG.drawRoundedRect(barX, barY, barW, barH, 18);
		lightG.endFill();
		lightG.beginFill(barColor);
		lightG.drawRoundedRect(barX, barY, barW, barH - 4, 18);
		lightG.endFill();
		lightG.beginFill(0xFFFFFF, 0.2);
		lightG.drawRoundedRect(barX, barY, barW, 6, 4);
		lightG.endFill();
	}

	function drawRivals():Void {
		rivalG.clear();
		var colors = [0x886622, 0x668844, 0x446688, 0x884466, 0x668866];
		for (i in 0...rivals.length) {
			var r = rivals[i];
			var rx = TRACK_LEFT + 30 + i * 55;
			if (rx > 150 && rx < 220) rx += 28;

			if (!r.alive) {
				if (r.deathTimer > 0) {
					rivalG.beginFill(0x440000, r.deathTimer * 0.5);
					rivalG.drawCircle(rx, r.y - 6, 14);
					rivalG.endFill();
					rivalG.beginFill(0xFF3344, r.deathTimer);
					rivalG.drawRect(rx - 8, r.y - 18, 16, 24);
					rivalG.endFill();
					rivalG.beginFill(0x000000);
					rivalG.drawRect(rx - 10, r.y - 14, 4, 20);
					rivalG.drawRect(rx + 6, r.y - 14, 4, 20);
					rivalG.drawRect(rx - 2, r.y - 18, 4, 24);
					rivalG.endFill();
				}
				continue;
			}

			var col = colors[i % colors.length];
			// Shadow
			rivalG.beginFill(0x000000, 0.2);
			rivalG.drawCircle(rx, r.y + 14, 8);
			rivalG.endFill();
			// Body (shirt)
			rivalG.beginFill(col);
			rivalG.drawRect(rx - 5, r.y - 12, 10, 16);
			rivalG.endFill();
			var hr = Std.int(Math.min(255, (col >> 16 & 0xFF) + 45));
			var hg = Std.int(Math.min(255, (col >> 8 & 0xFF) + 35));
			var hb = Std.int(Math.min(255, (col & 0xFF) + 25));
			rivalG.beginFill((hr << 16) | (hg << 8) | hb, 0.6);
			rivalG.drawRect(rx - 5, r.y - 12, 4, 16);
			rivalG.endFill();
			// Head
			rivalG.beginFill(0xE0C0A0);
			rivalG.drawCircle(rx, r.y - 16, 5);
			rivalG.endFill();
			// Legs
			rivalG.beginFill(0x554433);
			rivalG.drawRect(rx - 5, r.y + 4, 3, 9);
			rivalG.drawRect(rx + 2, r.y + 4, 3, 9);
			rivalG.endFill();
		}
	}

	function drawPlayer():Void {
		playerG.clear();
		var px = 180.0;
		var py = playerY;

		if (caughtMoving && deathTimer > 0) {
			playerG.beginFill(0x330000, deathTimer * 0.6);
			playerG.drawCircle(px, py - 4, 16);
			playerG.endFill();
			playerG.beginFill(0xFF2244, deathTimer);
			playerG.drawRect(px - 8, py - 18, 16, 28);
			playerG.endFill();
			return;
		}

		// Shadow
		playerG.beginFill(0x000000, 0.25);
		playerG.drawCircle(px, py + 14, 10);
		playerG.endFill();
		// Body (blue jersey)
		playerG.beginFill(0x2266AA);
		playerG.drawRect(px - 6, py - 14, 12, 18);
		playerG.endFill();
		playerG.beginFill(0x3388DD);
		playerG.drawRect(px - 6, py - 14, 5, 18);
		playerG.endFill();
		// Number
		playerG.beginFill(0xFFFFFF);
		playerG.drawRect(px - 3, py - 10, 6, 8);
		playerG.endFill();
		playerG.beginFill(0x2266AA);
		playerG.drawRect(px - 1, py - 8, 2, 4);
		playerG.endFill();
		// Head
		playerG.beginFill(0xF0D0A8);
		playerG.drawCircle(px, py - 18, 6);
		playerG.endFill();
		playerG.beginFill(0xFFEEDD, 0.5);
		playerG.drawCircle(px - 1, py - 19, 2);
		playerG.endFill();
		// Legs
		playerG.beginFill(0x2A4A7A);
		if (moving && lightState == 0) {
			var t = totalTime * 14;
			var l1 = 4 + Math.sin(t) * 4;
			var l2 = 4 - Math.sin(t) * 4;
			playerG.drawRect(px - 5, py + 4, 3, l1);
			playerG.drawRect(px + 2, py + 4, 3, l2);
		} else {
			playerG.drawRect(px - 5, py + 4, 3, 8);
			playerG.drawRect(px + 2, py + 4, 3, 8);
		}
		playerG.endFill();
	}

	function onPress():Void {
		if (gameOver) return;

		if (!started) {
			started = true;
			instructText.alpha = 0;
		}

		holding = true;
	}

	function onRelease():Void {
		holding = false;
	}

	public function update(dt:Float):Void {
		if (gameOver && !started) {
			if (instructText.alpha < 1.0) {
				instructText.alpha = Math.min(1.0, instructText.alpha + dt * 2.0);
			}
			drawScorePill();
			return;
		}

		if (gameOver) {
			deathTimer -= dt * 2.0;
			if (deathTimer < 0) deathTimer = 0;
			drawScorePill();
			drawPlayer();
			drawRivals();
			return;
		}

		totalTime += dt;

		// Light state machine
		lightTimer -= dt;
		if (lightTimer <= 0) {
			if (lightState == 0) {
				// Green → Yellow (warning)
				lightState = 1;
				lightTimer = WARNING_TIME;
			} else if (lightState == 1) {
				// Yellow → Red
				lightState = 2;
				lightTimer = RED_MIN + rng.random(Std.int((RED_MAX - RED_MIN) * 10)) / 10.0;
			} else {
				// Red → Green
				lightState = 0;
				// Shorter green as rounds progress
				var greenRange = GREEN_MAX - GREEN_MIN;
				var reduction = Math.min(roundsCompleted * 0.3, greenRange * 0.6);
				lightDuration = GREEN_MIN + rng.random(Std.int((greenRange - reduction) * 10)) / 10.0;
				lightTimer = lightDuration;
				roundsCompleted++;
			}
			drawDoll();
			drawLight();
		}

		// Player movement
		moving = holding && lightState != 2;
		if (holding) {
			if (lightState == 2) {
				// Caught moving on red light!
				caughtMoving = true;
				gameOver = true;
				deathTimer = 1.0;
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(0.4, 10);
					ctx.feedback.flash(0xFF2244, 0.35);
				}
				if (ctx != null) ctx.lose(score, getMinigameId());
				drawAll();
				return;
			}

			// Run forward (up)
			playerY -= playerSpeed * dt;
			score = Std.int((PLAYER_START_Y - playerY) / 4);
			scoreText.text = Std.string(score);

			// Check win (reached finish line)
			if (playerY <= FINISH_Y) {
				playerY = FINISH_Y;
				// Win this round! Reset to start, increase difficulty
				score += 50; // bonus
				scoreText.text = Std.string(score);
				playerY = PLAYER_START_Y;
				playerSpeed += 15.0;
				roundsCompleted += 2;

				// Reset rivals
				for (r in rivals) {
					r.y = PLAYER_START_Y + rng.random(20) - 10;
					r.alive = true;
					r.speed += 10;
				}

				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(0.15, 4);
					ctx.feedback.flash(0x44FF88, 0.12);
				}
			}
		}

		// Rival AI
		for (r in rivals) {
			if (!r.alive) {
				r.deathTimer -= dt * 2.0;
				continue;
			}

			if (lightState == 0) {
				// Green: rivals run
				r.y -= r.speed * dt;
			} else if (lightState == 1) {
				// Yellow: some rivals keep running (risky!)
				if (rng.random(100) < 30) {
					r.y -= r.speed * 0.5 * dt;
				}
			} else {
				// Red: some dumb rivals keep moving and die
				if (rng.random(1000) < 3) {
					r.alive = false;
					r.deathTimer = 1.0;
				}
			}

			// Rival reaches finish → reset
			if (r.y <= FINISH_Y) {
				r.y = PLAYER_START_Y + rng.random(30);
				r.speed += 5;
			}
		}

		drawScorePill();
		drawPlayer();
		drawRivals();

		if (lightState == 1) {
			drawLight();
		}
	}

	public function dispose():Void {
		contentObj.remove();
	}

	public function getMinigameId():String
		return "red_light_green_light";

	public function getTitle():String
		return "Red Light Green Light";
}
