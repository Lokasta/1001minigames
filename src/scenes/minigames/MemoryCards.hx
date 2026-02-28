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
	Memory Cards — vire pares de cartas antes do tempo acabar.
	Grid 4x4 (8 pares). Achou todos = score baseado no tempo restante.
	Tempo esgotou = lose com score dos pares já encontrados.
**/
class MemoryCards implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var COLS = 4;
	static var ROWS = 4;
	static var TOTAL_CARDS = 16;
	static var TOTAL_PAIRS = 8;
	static var TIME_LIMIT = 45.0;
	static var PREVIEW_TIME = 1.5; // show all cards briefly at start
	static var CARD_W = 62;
	static var CARD_H = 78;
	static var CARD_GAP = 10;
	static var GRID_TOP = 140;

	// Card symbols (emoji-style icons drawn with Graphics)
	static var SYMBOLS:Array<Int> = [
		0xFF4444, // red circle
		0x44AAFF, // blue diamond
		0x44DD66, // green star
		0xFFCC00, // yellow triangle
		0xBB55FF, // purple cross
		0xFF8844, // orange heart
		0x44DDDD, // cyan moon
		0xFF66AA, // pink square
	];

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var timerBarG:Graphics;
	var scoreText:Text;
	var titleText:Text;
	var pairsText:Text;

	// Card data
	var cards:Array<CardData>;
	var cardGraphics:Array<Graphics>;
	var cardInteractives:Array<Interactive>;

	// Game state
	var gameOver:Bool;
	var timeLeft:Float;
	var pairsFound:Int;
	var score:Int;
	var flipped1:Int; // index of first flipped card (-1 = none)
	var flipped2:Int; // index of second flipped card (-1 = none)
	var mismatchTimer:Float; // timer to show mismatched pair before flipping back
	var previewing:Bool;
	var previewTimer:Float;
	var rng:hxd.Rand;

	// Flip animation
	var flipAnims:Array<{idx:Int, progress:Float, flipping:Bool, toFaceUp:Bool}>;

	// Match flash
	var matchFlashTimer:Float;
	var matchFlashCards:Array<Int>;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		drawBackground();

		// Title
		titleText = new Text(hxd.res.DefaultFont.get(), contentObj);
		titleText.text = "MEMORY CARDS";
		titleText.textAlign = Center;
		titleText.x = DESIGN_W / 2;
		titleText.y = 20;
		titleText.scale(1.8);
		titleText.textColor = 0xFFFFFF;

		// Score
		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 55;
		scoreText.scale(2.0);
		scoreText.textColor = 0xFFCC00;

		// Pairs counter
		pairsText = new Text(hxd.res.DefaultFont.get(), contentObj);
		pairsText.text = "0 / 8 pairs";
		pairsText.textAlign = Center;
		pairsText.x = DESIGN_W / 2;
		pairsText.y = 85;
		pairsText.textColor = 0x9BA4C4;

		// Timer bar
		timerBarG = new Graphics(contentObj);

		// Init card data
		cards = [];
		cardGraphics = [];
		cardInteractives = [];
		flipAnims = [];
		matchFlashCards = [];

		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		// Create pairs
		var symbolPairs:Array<Int> = [];
		for (i in 0...TOTAL_PAIRS) {
			symbolPairs.push(i);
			symbolPairs.push(i);
		}
		// Shuffle
		for (i in 0...symbolPairs.length) {
			var j = rng.random(symbolPairs.length);
			var tmp = symbolPairs[i];
			symbolPairs[i] = symbolPairs[j];
			symbolPairs[j] = tmp;
		}

		// Grid offset to center
		var gridW = COLS * CARD_W + (COLS - 1) * CARD_GAP;
		var gridH = ROWS * CARD_H + (ROWS - 1) * CARD_GAP;
		var offsetX = (DESIGN_W - gridW) / 2;
		var offsetY = GRID_TOP;

		for (i in 0...TOTAL_CARDS) {
			var col = i % COLS;
			var row = Std.int(i / COLS);
			var cx = offsetX + col * (CARD_W + CARD_GAP);
			var cy = offsetY + row * (CARD_H + CARD_GAP);

			var card:CardData = {
				symbolIdx: symbolPairs[i],
				faceUp: false,
				matched: false,
				x: cx,
				y: cy,
			};
			cards.push(card);

			var g = new Graphics(contentObj);
			cardGraphics.push(g);

			var inter = new Interactive(CARD_W, CARD_H, contentObj);
			inter.x = cx;
			inter.y = cy;
			final idx = i;
			inter.onClick = function(_) onCardTap(idx);
			cardInteractives.push(inter);
		}

		gameOver = false;
		timeLeft = TIME_LIMIT;
		pairsFound = 0;
		score = 0;
		flipped1 = -1;
		flipped2 = -1;
		mismatchTimer = 0;
		previewing = true;
		previewTimer = PREVIEW_TIME;
		matchFlashTimer = 0;
	}

	function drawBackground():Void {
		bg.clear();
		// Dark gradient
		var steps = 16;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(12 + t * 8);
			var g = Std.int(10 + t * 16);
			var b = Std.int(30 + t * 20);
			var color = (r << 16) | (g << 8) | b;
			var yStart = Std.int(DESIGN_H * t);
			var yEnd = Std.int(DESIGN_H * (t + 1.0 / steps)) + 1;
			bg.beginFill(color);
			bg.drawRect(0, yStart, DESIGN_W, yEnd - yStart);
			bg.endFill();
		}
	}

	function onCardTap(idx:Int):Void {
		if (gameOver || previewing) return;
		if (mismatchTimer > 0) return; // wait for mismatch to resolve
		if (cards[idx].matched || cards[idx].faceUp) return;
		if (flipped1 == idx) return;

		// Flip card up
		cards[idx].faceUp = true;
		addFlipAnim(idx, true);

		if (flipped1 == -1) {
			flipped1 = idx;
		} else {
			flipped2 = idx;
			// Check match
			if (cards[flipped1].symbolIdx == cards[flipped2].symbolIdx) {
				// Match!
				cards[flipped1].matched = true;
				cards[flipped2].matched = true;
				pairsFound++;
				score += 10 + Std.int(timeLeft * 0.5);
				matchFlashCards = [flipped1, flipped2];
				matchFlashTimer = 0.4;

				if (ctx != null && ctx.feedback != null)
					ctx.feedback.flash(0xFFFFFF, 0.15);

				flipped1 = -1;
				flipped2 = -1;

				// Win condition
				if (pairsFound >= TOTAL_PAIRS) {
					score += Std.int(timeLeft * 5);
					gameOver = true;
					endGame();
				}
			} else {
				// Mismatch — show for a moment then flip back
				mismatchTimer = 0.7;
			}
		}
	}

	function addFlipAnim(idx:Int, toFaceUp:Bool):Void {
		// Remove existing anim for this card
		flipAnims = flipAnims.filter(function(a) return a.idx != idx);
		flipAnims.push({idx: idx, progress: 0, flipping: true, toFaceUp: toFaceUp});
	}

	function drawCard(g:Graphics, card:CardData, faceUp:Bool, flipScale:Float, flashAlpha:Float):Void {
		g.clear();
		var cx = card.x;
		var cy = card.y;
		var w = CARD_W * Math.abs(flipScale);
		var xOff = (CARD_W - w) / 2;

		if (w < 2) return;

		if (faceUp) {
			// Face-up: white card with symbol
			// Card shadow
			g.beginFill(0x000000, 0.2);
			g.drawRect(cx + xOff + 2, cy + 2, w, CARD_H);
			g.endFill();

			// Card body
			if (card.matched) {
				g.beginFill(0x1A3320, 0.9);
			} else {
				g.beginFill(0x1A1A2E, 0.95);
			}
			g.drawRect(cx + xOff, cy, w, CARD_H);
			g.endFill();

			// Border
			var borderColor = card.matched ? 0x44DD66 : 0x445588;
			g.lineStyle(1.5, borderColor, 0.8);
			g.drawRect(cx + xOff, cy, w, CARD_H);
			g.lineStyle();

			// Draw symbol in center
			if (Math.abs(flipScale) > 0.5) {
				drawSymbol(g, card.symbolIdx, cx + CARD_W / 2, cy + CARD_H / 2, card.matched);
			}
		} else {
			// Face-down: decorative back
			// Card shadow
			g.beginFill(0x000000, 0.2);
			g.drawRect(cx + xOff + 2, cy + 2, w, CARD_H);
			g.endFill();

			// Card back (gradient-ish)
			g.beginFill(0x2A2A5E);
			g.drawRect(cx + xOff, cy, w, CARD_H);
			g.endFill();

			// Inner pattern
			if (w > 20) {
				g.beginFill(0x3A3A7E, 0.6);
				g.drawRect(cx + xOff + 4, cy + 4, w - 8, CARD_H - 8);
				g.endFill();

				// Diamond pattern on back
				g.lineStyle(1, 0x5555AA, 0.3);
				var midX = cx + CARD_W / 2;
				var midY = cy + CARD_H / 2;
				g.moveTo(midX, midY - 15);
				g.lineTo(midX + 10, midY);
				g.lineTo(midX, midY + 15);
				g.lineTo(midX - 10, midY);
				g.lineTo(midX, midY - 15);
				g.lineStyle();
			}

			// Border
			g.lineStyle(1, 0x5555AA, 0.5);
			g.drawRect(cx + xOff, cy, w, CARD_H);
			g.lineStyle();
		}

		// Match flash overlay
		if (flashAlpha > 0) {
			g.beginFill(0xFFFFFF, flashAlpha * 0.4);
			g.drawRect(cx + xOff, cy, w, CARD_H);
			g.endFill();
		}
	}

	function drawSymbol(g:Graphics, symbolIdx:Int, cx:Float, cy:Float, matched:Bool):Void {
		var color = SYMBOLS[symbolIdx];
		var alpha = matched ? 0.6 : 1.0;
		var s = 14.0;

		switch (symbolIdx) {
			case 0: // Circle
				g.beginFill(color, alpha);
				g.drawCircle(cx, cy, s);
				g.endFill();

			case 1: // Diamond
				g.beginFill(color, alpha);
				g.moveTo(cx, cy - s);
				g.lineTo(cx + s * 0.7, cy);
				g.lineTo(cx, cy + s);
				g.lineTo(cx - s * 0.7, cy);
				g.lineTo(cx, cy - s);
				g.endFill();

			case 2: // Star (5-point)
				g.beginFill(color, alpha);
				for (i in 0...5) {
					var outerAngle = -Math.PI / 2 + i * Math.PI * 2 / 5;
					var innerAngle = outerAngle + Math.PI / 5;
					var ox = cx + Math.cos(outerAngle) * s;
					var oy = cy + Math.sin(outerAngle) * s;
					var ix = cx + Math.cos(innerAngle) * s * 0.4;
					var iy = cy + Math.sin(innerAngle) * s * 0.4;
					if (i == 0)
						g.moveTo(ox, oy);
					else
						g.lineTo(ox, oy);
					g.lineTo(ix, iy);
				}
				g.endFill();

			case 3: // Triangle
				g.beginFill(color, alpha);
				g.moveTo(cx, cy - s);
				g.lineTo(cx + s, cy + s * 0.7);
				g.lineTo(cx - s, cy + s * 0.7);
				g.lineTo(cx, cy - s);
				g.endFill();

			case 4: // Cross/Plus
				var t = 5.0;
				g.beginFill(color, alpha);
				g.drawRect(cx - t, cy - s, t * 2, s * 2);
				g.drawRect(cx - s, cy - t, s * 2, t * 2);
				g.endFill();

			case 5: // Heart
				g.beginFill(color, alpha);
				g.drawCircle(cx - 6, cy - 4, 8);
				g.drawCircle(cx + 6, cy - 4, 8);
				g.endFill();
				g.beginFill(color, alpha);
				g.moveTo(cx - 13, cy - 1);
				g.lineTo(cx, cy + 14);
				g.lineTo(cx + 13, cy - 1);
				g.lineTo(cx - 13, cy - 1);
				g.endFill();

			case 6: // Moon (crescent)
				g.beginFill(color, alpha);
				g.drawCircle(cx, cy, s);
				g.endFill();
				// Cut out part to make crescent
				g.beginFill(0x1A1A2E);
				g.drawCircle(cx + 7, cy - 3, s - 2);
				g.endFill();

			case 7: // Square (rotated)
				g.beginFill(color, alpha);
				var sq = s * 0.75;
				g.moveTo(cx, cy - sq);
				g.lineTo(cx + sq, cy);
				g.lineTo(cx, cy + sq);
				g.lineTo(cx - sq, cy);
				g.lineTo(cx, cy - sq);
				g.endFill();
		}
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		gameOver = false;
		timeLeft = TIME_LIMIT;
		pairsFound = 0;
		score = 0;
		flipped1 = -1;
		flipped2 = -1;
		mismatchTimer = 0;
		previewing = true;
		previewTimer = PREVIEW_TIME;
		matchFlashTimer = 0;
		flipAnims = [];
		matchFlashCards = [];

		// Show all cards face-up during preview
		for (c in cards) {
			c.faceUp = true;
			c.matched = false;
		}

		updateScoreDisplay();
	}

	function updateScoreDisplay():Void {
		scoreText.text = Std.string(score);
		pairsText.text = pairsFound + " / " + TOTAL_PAIRS + " pairs";
	}

	function endGame():Void {
		if (ctx != null) {
			ctx.lose(score, getMinigameId());
			ctx = null;
		}
	}

	public function update(dt:Float):Void {
		if (ctx == null) return;

		// Preview phase: show all cards face-up then flip them down
		if (previewing) {
			previewTimer -= dt;
			if (previewTimer <= 0) {
				previewing = false;
				for (i in 0...cards.length) {
					cards[i].faceUp = false;
					addFlipAnim(i, false);
				}
			}
		}

		if (!previewing && !gameOver) {
			timeLeft -= dt;
			if (timeLeft <= 0) {
				timeLeft = 0;
				gameOver = true;
				endGame();
				return;
			}
		}

		// Mismatch timer
		if (mismatchTimer > 0) {
			mismatchTimer -= dt;
			if (mismatchTimer <= 0) {
				// Flip mismatched cards back
				if (flipped1 >= 0) {
					cards[flipped1].faceUp = false;
					addFlipAnim(flipped1, false);
				}
				if (flipped2 >= 0) {
					cards[flipped2].faceUp = false;
					addFlipAnim(flipped2, false);
				}
				flipped1 = -1;
				flipped2 = -1;
			}
		}

		// Match flash timer
		if (matchFlashTimer > 0) {
			matchFlashTimer -= dt;
			if (matchFlashTimer <= 0) {
				matchFlashCards = [];
			}
		}

		// Update flip animations
		for (a in flipAnims) {
			if (a.flipping) {
				a.progress += dt * 4.0; // speed of flip
				if (a.progress >= 1.0) {
					a.progress = 1.0;
					a.flipping = false;
				}
			}
		}
		// Remove completed anims
		flipAnims = flipAnims.filter(function(a) return a.flipping);

		// Timer bar
		timerBarG.clear();
		var barY = 115;
		var barH = 6;
		var barMaxW = DESIGN_W - 40;
		// Background
		timerBarG.beginFill(0x222244, 0.6);
		timerBarG.drawRect(20, barY, barMaxW, barH);
		timerBarG.endFill();
		// Fill
		var ratio = timeLeft / TIME_LIMIT;
		var barColor = ratio > 0.3 ? 0x44AAFF : (ratio > 0.15 ? 0xFFAA00 : 0xFF3333);
		timerBarG.beginFill(barColor, 0.9);
		timerBarG.drawRect(20, barY, barMaxW * ratio, barH);
		timerBarG.endFill();

		// Draw all cards
		for (i in 0...cards.length) {
			var card = cards[i];
			var flipScale = 1.0;

			// Check if there's an active animation for this card
			for (a in flipAnims) {
				if (a.idx == i) {
					// Flip: scale goes 1 -> 0 -> 1, switching face at midpoint
					var p = a.progress;
					if (p < 0.5) {
						flipScale = 1.0 - p * 2.0;
					} else {
						flipScale = (p - 0.5) * 2.0;
					}
					break;
				}
			}

			var flashAlpha = 0.0;
			for (mc in matchFlashCards) {
				if (mc == i) {
					flashAlpha = matchFlashTimer / 0.4;
					break;
				}
			}

			drawCard(cardGraphics[i], card, card.faceUp, flipScale, flashAlpha);
		}

		updateScoreDisplay();

		// Pulse title color when low time
		if (timeLeft < 10 && !gameOver) {
			var pulse = Math.sin(timeLeft * 8) * 0.5 + 0.5;
			titleText.textColor = pulse > 0.5 ? 0xFF4444 : 0xFFFFFF;
		} else {
			titleText.textColor = 0xFFFFFF;
		}
	}

	public function dispose() {
		for (inter in cardInteractives)
			inter.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "memory-cards";

	public function getTitle():String
		return "Memory Cards";
}

private typedef CardData = {
	symbolIdx:Int,
	faceUp:Bool,
	matched:Bool,
	x:Float,
	y:Float,
};
