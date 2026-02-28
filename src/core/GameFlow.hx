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

	var transitionT: Float;
	var transitioning: Bool;
	var transitionSkipOutgoing: Bool; // true quando abrimos pelo debug sem tela de saída
	var debugMenu: DebugMenu;
	var debugMenuKeyPressed: Bool;

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

	function onSwipeUp() {
		if (transitioning) return;
		switch state {
			case Start:
				startTransitionToNextMinigame();
			case Score:
				startTransitionToNextMinigame();
			case Playing:
		}
	}

	public function startMinigameByIndex(index: Int) {
		if (index < 0 || index >= minigameFactories.length) return;
		if (state == Playing && currentMinigame != null) {
			currentMinigame.dispose();
			currentMinigame.content.remove();
			currentMinigame = null;
		}
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
		if (minigameFactories.length == 0) return;

		var totalWeight = 0.0;
		for (w in minigameWeights)
			totalWeight += w;

		if (totalWeight <= 0) {
			startMinigameByIndexInternal(Std.random(minigameFactories.length));
			return;
		}

		var r = Math.random() * totalWeight;
		for (i in 0...minigameWeights.length) {
			r -= minigameWeights[i];
			if (r < 0) {
				startMinigameByIndexInternal(i);
				return;
			}
		}
		// Defensive fallback for float drift
		startMinigameByIndexInternal(minigameFactories.length - 1);
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
