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
	Aca-mou (Whack-a-mole): 5 slots; bata nos alvos antes de sumirem.
	De vez em quando aparece um amigo (não bata) ou uma bomba (não bata). Bater em amigo ou bomba = perde.
**/
class WhackAMole implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var SLOT_COUNT = 5;
	static var SLOT_W = 64;
	static var SLOT_H = 90;
	static var SLOT_Y = 380;
	static var SLOT_START_X = 14;
	static var VISIBLE_TIME = 1.35;
	static var SPAWN_INTERVAL = 0.7;
	static var TARGET_CHANCE = 0.62;
	static var FRIEND_CHANCE = 0.19;
	static var BOMB_CHANCE = 0.19;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var slotsG: Graphics;
	var molesG: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var slots: Array<{ type: MoleType, spawnTime: Float }>;
	var spawnTimer: Float;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var now: Float;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x5D4E37);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		bg.beginFill(0x3d2e1f, 0.6);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		slotsG = new Graphics(contentObj);
		molesG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 20;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onRelease = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) {
				started = true;
				e.propagate = false;
				return;
			}
			var slot = slotFromX(e.relX);
			if (slot < 0 || slot >= SLOT_COUNT) return;
			var s = slots[slot];
			if (s == null) {
				e.propagate = false;
				return;
			}
			switch (s.type) {
				case Target:
					slots[slot] = null;
					score++;
					scoreText.text = Std.string(score);
				case Friend:
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				case Bomb:
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
			}
			e.propagate = false;
		};
	}

	inline function slotFromX(x: Float): Int {
		var i = Std.int((x - SLOT_START_X) / (SLOT_W + 4));
		if (i < 0) return -1;
		if (i >= SLOT_COUNT) return -1;
		return i;
	}

	inline function slotCenterX(slot: Int): Float {
		return SLOT_START_X + slot * (SLOT_W + 4) + SLOT_W / 2;
	}

	function drawSlots() {
		slotsG.clear();
		for (i in 0...SLOT_COUNT) {
			var x = SLOT_START_X + i * (SLOT_W + 4);
			slotsG.beginFill(0x2a1f15);
			slotsG.drawRoundedRect(x, SLOT_Y, SLOT_W, SLOT_H, 8);
			slotsG.endFill();
			slotsG.lineStyle(3, 0x1a1510);
			slotsG.drawRoundedRect(x, SLOT_Y, SLOT_W, SLOT_H, 8);
			slotsG.lineStyle(0);
			slotsG.beginFill(0x0d0a08);
			slotsG.drawEllipse(x + SLOT_W / 2, SLOT_Y + SLOT_H - 8, SLOT_W * 0.4, 12);
			slotsG.endFill();
		}
	}

	function drawMoles() {
		molesG.clear();
		for (i in 0...SLOT_COUNT) {
			var s = slots[i];
			if (s == null) continue;
			var age = now - s.spawnTime;
			if (age >= VISIBLE_TIME) {
				slots[i] = null;
				continue;
			}
			var cx = slotCenterX(i);
			var cy = SLOT_Y + SLOT_H / 2 - 10;
			var bob = Math.sin(age * 12) * 3;
			cy += bob;
			switch (s.type) {
				case Target:
					molesG.beginFill(0x8B4513);
					molesG.drawEllipse(cx, cy, 22, 26);
					molesG.endFill();
					molesG.beginFill(0x000000);
					molesG.drawCircle(cx - 6, cy - 4, 4);
					molesG.drawCircle(cx + 6, cy - 4, 4);
					molesG.endFill();
					molesG.beginFill(0xFF69B4);
					molesG.drawEllipse(cx, cy + 8, 6, 4);
					molesG.endFill();
				case Friend:
					molesG.beginFill(0x87CEEB);
					molesG.drawEllipse(cx, cy, 24, 28);
					molesG.endFill();
					molesG.beginFill(0xFFFFFF);
					molesG.drawCircle(cx - 6, cy - 4, 5);
					molesG.drawCircle(cx + 6, cy - 4, 5);
					molesG.endFill();
					molesG.beginFill(0x000000);
					molesG.drawCircle(cx - 5, cy - 4, 2);
					molesG.drawCircle(cx + 7, cy - 4, 2);
					molesG.endFill();
					molesG.beginFill(0xFFB6C1);
					molesG.drawEllipse(cx, cy + 10, 8, 5);
					molesG.endFill();
				case Bomb:
					molesG.beginFill(0x333333);
					molesG.drawCircle(cx, cy + 4, 20);
					molesG.endFill();
					molesG.lineStyle(2, 0x555555);
					molesG.drawCircle(cx, cy + 4, 20);
					molesG.lineStyle(0);
					molesG.beginFill(0x444444);
					molesG.drawRect(cx - 4, cy - 22, 8, 14);
					molesG.endFill();
					molesG.beginFill(0xFF4444);
					molesG.drawCircle(cx, cy - 26, 6);
					molesG.endFill();
			}
		}
	}

	function spawn() {
		var free: Array<Int> = [];
		for (i in 0...SLOT_COUNT) if (slots[i] == null) free.push(i);
		if (free.length == 0) return;
		var slot = free[Std.int(Math.random() * free.length)];
		var r = Math.random();
		var type = r < TARGET_CHANCE ? Target : (r < TARGET_CHANCE + FRIEND_CHANCE ? Friend : Bomb);
		slots[slot] = { type: type, spawnTime: now };
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		slots = [];
		for (_ in 0...SLOT_COUNT) slots.push(null);
		spawnTimer = 0.5;
		started = false;
		score = 0;
		gameOver = false;
		now = 0;
		scoreText.text = "0";
		drawSlots();
		drawMoles();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		slots = [];
	}

	public function getMinigameId(): String return "whack-a-mole";
	public function getTitle(): String return "Aca-mou";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started) {
			drawSlots();
			drawMoles();
			return;
		}
		now += dt;
		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			spawn();
		}
		drawSlots();
		drawMoles();
	}
}

private enum MoleType {
	Target;
	Friend;
	Bomb;
}
