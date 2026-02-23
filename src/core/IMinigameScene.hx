package core;

import h2d.Object;

/**
	Contrato para toda cena de minigame.
	Cada minigame é uma cena independente; pode usar componentes shared quando fizer sentido.
**/
interface IMinigameScene {
	/** Container 2D da cena (adiciona conteúdo aqui). */
	var content(get, never): Object;

	/** Chamado quando o minigame entra na tela. Inicializa e começa o gameplay. */
	function start(): Void;

	/** Chamado quando o feed troca de slide (ex.: swipe para próximo). Remove conteúdo e libera recursos. */
	function dispose(): Void;

	/** ID único do minigame (para analytics, rotação, etc.). */
	function getMinigameId(): String;

	/** Nome curto para UI (ex.: "Tap no verde"). */
	function getTitle(): String;
}
