package core;

/**
	Contexto passado ao minigame para reportar derrota, score e acessar o sistema de feedback.
**/
class MinigameContext {
	public var onLose: (score: Int, minigameId: String) -> Void;
	/** Sistema de feedback (shake, flash, fade, zoom, etc.). Preenchido pelo GameFlow. */
	public var feedback: Null<FeedbackManager>;

	public function new(onLose: (score: Int, minigameId: String) -> Void) {
		this.onLose = onLose;
	}

	public function lose(score: Int, minigameId: String) {
		if (onLose != null) onLose(score, minigameId);
	}
}
