package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class SpaceInvaders implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var SHIP_W = 30;
	static var SHIP_H = 16;
	static var ALIEN_W = 24;
	static var ALIEN_H = 16;
	static var GRID_COLS = 5;
	static var GRID_ROWS = 3;
	static var GRID_SPACE_X = 40;
	static var GRID_SPACE_Y = 30;
	static var BULLET_SPEED = 400.0;
	static var ALIEN_BULLET_SPEED = 200.0;
	static var ALIEN_MOVE_SPEED = 40.0;
	static var ALIEN_DROP = 20.0;
	static var ALIEN_SHOOT_INTERVAL = 1.5;
	static var SHIP_Y = 600.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var scoreText:Text;
	var interactive:Interactive;

	var shipX:Float;
	var targetX:Float;
	var score:Int;
	var gameOver:Bool;
	var started:Bool;

	var aliens:Array<{x:Float, y:Float, alive:Bool, row:Int}>;
	var alienDir:Float;
	var playerBullets:Array<{x:Float, y:Float}>;
	var alienBullets:Array<{x:Float, y:Float}>;
	var shootTimer:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x0A0A1A);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		// Stars
		var rng = new hxd.Rand(42);
		bg.beginFill(0xFFFFFF);
		for (_ in 0...40) {
			var sx = rng.random(DESIGN_W);
			var sy = rng.random(DESIGN_H);
			var size = 1 + rng.random(2);
			bg.drawRect(sx, sy, size, size);
		}
		bg.endFill();

		gameG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2 - 20;
		scoreText.y = 10;
		scoreText.scale(1.8);

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onMove = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			targetX = e.relX;
		};
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			targetX = e.relX;
			// Fire bullet on tap
			playerBullets.push({x: shipX, y: SHIP_Y - SHIP_H});
		};

		aliens = [];
		playerBullets = [];
		alienBullets = [];
		alienDir = 1;
		shootTimer = 0;
		score = 0;
		gameOver = true;
		started = false;
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
		gameOver = false;
		started = false;
		scoreText.text = "0";
		alienDir = 1;
		shootTimer = 0;

		playerBullets = [];
		alienBullets = [];

		// Build alien grid
		aliens = [];
		var startX = (DESIGN_W - (GRID_COLS - 1) * GRID_SPACE_X) / 2;
		var startY = 80.0;
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

		draw();
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
		return ALIEN_MOVE_SPEED * (GRID_COLS * GRID_ROWS) / alive;
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;

		if (!started) {
			draw();
			return;
		}

		// Ship follows touch
		shipX = targetX;
		if (shipX < SHIP_W / 2)
			shipX = SHIP_W / 2;
		if (shipX > DESIGN_W - SHIP_W / 2)
			shipX = DESIGN_W - SHIP_W / 2;

		// Move aliens
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
				// Clamp back in bounds
				if (a.x - ALIEN_W / 2 < 0)
					a.x = ALIEN_W / 2;
				if (a.x + ALIEN_W / 2 > DESIGN_W)
					a.x = DESIGN_W - ALIEN_W / 2;
				a.y += ALIEN_DROP;
			}
		}

		// Check if any alien reached ship level
		for (a in aliens) {
			if (a.alive && a.y + ALIEN_H / 2 >= SHIP_Y - 20) {
				endGame();
				return;
			}
		}

		// Move player bullets (upward)
		var i = playerBullets.length;
		while (i-- > 0) {
			playerBullets[i].y -= BULLET_SPEED * dt;
			if (playerBullets[i].y < -10)
				playerBullets.splice(i, 1);
		}

		// Move alien bullets (downward)
		i = alienBullets.length;
		while (i-- > 0) {
			alienBullets[i].y += ALIEN_BULLET_SPEED * dt;
			if (alienBullets[i].y > DESIGN_H + 10)
				alienBullets.splice(i, 1);
		}

		// Player bullet vs alien collision
		i = playerBullets.length;
		while (i-- > 0) {
			var b = playerBullets[i];
			var hit = false;
			for (a in aliens) {
				if (!a.alive)
					continue;
				if (b.x > a.x - ALIEN_W / 2 && b.x < a.x + ALIEN_W / 2 && b.y > a.y - ALIEN_H / 2 && b.y < a.y + ALIEN_H / 2) {
					a.alive = false;
					hit = true;
					score++;
					scoreText.text = Std.string(score);
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.08, 2);
					break;
				}
			}
			if (hit)
				playerBullets.splice(i, 1);
		}

		// Check win (all aliens dead)
		if (aliveCount() <= 0) {
			endGame();
			return;
		}

		// Alien bullet vs player collision
		i = alienBullets.length;
		while (i-- > 0) {
			var b = alienBullets[i];
			if (b.x > shipX - SHIP_W / 2 && b.x < shipX + SHIP_W / 2 && b.y > SHIP_Y - SHIP_H / 2 && b.y < SHIP_Y + SHIP_H / 2) {
				endGame();
				return;
			}
		}

		// Alien shooting
		shootTimer += dt;
		if (shootTimer >= ALIEN_SHOOT_INTERVAL) {
			shootTimer -= ALIEN_SHOOT_INTERVAL;
			// Pick a random alive alien to shoot
			var aliveAliens:Array<{x:Float, y:Float, alive:Bool, row:Int}> = [];
			for (a in aliens)
				if (a.alive)
					aliveAliens.push(a);
			if (aliveAliens.length > 0) {
				var shooter = aliveAliens[Std.random(aliveAliens.length)];
				alienBullets.push({x: shooter.x, y: shooter.y + ALIEN_H / 2});
			}
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

		// Draw aliens
		var colors = [0x44FF44, 0x44DDFF, 0xFF44FF];
		for (a in aliens) {
			if (!a.alive)
				continue;
			var color = colors[a.row % colors.length];
			gameG.beginFill(color);
			gameG.drawRect(a.x - ALIEN_W / 2, a.y - ALIEN_H / 2, ALIEN_W, ALIEN_H);
			gameG.endFill();
			// Eyes
			gameG.beginFill(0x000000);
			gameG.drawRect(a.x - 6, a.y - 3, 4, 4);
			gameG.drawRect(a.x + 2, a.y - 3, 4, 4);
			gameG.endFill();
		}

		// Draw player ship (green triangle)
		gameG.beginFill(0x00FF88);
		gameG.moveTo(shipX, SHIP_Y - SHIP_H);
		gameG.lineTo(shipX - SHIP_W / 2, SHIP_Y);
		gameG.lineTo(shipX + SHIP_W / 2, SHIP_Y);
		gameG.lineTo(shipX, SHIP_Y - SHIP_H);
		gameG.endFill();

		// Draw player bullets (white)
		gameG.beginFill(0xFFFFFF);
		for (b in playerBullets)
			gameG.drawRect(b.x - 2, b.y - 6, 4, 12);
		gameG.endFill();

		// Draw alien bullets (red)
		gameG.beginFill(0xFF3333);
		for (b in alienBullets)
			gameG.drawRect(b.x - 2, b.y - 6, 4, 12);
		gameG.endFill();
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
