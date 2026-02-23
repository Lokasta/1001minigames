package scenes;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;

/**
	Tela de score após perder num minigame. "Swipe up for next game".
	Interactive full-screen com propagateEvents = true para o swipe chegar ao feed.
**/
class ScoreScreen extends Object {
	var bg: Graphics;
	var scoreLabel: Text;
	var scoreValue: Text;
	var gameName: Text;
	var hint: Text;
	var interactive: Interactive;
	var designW: Int = 360;
	var designH: Int = 640;

	public function new(parent: Object) {
		super(parent);

		interactive = new Interactive(designW, designH, this);
		interactive.propagateEvents = true;

		bg = new Graphics(this);
		bg.beginFill(0x16213e);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		scoreLabel = new Text(hxd.res.DefaultFont.get(), this);
		scoreLabel.text = "Score";
		scoreLabel.textAlign = Center;
		scoreLabel.x = designW / 2;
		scoreLabel.y = designH * 0.3;

		scoreValue = new Text(hxd.res.DefaultFont.get(), this);
		scoreValue.text = "0";
		scoreValue.textAlign = Center;
		scoreValue.x = designW / 2;
		scoreValue.y = designH * 0.42;
		scoreValue.scale(2);

		gameName = new Text(hxd.res.DefaultFont.get(), this);
		gameName.text = "";
		gameName.textAlign = Center;
		gameName.x = designW / 2;
		gameName.y = designH * 0.52;
		gameName.alpha = 0.8;

		hint = new Text(hxd.res.DefaultFont.get(), this);
		hint.text = "Swipe up for next game";
		hint.textAlign = Center;
		hint.x = designW / 2;
		hint.y = designH * 0.65;
		hint.alpha = 0.9;
	}

	public function setScore(score: Int, minigameId: String) {
		scoreValue.text = Std.string(score);
		gameName.text = minigameId != null && minigameId != "" ? minigameId : "Minigame";
	}

	public function setSize(w: Int, h: Int) {
		designW = w;
		designH = h;
		interactive.width = w;
		interactive.height = h;
		bg.clear();
		bg.beginFill(0x16213e);
		bg.drawRect(0, 0, w, h);
		bg.endFill();
		scoreLabel.x = w / 2;
		scoreLabel.y = Std.int(h * 0.3);
		scoreValue.x = w / 2;
		scoreValue.y = Std.int(h * 0.42);
		gameName.x = w / 2;
		gameName.y = Std.int(h * 0.52);
		hint.x = w / 2;
		hint.y = Std.int(h * 0.65);
	}
}
