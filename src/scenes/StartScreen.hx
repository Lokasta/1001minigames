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
		bg.beginFill(0x1a1a2e);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		label = new Text(hxd.res.DefaultFont.get(), this);
		label.text = "TokTok Games";
		label.textAlign = Center;
		label.x = designW / 2;
		label.y = designH * 0.35;
		label.scale(1.5);

		hint = new Text(hxd.res.DefaultFont.get(), this);
		hint.text = "Swipe up to play";
		hint.textAlign = Center;
		hint.x = designW / 2;
		hint.y = designH * 0.55;
		hint.alpha = 0.9;
	}

	public function setSize(w: Int, h: Int) {
		designW = w;
		designH = h;
		interactive.width = w;
		interactive.height = h;
		bg.clear();
		bg.beginFill(0x1a1a2e);
		bg.drawRect(0, 0, w, h);
		bg.endFill();
		label.x = w / 2;
		label.y = Std.int(h * 0.35);
		hint.x = w / 2;
		hint.y = Std.int(h * 0.55);
	}
}
