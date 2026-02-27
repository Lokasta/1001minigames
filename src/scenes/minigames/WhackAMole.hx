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
	Whack-a-Mole: 3x3 grid de buracos. Toupeiras marrons = acerte.
	Coelhos azuis (amigo) e bombas = não bata. Miss limit = perder toupeiras demais.
**/
class WhackAMole implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var COLS = 3;
	static var ROWS = 3;
	static var HOLE_COUNT = 9;
	static var HOLE_W = 80;
	static var HOLE_H = 60;
	static var GRID_X = 30;
	static var GRID_Y = 220;
	static var COL_SPACING = 100;
	static var ROW_SPACING = 110;
	static var VISIBLE_TIME_START = 1.5;
	static var VISIBLE_TIME_MIN = 0.6;
	static var SPAWN_INTERVAL_START = 0.8;
	static var SPAWN_INTERVAL_MIN = 0.35;
	static var SPEED_RAMP = 60.0;
	static var TARGET_CHANCE = 0.65;
	static var FRIEND_CHANCE = 0.17;
	static var BOMB_CHANCE = 0.18;
	static var MISS_LIMIT = 8;
	static var WHACK_DUR = 0.25;
	static var DEATH_DUR = 0.5;

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var bg:Graphics;
	var holesG:Graphics;
	var molesG:Graphics;
	var effectsG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var missText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var slots:Array<MoleSlot>;
	var whacks:Array<{x:Float, y:Float, t:Float}>;
	var spawnTimer:Float;
	var started:Bool;
	var score:Int;
	var misses:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var now:Float;
	var elapsed:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		whacks = [];

		bg = new Graphics(contentObj);
		holesG = new Graphics(contentObj);
		molesG = new Graphics(contentObj);
		effectsG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 14;
		scoreText.y = 18;
		scoreText.scale(2.0);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		missText = new Text(hxd.res.DefaultFont.get(), contentObj);
		missText.text = "";
		missText.x = 14;
		missText.y = 22;
		missText.scale(1.0);
		missText.textAlign = Left;
		missText.textColor = 0xFF6666;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Acerte as toupeiras!";
		instructText.x = designW / 2;
		instructText.y = 160;
		instructText.scale(1.3);
		instructText.textAlign = Center;
		instructText.textColor = 0xFFFFFF;
		instructText.visible = true;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (ctx == null || gameOver)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			var idx = holeFromPos(e.relX, e.relY);
			if (idx < 0 || idx >= HOLE_COUNT) {
				e.propagate = false;
				return;
			}
			var s = slots[idx];
			if (s == null) {
				e.propagate = false;
				return;
			}
			var hx = holeX(idx) + HOLE_W / 2;
			var hy = holeY(idx) + HOLE_H / 2 - 20;
			switch (s.type) {
				case Target:
					slots[idx] = null;
					score++;
					scoreText.text = Std.string(score);
					whacks.push({x: hx, y: hy, t: 0});
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.06, 2);
				case Friend:
					gameOver = true;
					deathTimer = 0;
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.3, 5);
				case Bomb:
					gameOver = true;
					deathTimer = 0;
					if (ctx != null && ctx.feedback != null) {
						ctx.feedback.shake2D(0.4, 6);
						ctx.feedback.flash(0xFF2200, 0.15);
					}
			}
			e.propagate = false;
		};
	}

	function holeX(idx:Int):Float
		return GRID_X + (idx % COLS) * COL_SPACING;

	function holeY(idx:Int):Float
		return GRID_Y + Std.int(idx / COLS) * ROW_SPACING;

	function holeFromPos(px:Float, py:Float):Int {
		for (i in 0...HOLE_COUNT) {
			var x = holeX(i);
			var y = holeY(i);
			if (px >= x - 10 && px <= x + HOLE_W + 10 && py >= y - 30 && py <= y + HOLE_H + 10)
				return i;
		}
		return -1;
	}

	function currentVisibleTime():Float {
		var t = if (elapsed > SPEED_RAMP) 1.0 else elapsed / SPEED_RAMP;
		return VISIBLE_TIME_START + (VISIBLE_TIME_MIN - VISIBLE_TIME_START) * t;
	}

	function currentSpawnInterval():Float {
		var t = if (elapsed > SPEED_RAMP) 1.0 else elapsed / SPEED_RAMP;
		return SPAWN_INTERVAL_START + (SPAWN_INTERVAL_MIN - SPAWN_INTERVAL_START) * t;
	}

	function drawBackground() {
		bg.clear();
		var grassTop = 0x4CAF50;
		var grassBot = 0x388E3C;
		var steps = 6;
		var stepH = designH / steps;
		for (i in 0...steps) {
			var t = i / (steps - 1);
			var r = Std.int(((grassTop >> 16) & 0xFF) * (1 - t) + ((grassBot >> 16) & 0xFF) * t);
			var g = Std.int(((grassTop >> 8) & 0xFF) * (1 - t) + ((grassBot >> 8) & 0xFF) * t);
			var b = Std.int((grassTop & 0xFF) * (1 - t) + (grassBot & 0xFF) * t);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, i * stepH, designW, stepH + 1);
			bg.endFill();
		}
		bg.beginFill(0x2E7D32, 0.3);
		bg.drawEllipse(80, 120, 60, 30);
		bg.drawEllipse(280, 100, 50, 25);
		bg.drawEllipse(180, 580, 70, 30);
		bg.endFill();
	}

	function drawHoles() {
		holesG.clear();
		for (i in 0...HOLE_COUNT) {
			var x = holeX(i);
			var y = holeY(i);
			var cx = x + HOLE_W / 2;
			var cy = y + HOLE_H / 2;
			holesG.beginFill(0x3E2723);
			holesG.drawEllipse(cx, cy + 8, HOLE_W / 2 + 4, HOLE_H / 2 + 2);
			holesG.endFill();
			holesG.beginFill(0x1B0F0A);
			holesG.drawEllipse(cx, cy + 5, HOLE_W / 2, HOLE_H / 2 - 4);
			holesG.endFill();
			holesG.beginFill(0x5D4037, 0.5);
			holesG.drawEllipse(cx, cy + 12, HOLE_W / 2 + 6, 8);
			holesG.endFill();
		}
	}

	function drawMoles() {
		molesG.clear();
		var visTime = currentVisibleTime();
		for (i in 0...HOLE_COUNT) {
			var s = slots[i];
			if (s == null)
				continue;
			var age = now - s.spawnTime;
			if (age >= visTime) {
				if (s.type == Target) {
					misses++;
					updateMissText();
				}
				slots[i] = null;
				continue;
			}
			var cx = holeX(i) + HOLE_W / 2;
			var cy = holeY(i) + HOLE_H / 2;
			var popT = if (age < 0.12) age / 0.12 else if (age > visTime - 0.15) (visTime - age) / 0.15 else 1.0;
			if (popT < 0) popT = 0;
			if (popT > 1) popT = 1;
			var yOff = (1 - popT) * 30;
			cy = cy - 20 + yOff;
			var bob = Math.sin(age * 8) * 2;
			cy += bob;
			switch (s.type) {
				case Target:
					molesG.beginFill(0x8B6914);
					molesG.drawEllipse(cx, cy, 24, 28);
					molesG.endFill();
					molesG.beginFill(0xA07828);
					molesG.drawEllipse(cx, cy - 2, 20, 22);
					molesG.endFill();
					molesG.beginFill(0x8B6914);
					molesG.drawEllipse(cx - 16, cy - 22, 8, 10);
					molesG.drawEllipse(cx + 16, cy - 22, 8, 10);
					molesG.endFill();
					molesG.beginFill(0xFFFFFF);
					molesG.drawCircle(cx - 7, cy - 6, 5);
					molesG.drawCircle(cx + 7, cy - 6, 5);
					molesG.endFill();
					molesG.beginFill(0x111111);
					molesG.drawCircle(cx - 6, cy - 6, 3);
					molesG.drawCircle(cx + 8, cy - 6, 3);
					molesG.endFill();
					molesG.beginFill(0xFF69B4);
					molesG.drawEllipse(cx, cy + 6, 7, 5);
					molesG.endFill();
					molesG.beginFill(0x6B5010);
					molesG.drawRect(cx - 14, cy + 2, 3, 1);
					molesG.drawRect(cx - 16, cy + 5, 4, 1);
					molesG.drawRect(cx + 11, cy + 2, 3, 1);
					molesG.drawRect(cx + 12, cy + 5, 4, 1);
					molesG.endFill();
				case Friend:
					molesG.beginFill(0x90CAF9);
					molesG.drawEllipse(cx, cy, 22, 26);
					molesG.endFill();
					molesG.beginFill(0xBBDEFB);
					molesG.drawEllipse(cx, cy - 2, 18, 20);
					molesG.endFill();
					molesG.beginFill(0x90CAF9);
					molesG.drawEllipse(cx - 10, cy - 30, 6, 16);
					molesG.drawEllipse(cx + 10, cy - 30, 6, 16);
					molesG.endFill();
					molesG.beginFill(0xFFFFFF);
					molesG.drawCircle(cx - 6, cy - 6, 5);
					molesG.drawCircle(cx + 6, cy - 6, 5);
					molesG.endFill();
					molesG.beginFill(0x1565C0);
					molesG.drawCircle(cx - 5, cy - 6, 2.5);
					molesG.drawCircle(cx + 7, cy - 6, 2.5);
					molesG.endFill();
					molesG.beginFill(0xFFB6C1);
					molesG.drawEllipse(cx, cy + 8, 6, 4);
					molesG.endFill();
				case Bomb:
					molesG.beginFill(0x222222);
					molesG.drawCircle(cx, cy + 2, 22);
					molesG.endFill();
					molesG.beginFill(0x333333, 0.4);
					molesG.drawCircle(cx - 6, cy - 6, 8);
					molesG.endFill();
					molesG.lineStyle(2, 0x444444);
					molesG.drawCircle(cx, cy + 2, 22);
					molesG.lineStyle(0);
					molesG.beginFill(0x555555);
					molesG.drawRect(cx - 3, cy - 24, 6, 12);
					molesG.endFill();
					var sparkT = Math.sin(now * 10) * 0.5 + 0.5;
					molesG.beginFill(0xFF4422, 0.6 + sparkT * 0.4);
					molesG.drawCircle(cx, cy - 26, 4 + sparkT * 2);
					molesG.endFill();
					molesG.beginFill(0xFFAA00, sparkT * 0.7);
					molesG.drawCircle(cx, cy - 28, 2);
					molesG.endFill();
			}
		}
	}

	function drawEffects() {
		effectsG.clear();
		for (w in whacks) {
			var t = w.t / WHACK_DUR;
			if (t >= 1)
				continue;
			var alpha = 1 - t;
			var spread = 15 + t * 25;
			effectsG.beginFill(0xFFDD00, alpha * 0.8);
			for (a in 0...5) {
				var angle = a * Math.PI * 2 / 5 + t * 2;
				var sx = w.x + Math.cos(angle) * spread;
				var sy = w.y + Math.sin(angle) * spread;
				effectsG.drawCircle(sx, sy, 4 - t * 3);
			}
			effectsG.endFill();
			effectsG.beginFill(0xFFFFFF, alpha * 0.5);
			effectsG.drawCircle(w.x, w.y, 8 + t * 12);
			effectsG.endFill();
		}
	}

	function updateMissText() {
		var remaining = MISS_LIMIT - misses;
		if (remaining < 0) remaining = 0;
		var txt = "";
		for (_ in 0...remaining)
			txt += "o";
		for (_ in 0...misses)
			txt += "x";
		missText.text = txt;
	}

	function spawn() {
		var free:Array<Int> = [];
		for (i in 0...HOLE_COUNT)
			if (slots[i] == null)
				free.push(i);
		if (free.length == 0)
			return;
		var slot = free[Std.int(Math.random() * free.length)];
		var r = Math.random();
		var type = if (r < TARGET_CHANCE) Target else if (r < TARGET_CHANCE + FRIEND_CHANCE) Friend else Bomb;
		slots[slot] = {type: type, spawnTime: now};
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		slots = [];
		for (_ in 0...HOLE_COUNT)
			slots.push(null);
		whacks = [];
		spawnTimer = 0.5;
		started = false;
		score = 0;
		misses = 0;
		gameOver = false;
		deathTimer = -1;
		now = 0;
		elapsed = 0;
		scoreText.text = "0";
		instructText.visible = true;
		missText.text = "";
		flashG.clear();
		drawBackground();
		drawHoles();
		drawMoles();
		drawEffects();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		slots = [];
	}

	public function getMinigameId():String
		return "whack-a-mole";

	public function getTitle():String
		return "Acerte a Toupeira";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFF0000, (1 - t) * 0.4);
					flashG.drawRect(0, 0, designW, designH);
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
			drawHoles();
			drawMoles();
			return;
		}

		now += dt;
		elapsed += dt;

		if (misses >= MISS_LIMIT) {
			gameOver = true;
			deathTimer = 0;
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = currentSpawnInterval();
			spawn();
		}

		var i = whacks.length - 1;
		while (i >= 0) {
			whacks[i].t += dt;
			if (whacks[i].t >= WHACK_DUR)
				whacks.splice(i, 1);
			i--;
		}

		drawHoles();
		drawMoles();
		drawEffects();
	}
}

private enum MoleType {
	Target;
	Friend;
	Bomb;
}

private typedef MoleSlot = Null<{type:MoleType, spawnTime:Float}>;
