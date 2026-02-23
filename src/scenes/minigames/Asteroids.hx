package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class Asteroids implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var SHIP_RADIUS = 12.0;
	static var BULLET_SPEED = 350.0;
	static var BULLET_LIFETIME = 1.5;
	static var ROTATE_SPEED = 5.0;
	static var THRUST_FORCE = 200.0;
	static var MAX_SPEED = 180.0;
	static var FRICTION = 0.98;
	static var JOYSTICK_DEAD_ZONE = 8.0;
	static var TAP_MAX_DIST = 12.0;
	static var TAP_MAX_TIME = 0.25;
	static var ASTEROID_SPEED_MIN = 30.0;
	static var ASTEROID_SPEED_MAX = 70.0;
	static var LARGE_R = 25.0;
	static var MEDIUM_R = 15.0;
	static var SMALL_R = 8.0;
	static var INITIAL_ASTEROIDS = 4;
	static var SPAWN_INTERVAL = 5.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var scoreText:Text;
	var interactive:Interactive;

	// Ship state
	var shipX:Float;
	var shipY:Float;
	var shipVx:Float;
	var shipVy:Float;
	var shipAngle:Float;
	var thrusting:Bool;
	var score:Int;
	var gameOver:Bool;
	var started:Bool;

	// Touch / joystick state
	var touching:Bool;
	var touchStartX:Float;
	var touchStartY:Float;
	var touchCurX:Float;
	var touchCurY:Float;
	var touchTime:Float;
	var joystickActive:Bool;

	var asteroids:Array<{
		x:Float,
		y:Float,
		vx:Float,
		vy:Float,
		radius:Float,
		size:Int,
		verts:Array<Float>
	}>;
	var bullets:Array<{x:Float, y:Float, vx:Float, vy:Float, life:Float}>;
	var spawnTimer:Float;
	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		rng = new hxd.Rand(99);

		bg = new Graphics(contentObj);
		bg.beginFill(0x0A0A1A);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		var starRng = new hxd.Rand(42);
		bg.beginFill(0xFFFFFF);
		for (_ in 0...50) {
			var sx = starRng.random(DESIGN_W);
			var sy = starRng.random(DESIGN_H);
			var sz = 1 + starRng.random(2);
			bg.drawRect(sx, sy, sz, sz);
		}
		bg.endFill();

		gameG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2 - 20;
		scoreText.y = 10;
		scoreText.scale(1.8);

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			touching = true;
			touchStartX = e.relX;
			touchStartY = e.relY;
			touchCurX = e.relX;
			touchCurY = e.relY;
			touchTime = 0;
			joystickActive = false;
			thrusting = false;
		};
		interactive.onMove = function(e) {
			if (!touching || gameOver || ctx == null)
				return;
			touchCurX = e.relX;
			touchCurY = e.relY;
			var dx = touchCurX - touchStartX;
			var dy = touchCurY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist > JOYSTICK_DEAD_ZONE) {
				joystickActive = true;
			}
		};
		interactive.onRelease = function(e) {
			if (!touching)
				return;
			// Tap = fire
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist < TAP_MAX_DIST && touchTime < TAP_MAX_TIME) {
				fireBullet();
			}
			touching = false;
			joystickActive = false;
			thrusting = false;
		};
		interactive.onReleaseOutside = function(e) {
			touching = false;
			joystickActive = false;
			thrusting = false;
		};

		asteroids = [];
		bullets = [];
		shipX = DESIGN_W / 2;
		shipY = DESIGN_H / 2;
		shipVx = 0;
		shipVy = 0;
		shipAngle = -Math.PI / 2;
		thrusting = false;
		score = 0;
		gameOver = true;
		started = false;
		spawnTimer = 0;
		touching = false;
		joystickActive = false;
		touchTime = 0;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	function fireBullet() {
		var cos = Math.cos(shipAngle);
		var sin = Math.sin(shipAngle);
		bullets.push({
			x: shipX + cos * SHIP_RADIUS,
			y: shipY + sin * SHIP_RADIUS,
			vx: cos * BULLET_SPEED + shipVx * 0.3,
			vy: sin * BULLET_SPEED + shipVy * 0.3,
			life: BULLET_LIFETIME
		});
	}

	function generateVerts():Array<Float> {
		var verts = new Array<Float>();
		for (i in 0...8) {
			verts.push(0.7 + rng.rand() * 0.6);
		}
		return verts;
	}

	function spawnAsteroidFromEdge(size:Int):Void {
		var radius = size == 2 ? LARGE_R : (size == 1 ? MEDIUM_R : SMALL_R);
		var x:Float;
		var y:Float;
		var edge = rng.random(4);
		switch (edge) {
			case 0:
				x = rng.rand() * DESIGN_W;
				y = -radius;
			case 1:
				x = rng.rand() * DESIGN_W;
				y = DESIGN_H + radius;
			case 2:
				x = -radius;
				y = rng.rand() * DESIGN_H;
			default:
				x = DESIGN_W + radius;
				y = rng.rand() * DESIGN_H;
		}

		var cx = DESIGN_W / 2.0;
		var cy = DESIGN_H / 2.0;
		var dx = cx - x;
		var dy = cy - y;
		var dist = Math.sqrt(dx * dx + dy * dy);
		if (dist < 1)
			dist = 1;
		dx /= dist;
		dy /= dist;
		dx += (rng.rand() - 0.5) * 0.6;
		dy += (rng.rand() - 0.5) * 0.6;
		var speed = ASTEROID_SPEED_MIN + rng.rand() * (ASTEROID_SPEED_MAX - ASTEROID_SPEED_MIN);

		asteroids.push({
			x: x,
			y: y,
			vx: dx * speed,
			vy: dy * speed,
			radius: radius,
			size: size,
			verts: generateVerts()
		});
	}

	public function start() {
		shipX = DESIGN_W / 2;
		shipY = DESIGN_H / 2;
		shipVx = 0;
		shipVy = 0;
		shipAngle = -Math.PI / 2;
		thrusting = false;
		score = 0;
		gameOver = false;
		started = false;
		scoreText.text = "0";
		spawnTimer = 0;
		touching = false;
		joystickActive = false;
		touchTime = 0;

		bullets = [];
		asteroids = [];

		for (_ in 0...INITIAL_ASTEROIDS) {
			spawnAsteroidFromEdge(2);
		}

		draw();
	}

	function wrapCoord(val:Float, max:Float, margin:Float):Float {
		if (val < -margin)
			return val + max + margin * 2;
		if (val > max + margin)
			return val - max - margin * 2;
		return val;
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;

		if (!started) {
			draw();
			return;
		}

		// Track touch hold time
		if (touching)
			touchTime += dt;

		// Joystick: rotate ship toward drag direction and thrust
		thrusting = false;
		if (touching && joystickActive) {
			var dx = touchCurX - touchStartX;
			var dy = touchCurY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist > JOYSTICK_DEAD_ZONE) {
				// Target angle from joystick
				var targetAngle = Math.atan2(dy, dx);
				// Smooth rotate toward target
				var diff = targetAngle - shipAngle;
				// Normalize to [-PI, PI]
				while (diff > Math.PI)
					diff -= Math.PI * 2;
				while (diff < -Math.PI)
					diff += Math.PI * 2;
				var maxRot = ROTATE_SPEED * dt;
				if (diff > maxRot)
					diff = maxRot;
				if (diff < -maxRot)
					diff = -maxRot;
				shipAngle += diff;

				// Thrust proportional to drag distance (capped)
				var thrustPct = Math.min((dist - JOYSTICK_DEAD_ZONE) / 60.0, 1.0);
				shipVx += Math.cos(shipAngle) * THRUST_FORCE * thrustPct * dt;
				shipVy += Math.sin(shipAngle) * THRUST_FORCE * thrustPct * dt;
				thrusting = thrustPct > 0.2;
			}
		}

		// Friction
		shipVx *= FRICTION;
		shipVy *= FRICTION;

		// Clamp speed
		var spd = Math.sqrt(shipVx * shipVx + shipVy * shipVy);
		if (spd > MAX_SPEED) {
			shipVx = shipVx / spd * MAX_SPEED;
			shipVy = shipVy / spd * MAX_SPEED;
		}

		// Move ship
		shipX += shipVx * dt;
		shipY += shipVy * dt;

		// Wrap ship
		shipX = wrapCoord(shipX, DESIGN_W, SHIP_RADIUS);
		shipY = wrapCoord(shipY, DESIGN_H, SHIP_RADIUS);

		// Move bullets
		var i = bullets.length;
		while (i-- > 0) {
			var b = bullets[i];
			b.x += b.vx * dt;
			b.y += b.vy * dt;
			b.life -= dt;
			if (b.life <= 0 || b.x < -20 || b.x > DESIGN_W + 20 || b.y < -20 || b.y > DESIGN_H + 20)
				bullets.splice(i, 1);
		}

		// Move asteroids (wrap edges)
		for (a in asteroids) {
			a.x += a.vx * dt;
			a.y += a.vy * dt;
			a.x = wrapCoord(a.x, DESIGN_W, a.radius);
			a.y = wrapCoord(a.y, DESIGN_H, a.radius);
		}

		// Bullet vs asteroid collision
		i = bullets.length;
		while (i-- > 0) {
			var b = bullets[i];
			var hitIdx = -1;
			for (j in 0...asteroids.length) {
				var a = asteroids[j];
				var adx = b.x - a.x;
				var ady = b.y - a.y;
				if (adx * adx + ady * ady < a.radius * a.radius) {
					hitIdx = j;
					break;
				}
			}
			if (hitIdx >= 0) {
				var a = asteroids[hitIdx];
				score++;
				scoreText.text = Std.string(score);
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.08, 2);

				if (a.size > 0) {
					var newSize = a.size - 1;
					var newRadius = newSize == 1 ? MEDIUM_R : SMALL_R;
					var len = Math.sqrt(a.vx * a.vx + a.vy * a.vy);
					var perpX = if (len > 0) -a.vy / len * 30 else 30.0;
					var perpY = if (len > 0) a.vx / len * 30 else 0.0;
					asteroids.push({
						x: a.x,
						y: a.y,
						vx: a.vx + perpX,
						vy: a.vy + perpY,
						radius: newRadius,
						size: newSize,
						verts: generateVerts()
					});
					asteroids.push({
						x: a.x,
						y: a.y,
						vx: a.vx - perpX,
						vy: a.vy - perpY,
						radius: newRadius,
						size: newSize,
						verts: generateVerts()
					});
				}

				asteroids.splice(hitIdx, 1);
				bullets.splice(i, 1);
			}
		}

		// Asteroid vs ship collision
		for (a in asteroids) {
			var dx = a.x - shipX;
			var dy = a.y - shipY;
			var minDist = a.radius + SHIP_RADIUS;
			if (dx * dx + dy * dy < minDist * minDist) {
				endGame();
				return;
			}
		}

		// Spawn timer
		spawnTimer += dt;
		if (spawnTimer >= SPAWN_INTERVAL && asteroids.length < 8) {
			spawnTimer = 0;
			spawnAsteroidFromEdge(2);
		}

		draw();
	}

	function endGame() {
		gameOver = true;
		if (ctx != null && ctx.feedback != null)
			ctx.feedback.shake2D(0.2, 4);
		ctx.lose(score, getMinigameId());
		ctx = null;
	}

	function draw() {
		gameG.clear();

		// Draw ship (cyan triangle)
		var cos = Math.cos(shipAngle);
		var sin = Math.sin(shipAngle);
		var tipX = shipX + cos * SHIP_RADIUS;
		var tipY = shipY + sin * SHIP_RADIUS;
		var leftX = shipX + Math.cos(shipAngle + 2.5) * SHIP_RADIUS;
		var leftY = shipY + Math.sin(shipAngle + 2.5) * SHIP_RADIUS;
		var rightX = shipX + Math.cos(shipAngle - 2.5) * SHIP_RADIUS;
		var rightY = shipY + Math.sin(shipAngle - 2.5) * SHIP_RADIUS;

		gameG.beginFill(0x00EEFF);
		gameG.moveTo(tipX, tipY);
		gameG.lineTo(leftX, leftY);
		gameG.lineTo(rightX, rightY);
		gameG.lineTo(tipX, tipY);
		gameG.endFill();

		// Thrust flame
		if (thrusting) {
			var backX = shipX - cos * SHIP_RADIUS * 0.8;
			var backY = shipY - sin * SHIP_RADIUS * 0.8;
			var flameLen = 6 + rng.rand() * 6;
			var flameX = backX - cos * flameLen;
			var flameY = backY - sin * flameLen;
			gameG.beginFill(0xFF8800);
			gameG.moveTo(leftX, leftY);
			gameG.lineTo(flameX, flameY);
			gameG.lineTo(rightX, rightY);
			gameG.endFill();
		}

		// Draw joystick indicator when dragging
		if (touching && joystickActive) {
			// Origin dot
			gameG.beginFill(0xFFFFFF, 0.15);
			gameG.drawCircle(touchStartX, touchStartY, 30);
			gameG.endFill();
			// Direction line
			var dx = touchCurX - touchStartX;
			var dy = touchCurY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			var clampDist = Math.min(dist, 40.0);
			if (dist > 1) {
				var nx = dx / dist * clampDist;
				var ny = dy / dist * clampDist;
				gameG.lineStyle(2, 0xFFFFFF, 0.3);
				gameG.moveTo(touchStartX, touchStartY);
				gameG.lineTo(touchStartX + nx, touchStartY + ny);
				gameG.lineStyle();
				gameG.beginFill(0xFFFFFF, 0.3);
				gameG.drawCircle(touchStartX + nx, touchStartY + ny, 6);
				gameG.endFill();
			}
		}

		// Draw asteroids
		for (a in asteroids) {
			var color = a.size == 2 ? 0x888888 : (a.size == 1 ? 0xAAAAAA : 0xCCCCCC);
			gameG.lineStyle(1.5, color);
			var numVerts = a.verts.length;
			for (vi in 0...numVerts) {
				var angle = (vi / numVerts) * Math.PI * 2;
				var r = a.radius * a.verts[vi];
				var px = a.x + Math.cos(angle) * r;
				var py = a.y + Math.sin(angle) * r;
				if (vi == 0)
					gameG.moveTo(px, py);
				else
					gameG.lineTo(px, py);
			}
			var firstR = a.radius * a.verts[0];
			gameG.lineTo(a.x + firstR, a.y);
			gameG.lineStyle();
		}

		// Draw bullets
		gameG.beginFill(0xFFFF44);
		for (b in bullets) {
			gameG.drawCircle(b.x, b.y, 3);
		}
		gameG.endFill();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "asteroids";

	public function getTitle():String
		return "Asteroids";
}
