package core;

import h2d.Object;
import h2d.Scene;
import h2d.Graphics;
import h3d.scene.Scene as Scene3D;
import h3d.Vector;

/**
	Sistema de feedback reutilizável para triggar efeitos visuais no jogo.
	Suporta: Camera Shake, Zoom, Flash, Fade, FOV, Clipping Planes, Orthographic Size, Clear Impulse.
	Uso: GameFlow cria e atualiza; minigames acessam via gameFlow.feedback.
**/
class FeedbackManager {
	public var s2d: Scene;
	public var s3d: Null<Scene3D>;
	public var designW: Int;
	public var designH: Int;
	/** Objeto 2D a ser afetado por shake/zoom (ex: root do jogo). */
	public var contentRoot: Object;

	var overlay: Object;
	var overlayG: Graphics;

	// --- Shake (2D = contentRoot offset; 3D = camera pos/target offset) ---
	var shakeT: Float;
	var shakeDuration: Float;
	var shakeAmplitude: Float;
	var shakeFreq: Float;
	var shakeIs3D: Bool;
	var shakeOffsetX: Float;
	var shakeOffsetY: Float;
	var shakeOffsetZ: Float;
	var savedCamPos: Vector;
	var savedCamTarget: Vector;

	// --- Zoom 2D (contentRoot scale) ---
	var zoom2DT: Float;
	var zoom2DDuration: Float; // < 0 = hold until zoomEnd2D
	var zoom2DStart: Float;
	var zoom2DTarget: Float;

	// --- Zoom 3D (FOV) ---
	var zoom3DT: Float;
	var zoom3DDuration: Float;
	var zoom3DStart: Float;
	var zoom3DTarget: Float;
	var savedFov: Float;

	// --- Flash ---
	var flashT: Float;
	var flashDuration: Float;
	var flashColor: Int;
	var flashAlpha: Float;

	// --- Fade ---
	var fadeT: Float;
	var fadeDuration: Float;
	var fadeColor: Int;
	var fadeDirectionIn: Bool; // true = fade from opaque to transparent; false = fade to color
	var fadeAlpha: Float;

	// --- FOV direct (3D) ---
	var fovT: Float;
	var fovDuration: Float;
	var fovStart: Float;
	var fovTarget: Float;

	// --- Clipping planes (3D) ---
	var clipT: Float;
	var clipDuration: Float;
	var clipNearStart: Float;
	var clipNearTarget: Float;
	var clipFarStart: Float;
	var clipFarTarget: Float;
	var savedZNear: Float;
	var savedZFar: Float;

	// --- Orthographic size (2D scale, same as zoom2D but explicit API) ---
	// Reuses zoom2D state; orthoSize() is an alias for zoom2D with scale factor.

	public function new(s2d: Scene, designW: Int, designH: Int, contentRoot: Object, ?s3d: Scene3D) {
		this.s2d = s2d;
		this.s3d = s3d;
		this.designW = designW;
		this.designH = designH;
		this.contentRoot = contentRoot;

		overlay = new Object(s2d);
		overlay.visible = false;
		overlayG = new Graphics(overlay);

		shakeT = 1;
		shakeDuration = 0;
		shakeAmplitude = 0;
		shakeFreq = 12;
		shakeOffsetX = 0;
		shakeOffsetY = 0;
		shakeOffsetZ = 0;
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		zoom2DT = 1;
		zoom2DDuration = 0;
		zoom2DStart = 1;
		zoom2DTarget = 1;

		zoom3DT = 1;
		zoom3DDuration = 0;
		zoom3DStart = 25;
		zoom3DTarget = 25;
		savedFov = 25;

		flashT = 1;
		flashDuration = 0;
		flashColor = 0xFFFFFF;
		flashAlpha = 0;

		fadeT = 1;
		fadeDuration = 0;
		fadeColor = 0x000000;
		fadeDirectionIn = false;
		fadeAlpha = 0;

		fovT = 1;
		fovDuration = 0;
		fovStart = 25;
		fovTarget = 25;

		clipT = 1;
		clipDuration = 0;
		clipNearStart = 0.02;
		clipNearTarget = 0.02;
		clipFarStart = 4000;
		clipFarTarget = 4000;
		savedZNear = 0.02;
		savedZFar = 4000;
	}

	/** Shake da câmera 2D (contentRoot). duration em segundos, amplitude em pixels, frequency em Hz. */
	public function shake2D(durationSec: Float, amplitude: Float, frequency: Float = 12) {
		shakeT = 0;
		shakeDuration = durationSec;
		shakeAmplitude = amplitude;
		shakeFreq = frequency;
		shakeIs3D = false;
	}

	/** Shake da câmera 3D (offset em pos e target). duration em segundos, amplitude em unidades mundo, frequency em Hz. */
	public function shake3D(durationSec: Float, amplitude: Float, frequency: Float = 12) {
		if (s3d == null) return;
		shakeT = 0;
		shakeDuration = durationSec;
		shakeAmplitude = amplitude;
		shakeFreq = frequency;
		shakeIs3D = true;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
	}

	/** Zoom 2D: escala o contentRoot. duration < 0 = mantém até zoomEnd2D(). */
	public function zoom2D(targetScale: Float, durationSec: Float = 0.3) {
		zoom2DStart = contentRoot.scaleX; // assume scaleX == scaleY
		zoom2DTarget = targetScale;
		zoom2DT = 0;
		zoom2DDuration = durationSec;
	}

	/** Para o zoom 2D e volta ao scale 1 (ou chama zoom2D(1, 0.2)). */
	public function zoomEnd2D(durationSec: Float = 0.2) {
		zoom2D(1, durationSec);
	}

	/** Zoom 3D: altera FOV. duration < 0 = mantém até zoomEnd3D(). */
	public function zoom3D(targetFovY: Float, durationSec: Float = 0.3) {
		if (s3d == null) return;
		zoom3DStart = s3d.camera.fovY;
		zoom3DTarget = targetFovY;
		zoom3DT = 0;
		zoom3DDuration = durationSec;
	}

	public function zoomEnd3D(durationSec: Float = 0.2) {
		if (s3d == null) return;
		zoom3D(savedFov, durationSec);
	}

	/** Flash: exibe uma cor na tela por um curto tempo (alpha 1 -> 0). */
	public function flash(color: Int = 0xFFFFFF, durationSec: Float = 0.15) {
		flashT = 0;
		flashDuration = durationSec;
		flashColor = color;
		flashAlpha = 1;
	}

	/** Fade out: escurece até a cor (ex: preto) em durationSec. */
	public function fadeOut(color: Int = 0x000000, durationSec: Float = 0.5) {
		fadeT = 0;
		fadeDuration = durationSec;
		fadeColor = color;
		fadeDirectionIn = false;
		fadeAlpha = 0;
	}

	/** Fade in: da cor atual para transparente. */
	public function fadeIn(color: Int = 0x000000, durationSec: Float = 0.5) {
		fadeT = 0;
		fadeDuration = durationSec;
		fadeColor = color;
		fadeDirectionIn = true;
		fadeAlpha = 1;
	}

	/** Campo de visão 3D ao longo do tempo. */
	public function fov(targetFovY: Float, durationSec: Float = 0.3) {
		if (s3d == null) return;
		fovStart = s3d.camera.fovY;
		fovTarget = targetFovY;
		fovT = 0;
		fovDuration = durationSec;
	}

	/** Tween dos planos near/far da câmera 3D. */
	public function clipping(near: Float, far: Float, durationSec: Float = 0.3) {
		if (s3d == null) return;
		clipNearStart = s3d.camera.zNear;
		clipFarStart = s3d.camera.zFar;
		clipNearTarget = near;
		clipFarTarget = far;
		clipT = 0;
		clipDuration = durationSec;
	}

	/** Orthographic size (2D): equivale a zoom no conteúdo 2D. size = escala (ex: 1.2 = zoom in). */
	public function orthoSize(size: Float, durationSec: Float = 0.3) {
		zoom2D(size, durationSec);
	}

	/** Cancela qualquer shake/impulse em andamento. */
	public function clearImpulse() {
		shakeDuration = 0;
		shakeT = 1;
		shakeOffsetX = 0;
		shakeOffsetY = 0;
		shakeOffsetZ = 0;
		if (s3d != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		contentRoot.x = 0;
		contentRoot.y = 0;
	}

	/** Reseta TODOS os efeitos para estado neutro (shake, zoom, flash, fade, FOV, clipping). */
	public function resetAll() {
		clearImpulse();

		// Zoom 2D
		zoom2DT = 1;
		zoom2DDuration = 0;
		zoom2DStart = 1;
		zoom2DTarget = 1;
		contentRoot.scaleX = 1;
		contentRoot.scaleY = 1;

		// Zoom 3D
		zoom3DT = 1;
		zoom3DDuration = 0;
		if (s3d != null) {
			s3d.camera.fovY = savedFov;
		}

		// Flash
		flashT = 1;
		flashDuration = 0;
		flashAlpha = 0;

		// Fade
		fadeT = 1;
		fadeDuration = 0;
		fadeAlpha = 0;

		// FOV
		fovT = 1;
		fovDuration = 0;

		// Clipping
		clipT = 1;
		clipDuration = 0;
		if (s3d != null) {
			s3d.camera.zNear = savedZNear;
			s3d.camera.zFar = savedZFar;
		}

		// Overlay
		overlay.visible = false;
	}

	/** Chamado todo frame pelo GameFlow. */
	public function update(dt: Float) {
		if (contentRoot == null) return;
		// --- Shake ---
		if (shakeT < shakeDuration) {
			shakeT += dt;
			var t = shakeT / shakeDuration;
			var decay = 1 - t * t; // decay no fim
			var a = shakeAmplitude * decay;
			var angle = shakeT * shakeFreq * Math.PI * 2;
			shakeOffsetX = (Math.sin(angle) + Math.sin(angle * 2.3)) * 0.5 * a;
			shakeOffsetY = (Math.cos(angle * 1.7) + Math.sin(angle * 0.7)) * 0.5 * a;
			shakeOffsetZ = (Math.sin(angle * 1.3)) * 0.3 * a;

			if (!shakeIs3D) {
				contentRoot.x = shakeOffsetX;
				contentRoot.y = shakeOffsetY;
			}
			if (shakeIs3D && s3d != null) {
				// Translação pura (pos e target juntos) para evitar sensação de rotação forte
				s3d.camera.pos.x = savedCamPos.x + shakeOffsetX;
				s3d.camera.pos.y = savedCamPos.y + shakeOffsetY;
				s3d.camera.pos.z = savedCamPos.z + shakeOffsetZ;
				s3d.camera.target.x = savedCamTarget.x + shakeOffsetX;
				s3d.camera.target.y = savedCamTarget.y + shakeOffsetY;
				s3d.camera.target.z = savedCamTarget.z + shakeOffsetZ;
			}
		} else if (shakeDuration > 0) {
			shakeDuration = 0;
			if (!shakeIs3D) {
				contentRoot.x = 0;
				contentRoot.y = 0;
			}
			if (shakeIs3D && s3d != null) {
				s3d.camera.pos.load(savedCamPos);
				s3d.camera.target.load(savedCamTarget);
			}
		}

		// --- Zoom 2D ---
		if (zoom2DT < 1) {
			zoom2DT += dt / (zoom2DDuration <= 0 ? 0.3 : zoom2DDuration);
			if (zoom2DT > 1) zoom2DT = 1;
			var k = easeOutCubic(zoom2DT);
			var s = zoom2DStart + (zoom2DTarget - zoom2DStart) * k;
			contentRoot.scaleX = s;
			contentRoot.scaleY = s;
		}

		// --- Zoom 3D (FOV) ---
		if (s3d != null && zoom3DT < 1) {
			zoom3DT += dt / (zoom3DDuration <= 0 ? 0.3 : zoom3DDuration);
			if (zoom3DT > 1) zoom3DT = 1;
			var k = easeOutCubic(zoom3DT);
			s3d.camera.fovY = zoom3DStart + (zoom3DTarget - zoom3DStart) * k;
		}

		// --- Flash ---
		if (flashT < flashDuration) {
			flashT += dt;
			var t = flashT / flashDuration;
			flashAlpha = 1 - t; // linear decay
			drawOverlay(flashColor, flashAlpha);
			overlay.visible = true;
		} else if (flashDuration > 0) {
			flashDuration = 0;
			overlay.visible = false;
		}

		// --- Fade ---
		if (fadeT < fadeDuration) {
			fadeT += dt;
			var t = fadeT / fadeDuration;
			var k = easeOutCubic(t);
			if (fadeDirectionIn) fadeAlpha = 1 - k;
			else fadeAlpha = k;
			drawOverlay(fadeColor, fadeAlpha);
			overlay.visible = true;
		} else if (fadeDuration > 0) {
			fadeDuration = 0;
			overlay.visible = false;
		}

		// --- FOV direct ---
		if (s3d != null && fovT < fovDuration) {
			fovT += dt;
			var t = fovT / fovDuration;
			if (t >= 1) t = 1;
			var k = easeOutCubic(t);
			s3d.camera.fovY = fovStart + (fovTarget - fovStart) * k;
			if (t >= 1) fovDuration = 0;
		}

		// --- Clipping ---
		if (s3d != null && clipT < clipDuration) {
			clipT += dt;
			var t = clipT / clipDuration;
			if (t >= 1) t = 1;
			var k = easeOutCubic(t);
			s3d.camera.zNear = clipNearStart + (clipNearTarget - clipNearStart) * k;
			s3d.camera.zFar = clipFarStart + (clipFarTarget - clipFarStart) * k;
			if (t >= 1) clipDuration = 0;
		}
	}

	function drawOverlay(color: Int, alpha: Float) {
		overlayG.clear();
		overlayG.beginFill(color, alpha);
		overlayG.drawRect(0, 0, designW, designH);
		overlayG.endFill();
	}

	inline function easeOutCubic(t: Float): Float {
		var u = 1 - t;
		return 1 - u * u * u;
	}

	/** Salva FOV/clipping atuais como "restore" para zoomEnd3D (opcional). Chamado pelo minigame 3D ao configurar câmera. */
	public function save3DCameraDefaults() {
		if (s3d == null) return;
		savedFov = s3d.camera.fovY;
		savedZNear = s3d.camera.zNear;
		savedZFar = s3d.camera.zFar;
	}

	public function destroy() {
		overlay.remove();
		overlayG = null;
		contentRoot = null;
		s2d = null;
		s3d = null;
	}
}
