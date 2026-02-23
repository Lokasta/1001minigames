package core;

/** Minigame que precisa de update por frame (timer, física, etc.). */
interface IMinigameUpdatable {
	function update(dt: Float): Void;
}
