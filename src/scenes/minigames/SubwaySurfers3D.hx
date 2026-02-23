package scenes.minigames;

import h2d.Object;
import h2d.Text;
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
	Subway Surfers em 3D: 3 faixas, swipe esq/dir para trocar, swipe cima = pular, swipe baixo = rolar.
	Obstáculos altos = pular; baixos = rolar. Bateu = perde.
**/
class SubwaySurfers3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var LANE_W = 1.05;
	static var SPEED = 14;
	static var SPAWN_INTERVAL = 1.1;
	static var JUMP_V0 = 8.5;
	static var GRAVITY = 28;
	static var ROLL_DURATION = 0.55;
	static var SWIPE_THRESHOLD = 45;
	static var FAST_FALL_VY = -22.0;
	static var PLAYER_BASE_Y = 0.25;

	var s3d: Scene;
	final contentObj: h2d.Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var scoreText: Text;
	var interactive: Interactive;
	var sceneObjects: Array<h3d.scene.Object>;
	var ground: Mesh;
	var player: Mesh;
	var obstacles: Array<{ mesh: Mesh, lane: Int, z: Float, high: Bool }>;
	var playerLane: Int;
	var playerY: Float;
	var playerVy: Float;
	var rollT: Float;
	var wantSlideOnLand: Bool;
	var spawnTimer: Float;
	var score: Int;
	var gameOver: Bool;
	var started: Bool;
	var touchStartX: Float;
	var touchStartY: Float;
	var savedCamPos: Vector;
	var savedCamTarget: Vector;
	var savedCamUp: Vector;

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
		savedCamUp = new Vector();

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 24;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			touchStartX = e.relX;
			touchStartY = e.relY;
			e.propagate = false;
		};
		interactive.onRelease = function(e: Event) {
			if (gameOver || ctx == null) return;
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			if (Math.abs(dx) > SWIPE_THRESHOLD && Math.abs(dx) >= Math.abs(dy)) {
				if (dx < 0 && playerLane > -1) playerLane--;
				else if (dx > 0 && playerLane < 1) playerLane++;
				e.propagate = false;
			} else if (dy < -SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (playerY <= 0.01) {
					playerVy = JUMP_V0;
					if (rollT > 0) rollT = 0;
				}
				e.propagate = false;
			} else if (dy > SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (playerY > 0.01) {
					// No ar: dash pro chão e agachar/slide ao pousar
					playerVy = FAST_FALL_VY;
					wantSlideOnLand = true;
				} else if (rollT <= 0) {
					// No chão: agachar / slide
					rollT = ROLL_DURATION;
				}
				e.propagate = false;
			}
		};
	}

	public function setScene3D(scene: Scene) {
		s3d = scene;
	}

	inline function laneToX(lane: Int): Float return lane * LANE_W;

	function buildPrim(): h3d.prim.Polygon {
		var p = new Cube(1, 1, 1, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function setup3D() {
		if (s3d == null) return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		if (s3d.camera.up != null) savedCamUp.load(s3d.camera.up);
		// Câmera atrás e baixa para o personagem ficar visível; olhando para a pista à frente
		s3d.camera.pos.set(0, 1.8, -9);
		s3d.camera.target.set(0, 0.4, 22);
		if (s3d.camera.up != null) s3d.camera.up.set(0, 1, 0);
		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.4, 0.6, -0.5), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null) amb.ambientLight.set(0.55, 0.55, 0.6);

		// Chão horizontal: centro da pista à frente da câmera (trilho em +Z)
		var floorPrim = new Cube(12, 0.25, 55, true);
		floorPrim.unindex();
		floorPrim.addNormals();
		ground = new Mesh(floorPrim, s3d);
		ground.material.color.setColor(0x3d3d3d);
		ground.material.shadows = false;
		ground.setPosition(0, -0.125, 12);
		sceneObjects.push(ground);

		var playerPrim = buildPrim();
		player = new Mesh(playerPrim, s3d);
		player.material.color.setColor(0xE74C3C);
		player.material.shadows = false;
		player.scale(0.5);
		sceneObjects.push(player);
	}

	function spawnObstacle() {
		if (s3d == null) return;
		var lane = Std.int(Math.random() * 3) - 1;
		var high = Math.random() > 0.5;
		var prim = buildPrim();
		var mesh = new Mesh(prim, s3d);
		mesh.material.color.setColor(high ? 0x3498DB : 0x7F8C8D);
		mesh.material.shadows = false;
		mesh.scaleX = 0.6;
		mesh.scaleZ = 0.8;
		if (high) mesh.scaleY = 1.2;
		else mesh.scaleY = 0.4;
		mesh.x = laneToX(lane);
		mesh.z = 35;
		sceneObjects.push(mesh);
		obstacles.push({ mesh: mesh, lane: lane, z: 35, high: high });
	}

	function hitTest(): Bool {
		var rolling = rollT > 0;
		var playerBottomY = PLAYER_BASE_Y + playerY - 0.25;
		for (o in obstacles) {
			if (o.z > 4 || o.z < -2) continue;
			if (o.lane != playerLane) continue;
			if (o.high && playerBottomY < 0.5) return true;
			if (!o.high && !rolling) return true;
		}
		return false;
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		playerLane = 0;
		playerY = 0;
		playerVy = 0;
		rollT = 0;
		wantSlideOnLand = false;
		spawnTimer = 0.6;
		score = 0;
		gameOver = false;
		started = false;
		obstacles = [];
		scoreText.text = "0";
		setup3D();
	}

	public function dispose() {
		for (o in sceneObjects) o.remove();
		sceneObjects = [];
		obstacles = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
			if (savedCamUp != null && s3d.camera.up != null) s3d.camera.up.load(savedCamUp);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId(): String return "subway-surfers-3d";
	public function getTitle(): String return "Subway Surfers";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (s3d == null || player == null) return;

		if (!started) return;

		playerVy -= GRAVITY * dt;
		playerY += playerVy * dt;
		if (playerY < 0) {
			if (wantSlideOnLand) {
				rollT = ROLL_DURATION;
				wantSlideOnLand = false;
			}
			playerY = 0;
			playerVy = 0;
		}
		if (rollT > 0) rollT -= dt;

		player.x = laneToX(playerLane);
		player.y = PLAYER_BASE_Y + playerY;
		var rollAngle = rollT > 0 ? -Math.PI / 2 * (1 - rollT / ROLL_DURATION) : 0;
		player.setRotation(rollAngle, 0, 0);

		for (o in obstacles) {
			o.z -= SPEED * dt;
			o.mesh.z = o.z;
			o.mesh.x = laneToX(o.lane);
		}
		var i = obstacles.length - 1;
		while (i >= 0) {
			if (obstacles[i].z < -3) {
				obstacles[i].mesh.remove();
				obstacles.splice(i, 1);
				score++;
				scoreText.text = Std.string(score);
			}
			i--;
		}

		if (hitTest()) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = SPAWN_INTERVAL;
			spawnObstacle();
		}
	}
}
