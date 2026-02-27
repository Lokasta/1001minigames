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
		trackG = new Graphics(contentObj);
		rivalG = new Graphics(contentObj);
		playerG = new Graphics(contentObj);
		dollG = new Graphics(contentObj);
		lightG = new Graphics(contentObj);

		var font = hxd.res.DefaultFont.get();
		scoreText = new Text(font, contentObj);
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 15;
		scoreText.scale(2.0);
		scoreText.color = h3d.Vector4.fromColor(0xFFFFFFFF);

		instructText = new Text(font, contentObj);
		instructText.textAlign = Center;
		instructText.x = DESIGN_W / 2;
		instructText.y = 580;
		instructText.scale(1.0);
		instructText.color = h3d.Vector4.fromColor(0xFFDDDDDD);
		instructText.text = "HOLD to run, RELEASE on RED";
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
		// Sky gradient
		for (y in 0...16) {
			var t = y / 15.0;
			var r = Std.int(40 + t * 20);
			var g = Std.int(60 + t * 40);
			var b = Std.int(80 + t * 30);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, y * 10, DESIGN_W, 10);
			bg.endFill();
		}
		// Ground
		bg.beginFill(0x3A5A3A);
		bg.drawRect(0, 160, DESIGN_W, DESIGN_H - 160);
		bg.endFill();
		// Track/field lines
		bg.beginFill(0x4A6A4A);
		for (ly in 0...8) {
			bg.drawRect(0, 200 + ly * 50, DESIGN_W, 1);
		}
		bg.endFill();
		// Finish line
		var checkerSize = 10;
		for (cx in 0...Std.int(DESIGN_W / checkerSize)) {
			for (cy in 0...2) {
				var isWhite = (cx + cy) % 2 == 0;
				bg.beginFill(isWhite ? 0xFFFFFF : 0x222222);
				bg.drawRect(cx * checkerSize, Std.int(FINISH_Y) + cy * checkerSize, checkerSize, checkerSize);
				bg.endFill();
			}
		}
	}

	function drawAll():Void {
		drawDoll();
		drawLight();
		drawRivals();
		drawPlayer();
	}

	function drawDoll():Void {
		dollG.clear();
		// Giant doll (Round 6 style) - simplified
		var dx = DOLL_X;
		var dy = DOLL_Y;

		// Body (dress)
		if (lightState == 2) {
			// Facing players (red light) - front view
			// Dress
			dollG.beginFill(0xFF8833);
			dollG.drawRect(dx - 15, dy - 10, 30, 30);
			dollG.endFill();
			// Head
			dollG.beginFill(0xFFCC99);
			dollG.drawCircle(dx, dy - 18, 12);
			dollG.endFill();
			// Hair
			dollG.beginFill(0x222222);
			dollG.drawRect(dx - 12, dy - 30, 24, 8);
			dollG.endFill();
			// Hair buns
			dollG.drawCircle(dx - 14, dy - 22, 5);
			dollG.drawCircle(dx + 14, dy - 22, 5);
			dollG.endFill();
			// Eyes (menacing)
			dollG.beginFill(0x000000);
			dollG.drawCircle(dx - 5, dy - 18, 2);
			dollG.drawCircle(dx + 5, dy - 18, 2);
			dollG.endFill();
			// Red glow around eyes
			dollG.beginFill(0xFF0000, 0.3);
			dollG.drawCircle(dx - 5, dy - 18, 5);
			dollG.drawCircle(dx + 5, dy - 18, 5);
			dollG.endFill();
		} else {
			// Facing away (green light) - back view
			// Dress
			dollG.beginFill(0xFF8833);
			dollG.drawRect(dx - 15, dy - 10, 30, 30);
			dollG.endFill();
			// Head (back of head)
			dollG.beginFill(0x222222);
			dollG.drawCircle(dx, dy - 18, 12);
			dollG.endFill();
			// Hair buns
			dollG.drawCircle(dx - 14, dy - 22, 5);
			dollG.drawCircle(dx + 14, dy - 22, 5);
			dollG.endFill();
		}

		// Legs
		dollG.beginFill(0xFFCC99);
		dollG.drawRect(dx - 8, dy + 20, 5, 12);
		dollG.drawRect(dx + 3, dy + 20, 5, 12);
		dollG.endFill();
	}

	function drawLight():Void {
		lightG.clear();
		// Traffic light at top right
		var lx = 310.0;
		var ly = 20.0;

		// Housing
		lightG.beginFill(0x333333);
		lightG.drawRect(lx - 14, ly, 28, 50);
		lightG.endFill();

		// Red light
		lightG.beginFill(lightState == 2 ? 0xFF2222 : 0x441111);
		lightG.drawCircle(lx, ly + 12, 8);
		lightG.endFill();
		if (lightState == 2) {
			lightG.beginFill(0xFF2222, 0.3);
			lightG.drawCircle(lx, ly + 12, 12);
			lightG.endFill();
		}

		// Yellow light
		lightG.beginFill(lightState == 1 ? 0xFFCC00 : 0x443300);
		lightG.drawCircle(lx, ly + 28, 8);
		lightG.endFill();
		if (lightState == 1) {
			lightG.beginFill(0xFFCC00, 0.3);
			lightG.drawCircle(lx, ly + 28, 12);
			lightG.endFill();
		}

		// Green light
		lightG.beginFill(lightState == 0 ? 0x22FF22 : 0x113311);
		lightG.drawCircle(lx, ly + 44, 8);
		lightG.endFill();
		if (lightState == 0) {
			lightG.beginFill(0x22FF22, 0.3);
			lightG.drawCircle(lx, ly + 44, 12);
			lightG.endFill();
		}

		// Big text indicator
		var stateText = lightState == 0 ? "GREEN LIGHT!" : (lightState == 1 ? "WARNING..." : "RED LIGHT!");
		// Use colored bar at bottom
		var barColor = lightState == 0 ? 0x22AA22 : (lightState == 1 ? 0xCCAA00 : 0xCC2222);
		lightG.beginFill(barColor, 0.8);
		lightG.drawRect(0, DESIGN_H - 60, DESIGN_W, 30);
		lightG.endFill();
	}

	function drawRivals():Void {
		rivalG.clear();
		for (i in 0...rivals.length) {
			var r = rivals[i];
			var rx = TRACK_LEFT + 30 + i * 55;
			if (rx == 140 || rx == 195) rx += 25; // avoid overlapping with player at center

			if (!r.alive) {
				// Dead rival: X mark
				if (r.deathTimer > 0) {
					rivalG.beginFill(0xFF0000, r.deathTimer);
					rivalG.drawRect(rx - 8, r.y - 16, 16, 20);
					rivalG.endFill();
				}
				continue;
			}

			// Simple stick figure
			// Body
			rivalG.beginFill(0x888888);
			rivalG.drawRect(rx - 4, r.y - 12, 8, 16);
			rivalG.endFill();
			// Head
			rivalG.beginFill(0xCCBBAA);
			rivalG.drawCircle(rx, r.y - 16, 5);
			rivalG.endFill();
			// Legs
			rivalG.beginFill(0x666666);
			rivalG.drawRect(rx - 4, r.y + 4, 3, 8);
			rivalG.drawRect(rx + 1, r.y + 4, 3, 8);
			rivalG.endFill();
		}
	}

	function drawPlayer():Void {
		playerG.clear();
		var px = 180.0;
		var py = playerY;

		if (caughtMoving && deathTimer > 0) {
			// Death: red flash
			playerG.beginFill(0xFF0000, deathTimer);
			playerG.drawRect(px - 8, py - 18, 16, 28);
			playerG.endFill();
			return;
		}

		// Player character (slightly larger, colored)
		// Body
		playerG.beginFill(0x3388FF);
		playerG.drawRect(px - 6, py - 14, 12, 18);
		playerG.endFill();
		// Head
		playerG.beginFill(0xFFCC99);
		playerG.drawCircle(px, py - 18, 6);
		playerG.endFill();
		// Number on back
		playerG.beginFill(0xFFFFFF);
		playerG.drawRect(px - 3, py - 10, 6, 8);
		playerG.endFill();
		playerG.beginFill(0x3388FF);
		playerG.drawRect(px - 1, py - 8, 2, 4);
		playerG.endFill();
		// Legs (animate if moving)
		playerG.beginFill(0x2266CC);
		if (moving && lightState == 0) {
			// Running legs
			var legAnim = Math.sin(totalTime * 12.0) * 4;
			playerG.drawRect(px - 5, py + 4, 3, Std.int(8 + legAnim));
			playerG.drawRect(px + 2, py + 4, 3, Std.int(8 - legAnim));
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
			return;
		}

		if (gameOver) {
			deathTimer -= dt * 2.0;
			if (deathTimer < 0) deathTimer = 0;
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
					ctx.feedback.shake2D(8, 0.4);
					ctx.feedback.flash(0xFF0000, 0.3);
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
					ctx.feedback.shake2D(4, 0.2);
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

		drawPlayer();
		drawRivals();

		// Redraw light bar (for warning pulse)
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
