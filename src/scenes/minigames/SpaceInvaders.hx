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
	Space Invaders: mova a nave e toque para atirar. Destrua os aliens antes que cheguem.
**/
class SpaceInvaders implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var SHIP_W = 32;
	static var SHIP_H = 18;
	static var ALIEN_W = 26;
	static var ALIEN_H = 18;
	static var GRID_COLS = 6;
	static var GRID_ROWS = 4;
	static var GRID_SPACE_X = 38;
	static var GRID_SPACE_Y = 32;
	static var BULLET_SPEED = 420.0;
	static var ALIEN_BULLET_SPEED = 220.0;
	static var ALIEN_MOVE_SPEED = 35.0;
	static var ALIEN_DROP = 18.0;
	static var ALIEN_SHOOT_INTERVAL = 1.4;
	static var SHIP_Y = 590.0;
	static var DEATH_DUR = 0.5;
	static var EXPLOSION_DUR = 0.3;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var effectG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var waveText:Text;
	var interactive:Interactive;

	var shipX:Float;
	var targetX:Float;
	var score:Int;
	var wave:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var started:Bool;
	var elapsed:Float;

	var aliens:Array<{x:Float, y:Float, alive:Bool, row:Int}>;
	var alienDir:Float;
	var playerBullets:Array<{x:Float, y:Float}>;
	var alienBullets:Array<{x:Float, y:Float}>;
	var explosions:Array<{x:Float, y:Float, t:Float, color:Int}>;
	var shootTimer:Float;
	var starOffsets:Array<{x:Float, y:Float, s:Float, speed:Float}>;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		gameG = new Graphics(contentObj);
		effectG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W - 14;
		scoreText.y = 10;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		waveText = new Text(hxd.res.DefaultFont.get(), contentObj);
		waveText.text = "";
		waveText.x = 14;
		waveText.y = 12;
		waveText.scale(1.0);
		waveText.textAlign = Left;
		waveText.textColor = 0x668888;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Mova e toque para atirar";
		instructText.x = DESIGN_W / 2;
		instructText.y = SHIP_Y + 20;
		instructText.scale(1.0);
		instructText.textAlign = Center;
		instructText.textColor = 0x668888;
		instructText.visible = true;

		starOffsets = [];
		var rng = new hxd.Rand(42);
		for (_ in 0...50) {
			starOffsets.push({
				x: rng.random(DESIGN_W),
				y: rng.random(DESIGN_H),
				s: 1.0 + rng.random(2),
				speed: 8.0 + rng.random(20)
			});
		}

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onMove = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			targetX = e.relX;
		};
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			targetX = e.relX;
			if (playerBullets.length < 3)
				playerBullets.push({x: shipX, y: SHIP_Y - SHIP_H});
		};

		aliens = [];
		playerBullets = [];
		alienBullets = [];
		explosions = [];
		alienDir = 1;
		shootTimer = 0;
		score = 0;
		wave = 1;
		gameOver = true;
		deathTimer = -1;
		started = false;
		elapsed = 0;
		shipX = DESIGN_W / 2;
		targetX = DESIGN_W / 2;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		shipX = DESIGN_W / 2;
		targetX = DESIGN_W / 2;
		score = 0;
		wave = 1;
		gameOver = false;
		deathTimer = -1;
		started = false;
		elapsed = 0;
		scoreText.text = "0";
		waveText.text = "Wave 1";
		instructText.visible = true;
		flashG.clear();
		alienDir = 1;
		shootTimer = 0;
		playerBullets = [];
		alienBullets = [];
		explosions = [];
		spawnWave();
		drawBg();
		draw();
	}

	function spawnWave() {
		aliens = [];
		var startX = (DESIGN_W - (GRID_COLS - 1) * GRID_SPACE_X) / 2;
		var startY = 70.0;
		for (row in 0...GRID_ROWS) {
			for (col in 0...GRID_COLS) {
				aliens.push({
					x: startX + col * GRID_SPACE_X,
					y: startY + row * GRID_SPACE_Y,
					alive: true,
					row: row
				});
			}
		}
		alienDir = 1;
	}

	function aliveCount():Int {
		var c = 0;
		for (a in aliens)
			if (a.alive)
				c++;
		return c;
	}

	function currentSpeed():Float {
		var alive = aliveCount();
		if (alive <= 0)
			return ALIEN_MOVE_SPEED;
		return (ALIEN_MOVE_SPEED + wave * 5) * (GRID_COLS * GRID_ROWS) / alive;
	}

	function drawBg() {
		bg.clear();
		bg.beginFill(0x050510);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
	}

	function drawStars() {
		bg.beginFill(0xFFFFFF);
		for (s in starOffsets) {
			var sy = (s.y + elapsed * s.speed) % DESIGN_H;
			var alpha = 0.3 + Math.sin(elapsed * 2 + s.x) * 0.2;
			bg.beginFill(0xFFFFFF, alpha);
			bg.drawRect(s.x, sy, s.s, s.s);
			bg.endFill();
		}
	}

	function drawAlien(g:Graphics, cx:Float, cy:Float, row:Int) {
		var colors = [0x44FF44, 0x44CCFF, 0xFF66FF, 0xFFAA33];
		var c = colors[row % colors.length];
		var hw = ALIEN_W / 2;
		var hh = ALIEN_H / 2;
		g.beginFill(c);
		g.drawRoundedRect(cx - hw, cy - hh, ALIEN_W, ALIEN_H, 4);
		g.endFill();
		g.beginFill(c);
		g.drawRect(cx - hw - 4, cy - hh + 2, 4, 6);
		g.drawRect(cx + hw, cy - hh + 2, 4, 6);
		g.endFill();
		g.beginFill(c);
		g.drawRect(cx - hw + 2, cy + hh, 5, 4);
		g.drawRect(cx + hw - 7, cy + hh, 5, 4);
		g.endFill();
		g.beginFill(0x000000);
		g.drawRect(cx - 7, cy - 4, 5, 5);
		g.drawRect(cx + 2, cy - 4, 5, 5);
		g.endFill();
		g.beginFill(0xFFFFFF, 0.15);
		g.drawRoundedRect(cx - hw + 2, cy - hh + 1, ALIEN_W - 4, hh - 1, 2);
		g.endFill();
	}

	function drawShip(g:Graphics) {
		g.beginFill(0x00FF88, 0.1);
		g.drawEllipse(shipX, SHIP_Y - 4, SHIP_W / 2 + 6, SHIP_H / 2 + 6);
		g.endFill();
		g.beginFill(0x00FF88);
		g.moveTo(shipX, SHIP_Y - SHIP_H);
		g.lineTo(shipX - SHIP_W / 2, SHIP_Y);
		g.lineTo(shipX - SHIP_W / 2 + 6, SHIP_Y + 3);
		g.lineTo(shipX + SHIP_W / 2 - 6, SHIP_Y + 3);
		g.lineTo(shipX + SHIP_W / 2, SHIP_Y);
		g.lineTo(shipX, SHIP_Y - SHIP_H);
		g.endFill();
		g.beginFill(0x88FFBB, 0.4);
		g.moveTo(shipX, SHIP_Y - SHIP_H + 4);
		g.lineTo(shipX - 6, SHIP_Y - 4);
		g.lineTo(shipX + 6, SHIP_Y - 4);
		g.endFill();
		g.beginFill(0x00DDFF);
		g.drawCircle(shipX, SHIP_Y - SHIP_H + 6, 3);
		g.endFill();
	}

	function draw() {
		gameG.clear();

		for (a in aliens) {
			if (!a.alive)
				continue;
			drawAlien(gameG, a.x, a.y, a.row);
		}

		drawShip(gameG);

		gameG.beginFill(0x88FFFF);
		for (b in playerBullets) {
			gameG.drawRect(b.x - 1.5, b.y - 8, 3, 16);
		}
		gameG.endFill();
		gameG.beginFill(0xFFFFFF, 0.3);
		for (b in playerBullets) {
			gameG.drawRect(b.x - 3, b.y - 4, 6, 8);
		}
		gameG.endFill();

		gameG.beginFill(0xFF4444);
		for (b in alienBullets) {
			gameG.drawRect(b.x - 2, b.y - 6, 4, 12);
		}
		gameG.endFill();
		gameG.beginFill(0xFF8844, 0.3);
		for (b in alienBullets) {
			gameG.drawRect(b.x - 3, b.y - 3, 6, 6);
		}
		gameG.endFill();
	}

	function drawExplosions() {
		effectG.clear();
		for (e in explosions) {
			var t = e.t / EXPLOSION_DUR;
			if (t >= 1)
				continue;
			var alpha = 1 - t;
			var r = 8 + t * 18;
			effectG.beginFill(e.color, alpha * 0.7);
			effectG.drawCircle(e.x, e.y, r);
			effectG.endFill();
			effectG.beginFill(0xFFFFFF, alpha * 0.4);
			effectG.drawCircle(e.x, e.y, r * 0.4);
			effectG.endFill();
			for (p in 0...4) {
				var angle = p * Math.PI / 2 + t * 1.5;
				var dist = t * 16;
				effectG.beginFill(e.color, alpha * 0.5);
				effectG.drawCircle(e.x + Math.cos(angle) * dist, e.y + Math.sin(angle) * dist, 3 - t * 2);
				effectG.endFill();
			}
		}
	}

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFF2222, (1 - t) * 0.4);
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

		shipX = targetX;
		if (shipX < SHIP_W / 2)
			shipX = SHIP_W / 2;
		if (shipX > DESIGN_W - SHIP_W / 2)
			shipX = DESIGN_W - SHIP_W / 2;

		var speed = currentSpeed();
		var needDrop = false;
		for (a in aliens) {
			if (!a.alive)
				continue;
			a.x += speed * alienDir * dt;
			if (a.x - ALIEN_W / 2 < 0 || a.x + ALIEN_W / 2 > DESIGN_W)
				needDrop = true;
		}
		if (needDrop) {
			alienDir = -alienDir;
			for (a in aliens) {
				if (!a.alive)
					continue;
				if (a.x - ALIEN_W / 2 < 0)
					a.x = ALIEN_W / 2;
				if (a.x + ALIEN_W / 2 > DESIGN_W)
					a.x = DESIGN_W - ALIEN_W / 2;
				a.y += ALIEN_DROP;
			}
		}

		for (a in aliens) {
			if (a.alive && a.y + ALIEN_H / 2 >= SHIP_Y - 20) {
				gameOver = true;
				deathTimer = 0;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.3, 5);
				return;
			}
		}

		var i = playerBullets.length;
		while (i-- > 0) {
			playerBullets[i].y -= BULLET_SPEED * dt;
			if (playerBullets[i].y < -10)
				playerBullets.splice(i, 1);
		}

		i = alienBullets.length;
		while (i-- > 0) {
			alienBullets[i].y += ALIEN_BULLET_SPEED * dt;
			if (alienBullets[i].y > DESIGN_H + 10)
				alienBullets.splice(i, 1);
		}

		i = playerBullets.length;
		while (i-- > 0) {
			var b = playerBullets[i];
			var hit = false;
			for (a in aliens) {
				if (!a.alive)
					continue;
				if (b.x > a.x - ALIEN_W / 2 - 2 && b.x < a.x + ALIEN_W / 2 + 2 && b.y > a.y - ALIEN_H / 2 - 2 && b.y < a.y + ALIEN_H / 2 + 2) {
					var colors = [0x44FF44, 0x44CCFF, 0xFF66FF, 0xFFAA33];
					explosions.push({x: a.x, y: a.y, t: 0, color: colors[a.row % colors.length]});
					a.alive = false;
					hit = true;
					score++;
					scoreText.text = Std.string(score);
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.06, 1);
					break;
				}
			}
			if (hit)
				playerBullets.splice(i, 1);
		}

		if (aliveCount() <= 0) {
			wave++;
			waveText.text = "Wave " + Std.string(wave);
			spawnWave();
		}

		i = alienBullets.length;
		while (i-- > 0) {
			var b = alienBullets[i];
			if (b.x > shipX - SHIP_W / 2 - 2 && b.x < shipX + SHIP_W / 2 + 2 && b.y > SHIP_Y - SHIP_H && b.y < SHIP_Y + 4) {
				gameOver = true;
				deathTimer = 0;
				explosions.push({x: shipX, y: SHIP_Y - SHIP_H / 2, t: 0, color: 0x00FF88});
				if (ctx != null && ctx.feedback != null) {
					ctx.feedback.shake2D(0.4, 6);
					ctx.feedback.flash(0xFFFFFF, 0.1);
				}
				return;
			}
		}

		shootTimer += dt;
		var interval = ALIEN_SHOOT_INTERVAL - wave * 0.1;
		if (interval < 0.6)
			interval = 0.6;
		if (shootTimer >= interval) {
			shootTimer -= interval;
			var aliveAliens:Array<{x:Float, y:Float, alive:Bool, row:Int}> = [];
			for (a in aliens)
				if (a.alive)
					aliveAliens.push(a);
			if (aliveAliens.length > 0) {
				var shooter = aliveAliens[Std.random(aliveAliens.length)];
				alienBullets.push({x: shooter.x, y: shooter.y + ALIEN_H / 2});
			}
		}

		i = explosions.length - 1;
		while (i >= 0) {
			explosions[i].t += dt;
			if (explosions[i].t >= EXPLOSION_DUR)
				explosions.splice(i, 1);
			i--;
		}

		drawBg();
		drawStars();
		draw();
		drawExplosions();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "space_invaders";

	public function getTitle():String
		return "Space Invaders";
}
