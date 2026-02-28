package scenes;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;

/**
	Tela de score após perder num minigame.
	Polish visual com gradiente, partículas, glow, animações e botão Home.
**/
class ScoreScreen extends Object {
	var bg:Graphics;
	var scoreLabel:Text;
	var scoreValue:Text;
	var scoreShadow:Text;
	var gameName:Text;
	var hint:Text;
	var homeBtn:Graphics;
	var homeBtnInteractive:Interactive;
	var interactive:Interactive;
	var designW:Int = 360;
	var designH:Int = 640;

	// Animation
	var time:Float = 0.0;
	var particles:Array<{g:Graphics, x:Float, y:Float, vx:Float, vy:Float, life:Float, maxLife:Float, size:Float}> = [];
	var glowRing:Graphics;
	var chevrons:Array<Graphics> = [];
	var decorLine:Graphics;
	var scoreGlow:Graphics;

	var rankLabel:Text;
	var bestScoreText:Text;
	var encourageText:Text;
	var isFirstPlay:Bool = true;

	// Callback para voltar ao menu
	public var onGoHome:Null<Void->Void> = null;

	// Entrance animation
	var entranceT:Float = 0.0;
	static var ENTRANCE_DURATION = 0.6;

	public function new(parent:Object) {
		super(parent);

		interactive = new Interactive(designW, designH, this);
		interactive.propagateEvents = true;

		bg = new Graphics(this);

		// Glow ring behind score
		glowRing = new Graphics(this);

		// Score glow effect
		scoreGlow = new Graphics(this);

		// "GAME OVER" label
		scoreLabel = new Text(hxd.res.DefaultFont.get(), this);
		scoreLabel.text = "GAME OVER";
		scoreLabel.textAlign = Center;
		scoreLabel.scale(1.4);
		scoreLabel.textColor = 0xE74C6F;

		// Decorative line under label
		decorLine = new Graphics(this);

		// Game name
		gameName = new Text(hxd.res.DefaultFont.get(), this);
		gameName.text = "";
		gameName.textAlign = Center;
		gameName.scale(1.1);
		gameName.textColor = 0x9BA4C4;

		// Score shadow (glow effect)
		scoreShadow = new Text(hxd.res.DefaultFont.get(), this);
		scoreShadow.text = "0";
		scoreShadow.textAlign = Center;
		scoreShadow.scale(4);
		scoreShadow.textColor = 0x6C5CE7;
		scoreShadow.alpha = 0.3;

		// Score number big
		scoreValue = new Text(hxd.res.DefaultFont.get(), this);
		scoreValue.text = "0";
		scoreValue.textAlign = Center;
		scoreValue.scale(4);
		scoreValue.textColor = 0xFFFFFF;

		// Rank label (e.g. "Nice!", "Amazing!")
		rankLabel = new Text(hxd.res.DefaultFont.get(), this);
		rankLabel.text = "";
		rankLabel.textAlign = Center;
		rankLabel.scale(1.6);
		rankLabel.textColor = 0x5DADE2;

		// Best score line
		bestScoreText = new Text(hxd.res.DefaultFont.get(), this);
		bestScoreText.text = "";
		bestScoreText.textAlign = Center;
		bestScoreText.scale(1.0);
		bestScoreText.textColor = 0x9BA4C4;

		// Encouragement message
		encourageText = new Text(hxd.res.DefaultFont.get(), this);
		encourageText.text = "";
		encourageText.textAlign = Center;
		encourageText.scale(0.9);
		encourageText.textColor = 0x9BA4C4;

		// Hint text
		hint = new Text(hxd.res.DefaultFont.get(), this);
		hint.text = "Swipe up for next game";
		hint.textAlign = Center;
		hint.scale(1.0);
		hint.textColor = 0x9BA4C4;

		// Animated chevrons
		for (i in 0...3) {
			var c = new Graphics(this);
			chevrons.push(c);
		}

		// Home icon button (top-left corner, small house icon)
		homeBtn = new Graphics(this);
		homeBtnInteractive = new Interactive(48, 48, this);
		homeBtnInteractive.onClick = function(_) {
			if (onGoHome != null)
				onGoHome();
		};

		// Floating particles
		for (i in 0...10) {
			var g = new Graphics(this);
			var px = Math.random() * designW;
			var py = Math.random() * designH;
			var s = 1.0 + Math.random() * 2.0;
			particles.push({
				g: g,
				x: px,
				y: py,
				vx: (Math.random() - 0.5) * 6,
				vy: -8 - Math.random() * 12,
				life: Math.random() * 4.0,
				maxLife: 3.0 + Math.random() * 3.0,
				size: s
			});
		}

		layoutElements();
		drawBg();
	}

	function layoutElements():Void {
		var cx = designW / 2;

		scoreLabel.x = cx;
		scoreLabel.y = Std.int(designH * 0.18);

		gameName.x = cx;
		gameName.y = Std.int(designH * 0.26);

		scoreShadow.x = cx + 2;
		scoreShadow.y = Std.int(designH * 0.36) + 2;

		scoreValue.x = cx;
		scoreValue.y = Std.int(designH * 0.36);

		rankLabel.x = cx;
		rankLabel.y = Std.int(designH * 0.48);

		bestScoreText.x = cx;
		bestScoreText.y = Std.int(designH * 0.55);

		encourageText.x = cx;
		encourageText.y = Std.int(designH * 0.72);

		hint.x = cx;
		hint.y = Std.int(designH * 0.78);

		// Home icon — top-left corner
		homeBtnInteractive.x = 8;
		homeBtnInteractive.y = 8;
		homeBtnInteractive.width = 48;
		homeBtnInteractive.height = 48;
	}

	function drawBg():Void {
		bg.clear();

		// Dark gradient background (deep blue-purple)
		var steps = 20;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(10 + t * 12);
			var g = Std.int(8 + t * 14);
			var b = Std.int(24 + t * 30);
			var color = (r << 16) | (g << 8) | b;
			var yStart = Std.int(designH * t);
			var yEnd = Std.int(designH * (t + 1.0 / steps)) + 1;
			bg.beginFill(color);
			bg.drawRect(0, yStart, designW, yEnd - yStart);
			bg.endFill();
		}

		// Ambient circles
		bg.beginFill(0x3D1F6E, 0.08);
		bg.drawCircle(designW * 0.15, designH * 0.25, 100);
		bg.endFill();
		bg.beginFill(0x1A3A5C, 0.06);
		bg.drawCircle(designW * 0.85, designH * 0.7, 90);
		bg.endFill();
		bg.beginFill(0xE74C6F, 0.03);
		bg.drawCircle(designW * 0.5, designH * 0.45, 120);
		bg.endFill();

		// Subtle grid
		bg.lineStyle(1, 0xFFFFFF, 0.015);
		var gridSize = 40;
		var gx = 0;
		while (gx <= designW) {
			bg.moveTo(gx, 0);
			bg.lineTo(gx, designH);
			gx += gridSize;
		}
		var gy = 0;
		while (gy <= designH) {
			bg.moveTo(0, gy);
			bg.lineTo(designW, gy);
			gy += gridSize;
		}
		bg.lineStyle();

		// Top & bottom fades
		for (i in 0...30) {
			var a = 0.35 * (1.0 - i / 30.0);
			bg.beginFill(0x000000, a);
			bg.drawRect(0, i * 2, designW, 2);
			bg.endFill();
		}
		for (i in 0...50) {
			var a = 0.5 * (1.0 - i / 50.0);
			bg.beginFill(0x000000, a);
			bg.drawRect(0, designH - i * 2, designW, 2);
			bg.endFill();
		}
	}

	function drawChevron(g:Graphics, cx:Float, cy:Float, width:Float, alpha:Float):Void {
		g.clear();
		g.lineStyle(2.5, 0xFFFFFF, alpha);
		g.moveTo(cx - width, cy + width * 0.5);
		g.lineTo(cx, cy - width * 0.5);
		g.lineTo(cx + width, cy + width * 0.5);
		g.lineStyle();
	}

	public function setScore(score:Int, minigameId:String, bestScore:Int, isNewBest:Bool, isFirstPlay:Bool) {
		scoreValue.text = Std.string(score);
		scoreShadow.text = Std.string(score);
		gameName.text = minigameId != null && minigameId != "" ? minigameId : "Minigame";
		entranceT = 0.0;

		this.isFirstPlay = isFirstPlay;

		// Rank label based on ratio to best
		if (isFirstPlay) {
			rankLabel.text = "Good Start!";
			rankLabel.textColor = 0x5DADE2;
			encourageText.text = "Keep playing to set records!";
			encourageText.textColor = 0x5DADE2;
		} else if (isNewBest) {
			rankLabel.text = "NEW RECORD!";
			rankLabel.textColor = 0xFFD700;
			encourageText.text = "You beat your record!";
			encourageText.textColor = 0xFFD700;
		} else if (bestScore > 0) {
			var ratio = score / bestScore;
			if (ratio >= 1.0) {
				rankLabel.text = "Amazing!";
				rankLabel.textColor = 0xE74C6F;
				encourageText.text = "Matched your best!";
				encourageText.textColor = 0xE74C6F;
			} else if (ratio >= 0.8) {
				rankLabel.text = "Great!";
				rankLabel.textColor = 0xF4D03F;
				encourageText.text = "Almost there — try again!";
				encourageText.textColor = 0xF4D03F;
			} else if (ratio >= 0.5) {
				rankLabel.text = "Nice!";
				rankLabel.textColor = 0x58D68D;
				encourageText.text = "Getting closer!";
				encourageText.textColor = 0x58D68D;
			} else {
				rankLabel.text = "Keep Going!";
				rankLabel.textColor = 0x9BA4C4;
				encourageText.text = "Practice makes perfect!";
				encourageText.textColor = 0x9BA4C4;
			}
		} else {
			rankLabel.text = "Keep Going!";
			rankLabel.textColor = 0x9BA4C4;
			encourageText.text = "You can do it!";
			encourageText.textColor = 0x9BA4C4;
		}

		// Best score line
		if (isNewBest && !isFirstPlay) {
			bestScoreText.text = "NEW BEST!";
			bestScoreText.textColor = 0xFFD700;
		} else {
			bestScoreText.text = "BEST: " + Std.string(bestScore);
			bestScoreText.textColor = 0x9BA4C4;
		}
	}

	public function update(dt:Float):Void {
		time += dt;
		entranceT += dt;

		var cx = designW / 2;

		// Entrance animation factor (0..1)
		var enterFactor = Math.min(entranceT / ENTRANCE_DURATION, 1.0);
		// Ease out cubic
		var ef = 1.0 - (1.0 - enterFactor) * (1.0 - enterFactor) * (1.0 - enterFactor);

		// Score label slide in from top
		scoreLabel.y = Std.int(designH * 0.18 - 30 * (1.0 - ef));
		scoreLabel.alpha = ef;

		// Game name fade in
		gameName.alpha = Math.max(0, (ef - 0.3) / 0.7) * 0.8;

		// Score number scale-in (pop effect)
		var scoreEf = Math.max(0, (ef - 0.2) / 0.8);
		var pop = scoreEf < 1.0 ? 0.5 + scoreEf * 0.6 : 1.0 + Math.sin(time * 1.5) * 0.02;
		scoreValue.scaleX = 4.0 * pop;
		scoreValue.scaleY = 4.0 * pop;
		scoreShadow.scaleX = 4.0 * pop;
		scoreShadow.scaleY = 4.0 * pop;

		// Score glow pulse
		scoreGlow.clear();
		var glowAlpha = 0.08 + 0.04 * Math.sin(time * 2.0);
		var scoreY = Std.int(designH * 0.40);
		scoreGlow.beginFill(0x6C5CE7, glowAlpha * ef);
		scoreGlow.drawCircle(cx, scoreY, 70 + 10 * Math.sin(time * 1.2));
		scoreGlow.endFill();
		scoreGlow.beginFill(0xE74C6F, glowAlpha * 0.5 * ef);
		scoreGlow.drawCircle(cx, scoreY, 50 + 8 * Math.sin(time * 1.5));
		scoreGlow.endFill();

		// Glow ring
		glowRing.clear();
		var ringAlpha = 0.12 + 0.06 * Math.sin(time * 1.8);
		var ringR = 85 + 8 * Math.sin(time * 1.0);
		glowRing.beginFill(0xE74C6F, ringAlpha * 0.4 * ef);
		glowRing.drawCircle(cx, scoreY, ringR + 20);
		glowRing.endFill();
		glowRing.beginFill(0x6C5CE7, ringAlpha * 0.6 * ef);
		glowRing.drawCircle(cx, scoreY, ringR);
		glowRing.endFill();

		// Decorative line
		decorLine.clear();
		var lineW = (40 + 15 * Math.sin(time * 2.0)) * ef;
		var lineY = scoreLabel.y + 20;
		decorLine.beginFill(0xE74C6F, 0.6 * ef);
		decorLine.drawRect(cx - lineW, lineY, lineW * 2, 2);
		decorLine.endFill();
		decorLine.beginFill(0xFFFFFF, 0.8 * ef);
		decorLine.drawRect(cx - lineW * 0.4, lineY, lineW * 0.8, 2);
		decorLine.endFill();

		// Score shadow float
		scoreShadow.x = cx + 2;
		scoreShadow.y = Std.int(designH * 0.36) + 2;
		scoreShadow.alpha = 0.2 + 0.1 * Math.sin(time * 1.2);

		// Rank label fade in (slightly delayed)
		var rankEf = Math.max(0, (ef - 0.3) / 0.7);
		rankLabel.alpha = rankEf;
		rankLabel.y = Std.int(designH * 0.48 + 15 * (1.0 - rankEf));

		// Best score text fade in (more delayed)
		var bestEf = Math.max(0, (ef - 0.45) / 0.55);
		bestScoreText.alpha = bestEf * 0.8;
		bestScoreText.y = Std.int(designH * 0.55 + 10 * (1.0 - bestEf));

		// Encouragement text fade in (most delayed)
		var encEf = Math.max(0, (ef - 0.5) / 0.5);
		encourageText.alpha = encEf * 0.7;

		// Hint text pulse
		var hintAlpha = 0.4 + 0.3 * Math.sin(time * 2.0);
		hint.alpha = hintAlpha * ef;

		// Animated chevrons (lower, near hint)
		var chevronBaseY = designH * 0.70;
		for (i in 0...3) {
			var phase = time * 2.5 - i * 0.4;
			var bounce = Math.sin(phase);
			var fadePhase = (Math.sin(phase) + 1.0) * 0.5;
			var alpha = 0.2 + fadePhase * 0.6;
			if (i == 1)
				alpha *= 0.7;
			if (i == 2)
				alpha *= 0.4;
			var yOff = i * 14.0 + bounce * 4;
			drawChevron(chevrons[i], cx, chevronBaseY + yOff, 12.0, alpha * ef);
		}

		// Home icon (small house) — top-left corner, subtle
		homeBtn.clear();
		var homeAlpha = Math.max(0, (ef - 0.5) / 0.5) * 0.5;
		var hx = 32.0;
		var hy = 32.0;
		var hs = 11.0; // house half-size
		// Roof (triangle)
		homeBtn.lineStyle(1.5, 0xFFFFFF, homeAlpha);
		homeBtn.moveTo(hx - hs, hy - 1);
		homeBtn.lineTo(hx, hy - hs - 2);
		homeBtn.lineTo(hx + hs, hy - 1);
		// Walls (square)
		homeBtn.moveTo(hx - hs * 0.7, hy - 1);
		homeBtn.lineTo(hx - hs * 0.7, hy + hs - 1);
		homeBtn.lineTo(hx + hs * 0.7, hy + hs - 1);
		homeBtn.lineTo(hx + hs * 0.7, hy - 1);
		// Door
		homeBtn.moveTo(hx - 2, hy + hs - 1);
		homeBtn.lineTo(hx - 2, hy + 2);
		homeBtn.lineTo(hx + 2, hy + 2);
		homeBtn.lineTo(hx + 2, hy + hs - 1);
		homeBtn.lineStyle();

		// Floating particles
		for (p in particles) {
			p.life += dt;
			if (p.life >= p.maxLife) {
				p.x = Math.random() * designW;
				p.y = designH + 10;
				p.vx = (Math.random() - 0.5) * 6;
				p.vy = -8 - Math.random() * 12;
				p.life = 0;
				p.maxLife = 3.0 + Math.random() * 3.0;
				p.size = 1.0 + Math.random() * 2.0;
			}
			p.x += p.vx * dt;
			p.y += p.vy * dt;

			if (p.x < 0)
				p.x += designW;
			if (p.x > designW)
				p.x -= designW;

			var lifeRatio = p.life / p.maxLife;
			var fadeIn = Math.min(lifeRatio * 5, 1.0);
			var fadeOut = Math.max(1.0 - (lifeRatio - 0.6) * 2.5, 0.0);
			var pAlpha = fadeIn * fadeOut * 0.35;

			p.g.clear();
			p.g.beginFill(0xE74C6F, pAlpha * 0.25);
			p.g.drawCircle(p.x, p.y, p.size + 2);
			p.g.endFill();
			p.g.beginFill(0xFFFFFF, pAlpha);
			p.g.drawCircle(p.x, p.y, p.size);
			p.g.endFill();
		}
	}

	public function setSize(w:Int, h:Int) {
		designW = w;
		designH = h;
		interactive.width = w;
		interactive.height = h;
		layoutElements();
		drawBg();
	}
}
