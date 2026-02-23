package core;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import h2d.Mask;
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
	static var FOOTER_H = 28;

	var root:Object;
	var overlay:Graphics;
	var panel:Object;
	var designW:Int;
	var designH:Int;
	var names:Array<String>;
	var onSelect:Int->Void;
	var rowInteractives:Array<Interactive>;

	// Scroll state
	var listContainer:Object;
	var scrollY:Float;
	var maxScroll:Float;
	var totalListH:Float;
	var viewH:Float;
	var dragging:Bool;
	var dragStartY:Float;
	var dragStartScroll:Float;
	var scrollbarBg:Graphics;
	var scrollbarThumb:Graphics;

	public var visible(get, set):Bool;

	function get_visible()
		return root.visible;

	function set_visible(v:Bool) {
		root.visible = v;
		return v;
	}

	public function new(parent:Object, designW:Int, designH:Int, minigameNames:Array<String>, onSelectIndex:Int->Void) {
		this.designW = designW;
		this.designH = designH;
		this.names = minigameNames;
		this.onSelect = onSelectIndex;
		rowInteractives = [];
		scrollY = 0;
		dragging = false;

		root = new Object(parent);
		root.visible = false;

		overlay = new Graphics(root);
		overlay.beginFill(0x000000, 0.6);
		overlay.drawRect(0, 0, designW, designH);
		overlay.endFill();
		var overlayHit = new Interactive(designW, designH, root);
		overlayHit.propagateEvents = false;

		var panelW = Std.int(Math.min(PANEL_MIN_W + PAD * 2, designW - 32));
		var contentH = TITLE_H + names.length * ROW_H + PAD * 2 + FOOTER_H;
		var panelH = Std.int(Math.min(contentH, designH - 48));
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

		// Scrollable area
		viewH = panelH - TITLE_H - PAD - FOOTER_H;
		var listX = Std.int(panelX + PAD);
		var listYPos = Std.int(panelY + TITLE_H);
		var listW = panelW - PAD * 2;
		var count = names.length;
		totalListH = count * ROW_H;
		maxScroll = Math.max(0, totalListH - viewH);

		// Mask clips the list to the visible area
		var mask = new Mask(Std.int(listW), Std.int(viewH), panel);
		mask.x = listX;
		mask.y = listYPos;

		listContainer = new Object(mask);

		// Build all rows inside the list container
		for (i in 0...count) {
			var rowY = i * ROW_H;

			var rowBg = new Graphics(listContainer);
			rowBg.x = 0;
			rowBg.y = rowY;
			rowBg.beginFill(i % 2 == 0 ? 0x2d2d44 : 0x252538);
			rowBg.drawRoundedRect(0, 0, listW, ROW_H - 4, 6);
			rowBg.endFill();

			var label = new Text(hxd.res.DefaultFont.get(), listContainer);
			label.text = '${i + 1}. ${names[i]}';
			label.x = 12;
			label.y = rowY + 8;
			label.scale(1.1);
			label.textColor = 0xECF0F1;

			var hit = new Interactive(listW, ROW_H - 4, listContainer);
			hit.x = 0;
			hit.y = rowY;
			hit.cursor = Button;
			var idx = i;
			hit.onClick = function(_:Event) {
				onSelect(idx);
			};
			rowInteractives.push(hit);
		}

		// Scrollbar (only if needed)
		if (maxScroll > 0) {
			var sbW = 4;
			var sbX = panelX + panelW - PAD / 2 - sbW;
			scrollbarBg = new Graphics(panel);
			scrollbarBg.x = sbX;
			scrollbarBg.y = listYPos;
			scrollbarBg.beginFill(0x333355, 0.5);
			scrollbarBg.drawRoundedRect(0, 0, sbW, viewH, 2);
			scrollbarBg.endFill();

			scrollbarThumb = new Graphics(panel);
			scrollbarThumb.x = sbX;
			scrollbarThumb.y = listYPos;
			updateScrollbar();

			// Drag-to-scroll interactive over the list area
			var scrollHit = new Interactive(listW, viewH, panel);
			scrollHit.x = listX;
			scrollHit.y = listYPos;
			scrollHit.propagateEvents = true;
			scrollHit.onPush = function(e:Event) {
				dragging = true;
				dragStartY = e.relY;
				dragStartScroll = scrollY;
			};
			scrollHit.onMove = function(e:Event) {
				if (!dragging)
					return;
				var dy = e.relY - dragStartY;
				scrollY = dragStartScroll - dy;
				clampScroll();
				applyScroll();
			};
			scrollHit.onRelease = function(e:Event) {
				dragging = false;
			};
			scrollHit.onReleaseOutside = function(e:Event) {
				dragging = false;
			};
		}
	}

	function clampScroll() {
		if (scrollY < 0)
			scrollY = 0;
		if (scrollY > maxScroll)
			scrollY = maxScroll;
	}

	function applyScroll() {
		listContainer.y = -scrollY;
		updateScrollbar();
	}

	function updateScrollbar() {
		if (scrollbarThumb == null)
			return;
		scrollbarThumb.clear();
		var thumbH = Math.max(20, (viewH / totalListH) * viewH);
		var thumbY = if (maxScroll > 0) (scrollY / maxScroll) * (viewH - thumbH) else 0.0;
		scrollbarThumb.beginFill(0x6688AA, 0.8);
		scrollbarThumb.drawRoundedRect(0, thumbY, 4, thumbH, 2);
		scrollbarThumb.endFill();
	}

	public function dispose() {
		root.remove();
	}
}
