package scenes;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;

/**
	Tela inicial do feed: "Swipe up to play".
	Interactive full-screen com propagateEvents = true para o swipe chegar ao feed.
**/
class StartScreen extends Object {
	var bg:Graphics;
	var label:Text;
	var hint:Text;
	var interactive:Interactive;
	var designW:Int = 360;
	var designH:Int = 640;

	// Animation state
	var time:Float = 0.0;
	var chevrons:Array<Graphics> = [];
	var particles:Array<{g:Graphics, x:Float, y:Float, vx:Float, vy:Float, life:Float, maxLife:Float, size:Float}> = [];
	var glowRing:Graphics;
	var titleShadow:Text;
	var subtitleLine:Graphics;

	public function new(parent:Object) {
		super(parent);

		interactive = new Interactive(designW, designH, this);
		interactive.propagateEvents = true;

		bg = new Graphics(this);

		// Glow ring behind title
		glowRing = new Graphics(this);

		// Title shadow
		titleShadow = new Text(hxd.res.DefaultFont.get(), this);
		titleShadow.text = "TokTok Games";
		titleShadow.textAlign = Center;
		titleShadow.scale(2.8);
		titleShadow.textColor = 0x6C5CE7;
		titleShadow.alpha = 0.3;

		// Main title
		label = new Text(hxd.res.DefaultFont.get(), this);
		label.text = "TokTok Games";
		label.textAlign = Center;
		label.scale(2.8);
		label.textColor = 0xFFFFFF;

		// Subtitle line decoration
		subtitleLine = new Graphics(this);

		// Hint text
		hint = new Text(hxd.res.DefaultFont.get(), this);
		hint.text = "Swipe up to play";
		hint.textAlign = Center;
		hint.scale(1.1);
		hint.textColor = 0x9BA4C4;

		// Animated chevrons (3 stacked)
		for (i in 0...3) {
			var c = new Graphics(this);
			chevrons.push(c);
		}

		// Initialize floating particles
		for (i in 0...12) {
			var g = new Graphics(this);
			var px = Math.random() * designW;
			var py = Math.random() * designH;
			var s = 1.5 + Math.random() * 2.5;
			particles.push({
				g: g,
				x: px,
				y: py,
				vx: (Math.random() - 0.5) * 8,
				vy: -10 - Math.random() * 15,
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
		var titleY = Std.int(designH * 0.30);

		titleShadow.x = cx + 2;
		titleShadow.y = titleY + 2;
		label.x = cx;
		label.y = titleY;
		hint.x = cx;
		hint.y = Std.int(designH * 0.68);
	}

	function drawBg():Void {
		bg.clear();

		// Deep dark gradient background
		var steps = 20;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(8 + t * 8);
			var g = Std.int(6 + t * 12);
			var b = Std.int(18 + t * 20);
			var color = (r << 16) | (g << 8) | b;
			var yStart = Std.int(designH * t);
			var yEnd = Std.int(designH * (t + 1.0 / steps)) + 1;
			bg.beginFill(color);
			bg.drawRect(0, yStart, designW, yEnd - yStart);
			bg.endFill();
		}

		// Large soft ambient circles
		bg.beginFill(0x2D1F5E, 0.08);
		bg.drawCircle(designW * 0.2, designH * 0.15, 120);
		bg.endFill();
		bg.beginFill(0x1A3A5C, 0.06);
		bg.drawCircle(designW * 0.85, designH * 0.75, 100);
		bg.endFill();
		bg.beginFill(0x4A2080, 0.05);
		bg.drawCircle(designW * 0.5, designH * 0.9, 80);
		bg.endFill();

		// Grid pattern (subtle)
		bg.lineStyle(1, 0xFFFFFF, 0.02);
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

		// Top fade
		for (i in 0...30) {
			var a = 0.35 * (1.0 - i / 30.0);
			bg.beginFill(0x000000, a);
			bg.drawRect(0, i * 2, designW, 2);
			bg.endFill();
		}
		// Bottom fade
		for (i in 0...50) {
			var a = 0.5 * (1.0 - i / 50.0);
			bg.beginFill(0x000000, a);
			bg.drawRect(0, designH - i * 2, designW, 2);
			bg.endFill();
		}
	}

	function drawChevron(g:Graphics, cx:Float, cy:Float, width:Float, alpha:Float):Void {
		g.clear();
		// Chevron pointing up (^)
		g.lineStyle(2.5, 0xFFFFFF, alpha);
		g.moveTo(cx - width, cy + width * 0.5);
		g.lineTo(cx, cy - width * 0.5);
		g.lineTo(cx + width, cy + width * 0.5);
		g.lineStyle();
	}

	public function update(dt:Float):Void {
		time += dt;

		var cx = designW / 2;

		// Animate glow ring (pulsing behind title)
		glowRing.clear();
		var glowPulse = 0.4 + 0.15 * Math.sin(time * 1.5);
		var glowRadius = 90 + 10 * Math.sin(time * 0.8);
		// Outer ring
		glowRing.beginFill(0x6C5CE7, glowPulse * 0.15);
		glowRing.drawCircle(cx, designH * 0.33, glowRadius + 30);
		glowRing.endFill();
		// Inner ring
		glowRing.beginFill(0x8B7CF7, glowPulse * 0.2);
		glowRing.drawCircle(cx, designH * 0.33, glowRadius);
		glowRing.endFill();
		// Core glow
		glowRing.beginFill(0xA78BFA, glowPulse * 0.15);
		glowRing.drawCircle(cx, designH * 0.33, glowRadius - 30);
		glowRing.endFill();

		// Title float animation
		label.y = Std.int(designH * 0.30) + Math.sin(time * 1.2) * 3;
		titleShadow.y = label.y + 2;
		titleShadow.alpha = 0.2 + 0.1 * Math.sin(time * 1.2);

		// Subtitle line (decorative bar under title)
		subtitleLine.clear();
		var lineW = 60 + 20 * Math.sin(time * 2.0);
		var lineY = label.y + 28;
		// Gradient line
		subtitleLine.beginFill(0x6C5CE7, 0.6);
		subtitleLine.drawRect(cx - lineW, lineY, lineW * 2, 2);
		subtitleLine.endFill();
		subtitleLine.beginFill(0xA78BFA, 0.8);
		subtitleLine.drawRect(cx - lineW * 0.5, lineY, lineW, 2);
		subtitleLine.endFill();
		// Small diamond at center
		var dSize = 4.0;
		subtitleLine.beginFill(0xFFFFFF, 0.9);
		subtitleLine.moveTo(cx, lineY - dSize);
		subtitleLine.lineTo(cx + dSize, lineY + 1);
		subtitleLine.lineTo(cx, lineY + dSize + 2);
		subtitleLine.lineTo(cx - dSize, lineY + 1);
		subtitleLine.lineTo(cx, lineY - dSize);
		subtitleLine.endFill();

		// Animated chevrons (bouncing up)
		var chevronBaseY = designH * 0.58;
		for (i in 0...3) {
			var phase = time * 2.5 - i * 0.4;
			var bounce = Math.sin(phase);
			var fadePhase = (Math.sin(phase) + 1.0) * 0.5; // 0..1
			var alpha = 0.2 + fadePhase * 0.6;
			if (i == 0)
				alpha *= 1.0;
			if (i == 1)
				alpha *= 0.7;
			if (i == 2)
				alpha *= 0.4;
			var yOff = i * 14.0 + bounce * 4;
			drawChevron(chevrons[i], cx, chevronBaseY + yOff, 12.0, alpha);
		}

		// Hint text pulse
		var hintPulse = 0.5 + 0.3 * Math.sin(time * 2.0);
		hint.alpha = hintPulse;

		// Floating particles
		for (p in particles) {
			p.life += dt;
			if (p.life >= p.maxLife) {
				// Reset particle
				p.x = Math.random() * designW;
				p.y = designH + 10;
				p.vx = (Math.random() - 0.5) * 8;
				p.vy = -10 - Math.random() * 15;
				p.life = 0;
				p.maxLife = 3.0 + Math.random() * 3.0;
				p.size = 1.5 + Math.random() * 2.5;
			}
			p.x += p.vx * dt;
			p.y += p.vy * dt;

			// Wrap horizontally
			if (p.x < 0)
				p.x += designW;
			if (p.x > designW)
				p.x -= designW;

			var lifeRatio = p.life / p.maxLife;
			var fadeIn = Math.min(lifeRatio * 5, 1.0);
			var fadeOut = Math.max(1.0 - (lifeRatio - 0.6) * 2.5, 0.0);
			var alpha = fadeIn * fadeOut * 0.4;

			p.g.clear();
			// Tiny glowing dot
			p.g.beginFill(0xA78BFA, alpha * 0.3);
			p.g.drawCircle(p.x, p.y, p.size + 2);
			p.g.endFill();
			p.g.beginFill(0xFFFFFF, alpha);
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
