package scenes.minigames;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Minigame de exemplo: "Don't tap for 2 seconds".
	Se tocar = perde (score 0). Se aguentar 2s = ganha (score 50).
**/
class ExampleMinigame implements IMinigameSceneWithLose implements IMinigameUpdatable {
	final contentObj: Object;
	var title: Text;
	var instruction: Text;
	var ctx: MinigameContext;
	var timeLeft: Float = 2;
	var designW: Int = 360;
	var designH: Int = 640;
	var interactive: h2d.Interactive;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		var bg = new Graphics(contentObj);
		bg.beginFill(0x0f3460);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		title = new Text(hxd.res.DefaultFont.get(), contentObj);
		title.text = getTitle();
		title.textAlign = Center;
		title.x = designW / 2;
		title.y = designH * 0.25;

		instruction = new Text(hxd.res.DefaultFont.get(), contentObj);
		instruction.text = "Don't tap for 2 sec!";
		instruction.textAlign = Center;
		instruction.x = designW / 2;
		instruction.y = designH * 0.4;

		interactive = new h2d.Interactive(designW, designH, contentObj);
		interactive.onClick = function(_) {
			if (ctx != null) {
				ctx.lose(0, getMinigameId());
				ctx = null;
			}
		};
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		timeLeft = 2;
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId(): String return "example-dont-tap";
	public function getTitle(): String return "Don't tap!";

	/** Chamar de GameFlow.update ou do Main: repassa dt para o minigame. */
	public function update(dt: Float) {
		if (ctx == null) return;
		timeLeft -= dt;
		if (timeLeft <= 0) {
			ctx.lose(50, getMinigameId());
			ctx = null;
		}
	}
}
