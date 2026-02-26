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
	Guitar Hero com 4 lanes, sistema de BPM e músicas pré-chartadas.
	Notas caem sincronizadas ao BPM; toque a lane quando a nota chega na zona de hit.
	Perfect/Good/Miss timing; combo multiplier; health bar.
**/
class GuitarHero implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var LANE_COUNT = 4;
	static var LANE_W = 90;
	static var NOTE_SPEED = 240;
	static var NOTE_H = 24;
	static var HIT_Y = 520;
	static var PERFECT_RANGE = 25.0;
	static var GOOD_RANGE = 55.0;
	static var MISS_RANGE = 80.0;
	static var MAX_HEALTH = 30;
	static var HIT_FLASH_DURATION = 0.15;
	static var FEEDBACK_DURATION = 0.4;
	static var LANE_COLORS:Array<Int> = [0xE74C3C, 0x3498DB, 0x2ECC71, 0xF1C40F];

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var bg:Graphics;
	var lanesG:Graphics;
	var notesG:Graphics;
	var hitZoneG:Graphics;
	var hitFeedbackG:Graphics;
	var healthG:Graphics;
	var beatPulseG:Graphics;
	var scoreText:Text;
	var comboText:Text;
	var feedbackText:Text;
	var instructText:Text;
	var songTitle:Text;
	var interactive:Interactive;

	var hitFlashLane:Int;
	var hitFlashTimer:Float;
	var feedbackTimer:Float;
	var feedbackMsg:String;
	var feedbackColor:Int;

	var notes:Array<{lane:Int, y:Float, hit:Bool}>;
	var started:Bool;
	var score:Int;
	var combo:Int;
	var maxCombo:Int;
	var health:Int;
	var gameOver:Bool;

	var bpm:Float;
	var beatInterval:Float;
	var songTime:Float;
	var songNotes:Array<{beat:Float, lane:Int}>;
	var nextNoteIdx:Int;
	var travelTime:Float;
	var beatPulseT:Float;
	var lastBeatNum:Int;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x08080f);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		lanesG = new Graphics(contentObj);
		notesG = new Graphics(contentObj);
		hitZoneG = new Graphics(contentObj);
		hitFeedbackG = new Graphics(contentObj);
		healthG = new Graphics(contentObj);
		beatPulseG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 14;
		scoreText.y = 10;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		comboText = new Text(hxd.res.DefaultFont.get(), contentObj);
		comboText.text = "";
		comboText.x = designW / 2;
		comboText.y = 10;
		comboText.scale(1.3);
		comboText.textAlign = Center;
		comboText.textColor = 0xFFAA00;

		feedbackText = new Text(hxd.res.DefaultFont.get(), contentObj);
		feedbackText.text = "";
		feedbackText.x = designW / 2;
		feedbackText.y = HIT_Y - 50;
		feedbackText.scale(2.0);
		feedbackText.textAlign = Center;
		feedbackText.visible = false;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Toque para começar";
		instructText.x = designW / 2;
		instructText.y = designH / 2 - 20;
		instructText.scale(1.3);
		instructText.textAlign = Center;
		instructText.textColor = 0xFFFFFF;

		songTitle = new Text(hxd.res.DefaultFont.get(), contentObj);
		songTitle.text = "";
		songTitle.x = 14;
		songTitle.y = 10;
		songTitle.scale(0.9);
		songTitle.textAlign = Left;
		songTitle.textColor = 0x888899;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
				e.propagate = false;
				return;
			}
			var lane = Std.int(e.relX / LANE_W);
			if (lane < 0)
				lane = 0;
			if (lane >= LANE_COUNT)
				lane = LANE_COUNT - 1;
			tryHitLane(lane);
			e.propagate = false;
		};
	}

	function tryHitLane(lane:Int) {
		var bestNote:{lane:Int, y:Float, hit:Bool} = null;
		var bestDist = 999.0;
		for (n in notes) {
			if (n.lane != lane || n.hit)
				continue;
			var noteCenter = n.y + NOTE_H / 2;
			var dist = Math.abs(noteCenter - HIT_Y);
			if (dist < bestDist && dist < MISS_RANGE) {
				bestDist = dist;
				bestNote = n;
			}
		}
		if (bestNote != null) {
			bestNote.hit = true;
			if (bestDist <= PERFECT_RANGE) {
				score += 3 * comboMultiplier();
				combo++;
				if (health < MAX_HEALTH) health++;
				showFeedback("PERFECT", 0x00FFAA);
			} else if (bestDist <= GOOD_RANGE) {
				score += 2 * comboMultiplier();
				combo++;
				showFeedback("GOOD", 0xFFDD00);
			} else {
				score += 1 * comboMultiplier();
				combo++;
				showFeedback("OK", 0xAAAACC);
			}
			if (combo > maxCombo)
				maxCombo = combo;
			triggerHitFlash(lane);
		} else {
			combo = 0;
			showFeedback("MISS", 0xFF4444);
		}
		scoreText.text = Std.string(score);
	}

	function comboMultiplier():Int {
		if (combo >= 30) return 4;
		if (combo >= 15) return 3;
		if (combo >= 5) return 2;
		return 1;
	}

	function showFeedback(msg:String, color:Int) {
		feedbackMsg = msg;
		feedbackColor = color;
		feedbackTimer = FEEDBACK_DURATION;
		feedbackText.text = msg;
		feedbackText.textColor = color;
		feedbackText.visible = true;
		feedbackText.alpha = 1;
		feedbackText.scaleX = feedbackText.scaleY = 2.0;
		feedbackText.y = HIT_Y - 50;
	}

	function triggerHitFlash(lane:Int) {
		hitFlashLane = lane;
		hitFlashTimer = HIT_FLASH_DURATION;
	}

	function buildSong():Array<{beat:Float, lane:Int}> {
		bpm = 130;
		songTitle.text = "Neon Rush";
		var s:Array<{beat:Float, lane:Int}> = [];
		var patterns:Array<Array<Int>> = [
			[0, 2], [1], [3], [0], [2, 3], [1], [0], [3],
			[1, 3], [0], [2], [1], [0, 2], [3], [1], [2],
			[0], [1, 2], [3], [0], [2], [0, 3], [1], [2],
			[3], [0], [1, 3], [2], [0], [1], [2, 3], [0],
		];
		for (i in 0...patterns.length) {
			for (lane in patterns[i])
				s.push({beat: i * 1.0, lane: lane});
		}
		var bridge:Array<Array<Int>> = [
			[0, 1, 2, 3], [], [0, 3], [], [1, 2], [], [0, 1, 2, 3], [],
		];
		var offset = patterns.length;
		for (i in 0...bridge.length) {
			for (lane in bridge[i])
				s.push({beat: offset + i * 1.0, lane: lane});
		}
		var verse2:Array<Array<Int>> = [
			[2], [0, 3], [1], [2], [0], [3], [1, 2], [0],
			[3], [1], [0, 2], [3], [1], [0], [2, 3], [1],
			[0], [2], [3, 1], [0], [2], [1], [0, 3], [2],
			[1], [0, 2], [3], [1], [0], [2], [1, 3], [0],
		];
		var offset2 = offset + bridge.length;
		for (i in 0...verse2.length) {
			for (lane in verse2[i])
				s.push({beat: offset2 + i * 1.0, lane: lane});
		}
		var finale:Array<Array<Int>> = [
			[0, 1], [2, 3], [0, 1], [2, 3],
			[0, 2], [1, 3], [0, 2], [1, 3],
			[0, 1, 2, 3], [], [0, 1, 2, 3], [],
			[0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3],
		];
		var offset3 = offset2 + verse2.length;
		for (i in 0...finale.length) {
			for (lane in finale[i])
				s.push({beat: offset3 + i * 0.5, lane: lane});
		}
		return s;
	}

	function drawLanes() {
		lanesG.clear();
		for (i in 0...LANE_COUNT) {
			var x = i * LANE_W;
			var c = LANE_COLORS[i];
			var r = (c >> 16) & 0xFF;
			var g = (c >> 8) & 0xFF;
			var b = c & 0xFF;
			var dimColor = (Std.int(r * 0.08) << 16) | (Std.int(g * 0.08) << 8) | Std.int(b * 0.08);
			lanesG.beginFill(dimColor, 0.6);
			lanesG.drawRect(x + 1, 0, LANE_W - 2, designH);
			lanesG.endFill();
		}
		lanesG.lineStyle(1, 0x1a1a28, 0.8);
		for (i in 1...LANE_COUNT) {
			lanesG.moveTo(i * LANE_W, 0);
			lanesG.lineTo(i * LANE_W, designH);
		}
		lanesG.lineStyle(0);
	}

	function drawHitZone() {
		hitZoneG.clear();
		var zoneH = 12.0;
		for (i in 0...LANE_COUNT) {
			var x = i * LANE_W;
			var c = LANE_COLORS[i];
			hitZoneG.beginFill(c, 0.15);
			hitZoneG.drawRect(x + 2, HIT_Y - zoneH, LANE_W - 4, zoneH * 2);
			hitZoneG.endFill();
			hitZoneG.beginFill(c, 0.5);
			hitZoneG.drawRect(x + 4, HIT_Y - 2, LANE_W - 8, 4);
			hitZoneG.endFill();
		}
		hitZoneG.lineStyle(2, 0x5566AA, 0.3);
		hitZoneG.moveTo(0, HIT_Y);
		hitZoneG.lineTo(designW, HIT_Y);
		hitZoneG.lineStyle(0);
	}

	function drawHitFeedback() {
		hitFeedbackG.clear();
		if (hitFlashLane < 0 || hitFlashTimer <= 0)
			return;
		var t = hitFlashTimer / HIT_FLASH_DURATION;
		var c = LANE_COLORS[hitFlashLane];
		hitFeedbackG.beginFill(c, t * 0.7);
		hitFeedbackG.drawRect(hitFlashLane * LANE_W + 2, HIT_Y - 25, LANE_W - 4, 50);
		hitFeedbackG.endFill();
		hitFeedbackG.beginFill(0xFFFFFF, t * 0.4);
		hitFeedbackG.drawRect(hitFlashLane * LANE_W + 10, HIT_Y - 15, LANE_W - 20, 30);
		hitFeedbackG.endFill();
	}

	function drawBeatPulse() {
		beatPulseG.clear();
		if (beatPulseT <= 0)
			return;
		var alpha = beatPulseT * 0.15;
		beatPulseG.lineStyle(2, 0x5566FF, alpha);
		beatPulseG.moveTo(0, HIT_Y);
		beatPulseG.lineTo(designW, HIT_Y);
		beatPulseG.lineStyle(0);
		for (i in 0...LANE_COUNT) {
			var x = i * LANE_W + LANE_W / 2;
			beatPulseG.beginFill(LANE_COLORS[i], alpha * 0.4);
			beatPulseG.drawCircle(x, HIT_Y, 8 + (1 - beatPulseT) * 15);
			beatPulseG.endFill();
		}
	}

	function drawNotes() {
		notesG.clear();
		for (n in notes) {
			if (n.hit)
				continue;
			var x = n.lane * LANE_W + 6;
			var w = LANE_W - 12;
			var c = LANE_COLORS[n.lane];
			notesG.beginFill(c, 0.9);
			notesG.drawRoundedRect(x, n.y, w, NOTE_H, 5);
			notesG.endFill();
			var r = (c >> 16) & 0xFF;
			var g = (c >> 8) & 0xFF;
			var b = c & 0xFF;
			var lightC = (Std.int(Math.min(255, r * 1.4)) << 16) | (Std.int(Math.min(255, g * 1.4)) << 8) | Std.int(Math.min(255, b * 1.4));
			notesG.beginFill(lightC, 0.5);
			notesG.drawRoundedRect(x + 3, n.y + 2, w - 6, NOTE_H * 0.4, 3);
			notesG.endFill();
		}
	}

	function drawHealth() {
		healthG.clear();
		var barW = 100.0;
		var barH = 6.0;
		var barX = designW / 2 - barW / 2;
		var barY = designH - 18.0;
		healthG.beginFill(0x222233, 0.7);
		healthG.drawRect(barX, barY, barW, barH);
		healthG.endFill();
		var ratio = health / MAX_HEALTH;
		var color = if (ratio > 0.5) 0x2ECC71 else if (ratio > 0.25) 0xF1C40F else 0xE74C3C;
		healthG.beginFill(color, 0.9);
		healthG.drawRect(barX, barY, barW * ratio, barH);
		healthG.endFill();
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		notes = [];
		started = false;
		score = 0;
		combo = 0;
		maxCombo = 0;
		health = MAX_HEALTH;
		gameOver = false;
		hitFlashLane = -1;
		hitFlashTimer = 0;
		feedbackTimer = 0;
		beatPulseT = 0;
		lastBeatNum = -1;
		songTime = 0;
		nextNoteIdx = 0;
		scoreText.text = "0";
		comboText.text = "";
		feedbackText.visible = false;
		instructText.visible = true;
		songNotes = buildSong();
		beatInterval = 60.0 / bpm;
		travelTime = (HIT_Y + NOTE_H) / NOTE_SPEED;
		drawLanes();
		drawHitZone();
		drawHitFeedback();
		drawNotes();
		drawHealth();
		drawBeatPulse();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		notes = [];
	}

	public function getMinigameId():String
		return "guitar-hero";

	public function getTitle():String
		return "Guitar Hero";

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started) {
			drawLanes();
			drawHitZone();
			drawNotes();
			drawHealth();
			return;
		}

		songTime += dt;

		var currentBeat = Std.int(songTime / beatInterval);
		if (currentBeat != lastBeatNum) {
			lastBeatNum = currentBeat;
			beatPulseT = 1.0;
		}
		if (beatPulseT > 0)
			beatPulseT -= dt * 4;

		while (nextNoteIdx < songNotes.length) {
			var sn = songNotes[nextNoteIdx];
			var spawnTime = sn.beat * beatInterval - travelTime;
			if (songTime >= spawnTime) {
				var startY = -(songTime - spawnTime) * NOTE_SPEED;
				notes.push({lane: sn.lane, y: startY, hit: false});
				nextNoteIdx++;
			} else {
				break;
			}
		}

		for (n in notes)
			n.y += NOTE_SPEED * dt;

		var i = notes.length - 1;
		while (i >= 0) {
			var n = notes[i];
			if (n.hit && n.y > HIT_Y + 60) {
				notes.splice(i, 1);
			} else if (!n.hit && n.y > HIT_Y + MISS_RANGE + NOTE_H) {
				notes.splice(i, 1);
				combo = 0;
				health--;
				showFeedback("MISS", 0xFF4444);
				if (health <= 0) {
					gameOver = true;
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.flash(0xFF0000, 0.2);
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				}
			}
			i--;
		}

		if (nextNoteIdx >= songNotes.length && notes.length == 0) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		if (hitFlashTimer > 0) {
			hitFlashTimer -= dt;
			if (hitFlashTimer <= 0)
				hitFlashLane = -1;
		}
		if (feedbackTimer > 0) {
			feedbackTimer -= dt;
			var t = feedbackTimer / FEEDBACK_DURATION;
			feedbackText.alpha = t;
			feedbackText.scaleX = feedbackText.scaleY = 2.0 + (1 - t) * 0.5;
			feedbackText.y = HIT_Y - 50 - (1 - t) * 30;
			if (feedbackTimer <= 0)
				feedbackText.visible = false;
		}

		var mult = comboMultiplier();
		comboText.text = if (combo > 2) 'x${combo}' + (mult > 1 ? ' (${mult}x)' : "") else "";

		drawLanes();
		drawHitZone();
		drawHitFeedback();
		drawBeatPulse();
		drawNotes();
		drawHealth();
	}
}
