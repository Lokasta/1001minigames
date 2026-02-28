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
	var bg: Graphics;
	var label: Text;
	var hint: Text;
	var interactive: Interactive;
	var designW: Int = 360;
	var designH: Int = 640;

	public function new(parent: Object) {
		super(parent);

		interactive = new Interactive(designW, designH, this);
		interactive.propagateEvents = true;

		bg = new Graphics(this);

		label = new Text(hxd.res.DefaultFont.get(), this);
		label.text = "TokTok Games";
		label.textAlign = Center;
		label.x = designW / 2;
		label.y = Std.int(designH * 0.32);
		label.scale(2.2);
		label.textColor = 0xFFFFFF;

		hint = new Text(hxd.res.DefaultFont.get(), this);
		hint.text = "Swipe up to play";
		hint.textAlign = Center;
		hint.x = designW / 2;
		hint.y = Std.int(designH * 0.56);
		hint.scale(1.15);
		hint.textColor = 0xAABBEE;
		hint.alpha = 0.95;

		drawBg();
	}

	function drawBg(): Void {
		bg.clear();

		// Base gradient
		bg.beginFill(0x0D0A14);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		bg.beginFill(0x12101C);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		bg.beginFill(0x1A1628);
		bg.drawRect(0, 0, designW, Std.int(designH * 0.6));
		bg.endFill();
		// Soft radial glow behind title
		bg.beginFill(0x2D2440, 0.5);
		bg.drawCircle(designW / 2, designH * 0.35, 140);
		bg.endFill();
		bg.beginFill(0x3A3050, 0.25);
		bg.drawCircle(designW / 2, designH * 0.35, 100);
		bg.endFill();
		// Decorative dots (subtle)
		bg.beginFill(0xFFFFFF, 0.04);
		bg.drawCircle(60, 120, 40);
		bg.drawCircle(designW - 70, designH - 150, 50);
		bg.drawCircle(designW / 2 + 100, 200, 25);
		bg.endFill();
		// Vignette
		bg.beginFill(0x000000, 0.4);
		bg.drawRect(0, 0, designW, 70);
		bg.drawRect(0, designH - 100, designW, 100);
		bg.drawRect(0, 0, 50, designH);
		bg.drawRect(designW - 50, 0, 50, designH);
		bg.endFill();

		// Swipe-up arrow (chevron)
		var arrowY = Std.int(designH * 0.48);
		var cx = designW / 2;
		var arrowW = 14.0;
		var arrowH = 10.0;
		bg.beginFill(0x8899CC, 0.5);
		bg.moveTo(cx, arrowY - arrowH);
		bg.lineTo(cx - arrowW, arrowY);
		bg.lineTo(cx, arrowY + arrowH * 0.5);
		bg.lineTo(cx + arrowW, arrowY);
		bg.lineTo(cx, arrowY - arrowH);
		bg.endFill();
		bg.beginFill(0xAABBEE, 0.8);
		bg.moveTo(cx, arrowY - arrowH + 3);
		bg.lineTo(cx - arrowW + 3, arrowY);
		bg.lineTo(cx, arrowY + arrowH * 0.5 - 2);
		bg.lineTo(cx + arrowW - 3, arrowY);
		bg.lineTo(cx, arrowY - arrowH + 3);
		bg.endFill();
	}

	public function setSize(w: Int, h: Int) {
		designW = w;
		designH = h;
		interactive.width = w;
		interactive.height = h;
		label.x = w / 2;
		label.y = Std.int(h * 0.32);
		hint.x = w / 2;
		hint.y = Std.int(h * 0.56);
		drawBg();
	}
}
