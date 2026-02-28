package core;

import h2d.Object;
import h2d.Scene;
import h3d.scene.Scene as Scene3D;
import core.MinigameContext;
import core.IMinigame3D;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;
import core.DebugMenu;
import core.FeedbackManager;
import shared.Easing;

/**
	Feed de slides: Start → Minigame → Score → (swipe) → próximo Minigame → ...
	Transição: UM só container que desliza. O minigame é adicionado como filho e NUNCA
	é removido no fim da animação — só removemos o conteúdo que saiu (start/score).
**/
class GameFlow {
	public var s2d: Scene;
	public var s3d: Null<Scene3D>;
	public var designW: Int;
	public var designH: Int;

	static var TRANSITION_DURATION = 0.38;

	// Drag-driven transition constants
	static var DRAG_THRESHOLD: Float = 0.3;
	static var SNAP_DURATION: Float = 0.25;
	static var RUBBERBAND_DURATION: Float = 0.2;

	var state: FlowState;
	var swipe: SwipeDetector;
	var root: Object;
	/** Único container que desliza; filhos = tela que sai (y=0) + minigame (y=designH durante anim). */
	var slideContainer: Object;

	var startScreen: scenes.StartScreen;
	var scoreScreen: scenes.ScoreScreen;
	var currentMinigame: IMinigameScene = null;
	var minigameNames: Array<String>;
	var minigameFactories: Array<Void->IMinigameScene>;
	var minigameWeights: Array<Float>;
	var lastScore: Int = 0;
	var lastMinigameId: String = "";
	var lastPlayedIndex: Int = -1;

	var transitionT: Float;
	var transitioning: Bool;
	var transitionSkipOutgoing: Bool; // true quando abrimos pelo debug sem tela de saída
	var debugMenu: DebugMenu;
	var debugMenuKeyPressed: Bool;

	// Drag-driven transition state
	var isDragging: Bool = false;
	var dragProgress: Float = 0;
	var previewMinigame: IMinigameScene = null;
	var previewMinigameIndex: Int = -1;
	var isSnapping: Bool = false;
	var isRubberbanding: Bool = false;
	var snapT: Float = 0;
	var snapStartProgress: Float = 0;

	// 3-finger hold to open debug menu on mobile
	var activeTouches: Map<Int, Bool>;
	var threeTouchTimer: Float;
	static var DEBUG_HOLD_TIME = 3.0;
	static var DEBUG_TOUCH_COUNT = 3;

	var hashChecked: Bool = false;

	/** Sistema de feedback (shake, zoom, flash, fade, FOV, etc.). Minigames usam via gameFlow.feedback. */
	public var feedback: FeedbackManager;

	public function new(s2d: Scene, designW: Int, designH: Int, ?s3d: Scene3D) {
		this.s2d = s2d;
		this.s3d = s3d;
		this.designW = designW;
		this.designH = designH;

		root = new Object(s2d);
		minigameNames = [];
		minigameFactories = [];
		minigameWeights = [];
		transitionT = 0;
		transitioning = false;
		transitionSkipOutgoing = false;
		debugMenuKeyPressed = false;
		debugMenu = null;
		activeTouches = new Map();
		threeTouchTimer = 0;

		// Multi-touch listener for 3-finger debug menu activation
		var win = hxd.Window.getInstance();
		win.addEventTarget(onWindowEvent);

		// SwipeDetector primeiro para ficar "atrás"; slideContainer em cima para minigames receberem input
		swipe = new SwipeDetector(root, designW, designH);
		swipe.onSwipeUp = onSwipeUp;
		swipe.onDragStart = onDragStart;
		swipe.onDragMove = onDragMove;
		swipe.onDragEnd = onDragEnd;
		swipe.onDragCancel = onDragCancel;

		slideContainer = new Object(root);

		startScreen = new scenes.StartScreen(slideContainer);
		startScreen.setSize(designW, designH);

		scoreScreen = new scenes.ScoreScreen(slideContainer);
		scoreScreen.setSize(designW, designH);
		scoreScreen.visible = false;
		scoreScreen.onGoHome = onGoHome;

		state = Start;
		startScreen.visible = true;

		feedback = new FeedbackManager(s2d, designW, designH, root, s3d);
	}

	public function registerMinigame(name: String, factory: Void->IMinigameScene, weight: Float = 1.0) {
		minigameNames.push(name);
		minigameFactories.push(factory);
		minigameWeights.push(weight < 0 ? 0.0 : weight);
	}

	function onDebugSelectMinigame(index: Int) {
		if (index < 0 || index >= minigameFactories.length) return;
		if (debugMenu != null) debugMenu.visible = false;
		cancelDragIfActive();
		startMinigameByIndex(index);
	}

	function ensureDebugMenu() {
		if (debugMenu != null) return;
		debugMenu = new DebugMenu(root, designW, designH, minigameNames, onDebugSelectMinigame);
	}

	function onWindowEvent(e: hxd.Event) {
		switch (e.kind) {
			case EPush:
				activeTouches.set(e.touchId, true);
				// Reset timer when touch count changes
				var count = countTouches();
				if (count >= DEBUG_TOUCH_COUNT)
					threeTouchTimer = 0;
			case ERelease, EReleaseOutside:
				activeTouches.remove(e.touchId);
				if (countTouches() < DEBUG_TOUCH_COUNT)
					threeTouchTimer = 0;
			default:
		}
	}

	function countTouches(): Int {
		var c = 0;
		for (_ in activeTouches)
			c++;
		return c;
	}

	public function toggleDebugMenu(): Bool {
		ensureDebugMenu();
		debugMenu.visible = !debugMenu.visible;
		return debugMenu.visible;
	}

	public function isDebugMenuVisible(): Bool {
		return debugMenu != null && debugMenu.visible;
	}

	/** True quando o minigame atual usa a cena 3D (para restringir viewport ao letterbox). */
	public function isCurrentMinigame3D(): Bool {
		return currentMinigame != null && Std.isOfType(currentMinigame, IMinigame3D);
	}

	function isAnimating(): Bool {
		return transitioning || isDragging || isSnapping || isRubberbanding;
	}

	// --- Fast swipe (existing behavior) ---

	function onSwipeUp() {
		if (isAnimating()) return;
		switch state {
			case Start:
				startTransitionToNextMinigame();
			case Score:
				startTransitionToNextMinigame();
			case Playing:
		}
	}

	// --- Drag-driven transition ---

	function onDragStart(startY: Float) {
		if (state != Start && state != Score) return;
		if (isAnimating()) return;
		if (minigameFactories.length == 0) return;

		isDragging = true;
		dragProgress = 0;

		// Pre-instantiate next minigame
		previewMinigameIndex = Std.random(minigameFactories.length);
		previewMinigame = minigameFactories[previewMinigameIndex]();

		// Add to scene graph below current screen
		slideContainer.addChild(previewMinigame.content);
		previewMinigame.content.y = designH;
		previewMinigame.content.visible = true;
		previewMinigame.content.scaleX = 0.97;
		previewMinigame.content.scaleY = 0.97;

		// Do NOT call start(), setOnLose(), or setScene3D() yet
	}

	function onDragMove(dy: Float) {
		if (!isDragging) return;

		// dy negative = upward drag, positive = downward
		dragProgress = Math.max(0, Math.min(1, -dy / designH));

		slideContainer.y = -designH * dragProgress;

		if (previewMinigame != null) {
			var s = 0.97 + 0.03 * dragProgress;
			previewMinigame.content.scaleX = s;
			previewMinigame.content.scaleY = s;
		}
	}

	function onDragEnd(dy: Float) {
		if (!isDragging) return;
		isDragging = false;

		// Recalculate final progress
		dragProgress = Math.max(0, Math.min(1, -dy / designH));
		snapStartProgress = dragProgress;

		if (dragProgress >= DRAG_THRESHOLD) {
			// Snap forward — complete the transition
			isSnapping = true;
			snapT = 0;

			// Set up the minigame fully now
			currentMinigame = previewMinigame;
			previewMinigame = null;

			if (s3d != null && Std.isOfType(currentMinigame, IMinigame3D)) {
				(cast currentMinigame : IMinigame3D).setScene3D(s3d);
			}
			var ctx = new MinigameContext(onMinigameLost);
			ctx.feedback = feedback;
			if (Std.isOfType(currentMinigame, IMinigameSceneWithLose)) {
				(cast currentMinigame : IMinigameSceneWithLose).setOnLose(ctx);
			}

			currentMinigame.start();
			state = Playing;
		} else {
			// Rubber-band back
			isRubberbanding = true;
			snapT = 0;
		}
	}

	function onDragCancel() {
		if (!isDragging) return;
		isDragging = false;

		// Always rubber-band back on cancel
		snapStartProgress = dragProgress;
		isRubberbanding = true;
		snapT = 0;
	}

	function cancelDragIfActive() {
		if (isDragging) {
			isDragging = false;
			cleanupPreviewMinigame();
			slideContainer.y = 0;
		}
		if (isSnapping) {
			isSnapping = false;
		}
		if (isRubberbanding) {
			isRubberbanding = false;
			cleanupPreviewMinigame();
			slideContainer.y = 0;
		}
	}

	function cleanupPreviewMinigame() {
		if (previewMinigame != null) {
			previewMinigame.dispose();
			previewMinigame.content.remove();
			previewMinigame = null;
			previewMinigameIndex = -1;
		}
	}

	// --- Existing transition methods ---

	public function startMinigameByIndex(index: Int) {
		if (index < 0 || index >= minigameFactories.length) return;
		cancelDragIfActive();
		if (state == Playing && currentMinigame != null) {
			currentMinigame.dispose();
			currentMinigame.content.remove();
			currentMinigame = null;
		}
		feedback.resetAll();
		if (state == Start) {
			var outgoing = slideContainer.getChildAt(0);
			slideContainer.removeChild(outgoing);
			outgoing.visible = false;
		} else if (state == Score) {
			var outgoing = slideContainer.getChildAt(0);
			slideContainer.removeChild(outgoing);
			outgoing.visible = false;
		}
		startMinigameByIndexInternal(index);
	}

	function startMinigameByIndexInternal(index: Int) {
		if (minigameFactories.length == 0) return;
		lastPlayedIndex = index;

		transitioning = true;
		transitionT = 0;
		transitionSkipOutgoing = (slideContainer.numChildren == 0);

		var factory = minigameFactories[index];
		currentMinigame = factory();
		if (s3d != null && Std.isOfType(currentMinigame, IMinigame3D)) {
			(cast currentMinigame : IMinigame3D).setScene3D(s3d);
		}
		var ctx = new MinigameContext(onMinigameLost);
		ctx.feedback = feedback;
		if (Std.isOfType(currentMinigame, IMinigameSceneWithLose)) {
			(cast currentMinigame : IMinigameSceneWithLose).setOnLose(ctx);
		}

		// Minigame entra ABAIXO da tela (y = designH). Só animamos o container para cima.
		slideContainer.addChild(currentMinigame.content);
		currentMinigame.content.visible = true;
		currentMinigame.content.x = 0;
		currentMinigame.content.y = designH;
		currentMinigame.content.scaleX = 0.97;
		currentMinigame.content.scaleY = 0.97;
		currentMinigame.start();

		state = Playing;
	}

	function startTransitionToNextMinigame() {
		var n = minigameFactories.length;
		if (n == 0) return;

		var totalWeight = 0.0;
		for (w in minigameWeights)
			totalWeight += w;

		if (totalWeight <= 0) {
			var idx = Std.random(n);
			while (idx == lastPlayedIndex && n > 1)
				idx = Std.random(n);
			startMinigameByIndexInternal(idx);
			return;
		}

		var idx = -1;
		var attempts = 0;
		while (attempts < 20) {
			var r = Math.random() * totalWeight;
			for (i in 0...minigameWeights.length) {
				r -= minigameWeights[i];
				if (r < 0) {
					idx = i;
					break;
				}
			}
			if (idx < 0) idx = n - 1;
			if (idx != lastPlayedIndex || n <= 1) break;
			idx = -1;
			attempts++;
		}
		if (idx < 0) idx = Std.random(n);
		startMinigameByIndexInternal(idx);
	}

	function finishTransition() {
		if (!transitionSkipOutgoing) {
			var outgoing = slideContainer.getChildAt(0);
			slideContainer.removeChild(outgoing);
			outgoing.visible = false;
		}
		transitionSkipOutgoing = false;

		slideContainer.y = 0;
		slideContainer.scaleX = 1;
		slideContainer.scaleY = 1;
		currentMinigame.content.y = 0;
		currentMinigame.content.scaleX = 1;
		currentMinigame.content.scaleY = 1;

		transitioning = false;
	}

	function finishDragTransition() {
		// Remove outgoing screen (first child — start or score screen)
		if (slideContainer.numChildren > 1) {
			var outgoing = slideContainer.getChildAt(0);
			slideContainer.removeChild(outgoing);
			outgoing.visible = false;
		}

		slideContainer.y = 0;
		currentMinigame.content.y = 0;
		currentMinigame.content.scaleX = 1;
		currentMinigame.content.scaleY = 1;

		isSnapping = false;
	}

	function onGoHome() {
		if (state != Score) return;
		scoreScreen.visible = false;
		slideContainer.removeChildren();
		slideContainer.addChild(startScreen);
		startScreen.visible = true;
		state = Start;
	}

	public function onMinigameLost(score: Int, minigameId: String) {
		if (state != Playing || currentMinigame == null) return;

		currentMinigame.dispose();
		currentMinigame.content.remove();
		currentMinigame = null;

		feedback.resetAll();

		lastScore = score;
		lastMinigameId = minigameId;
		scoreScreen.setScore(score, minigameId);
		scoreScreen.visible = true;
		slideContainer.removeChildren();
		slideContainer.addChild(scoreScreen);
		state = Score;
	}

	public function update(dt: Float) {
		// URL hash: open specific minigame for testing (e.g. #knife or #16 for Knife Hit)
		if (!hashChecked) {
			hashChecked = true;
			#if js
			if (state == Start) {
				var h = js.Browser.location.hash;
				if (h != null && h.length > 1) {
					var tag = h.substr(1); // remove #
					var idx = Std.parseInt(tag);
					if (idx == null) {
						// Name-based lookup
						for (i in 0...minigameNames.length) {
							if (minigameNames[i].toLowerCase().indexOf(tag.toLowerCase()) >= 0) {
								idx = i;
								break;
							}
						}
					}
					if (idx != null && idx >= 0 && idx < minigameFactories.length) {
						js.Browser.window.history.replaceState("", "", js.Browser.window.location.pathname + (js.Browser.window.location.search != null ? js.Browser.window.location.search : ""));
						startMinigameByIndex(idx);
					}
				}
			}
			#end
		}
		// Debug menu: K toggle, Esc fecha, 3-finger hold (mobile)
		if (hxd.Key.isPressed(hxd.Key.K)) toggleDebugMenu();
		if (isDebugMenuVisible() && hxd.Key.isPressed(hxd.Key.ESCAPE)) {
			debugMenu.visible = false;
		}
		// 3-finger hold for mobile
		if (countTouches() >= DEBUG_TOUCH_COUNT && !isDebugMenuVisible()) {
			threeTouchTimer += dt;
			if (threeTouchTimer >= DEBUG_HOLD_TIME) {
				threeTouchTimer = 0;
				toggleDebugMenu();
			}
		} else if (countTouches() < DEBUG_TOUCH_COUNT) {
			threeTouchTimer = 0;
		}

		// Old automated transition (fast swipe / debug menu)
		if (transitioning) {
			transitionT += dt;
			var t = transitionT / TRANSITION_DURATION;
			if (t >= 1) {
				t = 1;
				finishTransition();
			} else {
				var ease = Easing.easeOutCubic(t);
				slideContainer.y = -designH * ease;
				currentMinigame.content.scaleX = currentMinigame.content.scaleY = 0.97 + 0.03 * ease;
			}
			return;
		}

		// Snap-forward animation after drag release past threshold
		if (isSnapping) {
			snapT += dt;
			var t = snapT / SNAP_DURATION;
			if (t >= 1) {
				finishDragTransition();
			} else {
				var ease = Easing.easeOutCubic(t);
				// Interpolate from snapStartProgress to 1.0
				var progress = snapStartProgress + (1.0 - snapStartProgress) * ease;
				slideContainer.y = -designH * progress;
				if (currentMinigame != null) {
					var s = 0.97 + 0.03 * progress;
					currentMinigame.content.scaleX = s;
					currentMinigame.content.scaleY = s;
				}
			}
			return;
		}

		// Rubber-band animation after drag release below threshold
		if (isRubberbanding) {
			snapT += dt;
			var t = snapT / RUBBERBAND_DURATION;
			if (t >= 1) {
				slideContainer.y = 0;
				isRubberbanding = false;
				cleanupPreviewMinigame();
			} else {
				var ease = Easing.easeOutCubic(t);
				// Interpolate from snapStartProgress back to 0
				var progress = snapStartProgress * (1.0 - ease);
				slideContainer.y = -designH * progress;
				if (previewMinigame != null) {
					var s = 0.97 + 0.03 * progress;
					previewMinigame.content.scaleX = s;
					previewMinigame.content.scaleY = s;
				}
			}
			return;
		}

		if (feedback != null) feedback.update(dt);
		if (startScreen != null && state == Start) startScreen.update(dt);
		if (scoreScreen != null && state == Score) scoreScreen.update(dt);
		if (currentMinigame != null && Std.isOfType(currentMinigame, IMinigameUpdatable)) {
			(cast currentMinigame : IMinigameUpdatable).update(dt);
		}
	}

	public function resize(w: Int, h: Int) {
		swipe.setSize(w, h);
		if (startScreen != null) startScreen.setSize(w, h);
		if (scoreScreen != null) scoreScreen.setSize(w, h);

		// Cancel any in-progress drag on resize
		if (isDragging || isRubberbanding) {
			cancelDragIfActive();
			swipe.cancelDrag();
		}
	}

	public function dispose() {
		hxd.Window.getInstance().removeEventTarget(onWindowEvent);
		if (feedback != null) {
			feedback.destroy();
			feedback = null;
		}
		if (debugMenu != null) {
			debugMenu.dispose();
			debugMenu = null;
		}
		swipe.dispose();
		cleanupPreviewMinigame();
		if (currentMinigame != null) {
			currentMinigame.dispose();
			currentMinigame = null;
		}
		startScreen = null;
		scoreScreen = null;
		root.remove();
	}
}

enum FlowState {
	Start;
	Playing;
	Score;
}
