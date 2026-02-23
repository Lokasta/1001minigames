package core;

import h3d.scene.Scene;

/**
	Minigames que usam a cena 3D (s3d). O GameFlow chama setScene3D(s3d) após criar o minigame.
**/
interface IMinigame3D {
	function setScene3D(s3d: Scene): Void;
}
