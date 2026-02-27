package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class TapTheColor implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var TIME_LIMIT_START = 3.0;
	static var TIME_LIMIT_MIN = 1.0;
	static var TIME_SHRINK_PER_ROUND = 0.15;
	static var OPTION_COUNT = 4;

	static var COLOR_NAMES:Array<String> = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE", "ORANGE"];
	static var COLOR_VALUES:Array<Int> = [0xFF2222, 0x2266FF, 0x22CC44, 0xFFDD00, 0xBB44FF, 0xFF8800];

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var timerBarG:Graphics;
	var wordText:Text;
	var scoreText:Text;
	var instructText:Text;
	var optionButtons:Array<{g:Graphics, inter:Interactive, colorIdx:Int}>;

	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var roundTimer:Float;
	var timeLimit:Float;
	var correctColorIdx:Int; // the INK color index (correct answer)
	var rng:hxd.Rand;

	// Flash feedback
	var flashTimer:Float;
	var flashColor:Int;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		bg.beginFill(0x1A1A2E);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();

		// Score
		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 30;
		scoreText.scale(2.5);
		scoreText.textColor = 0xFFFFFF;
		scoreText.textAlign = Center;

		// Instruction
		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Tap the INK color, not the word!";
		instructText.x = DESIGN_W / 2;
		instructText.y = 75;
		instructText.scale(1.0);
		instructText.textColor = 0x666688;
		instructText.textAlign = Center;

		// Timer bar
		timerBarG = new Graphics(contentObj);

		// Word display (big centered text)
		wordText = new Text(hxd.res.DefaultFont.get(), contentObj);
		wordText.text = "";
		wordText.x = DESIGN_W / 2;
		wordText.y = 200;
		wordText.scale(4.0);
		wordText.textAlign = Center;

		// Option buttons - 2x2 grid in lower half
		optionButtons = [];
		var btnW = 140;
		var btnH = 90;
		var gapX = 20;
		var gapY = 20;
		var startX = (DESIGN_W - btnW * 2 - gapX) / 2;
		var startY = 360;

		for (i in 0...OPTION_COUNT) {
			var col = i % 2;
			var row = Std.int(i / 2);
			var bx = startX + col * (btnW + gapX);
			var by = startY + row * (btnH + gapY);

			var g = new Graphics(contentObj);
			var inter = new Interactive(btnW, btnH, contentObj);
			inter.x = bx;
			inter.y = by;
			var idx = i;
			inter.onPush = function(_) {
				onOptionTap(idx);
			};

			optionButtons.push({g: g, inter: inter, colorIdx: 0});
		}

		rng = new hxd.Rand(99);
		score = 0;
		gameOver = false;
		started = false;
		roundTimer = 0;
		timeLimit = TIME_LIMIT_START;
		correctColorIdx = 0;
		flashTimer = 0;
		flashColor = 0;
	}

	function onOptionTap(btnIdx:Int) {
		if (gameOver || !started) return;
		if (flashTimer > 0) return; // Still showing feedback

		var btn = optionButtons[btnIdx];
		if (btn.colorIdx == correctColorIdx) {
			// Correct!
			score++;
			scoreText.text = Std.string(score);
			flashTimer = 0.2;
			flashColor = 0x22FF44;
			if (ctx != null) ctx.feedback.flash(0x22FF44, 0.1);
			// Next round after flash
		} else {
			// Wrong - game over
			gameOver = true;
			flashTimer = 0.3;
			flashColor = 0xFF2222;
			if (ctx != null) {
				ctx.feedback.flash(0xFF0000, 0.2);
				ctx.feedback.shake2D(0.3, 6);
				ctx.lose(score, getMinigameId());
			}
		}
	}

	function nextRound() {
		// Pick a word (color name) and an ink color (different from word meaning)
		var wordIdx = rng.random(COLOR_NAMES.length);
		var inkIdx = wordIdx;
		while (inkIdx == wordIdx)
			inkIdx = rng.random(COLOR_NAMES.length);

		correctColorIdx = inkIdx;
		wordText.text = COLOR_NAMES[wordIdx];
		wordText.textColor = COLOR_VALUES[inkIdx];

		// Pick 4 options: must include correctColorIdx, rest are random unique
		var options:Array<Int> = [correctColorIdx];
		while (options.length < OPTION_COUNT) {
			var c = rng.random(COLOR_NAMES.length);
			var dup = false;
			for (o in options)
				if (o == c) {
					dup = true;
					break;
				}
			if (!dup) options.push(c);
		}
		// Shuffle options
		for (i in 0...options.length) {
			var j = rng.random(options.length);
			var tmp = options[i];
			options[i] = options[j];
			options[j] = tmp;
		}

		// Assign to buttons
		var btnW = 140;
		var btnH = 90;
		var gapX = 20;
		var gapY = 20;
		var startX = (DESIGN_W - btnW * 2 - gapX) / 2;
		var startY = 360;

		for (i in 0...OPTION_COUNT) {
			var btn = optionButtons[i];
			btn.colorIdx = options[i];
			var col = i % 2;
			var row = Std.int(i / 2);
			var bx = startX + col * (btnW + gapX);
			var by = startY + row * (btnH + gapY);

			btn.g.clear();
			// Button background
			btn.g.beginFill(COLOR_VALUES[options[i]]);
			drawRoundRect(btn.g, bx, by, btnW, btnH, 12);
			btn.g.endFill();
			// Label
			btn.g.beginFill(darken(COLOR_VALUES[options[i]], 80));
			drawRoundRect(btn.g, bx + 3, by + 3, btnW - 6, btnH - 6, 10);
			btn.g.endFill();
			btn.g.beginFill(COLOR_VALUES[options[i]]);
			drawRoundRect(btn.g, bx + 4, by + 4, btnW - 8, btnH - 8, 9);
			btn.g.endFill();
			// Highlight
			btn.g.beginFill(brighten(COLOR_VALUES[options[i]], 40), 0.4);
			drawRoundRect(btn.g, bx + 6, by + 6, btnW - 12, 20, 6);
			btn.g.endFill();
		}

		roundTimer = 0;
		timeLimit = Math.max(TIME_LIMIT_MIN, TIME_LIMIT_START - score * TIME_SHRINK_PER_ROUND);
	}

	public function getMinigameId():String
		return "tap_the_color";

	public function getTitle():String
		return "Tap the Color";

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start() {
		score = 0;
		gameOver = false;
		started = true;
		roundTimer = 0;
		timeLimit = TIME_LIMIT_START;
		flashTimer = 0;
		scoreText.text = "0";
		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);
		nextRound();
	}

	public function update(dt:Float) {
		if (!started || gameOver) return;

		// Flash feedback
		if (flashTimer > 0) {
			flashTimer -= dt;
			if (flashTimer <= 0) {
				flashTimer = 0;
				if (!gameOver) nextRound();
			}
			return;
		}

		roundTimer += dt;

		// Timer bar
		var pct = 1.0 - roundTimer / timeLimit;
		if (pct < 0) pct = 0;
		timerBarG.clear();
		var barY = 110;
		var barH = 8;
		var barW = 280;
		var barX = (DESIGN_W - barW) / 2;
		// Background
		timerBarG.beginFill(0x333355);
		drawRoundRect(timerBarG, barX, barY, barW, barH, 4);
		timerBarG.endFill();
		// Fill
		var fillColor = pct > 0.3 ? 0x44CC66 : 0xFF4444;
		timerBarG.beginFill(fillColor);
		drawRoundRect(timerBarG, barX, barY, barW * pct, barH, 4);
		timerBarG.endFill();

		// Time's up
		if (roundTimer >= timeLimit) {
			gameOver = true;
			if (ctx != null) {
				ctx.feedback.flash(0xFF0000, 0.2);
				ctx.feedback.shake2D(0.3, 6);
				ctx.lose(score, getMinigameId());
			}
		}
	}

	function drawRoundRect(g:Graphics, x:Float, y:Float, w:Float, h:Float, r:Float) {
		// Approximate rounded rect with a regular rect (heaps Graphics doesn't have roundRect)
		g.drawRect(x, y, w, h);
	}

	function brighten(color:Int, amount:Int):Int {
		var r = Std.int(Math.min(255, ((color >> 16) & 0xFF) + amount));
		var g = Std.int(Math.min(255, ((color >> 8) & 0xFF) + amount));
		var b = Std.int(Math.min(255, (color & 0xFF) + amount));
		return (r << 16) | (g << 8) | b;
	}

	function darken(color:Int, amount:Int):Int {
		var r = Std.int(Math.max(0, ((color >> 16) & 0xFF) - amount));
		var g = Std.int(Math.max(0, ((color >> 8) & 0xFF) - amount));
		var b = Std.int(Math.max(0, (color & 0xFF) - amount));
		return (r << 16) | (g << 8) | b;
	}

	public function dispose() {
		for (btn in optionButtons) {
			btn.g.remove();
			btn.inter.remove();
		}
		optionButtons = [];
		if (timerBarG != null) timerBarG.remove();
		if (wordText != null) wordText.remove();
		if (scoreText != null) scoreText.remove();
		if (instructText != null) instructText.remove();
		if (bg != null) bg.remove();
		contentObj.removeChildren();
	}
}
