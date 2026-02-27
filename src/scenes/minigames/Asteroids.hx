package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Asteroids: arraste para mover/rotacionar a nave, toque rápido para atirar.
	Asteroides grandes se dividem em menores. Wrap nas bordas.
**/
class Asteroids implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var SHIP_RADIUS = 13.0;
	static var BULLET_SPEED = 370.0;
	static var BULLET_LIFETIME = 1.4;
	static var ROTATE_SPEED = 5.5;
	static var THRUST_FORCE = 220.0;
	static var MAX_SPEED = 190.0;
	static var FRICTION = 0.98;
	static var JOYSTICK_DEAD_ZONE = 8.0;
	static var TAP_MAX_DIST = 14.0;
	static var TAP_MAX_TIME = 0.25;
	static var ASTEROID_SPEED_MIN = 30.0;
	static var ASTEROID_SPEED_MAX = 75.0;
	static var LARGE_R = 26.0;
	static var MEDIUM_R = 16.0;
	static var SMALL_R = 9.0;
	static var INITIAL_ASTEROIDS = 4;
	static var SPAWN_INTERVAL = 4.5;
	static var DEATH_DUR = 0.55;
	static var EXPLOSION_DUR = 0.35;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var effectG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var shipX:Float;
	var shipY:Float;
	var shipVx:Float;
	var shipVy:Float;
	var shipAngle:Float;
	var thrusting:Bool;
	var score:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var started:Bool;
	var elapsed:Float;

	var touching:Bool;
	var touchStartX:Float;
	var touchStartY:Float;
	var touchCurX:Float;
	var touchCurY:Float;
	var touchTime:Float;
	var joystickActive:Bool;

	var asteroids:Array<Asteroid>;
	var bullets:Array<{x:Float, y:Float, vx:Float, vy:Float, life:Float}>;
	var explosions:Array<{x:Float, y:Float, t:Float, color:Int, r:Float}>;
	var spawnTimer:Float;
	var rng:hxd.Rand;
	var stars:Array<{x:Float, y:Float, s:Float, twinkle:Float}>;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		rng = new hxd.Rand(99);

		bg = new Graphics(contentObj);
		gameG = new Graphics(contentObj);
		effectG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		stars = [];
		var starRng = new hxd.Rand(42);
		for (_ in 0...60)
			stars.push({x: starRng.rand() * DESIGN_W, y: starRng.rand() * DESIGN_H, s: 1.0 + starRng.rand() * 1.5, twinkle: starRng.rand() * 6.28});

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W - 14;
		scoreText.y = 10;
		scoreText.scale(1.8);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Arraste: mover | Toque: atirar";
		instructText.x = DESIGN_W / 2;
		instructText.y = DESIGN_H - 30;
		instructText.scale(0.9);
		instructText.textAlign = Center;
		instructText.textColor = 0x556677;
		instructText.visible = true;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
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
			if (Math.sqrt(dx * dx + dy * dy) > JOYSTICK_DEAD_ZONE)
				joystickActive = true;
		};
		interactive.onRelease = function(e) {
			if (!touching)
				return;
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			if (Math.sqrt(dx * dx + dy * dy) < TAP_MAX_DIST && touchTime < TAP_MAX_TIME)
				fireBullet();
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
		explosions = [];
		gameOver = true;
		deathTimer = -1;
		started = false;
		elapsed = 0;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	function fireBullet() {
		if (bullets.length >= 5)
			return;
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
		for (i in 0...10)
			verts.push(0.7 + rng.rand() * 0.6);
		return verts;
	}

	function spawnAsteroidFromEdge(size:Int) {
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
			x: x, y: y, vx: dx * speed, vy: dy * speed,
			radius: radius, size: size, verts: generateVerts(),
			rot: rng.rand() * 6.28, rotSpeed: (rng.rand() - 0.5) * 2.0
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
		deathTimer = -1;
		started = false;
		elapsed = 0;
		scoreText.text = "0";
		instructText.visible = true;
		flashG.clear();
		spawnTimer = 0;
		touching = false;
		joystickActive = false;
		touchTime = 0;
		bullets = [];
		asteroids = [];
		explosions = [];
		for (_ in 0...INITIAL_ASTEROIDS)
			spawnAsteroidFromEdge(2);
		drawBg();
		draw();
	}

	function wrapCoord(val:Float, max:Float, margin:Float):Float {
		if (val < -margin)
			return val + max + margin * 2;
		if (val > max + margin)
			return val - max - margin * 2;
		return val;
	}

	function drawBg() {
		bg.clear();
		bg.beginFill(0x050510);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		for (s in stars) {
			var twinkle = 0.3 + Math.sin(elapsed * 1.5 + s.twinkle) * 0.25;
			bg.beginFill(0xFFFFFF, twinkle);
			bg.drawRect(s.x, s.y, s.s, s.s);
			bg.endFill();
		}
	}

	function addExplosion(x:Float, y:Float, color:Int, size:Float) {
		for (_ in 0...6)
			explosions.push({
				x: x + (rng.rand() - 0.5) * size,
				y: y + (rng.rand() - 0.5) * size,
				t: 0, color: color, r: 3 + rng.rand() * size * 0.3
			});
	}

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				elapsed += dt;
				var t = deathTimer / DEATH_DUR;
				var ei = explosions.length - 1;
				while (ei >= 0) {
					explosions[ei].t += dt;
					if (explosions[ei].t >= EXPLOSION_DUR)
						explosions.splice(ei, 1);
					ei--;
				}
				drawBg();
				draw();
				drawExplosions();
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFFFFFF, (1 - t) * 0.4);
					flashG.drawRect(0, 0, DESIGN_W, DESIGN_H);
					flashG.endFill();
				} else {
					flashG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (!started) {
			drawBg();
			draw();
			return;
		}

		elapsed += dt;
		if (touching)
			touchTime += dt;

		thrusting = false;
		if (touching && joystickActive) {
			var dx = touchCurX - touchStartX;
			var dy = touchCurY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist > JOYSTICK_DEAD_ZONE) {
				var targetAngle = Math.atan2(dy, dx);
				var diff = targetAngle - shipAngle;
				while (diff > Math.PI) diff -= Math.PI * 2;
				while (diff < -Math.PI) diff += Math.PI * 2;
				var maxRot = ROTATE_SPEED * dt;
				if (diff > maxRot) diff = maxRot;
				if (diff < -maxRot) diff = -maxRot;
				shipAngle += diff;
				var thrustPct = Math.min((dist - JOYSTICK_DEAD_ZONE) / 60.0, 1.0);
				shipVx += Math.cos(shipAngle) * THRUST_FORCE * thrustPct * dt;
				shipVy += Math.sin(shipAngle) * THRUST_FORCE * thrustPct * dt;
				thrusting = thrustPct > 0.2;
			}
		}

		shipVx *= FRICTION;
		shipVy *= FRICTION;
		var spd = Math.sqrt(shipVx * shipVx + shipVy * shipVy);
		if (spd > MAX_SPEED) {
			shipVx = shipVx / spd * MAX_SPEED;
			shipVy = shipVy / spd * MAX_SPEED;
		}
		shipX += shipVx * dt;
		shipY += shipVy * dt;
		shipX = wrapCoord(shipX, DESIGN_W, SHIP_RADIUS);
		shipY = wrapCoord(shipY, DESIGN_H, SHIP_RADIUS);

		var i = bullets.length;
		while (i-- > 0) {
			var b = bullets[i];
			b.x += b.vx * dt;
			b.y += b.vy * dt;
			b.life -= dt;
			if (b.life <= 0 || b.x < -20 || b.x > DESIGN_W + 20 || b.y < -20 || b.y > DESIGN_H + 20)
				bullets.splice(i, 1);
		}

		for (a in asteroids) {
			a.x += a.vx * dt;
			a.y += a.vy * dt;
			a.x = wrapCoord(a.x, DESIGN_W, a.radius);
			a.y = wrapCoord(a.y, DESIGN_H, a.radius);
			a.rot += a.rotSpeed * dt;
		}

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
				var color = a.size == 2 ? 0xAA8855 : (a.size == 1 ? 0xBBAA77 : 0xCCBB99);
				addExplosion(a.x, a.y, color, a.radius);
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.06, 1);

				if (a.size > 0) {
					var newSize = a.size - 1;
					var newRadius = newSize == 1 ? MEDIUM_R : SMALL_R;
					var len = Math.sqrt(a.vx * a.vx + a.vy * a.vy);
					var perpX = if (len > 0) -a.vy / len * 30 else 30.0;
					var perpY = if (len > 0) a.vx / len * 30 else 0.0;
					asteroids.push({
						x: a.x, y: a.y, vx: a.vx + perpX, vy: a.vy + perpY,
						radius: newRadius, size: newSize, verts: generateVerts(),
						rot: 0, rotSpeed: (rng.rand() - 0.5) * 3.0
					});
					asteroids.push({
						x: a.x, y: a.y, vx: a.vx - perpX, vy: a.vy - perpY,
						radius: newRadius, size: newSize, verts: generateVerts(),
						rot: 0, rotSpeed: (rng.rand() - 0.5) * 3.0
					});
				}
				asteroids.splice(hitIdx, 1);
				bullets.splice(i, 1);
			}
		}

		for (a in asteroids) {
			var dx = a.x - shipX;
			var dy = a.y - shipY;
			var minDist = a.radius + SHIP_RADIUS - 3;
			if (dx * dx + dy * dy < minDist * minDist) {
				gameOver = true;
				deathTimer = 0;
				addExplosion(shipX, shipY, 0x00EEFF, 20);
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(0.4, 6);
					ctx.feedback.flash(0xFFFFFF, 0.1);
				}
				return;
			}
		}

		spawnTimer += dt;
		if (spawnTimer >= SPAWN_INTERVAL && asteroids.length < 10) {
			spawnTimer = 0;
			spawnAsteroidFromEdge(2);
		}

		i = explosions.length - 1;
		while (i >= 0) {
			explosions[i].t += dt;
			if (explosions[i].t >= EXPLOSION_DUR)
				explosions.splice(i, 1);
			i--;
		}

		drawBg();
		draw();
		drawExplosions();
	}

	function drawExplosions() {
		effectG.clear();
		for (e in explosions) {
			var t = e.t / EXPLOSION_DUR;
			if (t >= 1)
				continue;
			var alpha = 1 - t;
			var r = e.r + t * 12;
			effectG.beginFill(e.color, alpha * 0.7);
			effectG.drawCircle(e.x, e.y, r);
			effectG.endFill();
			effectG.beginFill(0xFFFFFF, alpha * 0.3);
			effectG.drawCircle(e.x, e.y, r * 0.3);
			effectG.endFill();
		}
	}

	function draw() {
		gameG.clear();

		var cos = Math.cos(shipAngle);
		var sin = Math.sin(shipAngle);
		var tipX = shipX + cos * SHIP_RADIUS;
		var tipY = shipY + sin * SHIP_RADIUS;
		var leftX = shipX + Math.cos(shipAngle + 2.5) * SHIP_RADIUS;
		var leftY = shipY + Math.sin(shipAngle + 2.5) * SHIP_RADIUS;
		var rightX = shipX + Math.cos(shipAngle - 2.5) * SHIP_RADIUS;
		var rightY = shipY + Math.sin(shipAngle - 2.5) * SHIP_RADIUS;

		if (!gameOver) {
			gameG.beginFill(0x00EEFF, 0.1);
			gameG.drawCircle(shipX, shipY, SHIP_RADIUS + 6);
			gameG.endFill();
		}

		gameG.beginFill(0x00DDEE);
		gameG.moveTo(tipX, tipY);
		gameG.lineTo(leftX, leftY);
		gameG.lineTo(shipX - cos * 4, shipY - sin * 4);
		gameG.lineTo(rightX, rightY);
		gameG.endFill();
		gameG.beginFill(0x66EEFF, 0.4);
		gameG.moveTo(tipX, tipY);
		gameG.lineTo(shipX + Math.cos(shipAngle + 1.2) * SHIP_RADIUS * 0.5, shipY + Math.sin(shipAngle + 1.2) * SHIP_RADIUS * 0.5);
		gameG.lineTo(shipX + Math.cos(shipAngle - 1.2) * SHIP_RADIUS * 0.5, shipY + Math.sin(shipAngle - 1.2) * SHIP_RADIUS * 0.5);
		gameG.endFill();

		if (thrusting) {
			var backX = shipX - cos * SHIP_RADIUS * 0.6;
			var backY = shipY - sin * SHIP_RADIUS * 0.6;
			var flameLen = 8 + rng.rand() * 8;
			var flameX = backX - cos * flameLen;
			var flameY = backY - sin * flameLen;
			gameG.beginFill(0xFF8800, 0.8);
			gameG.moveTo(leftX, leftY);
			gameG.lineTo(flameX, flameY);
			gameG.lineTo(rightX, rightY);
			gameG.endFill();
			gameG.beginFill(0xFFDD44, 0.5);
			var innerFlame = backX - cos * flameLen * 0.5;
			var innerFlameY = backY - sin * flameLen * 0.5;
			gameG.moveTo(shipX - cos * 3 + Math.cos(shipAngle + Math.PI / 2) * 4, shipY - sin * 3 + Math.sin(shipAngle + Math.PI / 2) * 4);
			gameG.lineTo(innerFlame, innerFlameY);
			gameG.lineTo(shipX - cos * 3 - Math.cos(shipAngle + Math.PI / 2) * 4, shipY - sin * 3 - Math.sin(shipAngle + Math.PI / 2) * 4);
			gameG.endFill();
		}

		if (touching && joystickActive) {
			gameG.beginFill(0xFFFFFF, 0.1);
			gameG.drawCircle(touchStartX, touchStartY, 28);
			gameG.endFill();
			var dx = touchCurX - touchStartX;
			var dy = touchCurY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist > 1) {
				var clamp = Math.min(dist, 40.0);
				var nx = dx / dist * clamp;
				var ny = dy / dist * clamp;
				gameG.lineStyle(2, 0xFFFFFF, 0.2);
				gameG.moveTo(touchStartX, touchStartY);
				gameG.lineTo(touchStartX + nx, touchStartY + ny);
				gameG.lineStyle();
				gameG.beginFill(0xFFFFFF, 0.25);
				gameG.drawCircle(touchStartX + nx, touchStartY + ny, 5);
				gameG.endFill();
			}
		}

		for (a in asteroids) {
			var fillC = a.size == 2 ? 0x554433 : (a.size == 1 ? 0x665544 : 0x776655);
			var lineC = a.size == 2 ? 0x998866 : (a.size == 1 ? 0xAA9977 : 0xBBAA88);
			var numVerts = a.verts.length;
			gameG.beginFill(fillC);
			for (vi in 0...numVerts) {
				var angle = (vi / numVerts) * Math.PI * 2 + a.rot;
				var r = a.radius * a.verts[vi];
				var px = a.x + Math.cos(angle) * r;
				var py = a.y + Math.sin(angle) * r;
				if (vi == 0)
					gameG.moveTo(px, py);
				else
					gameG.lineTo(px, py);
			}
			gameG.endFill();
			gameG.lineStyle(1.5, lineC, 0.8);
			for (vi in 0...numVerts) {
				var angle = (vi / numVerts) * Math.PI * 2 + a.rot;
				var r = a.radius * a.verts[vi];
				var px = a.x + Math.cos(angle) * r;
				var py = a.y + Math.sin(angle) * r;
				if (vi == 0)
					gameG.moveTo(px, py);
				else
					gameG.lineTo(px, py);
			}
			var firstAngle = a.rot;
			gameG.lineTo(a.x + Math.cos(firstAngle) * a.radius * a.verts[0], a.y + Math.sin(firstAngle) * a.radius * a.verts[0]);
			gameG.lineStyle();
		}

		for (b in bullets) {
			var alpha = b.life / BULLET_LIFETIME;
			gameG.beginFill(0xFFFF44, alpha * 0.25);
			gameG.drawCircle(b.x, b.y, 6);
			gameG.endFill();
			gameG.beginFill(0xFFFF88, alpha);
			gameG.drawCircle(b.x, b.y, 3);
			gameG.endFill();
		}
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

private typedef Asteroid = {
	var x:Float;
	var y:Float;
	var vx:Float;
	var vy:Float;
	var radius:Float;
	var size:Int;
	var verts:Array<Float>;
	var rot:Float;
	var rotSpeed:Float;
}
