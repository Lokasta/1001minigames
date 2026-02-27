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
	Simon Says: 4 cores. O jogo pisca uma sequência crescente; repita na ordem.
	A cada rodada, um novo item é adicionado. Errar = perde.
**/
class SimonSays implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var CENTER_X = 180;
	static var CENTER_Y = 310;
	static var RADIUS = 135;
	static var INNER_R = 0.28;
	static var FLASH_DURATION = 0.55;
	static var PAUSE_BETWEEN = 0.25;
	static var ROUND_DONE_DELAY = 0.6;
	static var PRE_FLASH_DELAY = 0.7;
	static var DEATH_DUR = 0.6;
	static var CORRECT_FLASH_DUR = 0.2;

	static var COLORS = [0x27ae60, 0xE74C3C, 0xF1C40F, 0x3498DB];
	static var COLORS_BRIGHT = [0x5FF09A, 0xFF8888, 0xFFF088, 0x88CCFF];
	static var COLORS_DIM = [0x1D8A4D, 0xB83A30, 0xC09B30, 0x2A7AAA];

	final contentObj:Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var bg:Graphics;
	var padsG:Graphics;
	var glowG:Graphics;
	var flashG:Graphics;
	var scoreText:Text;
	var levelText:Text;
	var statusText:Text;
	var interactive:Interactive;

	var sequence:Array<Int>;
	var userStep:Int;
	var state:SimonState;
	var playIndex:Int;
	var playTimer:Float;
	var roundDoneTimer:Float;
	var score:Int;
	var gameOver:Bool;
	var deathTimer:Float;
	var started:Bool;
	var flashPad:Int;
	var flashTimer:Float;
	var correctFlashTimer:Float;
	var preFlashTimer:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		padsG = new Graphics(contentObj);
		glowG = new Graphics(contentObj);
		flashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 14;
		scoreText.y = 18;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		levelText = new Text(hxd.res.DefaultFont.get(), contentObj);
		levelText.text = "";
		levelText.x = 14;
		levelText.y = 18;
		levelText.scale(1.1);
		levelText.textAlign = Left;
		levelText.textColor = 0x888899;

		statusText = new Text(hxd.res.DefaultFont.get(), contentObj);
		statusText.text = "Toque para começar";
		statusText.x = designW / 2;
		statusText.y = 530;
		statusText.scale(1.4);
		statusText.textAlign = Center;
		statusText.textColor = 0xDDDDEE;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (ctx == null || gameOver)
				return;
			if (!started) {
				started = true;
				startRound();
				e.propagate = false;
				return;
			}
			if (state != AwaitingInput)
				return;
			var pad = padFromPoint(e.relX, e.relY);
			if (pad < 0)
				return;
			flashPad = pad;
			flashTimer = 0.2;
			if (pad != sequence[userStep]) {
				gameOver = true;
				deathTimer = 0;
				statusText.text = "Errou!";
				statusText.textColor = 0xFF4444;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.3, 5);
				e.propagate = false;
				return;
			}
			userStep++;
			correctFlashTimer = CORRECT_FLASH_DUR;
			if (userStep >= sequence.length) {
				score = sequence.length;
				scoreText.text = Std.string(score);
				state = RoundDone;
				roundDoneTimer = ROUND_DONE_DELAY;
				statusText.text = "Correto!";
				statusText.textColor = 0x44FF88;
			}
			e.propagate = false;
		};
	}

	function padFromPoint(x:Float, y:Float):Int {
		var dx = x - CENTER_X;
		var dy = y - CENTER_Y;
		var dist = Math.sqrt(dx * dx + dy * dy);
		if (dist > RADIUS + 10 || dist < RADIUS * INNER_R)
			return -1;
		var angle = Math.atan2(dy, dx);
		var pi4 = Math.PI / 4;
		var pi34 = 3 * Math.PI / 4;
		if (angle >= -pi34 && angle < -pi4)
			return 0;
		if (angle >= -pi4 && angle < pi4)
			return 1;
		if (angle >= pi4 && angle < pi34)
			return 2;
		return 3;
	}

	function startRound() {
		sequence.push(Std.int(Math.random() * 4));
		userStep = 0;
		state = Playing;
		playIndex = -1;
		flashPad = -1;
		flashTimer = 0;
		preFlashTimer = PRE_FLASH_DELAY;
		playTimer = 0;
		statusText.text = "Observe...";
		statusText.textColor = 0xAAAABB;
		levelText.text = "Nível " + Std.string(sequence.length);
	}

	function drawBackground() {
		bg.clear();
		var top = 0x12121e;
		var bot = 0x0a0a14;
		var steps = 5;
		var stepH = designH / steps;
		for (i in 0...steps) {
			var t = i / (steps - 1);
			var r = Std.int(((top >> 16) & 0xFF) * (1 - t) + ((bot >> 16) & 0xFF) * t);
			var g = Std.int(((top >> 8) & 0xFF) * (1 - t) + ((bot >> 8) & 0xFF) * t);
			var b = Std.int((top & 0xFF) * (1 - t) + (bot & 0xFF) * t);
			bg.beginFill((r << 16) | (g << 8) | b);
			bg.drawRect(0, i * stepH, designW, stepH + 1);
			bg.endFill();
		}
	}

	function drawPads() {
		padsG.clear();
		glowG.clear();
		var cx = CENTER_X;
		var cy = CENTER_Y;
		var gap = 0.04;
		var starts = [
			-3 * Math.PI / 4 + gap,
			-Math.PI / 4 + gap,
			Math.PI / 4 + gap,
			3 * Math.PI / 4 + gap
		];
		var ends = [
			-Math.PI / 4 - gap,
			Math.PI / 4 - gap,
			3 * Math.PI / 4 - gap,
			5 * Math.PI / 4 - gap
		];

		for (i in 0...4) {
			var bright = flashPad == i && flashTimer > 0;
			var dimmed = state == Playing && !bright;
			var c = if (bright) COLORS_BRIGHT[i] else if (dimmed) COLORS_DIM[i] else COLORS[i];
			var innerR = RADIUS * INNER_R;
			var startA = starts[i];
			var endA = ends[i];
			var segs = 20;

			if (bright) {
				var glowAlpha = flashTimer / (state == Playing ? FLASH_DURATION : 0.2);
				glowG.beginFill(COLORS_BRIGHT[i], glowAlpha * 0.3);
				glowG.moveTo(cx + Math.cos(startA) * (RADIUS + 12), cy + Math.sin(startA) * (RADIUS + 12));
				for (a in 1...segs + 1) {
					var t = a / segs;
					var angle = startA + t * (endA - startA);
					glowG.lineTo(cx + Math.cos(angle) * (RADIUS + 12), cy + Math.sin(angle) * (RADIUS + 12));
				}
				for (a in 0...segs + 1) {
					var t = 1.0 - a / segs;
					var angle = startA + t * (endA - startA);
					glowG.lineTo(cx + Math.cos(angle) * (innerR - 4), cy + Math.sin(angle) * (innerR - 4));
				}
				glowG.endFill();
			}

			padsG.beginFill(c);
			padsG.moveTo(cx + Math.cos(startA) * innerR, cy + Math.sin(startA) * innerR);
			for (a in 1...segs + 1) {
				var t = a / segs;
				var angle = startA + t * (endA - startA);
				padsG.lineTo(cx + Math.cos(angle) * RADIUS, cy + Math.sin(angle) * RADIUS);
			}
			for (a in 0...segs + 1) {
				var t = 1.0 - a / segs;
				var angle = startA + t * (endA - startA);
				padsG.lineTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR);
			}
			padsG.endFill();

			padsG.beginFill(0xFFFFFF, bright ? 0.15 : 0.06);
			var highlightR = RADIUS * 0.7;
			var highlightInner = innerR + 6;
			padsG.moveTo(cx + Math.cos(startA) * highlightInner, cy + Math.sin(startA) * highlightInner);
			for (a in 1...segs + 1) {
				var t = a / segs;
				var angle = startA + t * (endA - startA);
				padsG.lineTo(cx + Math.cos(angle) * highlightR, cy + Math.sin(angle) * highlightR);
			}
			for (a in 0...segs + 1) {
				var t = 1.0 - a / segs;
				var angle = startA + t * (endA - startA);
				padsG.lineTo(cx + Math.cos(angle) * highlightInner, cy + Math.sin(angle) * highlightInner);
			}
			padsG.endFill();
		}

		padsG.beginFill(0x16162a);
		padsG.drawCircle(cx, cy, RADIUS * INNER_R);
		padsG.endFill();
		padsG.lineStyle(2, 0x2a2a4e);
		padsG.drawCircle(cx, cy, RADIUS * INNER_R);
		padsG.lineStyle(0);

		if (correctFlashTimer > 0) {
			var t = correctFlashTimer / CORRECT_FLASH_DUR;
			padsG.beginFill(0x44FF88, t * 0.4);
			padsG.drawCircle(cx, cy, RADIUS * INNER_R - 2);
			padsG.endFill();
		}
	}

	public function setOnLose(c:MinigameContext) {
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
		deathTimer = -1;
		started = false;
		flashPad = -1;
		flashTimer = 0;
		correctFlashTimer = 0;
		preFlashTimer = 0;
		scoreText.text = "0";
		levelText.text = "";
		statusText.text = "Toque para começar";
		statusText.textColor = 0xDDDDEE;
		flashG.clear();
		drawBackground();
		drawPads();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		sequence = [];
	}

	public function getMinigameId():String
		return "simon-says";

	public function getTitle():String
		return "Simon Says";

	public function update(dt:Float) {
		if (ctx == null)
			return;

		if (gameOver) {
			if (deathTimer >= 0) {
				deathTimer += dt;
				var t = deathTimer / DEATH_DUR;
				if (t < 1) {
					flashG.clear();
					flashG.beginFill(0xFF2222, (1 - t) * 0.35);
					flashG.drawRect(0, 0, designW, designH);
					flashG.endFill();
					drawPads();
				} else {
					flashG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}

		if (flashTimer > 0) {
			flashTimer -= dt;
			if (flashTimer <= 0)
				flashPad = -1;
		}

		if (correctFlashTimer > 0)
			correctFlashTimer -= dt;

		if (state == Playing) {
			if (preFlashTimer > 0) {
				preFlashTimer -= dt;
				if (preFlashTimer <= 0) {
					playIndex = 0;
					flashPad = sequence[0];
					flashTimer = FLASH_DURATION;
					playTimer = FLASH_DURATION + PAUSE_BETWEEN;
				}
				drawPads();
				return;
			}
			playTimer -= dt;
			if (playTimer <= 0) {
				playIndex++;
				if (playIndex >= sequence.length) {
					state = AwaitingInput;
					flashPad = -1;
					statusText.text = "Sua vez!";
					statusText.textColor = 0xFFFFFF;
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
