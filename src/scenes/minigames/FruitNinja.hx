package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import hxd.Event;
import h3d.scene.Scene;
import h3d.scene.Mesh;
import h3d.prim.Sphere;
import h3d.prim.Cube;
import h3d.Vector;
import h3d.col.Ray;
import h3d.col.Plane;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;
import core.IMinigame3D;

/**
	Fruit Ninja: frutas sobem, deslize para cortar. Cortar bomba = game over.
	Frutas em 3D (placeholders Sphere/Cube); depois você pode trocar por modelos 3D em createFruitMesh/createBombMesh.
**/
class FruitNinja implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRAVITY = 380;
	static var SPAWN_INTERVAL = 0.85;
	static var BOMB_CHANCE = 0.14;
	static var MISS_LIMIT = 3;
	static var SWIPE_STEP_PX = 12;
	static var SWIPE_RADIUS = 22;
	static var COMBO_TEXT_DURATION = 0.4;
	static var PLANE_Y0: Plane = new Plane(0, 1, 0, 0);
	/** Escala design→3D: área 360×640 cabe no frustum da câmera. */
	static var DESIGN_TO_3D_SCALE = 0.012;

	var s3d: Scene;
	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;
	var savedCamPos: Vector;
	var savedCamTarget: Vector;

	var bg: Graphics;
	var fruitsG: Graphics;
	var slashG: Graphics;
	var splashG: Graphics;
	var scoreText: Text;
	var comboText: Text;
	var livesText: Text;
	var interactive: Interactive;

	var items: Array<FruitItem>;
	var swipePoints: Array<{ x: Float, y: Float }>;
	var splashes: Array<{ x: Float, y: Float, t: Float }>;
	var pieces: Array<CutPiece>;
	var sceneObjects: Array<h3d.scene.Object>;
	var spawnTimer: Float;
	var started: Bool;
	var score: Int;
	var combo: Int;
	var comboTextTimer: Float;
	var misses: Int;
	var gameOver: Bool;
	var lastSwipeX: Float;
	var lastSwipeY: Float;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function setScene3D(scene: Scene) {
		s3d = scene;
	}

	/** Converte coordenada X do design (0..360) para 3D. */
	inline function designTo3Dx(x: Float): Float return (x / designW - 0.5) * (designW * DESIGN_TO_3D_SCALE);
	/** Converte Y do design (0=topo, 640=baixo) para 3D Z (baixo da tela = +Z, topo = -Z, para subir de baixo pra cima). */
	inline function designTo3Dz(y: Float): Float return (y / designH - 0.5) * (designH * DESIGN_TO_3D_SCALE);

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		sceneObjects = [];
		pieces = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		bg = new Graphics(contentObj);
		bg.beginFill(0x1a1a2e);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		bg.beginFill(0x0f0f1a, 0.5);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();

		fruitsG = new Graphics(contentObj);
		slashG = new Graphics(contentObj);
		splashG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 45;
		scoreText.y = 14;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;

		livesText = new Text(hxd.res.DefaultFont.get(), contentObj);
		livesText.text = "♥♥♥";
		livesText.x = 20;
		livesText.y = 14;
		livesText.scale(1.3);
		livesText.textColor = 0xFF4466;

		comboText = new Text(hxd.res.DefaultFont.get(), contentObj);
		comboText.text = "";
		comboText.x = designW / 2 - 40;
		comboText.y = designH * 0.4 - 30;
		comboText.scale(2);
		comboText.textAlign = Center;
		comboText.textColor = 0xFFDD00;
		comboText.visible = false;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			var x = clampDesign(e.relX, 0, designW);
			var y = clampDesign(e.relY, 0, designH);
			swipePoints = [{ x: x, y: y }];
			lastSwipeX = x;
			lastSwipeY = y;
			e.propagate = false;
		};
		interactive.onMove = function(e: Event) {
			if (swipePoints == null) return;
			var x = clampDesign(e.relX, 0, designW);
			var y = clampDesign(e.relY, 0, designH);
			var dx = x - lastSwipeX;
			var dy = y - lastSwipeY;
			if (dx * dx + dy * dy >= SWIPE_STEP_PX * SWIPE_STEP_PX) {
				swipePoints.push({ x: x, y: y });
				lastSwipeX = x;
				lastSwipeY = y;
				if (swipePoints.length >= 2)
					processSlash();
			}
		};
		interactive.onRelease = function(e: Event) {
			if (swipePoints == null || swipePoints.length < 2) {
				swipePoints = null;
				return;
			}
			// Qualquer swipe com 2+ pontos vale (sem exigir comprimento mínimo)
			processSlash();
			swipePoints = null;
			e.propagate = false;
		};
	}

	inline function clampDesign(v: Float, min: Float, max: Float): Float {
		return v < min ? min : (v > max ? max : v);
	}

	/** Colisão no espaço 3D: swipe → raio da câmera → plano y=0 → segmento vs círculo em XZ. */
	function processSlash3D(toRemove: Array<FruitItem>) {
		var scene = contentObj.getScene();
		if (scene == null || swipePoints.length < 2) return;
		var vw = scene.width;
		var vh = scene.height;
		if (vw <= 0 || vh <= 0) return;
		s3d.camera.update();
		var pts: Array<{ x: Float, z: Float }> = [];
		for (p in swipePoints) {
			var vpX = p.x * vw / designW;
			var vpY = p.y * vh / designH;
			var ray = s3d.camera.rayFromScreen(vpX, vpY, vw, vh);
			var hit = ray.intersect(PLANE_Y0);
			if (hit != null)
				pts.push({ x: hit.x, z: hit.z });
		}
		if (pts.length < 2) return;
		for (item in items) {
			var cx = designTo3Dx(item.x);
			var cz = designTo3Dz(item.y);
			var r3d = (item.r / 25) * 0.35 + 0.22;
			if (segmentIntersectsCircle3D(pts, cx, cz, r3d))
				toRemove.push(item);
		}
	}

	function segmentIntersectsCircle3D(pts: Array<{ x: Float, z: Float }>, cx: Float, cz: Float, r: Float): Bool {
		for (i in 0...pts.length - 1) {
			var a = pts[i];
			var b = pts[i + 1];
			if (segmentVsCircleXZ(a.x, a.z, b.x, b.z, cx, cz, r)) return true;
		}
		return false;
	}

	inline function segmentVsCircleXZ(x1: Float, z1: Float, x2: Float, z2: Float, cx: Float, cz: Float, r: Float): Bool {
		var dx = x2 - x1;
		var dz = z2 - z1;
		var len2 = dx * dx + dz * dz;
		if (len2 < 1e-6) return (cx - x1) * (cx - x1) + (cz - z1) * (cz - z1) <= r * r;
		var t = ((cx - x1) * dx + (cz - z1) * dz) / len2;
		if (t < 0) t = 0;
		if (t > 1) t = 1;
		var px = x1 + t * dx;
		var pz = z1 + t * dz;
		var d2 = (cx - px) * (cx - px) + (cz - pz) * (cz - pz);
		return d2 <= r * r;
	}

	function processSlash() {
		var hitCount = 0;
		var hitBomb = false;
		var toRemove: Array<FruitItem> = [];
		if (s3d != null) {
			processSlash3D(toRemove);
		} else {
			for (item in items) {
				var hitR = item.r + SWIPE_RADIUS;
				if (segmentIntersectsCircleList(item.x, item.y, hitR))
					toRemove.push(item);
			}
		}
		for (item in toRemove) {
			if (item.isBomb) hitBomb = true;
			else {
				hitCount++;
				addSplash(item.x, item.y, item.color);
				spawnCutPieces(item);
			}
		}
		for (item in toRemove) {
			if (item.mesh != null) {
				item.mesh.remove();
				item.mesh = null;
			}
			items.remove(item);
		}
		if (hitBomb) {
			gameOver = true;
			if (ctx.feedback != null) {
				ctx.feedback.shake3D(0.4, 0.06, 14);
				ctx.feedback.flash(0xFF2222, 0.2);
			}
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}
		if (hitCount > 0) {
			score += hitCount;
			combo = hitCount;
			comboTextTimer = COMBO_TEXT_DURATION;
			comboText.text = hitCount > 1 ? 'x${hitCount}' : "";
			comboText.visible = true;
			scoreText.text = Std.string(score);
			if (ctx.feedback != null) {
				ctx.feedback.shake3D(0.08, 0.012, 16);
				ctx.feedback.flash(0xFFFFFF, 0.05);
			}
		}
	}

	function segmentIntersectsCircleList(cx: Float, cy: Float, r: Float): Bool {
		for (i in 0...swipePoints.length - 1) {
			var a = swipePoints[i];
			var b = swipePoints[i + 1];
			if (segmentIntersectsCircle(a.x, a.y, b.x, b.y, cx, cy, r)) return true;
		}
		return false;
	}

	function segmentIntersectsCircle(x1: Float, y1: Float, x2: Float, y2: Float, cx: Float, cy: Float, r: Float): Bool {
		var dx = x2 - x1;
		var dy = y2 - y1;
		var len2 = dx * dx + dy * dy;
		if (len2 < 0.001) return (cx - x1) * (cx - x1) + (cy - y1) * (cy - y1) <= r * r;
		var t = ((cx - x1) * dx + (cy - y1) * dy) / len2;
		if (t < 0) t = 0;
		if (t > 1) t = 1;
		var px = x1 + t * dx;
		var py = y1 + t * dy;
		var d2 = (cx - px) * (cx - px) + (cy - py) * (cy - py);
		return d2 <= r * r;
	}

	function addSplash(x: Float, y: Float, color: Int) {
		for (_ in 0...8)
			splashes.push({ x: x + (Math.random() - 0.5) * 30, y: y + (Math.random() - 0.5) * 30, t: 0.25 });
	}

	function spawnCutPieces(item: FruitItem) {
		var n = 2 + Std.int(Math.random() * 3);
		for (_ in 0...n) {
			var angle = Math.random() * Math.PI * 2;
			var speed = 120 + Math.random() * 180;
			var vx = item.vx * 0.3 + Math.cos(angle) * speed;
			var vy = item.vy * 0.2 + Math.sin(angle) * speed * 0.6 + 80 + Math.random() * 120;
			var px = item.x + (Math.random() - 0.5) * item.r;
			var py = item.y;
			var piece: CutPiece = {
				x: px,
				y: py,
				vx: vx,
				vy: vy,
				life: 0.7,
				color: item.color,
				mesh: null
			};
			if (s3d != null) {
				piece.mesh = createPieceMesh(item.color);
				if (piece.mesh != null) piece.mesh.setPosition(designTo3Dx(px), 0, designTo3Dz(py));
			}
			pieces.push(piece);
		}
	}

	function createPieceMesh(color: Int): Mesh {
		if (s3d == null) return null;
		var prim = new Sphere(1, 8, 8);
		prim.unindex();
		prim.addNormals();
		var mesh = new Mesh(prim, s3d);
		mesh.material.color.setColor(color);
		mesh.material.shadows = false;
		mesh.setScale(0.08);
		return mesh;
	}

	/** Placeholder: esfera. Para usar seus modelos 3D, troque por ex. hxd.res.Model.get().toMesh() ou clone do seu mesh. */
	function createFruitMesh(r: Float, color: Int): Mesh {
		if (s3d == null) return null;
		var prim = new Sphere(1, 16, 16);
		prim.unindex();
		prim.addNormals();
		var mesh = new Mesh(prim, s3d);
		mesh.material.color.setColor(color);
		mesh.material.shadows = false;
		var scale = (r / 25) * 0.35;
		mesh.setScale(scale);
		sceneObjects.push(mesh);
		return mesh;
	}

	/** Placeholder: cubo. Troque por seu modelo 3D de bomba quando tiver. */
	function createBombMesh(r: Float): Mesh {
		if (s3d == null) return null;
		var prim = new Cube(1, 1.2, 0.6, true);
		prim.unindex();
		prim.addNormals();
		var mesh = new Mesh(prim, s3d);
		mesh.material.color.setColor(0x2a2a2a);
		mesh.material.shadows = false;
		mesh.setScale((r / 25) * 0.35);
		sceneObjects.push(mesh);
		return mesh;
	}

	function spawnItem() {
		var isBomb = Math.random() < BOMB_CHANCE;
		var x = 60 + Math.random() * (designW - 120);
		var y = designH + 15;
		var vx = (Math.random() - 0.5) * 80;
		var vy = -480 - Math.random() * 160;
		var r = isBomb ? 22 : 18 + Math.random() * 10;
		var color = isBomb ? 0x222222 : [
			0xE74C3C, 0xF39C12, 0x2ECC71, 0x3498DB, 0x9B59B6, 0x1ABC9C, 0xE91E63
		][Std.int(Math.random() * 7)];
		var mesh: Mesh = null;
		if (s3d != null) {
			mesh = isBomb ? createBombMesh(r) : createFruitMesh(r, color);
			if (mesh != null) mesh.setPosition(designTo3Dx(x), 0, designTo3Dz(y));
		}
		items.push({ x: x, y: y, vx: vx, vy: vy, r: r, color: color, isBomb: isBomb, mesh: mesh });
	}

	function drawPieces() {
		if (s3d != null) return; // 3D: pieces são meshes atualizados em update()
		for (p in pieces) {
			var r = 4 + (1 - p.life / 0.7) * 4;
			fruitsG.beginFill(p.color, p.life / 0.7);
			fruitsG.drawCircle(p.x, p.y, r);
			fruitsG.endFill();
		}
	}

	function drawFruits() {
		if (s3d != null) return;
		fruitsG.clear();
		for (item in items) {
			if (item.isBomb) {
				fruitsG.beginFill(0x2a2a2a);
				fruitsG.drawCircle(item.x, item.y, item.r);
				fruitsG.endFill();
				fruitsG.lineStyle(2, 0x444444);
				fruitsG.drawCircle(item.x, item.y, item.r);
				fruitsG.lineStyle(0);
				fruitsG.beginFill(0x666666);
				fruitsG.drawRect(item.x - 4, item.y - item.r - 12, 8, 14);
				fruitsG.endFill();
				fruitsG.beginFill(0xFF4444);
				fruitsG.drawCircle(item.x, item.y - item.r - 14, 6);
				fruitsG.endFill();
			} else {
				fruitsG.beginFill(item.color);
				fruitsG.drawCircle(item.x, item.y, item.r);
				fruitsG.endFill();
				fruitsG.lineStyle(2, 0xFFFFFF, 0.35);
				fruitsG.drawCircle(item.x - item.r * 0.3, item.y - item.r * 0.3, item.r * 0.4);
				fruitsG.lineStyle(0);
			}
		}
	}

	function drawSlash() {
		slashG.clear();
		if (swipePoints == null || swipePoints.length < 2) return;
		slashG.lineStyle(6, 0xFFFFFF, 0.7);
		slashG.moveTo(swipePoints[0].x, swipePoints[0].y);
		for (i in 1...swipePoints.length)
			slashG.lineTo(swipePoints[i].x, swipePoints[i].y);
		slashG.lineStyle(0);
	}

	function drawSplashes() {
		splashG.clear();
		for (s in splashes) {
			var alpha = 1 - s.t / 0.25;
			if (alpha <= 0) continue;
			var scale = 1 + (1 - alpha) * 1.5;
			splashG.beginFill(0xFFFFFF, alpha * 0.9);
			splashG.drawCircle(s.x, s.y, 6 * scale);
			splashG.endFill();
		}
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	function setup3D() {
		if (s3d == null) return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		// Câmera olha -Z; plano XZ com Z para cima (frutas em Y=0, movendo em X e Z)
		s3d.camera.pos.set(0, 11, 0);
		s3d.camera.target.set(0, 0, 0);
		if (s3d.camera.up != null) s3d.camera.up.set(0, 1, 0);
		s3d.camera.screenRatio = designW / designH;
		s3d.camera.fovY = 44;
		var light = new h3d.scene.fwd.DirLight(new Vector(0.3, -0.8, 0.4), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null) amb.ambientLight.set(0.6, 0.6, 0.65);
	}

	public function start() {
		items = [];
		splashes = [];
		pieces = [];
		swipePoints = null;
		sceneObjects = [];
		spawnTimer = 0.6;
		started = false;
		score = 0;
		combo = 0;
		comboTextTimer = 0;
		misses = 0;
		gameOver = false;
		scoreText.text = "0";
		livesText.text = "♥♥♥";
		comboText.visible = false;
		if (s3d != null) setup3D();
		drawFruits();
		drawSlash();
		drawSplashes();
	}

	public function dispose() {
		for (item in items) if (item.mesh != null) { item.mesh.remove(); item.mesh = null; }
		items = [];
		for (p in pieces) if (p.mesh != null) { p.mesh.remove(); p.mesh = null; }
		pieces = [];
		for (o in sceneObjects) o.remove();
		sceneObjects = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		s3d = null;
		ctx = null;
		splashes = [];
	}

	public function getMinigameId(): String return "fruit-ninja";
	public function getTitle(): String return "Fruit Ninja";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started) {
			drawFruits();
			drawSlash();
			drawSplashes();
			return;
		}

		for (item in items) {
			item.vy += GRAVITY * dt;
			item.x += item.vx * dt;
			item.y += item.vy * dt;
			if (item.mesh != null) {
				// Eixos 3D: X = horizontal tela, Z = “vertical” tela (câmera vê XZ com Z para cima)
				item.mesh.setPosition(designTo3Dx(item.x), 0, designTo3Dz(item.y));
			}
		}

		var j = pieces.length - 1;
		while (j >= 0) {
			var p = pieces[j];
			p.vy += GRAVITY * dt;
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.life -= dt;
			if (p.mesh != null) {
				p.mesh.setPosition(designTo3Dx(p.x), 0, designTo3Dz(p.y));
				p.mesh.setScale(0.08 * Math.max(0.01, p.life / 0.7));
			}
			if (p.life <= 0 || p.y > designH + 50) {
				if (p.mesh != null) {
					p.mesh.remove();
					p.mesh = null;
				}
				pieces.splice(j, 1);
			}
			j--;
		}

		var i = items.length - 1;
		while (i >= 0) {
			if (items[i].y < -50 || items[i].y > designH + 80) {
				if (items[i].mesh != null) {
					items[i].mesh.remove();
					items[i].mesh = null;
				}
				if (!items[i].isBomb) {
					misses++;
					updateLivesText();
					if (ctx.feedback != null) {
						ctx.feedback.shake3D(0.1, 0.018, 12);
						ctx.feedback.flash(0xFF6644, 0.06);
					}
					if (misses >= MISS_LIMIT) {
						gameOver = true;
						ctx.lose(score, getMinigameId());
						ctx = null;
						return;
					}
				}
				items.splice(i, 1);
			}
			i--;
		}

		for (s in splashes) s.t += dt;
		while (splashes.length > 0 && splashes[0].t >= 0.25) splashes.shift();

		if (comboTextTimer > 0) {
			comboTextTimer -= dt;
			if (comboTextTimer <= 0) comboText.visible = false;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			spawnItem();
		}

		drawFruits();
		drawPieces();
		drawSlash();
		drawSplashes();
	}

	function updateLivesText() {
		var hearts = "";
		for (_ in 0...(MISS_LIMIT - misses)) hearts += "♥";
		livesText.text = hearts;
		if (hearts.length == 0) livesText.text = "♥";
	}
}

private typedef FruitItem = {
	var x: Float;
	var y: Float;
	var vx: Float;
	var vy: Float;
	var r: Float;
	var color: Int;
	var isBomb: Bool;
	@:optional var mesh: h3d.scene.Mesh;
}

private typedef CutPiece = {
	var x: Float;
	var y: Float;
	var vx: Float;
	var vy: Float;
	var life: Float;
	var color: Int;
	@:optional var mesh: h3d.scene.Mesh;
}
