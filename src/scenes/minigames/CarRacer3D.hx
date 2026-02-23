package scenes.minigames;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;
import hxd.Event;
import h3d.scene.Scene;
import h3d.scene.Mesh;
import h3d.prim.Cube;
import h3d.Vector;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;
import core.IMinigame3D;

/**
	Corrida em 3D: arraste para steer (esquerda/direita). Estrada e carros em 3D; câmera atrás do carro.
**/
class CarRacer3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var ROAD_SPEED = 18.0;
	static var SPAWN_INTERVAL = 1.0;
	static var ROAD_HALF_W = 2.2;
	static var STEER_SENSITIVITY = 0.0024;
	static var STEER_SMOOTH = 7.0;
	static var HIT_MARGIN_Z = 0.8;
	static var CAR_HALF_W = 0.35;
	static var OBSTACLE_HALF_W = 0.4;
	static var EXPLOSION_DURATION = 0.5;

	var s3d: Scene;
	final contentObj: h2d.Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;
	var savedCamPos: Vector;
	var savedCamTarget: Vector;

	var scoreText: Text;
	var explosionG: Graphics;
	var interactive: Interactive;
	var sceneObjects: Array<h3d.scene.Object>;
	var road: Mesh;
	var playerCar: Mesh;
	var obstacles: Array<{ mesh: Mesh, x: Float, z: Float }>;

	var carX: Float;
	var targetCarX: Float;
	var spawnTimer: Float;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var exploding: Bool;
	var explosionT: Float;
	var lastDragX: Float;
	var dragging: Bool;

	public var content(get, never): h2d.Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new h2d.Object();
		contentObj.visible = false;
		sceneObjects = [];
		obstacles = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 54;
		scoreText.y = 18;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		explosionG = new Graphics(contentObj);
		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			lastDragX = e.relX;
			dragging = true;
			e.propagate = false;
		};
		interactive.onMove = function(e: Event) {
			if (!dragging || gameOver) return;
			var dx = e.relX - lastDragX;
			targetCarX += dx * STEER_SENSITIVITY;
			if (targetCarX < 0) targetCarX = 0;
			if (targetCarX > 1) targetCarX = 1;
			lastDragX = e.relX;
			e.propagate = false;
		};
		interactive.onRelease = function(_: Event) { dragging = false; };
	}

	public function setScene3D(scene: Scene) {
		s3d = scene;
	}

	function makeCube(): h3d.prim.Polygon {
		var p = new Cube(1, 1, 1, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function setup3D() {
		if (s3d == null) return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		s3d.camera.pos.set(0, 4, -10);
		s3d.camera.target.set(0, 0, 25);
		if (s3d.camera.up != null) s3d.camera.up.set(0, 1, 0);
		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.4, 0.6, -0.4), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null) amb.ambientLight.set(0.55, 0.55, 0.6);

		var roadPrim = new Cube(ROAD_HALF_W * 2.2, 0.15, 60, true);
		roadPrim.unindex();
		roadPrim.addNormals();
		road = new Mesh(roadPrim, s3d);
		road.material.color.setColor(0x34495e);
		road.material.shadows = false;
		road.setPosition(0, -0.075, 18);
		sceneObjects.push(road);

		playerCar = new Mesh(makeCube(), s3d);
		playerCar.material.color.setColor(0xE74C3C);
		playerCar.material.shadows = false;
		playerCar.scaleX = 0.5;
		playerCar.scaleY = 0.28;
		playerCar.scaleZ = 0.7;
		sceneObjects.push(playerCar);
	}

	function spawnObstacle() {
		if (s3d == null) return;
		var mesh = new Mesh(makeCube(), s3d);
		mesh.material.color.setColor(0x7F8C8D);
		mesh.material.shadows = false;
		mesh.scaleX = 0.45;
		mesh.scaleY = 0.25;
		mesh.scaleZ = 0.6;
		var x = -ROAD_HALF_W + 0.3 + Math.random() * (ROAD_HALF_W * 2 - 0.6);
		mesh.setPosition(x, 0, 40);
		sceneObjects.push(mesh);
		obstacles.push({ mesh: mesh, x: x, z: 40 });
	}

	function hitTest(): Bool {
		for (o in obstacles) {
			if (o.z < -HIT_MARGIN_Z || o.z > HIT_MARGIN_Z) continue;
			if (Math.abs(o.x - carX) < CAR_HALF_W + OBSTACLE_HALF_W)
				return true;
		}
		return false;
	}

	function drawExplosion2D() {
		explosionG.clear();
		if (explosionT <= 0 || explosionT >= EXPLOSION_DURATION) return;
		var t = explosionT / EXPLOSION_DURATION;
		var cx = designW / 2;
		var cy = designH * 0.82;
		var r = 20 + t * 50;
		var alpha = 1 - t * t;
		explosionG.beginFill(0xFF6600, alpha * 0.9);
		explosionG.drawCircle(cx, cy, r);
		explosionG.endFill();
		explosionG.beginFill(0xFFAA00, alpha * 0.5);
		explosionG.drawCircle(cx, cy, r * 0.6);
		explosionG.endFill();
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		targetCarX = 0.5;
		carX = (targetCarX - 0.5) * (ROAD_HALF_W * 2);
		spawnTimer = 0.4;
		started = false;
		gameOver = false;
		exploding = false;
		explosionT = -1;
		score = 0;
		scoreText.text = "0";
		for (o in obstacles) o.mesh.remove();
		obstacles = [];
		setup3D();
		if (playerCar != null) playerCar.setPosition(0, 0, 0);
	}

	public function dispose() {
		for (o in sceneObjects) o.remove();
		sceneObjects = [];
		obstacles = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId(): String return "car-racer-3d";
	public function getTitle(): String return "Corrida";

	public function update(dt: Float) {
		if (ctx == null) return;
		if (exploding) {
			explosionT += dt;
			drawExplosion2D();
			if (explosionT >= EXPLOSION_DURATION) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			return;
		}
		if (gameOver) return;
		if (!started || playerCar == null) return;

		var worldX = (targetCarX - 0.5) * (ROAD_HALF_W * 2);
		carX += (worldX - carX) * (1 - Math.exp(-STEER_SMOOTH * dt));
		playerCar.setPosition(carX, 0, 0);

		for (o in obstacles) {
			o.z -= ROAD_SPEED * dt;
			o.mesh.setPosition(o.x, 0, o.z);
		}

		var i = obstacles.length - 1;
		while (i >= 0) {
			if (obstacles[i].z < -6) {
				obstacles[i].mesh.remove();
				obstacles.splice(i, 1);
				score++;
				scoreText.text = Std.string(score);
			}
			i--;
		}

		if (hitTest()) {
			gameOver = true;
			exploding = true;
			explosionT = 0;
			if (ctx.feedback != null) {
				ctx.feedback.shake3D(0.5, 0.2, 14);
				ctx.feedback.flash(0xFF6600, 0.15);
			}
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			spawnObstacle();
		}
	}
}
