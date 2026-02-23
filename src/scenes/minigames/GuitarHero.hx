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
	Guitar Hero com 4 lanes: dois botões à esquerda, dois à direita (segurar o celular com as duas mãos).
	Notas caem; você acerta a lane quando a nota entra na zona de hit.
	Sistema de música = placeholder por enquanto (notas em padrão exemplo).
**/
class GuitarHero implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var LANE_COUNT = 4;
	static var LANE_W = 90;
	static var NOTE_SPEED = 320;
	static var NOTE_H = 28;
	static var HIT_ZONE_TOP = 480;
	static var HIT_ZONE_BOTTOM = 540;
	static var MISS_LIMIT = 8;
	static var SPAWN_INTERVAL = 0.45;
	static var HIT_FLASH_DURATION = 0.18;
	static var HIT_TEXT_DURATION = 0.35;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var lanesG: Graphics;
	var notesG: Graphics;
	var hitZoneG: Graphics;
	var hitFeedbackG: Graphics;
	var scoreText: Text;
	var comboText: Text;
	var hitText: Text;
	var interactive: Interactive;
	var hitFlashLane: Int;
	var hitFlashTimer: Float;
	var hitTextTimer: Float;
	var hitTextLane: Int;

	var notes: Array<{ lane: Int, y: Float }>;
	var spawnTimer: Float;
	var started: Bool;
	var score: Int;
	var combo: Int;
	var misses: Int;
	var gameOver: Bool;
	var placeHolderBeat: Int;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x0d0d12);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		lanesG = new Graphics(contentObj);
		notesG = new Graphics(contentObj);
		hitZoneG = new Graphics(contentObj);
		hitFeedbackG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 12;
		scoreText.scale(1.4);
		scoreText.textAlign = Right;

		comboText = new Text(hxd.res.DefaultFont.get(), contentObj);
		comboText.text = "";
		comboText.x = designW / 2 - 30;
		comboText.y = 12;
		comboText.scale(1.2);
		comboText.textColor = 0xFFAA00;

		hitText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hitText.text = "HIT!";
		hitText.textAlign = Center;
		hitText.scale(1.8);
		hitText.visible = false;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onRelease = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) {
				started = true;
				e.propagate = false;
				return;
			}
			var lane = Std.int(e.relX / LANE_W);
			if (lane < 0) lane = 0;
			if (lane >= LANE_COUNT) lane = LANE_COUNT - 1;
			tryHitLane(lane);
			e.propagate = false;
		};
	}

	function tryHitLane(lane: Int) {
		for (n in notes) {
			if (n.lane != lane) continue;
			var noteBottom = n.y + NOTE_H;
			if (noteBottom >= HIT_ZONE_TOP && n.y <= HIT_ZONE_BOTTOM) {
				notes.remove(n);
				score++;
				combo++;
				triggerHitFeedback(lane);
				return;
			}
		}
		combo = 0;
	}

	function triggerHitFeedback(lane: Int) {
		hitFlashLane = lane;
		hitFlashTimer = HIT_FLASH_DURATION;
		hitTextLane = lane;
		hitTextTimer = HIT_TEXT_DURATION;
		hitText.visible = true;
		hitText.x = lane * LANE_W + LANE_W / 2;
		hitText.y = (HIT_ZONE_TOP + HIT_ZONE_BOTTOM) / 2 - 20;
		hitText.text = combo > 1 ? 'x${combo}' : "HIT!";
		hitText.textColor = combo > 1 ? 0xFFDD00 : 0xFFFFFF;
		hitText.alpha = 1;
		hitText.scaleX = hitText.scaleY = 1.2;
	}

	function spawnNote(lane: Int) {
		notes.push({ lane: lane, y: -NOTE_H });
	}

	function drawLanes() {
		lanesG.clear();
		lanesG.lineStyle(2, 0x2a2a35);
		for (i in 1...LANE_COUNT) {
			var x = i * LANE_W;
			lanesG.moveTo(x, 0);
			lanesG.lineTo(x, designH);
		}
		lanesG.lineStyle(0);
		lanesG.beginFill(0x1a1a22, 0.6);
		for (i in 0...LANE_COUNT) {
			var x = i * LANE_W;
			lanesG.drawRect(x + 1, 0, LANE_W - 2, designH);
		}
		lanesG.endFill();
	}

	function drawHitZone() {
		hitZoneG.clear();
		hitZoneG.beginFill(0x333355, 0.25);
		hitZoneG.drawRect(0, HIT_ZONE_TOP, designW, HIT_ZONE_BOTTOM - HIT_ZONE_TOP);
		hitZoneG.endFill();
		hitZoneG.lineStyle(3, 0x5566FF);
		hitZoneG.moveTo(0, HIT_ZONE_TOP);
		hitZoneG.lineTo(designW, HIT_ZONE_TOP);
		hitZoneG.moveTo(0, HIT_ZONE_BOTTOM);
		hitZoneG.lineTo(designW, HIT_ZONE_BOTTOM);
		hitZoneG.lineStyle(0);
	}

	function drawHitFeedback() {
		hitFeedbackG.clear();
		if (hitFlashLane < 0 || hitFlashTimer <= 0) return;
		var t = hitFlashTimer / HIT_FLASH_DURATION;
		var colors = [0xE74C3C, 0x3498DB, 0x2ECC71, 0xF1C40F];
		var c = colors[hitFlashLane];
		var alpha = t * 0.85;
		hitFeedbackG.beginFill(c, alpha);
		hitFeedbackG.drawRect(hitFlashLane * LANE_W + 2, HIT_ZONE_TOP, LANE_W - 4, HIT_ZONE_BOTTOM - HIT_ZONE_TOP);
		hitFeedbackG.endFill();
		hitFeedbackG.beginFill(0xFFFFFF, t * 0.4);
		hitFeedbackG.drawRect(hitFlashLane * LANE_W + 8, HIT_ZONE_TOP + 8, LANE_W - 16, HIT_ZONE_BOTTOM - HIT_ZONE_TOP - 16);
		hitFeedbackG.endFill();
	}

	function drawNotes() {
		notesG.clear();
		var colors = [0xE74C3C, 0x3498DB, 0x2ECC71, 0xF1C40F];
		for (n in notes) {
			var x = n.lane * LANE_W + 4;
			notesG.beginFill(colors[n.lane]);
			notesG.drawRoundedRect(x, n.y, LANE_W - 8, NOTE_H, 6);
			notesG.endFill();
			notesG.lineStyle(2, 0xFFFFFF, 0.4);
			notesG.drawRoundedRect(x, n.y, LANE_W - 8, NOTE_H, 6);
			notesG.lineStyle(0);
		}
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		notes = [];
		spawnTimer = 0;
		started = false;
		score = 0;
		combo = 0;
		misses = 0;
		gameOver = false;
		placeHolderBeat = 0;
		hitFlashLane = -1;
		hitFlashTimer = 0;
		hitTextTimer = 0;
		hitTextLane = -1;
		scoreText.text = "0";
		comboText.text = "";
		hitText.visible = false;
		drawLanes();
		drawHitZone();
		drawHitFeedback();
		drawNotes();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		notes = [];
	}

	public function getMinigameId(): String return "guitar-hero";
	public function getTitle(): String return "Guitar Hero";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started) {
			drawLanes();
			drawHitZone();
			drawHitFeedback();
			drawNotes();
			return;
		}

		for (n in notes) n.y += NOTE_SPEED * dt;

		var i = notes.length - 1;
		while (i >= 0) {
			if (notes[i].y > designH) {
				notes.splice(i, 1);
				misses++;
				combo = 0;
				if (misses >= MISS_LIMIT) {
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				}
			}
			i--;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			placeHolderPattern();
		}

		if (hitFlashTimer > 0) {
			hitFlashTimer -= dt;
			if (hitFlashTimer <= 0) hitFlashLane = -1;
		}
		if (hitTextTimer > 0) {
			hitTextTimer -= dt;
			var t = hitTextTimer / HIT_TEXT_DURATION;
			hitText.alpha = t;
			hitText.scaleX = hitText.scaleY = 1.2 + (1 - t) * 0.4;
			hitText.y = (HIT_ZONE_TOP + HIT_ZONE_BOTTOM) / 2 - 20 - (1 - t) * 25;
			if (hitTextTimer <= 0) hitText.visible = false;
		}

		comboText.text = combo > 1 ? 'x${combo}' : "";
		drawLanes();
		drawHitZone();
		drawHitFeedback();
		drawNotes();
	}

	function placeHolderPattern() {
		placeHolderBeat++;
		var r = placeHolderBeat % 8;
		if (r == 0 || r == 4) spawnNote(Std.random(LANE_COUNT));
		else if (r == 1 || r == 5) {
			spawnNote(0);
			spawnNote(2);
		} else if (r == 2 || r == 6) spawnNote(1);
		else spawnNote(3);
	}
}
