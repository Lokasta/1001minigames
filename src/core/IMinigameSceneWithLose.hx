package core;

/** Minigame que reporta "perdeu" com score via MinigameContext. */
interface IMinigameSceneWithLose extends IMinigameScene {
	function setOnLose(ctx: MinigameContext): Void;
}
