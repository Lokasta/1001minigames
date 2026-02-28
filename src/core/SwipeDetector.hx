package core;

import h2d.Interactive;
import hxd.Event;

/**
	Detecta swipe up (e opcionalmente swipe down) em uma área interativa.
	Também emite callbacks contínuos de drag para partial-drag preview.
**/
class SwipeDetector {
	public var onSwipeUp: Void->Void;
	public var onSwipeDown: Void->Void;

	/** Drag callbacks for partial-drag preview. */
	public var onDragStart: Float->Void;
	public var onDragMove: Float->Void;
	public var onDragEnd: Float->Void;
	public var onDragCancel: Void->Void;

	var interactive: Interactive;
	var startY: Float = 0;
	var startX: Float = 0;
	var startTime: Float = 0;
	var isDragging: Bool = false;
	var dragStartY: Float = 0;
	var hasTouch: Bool = false;

	/** Distância mínima (em pixels) para considerar swipe. */
	public var thresholdPx: Float = 60;

	/** Tempo máximo (em segundos) do gesto para contar como swipe rápido. */
	public var maxDurationSec: Float = 0.4;

	/** Dead zone before drag activates (avoids conflicts with taps). */
	static var DRAG_DEAD_ZONE: Float = 10.0;

	public function new(parent: h2d.Object, width: Float, height: Float) {
		interactive = new Interactive(width, height, parent);
		interactive.propagateEvents = true;

		interactive.onPush = function(e: Event) {
			startX = e.relX;
			startY = e.relY;
			startTime = haxe.Timer.stamp();
			isDragging = false;
			hasTouch = true;
		};

		interactive.onMove = function(e: Event) {
			if (!hasTouch) return;
			var dy = e.relY - startY;
			var dx = e.relX - startX;

			if (!isDragging) {
				// Check if vertical movement exceeds dead zone and is predominantly vertical
				if (Math.abs(dy) > DRAG_DEAD_ZONE && Math.abs(dy) > Math.abs(dx)) {
					isDragging = true;
					dragStartY = startY;
					if (onDragStart != null) onDragStart(dragStartY);
				}
			} else {
				// Already dragging — check for cancel (horizontal takeover)
				if (Math.abs(dx) > Math.abs(dy) * 2 && Math.abs(dx) > 30) {
					isDragging = false;
					hasTouch = false;
					if (onDragCancel != null) onDragCancel();
					return;
				}
				if (onDragMove != null) onDragMove(dy);
			}
		};

		interactive.onRelease = function(e: Event) {
			if (!hasTouch) return;
			hasTouch = false;

			if (isDragging) {
				var dy = e.relY - startY;
				isDragging = false;
				if (onDragEnd != null) onDragEnd(dy);
				return;
			}

			// Fast-swipe detection (existing behavior)
			var dt = haxe.Timer.stamp() - startTime;
			if (dt > maxDurationSec) return;

			var dy = e.relY - startY;
			var dx = e.relX - startX;

			if (dy < -thresholdPx && Math.abs(dy) >= Math.abs(dx)) {
				if (onSwipeUp != null) onSwipeUp();
			} else if (dy > thresholdPx && Math.abs(dy) >= Math.abs(dx)) {
				if (onSwipeDown != null) onSwipeDown();
			}
		};

		interactive.onReleaseOutside = function(e: Event) {
			if (!hasTouch) return;
			hasTouch = false;

			if (isDragging) {
				var dy = e.relY - startY;
				isDragging = false;
				if (onDragEnd != null) onDragEnd(dy);
			}
		};
	}

	public function cancelDrag() {
		if (isDragging) {
			isDragging = false;
			hasTouch = false;
			if (onDragCancel != null) onDragCancel();
		}
	}

	public function setSize(w: Float, h: Float) {
		interactive.width = w;
		interactive.height = h;
	}

	public function dispose() {
		interactive.remove();
		onSwipeUp = null;
		onSwipeDown = null;
		onDragStart = null;
		onDragMove = null;
		onDragEnd = null;
		onDragCancel = null;
	}
}
