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
	Simon Says: 4 cores no centro; o jogo toca uma sequência (pisca as cores).
	Você repete a mesma sequência. A cada rodada aumenta mais um; errar = perde.
**/
class SimonSays implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var CENTER_X = 180;
	static var CENTER_Y = 300;
	static var RADIUS = 130;
	static var FLASH_DURATION = 0.42;
	static var PAUSE_BETWEEN = 0.18;
	static var ROUND_DONE_DELAY = 0.5;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var padsG: Graphics;
	var scoreText: Text;
	var roundText: Text;
	var interactive: Interactive;

	var sequence: Array<Int>;
	var userStep: Int;
	var state: SimonState;
	var playIndex: Int;
	var playTimer: Float;
	var roundDoneTimer: Float;
	var score: Int;
	var gameOver: Bool;
	var started: Bool;
	var flashPad: Int;
	var flashTimer: Float;

	static var COLORS = [0x27ae60, 0xE74C3C, 0xF1C40F, 0x3498DB];
	static var COLORS_BRIGHT = [0x2ecc71, 0xFF6B6B, 0xFFE066, 0x74B9FF];

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x1a1a2e);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		padsG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 22;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;

		roundText = new Text(hxd.res.DefaultFont.get(), contentObj);
		roundText.text = "Repita!";
		roundText.textAlign = Center;
		roundText.x = designW / 2;
		roundText.y = 520;
		roundText.scale(1.3);
		roundText.alpha = 0.9;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onRelease = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) {
				started = true;
				startRound();
				e.propagate = false;
				return;
			}
			if (state != AwaitingInput) return;
			var pad = padFromPoint(e.relX, e.relY);
			if (pad < 0) return;
			flashPad = pad;
			flashTimer = 0.2;
			if (pad != sequence[userStep]) {
				gameOver = true;
				ctx.lose(score, getMinigameId());
				ctx = null;
				return;
			}
			userStep++;
			if (userStep >= sequence.length) {
				score = sequence.length;
				scoreText.text = Std.string(score);
				state = RoundDone;
				roundDoneTimer = ROUND_DONE_DELAY;
			}
			e.propagate = false;
		};
	}

	inline function padFromPoint(x: Float, y: Float): Int {
		var dx = x - CENTER_X;
		var dy = y - CENTER_Y;
		var dist = Math.sqrt(dx * dx + dy * dy);
		if (dist > RADIUS || dist < RADIUS * 0.35) return -1;
		var angle = Math.atan2(dy, dx);
		var pi4 = Math.PI / 4;
		var pi34 = 3 * Math.PI / 4;
		if (angle >= -pi34 && angle < -pi4) return 0;
		if (angle >= -pi4 && angle < pi4) return 1;
		if (angle >= pi4 && angle < pi34) return 2;
		return 3;
	}

	function startRound() {
		sequence.push(Std.int(Math.random() * 4));
		userStep = 0;
		state = Playing;
		playIndex = 0;
		playTimer = 0;
		roundText.text = "Observe...";
	}

	function drawPads() {
		padsG.clear();
		var cx = CENTER_X;
		var cy = CENTER_Y;
		var starts = [5 * Math.PI / 4, 7 * Math.PI / 4, Math.PI / 4, 3 * Math.PI / 4];
		var ends   = [7 * Math.PI / 4, 9 * Math.PI / 4, 3 * Math.PI / 4, 5 * Math.PI / 4];
		for (i in 0...4) {
			var startAngle = starts[i];
			var endAngle = ends[i];
			var bright = (state == Playing || state == AwaitingInput) && flashPad == i && flashTimer > 0;
			var c = bright ? COLORS_BRIGHT[i] : COLORS[i];
			padsG.beginFill(c);
			padsG.moveTo(cx, cy);
			for (a in 0...21) {
				var t = a / 20;
				var a2 = startAngle + t * (endAngle - startAngle);
				padsG.lineTo(cx + Math.cos(a2) * RADIUS, cy + Math.sin(a2) * RADIUS);
			}
			padsG.lineTo(cx, cy);
			padsG.endFill();
			padsG.lineStyle(4, 0xFFFFFF, 0.5);
			padsG.moveTo(cx, cy);
			for (a in 0...21) {
				var t = a / 20;
				var a2 = startAngle + t * (endAngle - startAngle);
				padsG.lineTo(cx + Math.cos(a2) * RADIUS, cy + Math.sin(a2) * RADIUS);
			}
			padsG.lineTo(cx, cy);
			padsG.lineStyle(0);
		}
		padsG.beginFill(0x1a1a2e);
		padsG.drawCircle(cx, cy, RADIUS * 0.35);
		padsG.endFill();
		padsG.lineStyle(3, 0x2a2a4e);
		padsG.drawCircle(cx, cy, RADIUS * 0.35);
		padsG.lineStyle(0);
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		sequence = [];
		userStep = 0;
		state = WaitingStart;
		playIndex = 0;
		playTimer = 0;
		roundDoneTimer = 0;
		score = 0;
		gameOver = false;
		started = false;
		flashPad = -1;
		flashTimer = 0;
		scoreText.text = "0";
		roundText.text = "Toque para começar";
		drawPads();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		sequence = [];
	}

	public function getMinigameId(): String return "simon-says";
	public function getTitle(): String return "Simon Says";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;

		if (flashTimer > 0) {
			flashTimer -= dt;
			if (flashTimer <= 0) flashPad = -1;
		}

		if (state == Playing) {
			playTimer -= dt;
			if (playTimer <= 0) {
				playIndex++;
				if (playIndex >= sequence.length) {
					state = AwaitingInput;
					roundText.text = "Sua vez!";
					drawPads();
					return;
				}
				flashPad = sequence[playIndex];
				flashTimer = FLASH_DURATION;
				playTimer = FLASH_DURATION + PAUSE_BETWEEN;
			}
		} else if (state == RoundDone) {
			roundDoneTimer -= dt;
			if (roundDoneTimer <= 0)
				startRound();
		}

		drawPads();
	}
}

private enum SimonState {
	WaitingStart;
	Playing;
	AwaitingInput;
	RoundDone;
}
