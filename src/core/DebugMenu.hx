package core;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import hxd.Event;

/**
	Menu de debug (dev): lista de minigames para abrir direto.
	Atalho: K (toggle). Esc fecha.
**/
class DebugMenu {
	static var PAD = 24;
	static var ROW_H = 40;
	static var PANEL_MIN_W = 280;
	static var TITLE_H = 44;

	var root: Object;
	var overlay: Graphics;
	var panel: Object;
	var designW: Int;
	var designH: Int;
	var names: Array<String>;
	var onSelect: Int->Void;
	var rowInteractives: Array<Interactive>;

	public var visible(get, set): Bool;
	function get_visible() return root.visible;
	function set_visible(v: Bool) {
		root.visible = v;
		return v;
	}

	public function new(parent: Object, designW: Int, designH: Int, minigameNames: Array<String>, onSelectIndex: Int->Void) {
		this.designW = designW;
		this.designH = designH;
		this.names = minigameNames;
		this.onSelect = onSelectIndex;
		rowInteractives = [];

		root = new Object(parent);
		root.visible = false;

		overlay = new Graphics(root);
		overlay.beginFill(0x000000, 0.6);
		overlay.drawRect(0, 0, designW, designH);
		overlay.endFill();
		var overlayHit = new Interactive(designW, designH, root);
		overlayHit.propagateEvents = false;

		var panelW = Std.int(Math.min(PANEL_MIN_W + PAD * 2, designW - 32));
		var panelH = TITLE_H + names.length * ROW_H + PAD * 2;
		panelH = Std.int(Math.min(panelH, designH - 48));
		var panelX = (designW - panelW) / 2;
		var panelY = (designH - panelH) / 2;

		panel = new Object(root);
		var bg = new Graphics(panel);
		bg.x = panelX;
		bg.y = panelY;
		bg.beginFill(0x1a1a2e);
		bg.drawRoundedRect(0, 0, panelW, panelH, 12);
		bg.endFill();
		bg.lineStyle(2, 0x3498DB);
		bg.drawRoundedRect(0, 0, panelW, panelH, 12);
		bg.lineStyle(0);

		var title = new Text(hxd.res.DefaultFont.get(), panel);
		title.text = "Debug – escolha o jogo";
		title.x = panelX + PAD;
		title.y = panelY + 12;
		title.scale(1.4);
		title.textColor = 0xFFFFFF;

		var hint = new Text(hxd.res.DefaultFont.get(), panel);
		hint.text = "K ou Esc para fechar";
		hint.x = panelX + PAD;
		hint.y = panelY + panelH - 22;
		hint.scale(0.9);
		hint.textColor = 0x95a5a6;

		var scrollH = panelH - TITLE_H - PAD * 2 - 28;
		var listY = panelY + TITLE_H;
		var listW = panelW - PAD * 2;
		var count = names.length;
		var showCount = Std.int(Math.min(count, Math.floor(scrollH / ROW_H)));

		for (i in 0...count) {
			var rowY = listY + i * ROW_H;
			if (rowY + ROW_H > panelY + panelH - PAD - 24) break;

			var rowBg = new Graphics(panel);
			rowBg.x = panelX + PAD;
			rowBg.y = rowY;
			rowBg.beginFill(i % 2 == 0 ? 0x2d2d44 : 0x252538);
			rowBg.drawRoundedRect(0, 0, listW, ROW_H - 4, 6);
			rowBg.endFill();

			var label = new Text(hxd.res.DefaultFont.get(), panel);
			label.text = '${i + 1}. ${names[i]}';
			label.x = panelX + PAD + 12;
			label.y = rowY + 8;
			label.scale(1.1);
			label.textColor = 0xECF0F1;

			var hit = new Interactive(listW, ROW_H - 4, panel);
			hit.x = panelX + PAD;
			hit.y = rowY;
			hit.cursor = Button;
			var idx = i;
			hit.onClick = function(_: Event) {
				onSelect(idx);
			};
			rowInteractives.push(hit);
		}
	}

	public function dispose() {
		root.remove();
	}
}
