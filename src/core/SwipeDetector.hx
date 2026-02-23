package core;

import h2d.Interactive;
import hxd.Event;

/**
	Detecta swipe up (e opcionalmente swipe down) em uma área interativa.
	Usado pelo feed para avançar de slide.
**/
class SwipeDetector {
	public var onSwipeUp: Void->Void;
	public var onSwipeDown: Void->Void;

	var interactive: Interactive;
	var startY: Float = 0;
	var startX: Float = 0;
	var startTime: Float = 0;

	/** Distância mínima (em pixels) para considerar swipe. */
	public var thresholdPx: Float = 60;
	/** Tempo máximo (em segundos) do gesto para contar como swipe. */
	public var maxDurationSec: Float = 0.4;

	public function new(parent: h2d.Object, width: Float, height: Float) {
		interactive = new Interactive(width, height, parent);
		// true = evento também é enviado aos Interactives "abaixo" (ex.: minigames), para tap/clique funcionar
		interactive.propagateEvents = true;

		interactive.onPush = function(e: Event) {
			startX = e.relX;
			startY = e.relY;
			startTime = haxe.Timer.stamp();
		};

		interactive.onRelease = function(e: Event) {
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
	}

	public function setSize(w: Float, h: Float) {
		interactive.width = w;
		interactive.height = h;
	}

	public function dispose() {
		interactive.remove();
		onSwipeUp = null;
		onSwipeDown = null;
	}
}
