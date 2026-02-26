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
	static var ROAD_SPEED_START = 14.0;
	static var ROAD_SPEED_MAX = 28.0;
	static var SPEED_RAMP_TIME = 40.0;
	static var SPAWN_INTERVAL_START = 1.3;
	static var SPAWN_INTERVAL_MIN = 0.55;
	static var ROAD_HALF_W = 2.5;
	static var STEER_SENSITIVITY = 0.012;
	static var STEER_SMOOTH = 8.0;
	static var HIT_MARGIN_Z = 1.0;
	static var CAR_HALF_W = 0.45;
	static var OBSTACLE_HALF_W = 0.45;
	static var EXPLOSION_DURATION = 0.6;
	static var LANE_COUNT = 3;

	var s3d:Scene;
	final contentObj:h2d.Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;
	var savedCamPos:Vector;
	var savedCamTarget:Vector;

	var scoreText:Text;
	var instructText:Text;
	var speedText:Text;
	var explosionG:Graphics;
	var interactive:Interactive;
	var sceneObjects:Array<h3d.scene.Object>;
	var road:Mesh;
	var playerCar:Mesh;
	var playerRoof:Mesh;
	var grassLeft:Mesh;
	var grassRight:Mesh;
	var roadLineLeft:Mesh;
	var roadLineRight:Mesh;
	var dashLines:Array<Mesh>;
	var obstacles:Array<{mesh:Mesh, roof:Mesh, x:Float, z:Float, colorIdx:Int}>;

	var carX:Float;
	var targetCarX:Float;
	var spawnTimer:Float;
	var started:Bool;
	var score:Int;
	var gameOver:Bool;
	var exploding:Bool;
	var explosionT:Float;
	var lastDragX:Float;
	var dragging:Bool;
	var elapsedTime:Float;
	var dashOffset:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new h2d.Object();
		contentObj.visible = false;
		sceneObjects = [];
		obstacles = [];
		dashLines = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 54;
		scoreText.y = 18;
		scoreText.scale(1.5);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Arraste para desviar";
		instructText.x = designW / 2;
		instructText.y = 50;
		instructText.scale(1.2);
		instructText.textAlign = Center;
		instructText.textColor = 0xFFFFFF;
		instructText.visible = true;

		speedText = new Text(hxd.res.DefaultFont.get(), contentObj);
		speedText.text = "";
		speedText.x = 14;
		speedText.y = 18;
		speedText.scale(1.0);
		speedText.textAlign = Left;
		speedText.textColor = 0xAAFFAA;

		explosionG = new Graphics(contentObj);
		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			lastDragX = e.relX;
			dragging = true;
			e.propagate = false;
		};
		interactive.onMove = function(e:Event) {
			if (!dragging || gameOver)
				return;
			var dx = e.relX - lastDragX;
			targetCarX += dx * STEER_SENSITIVITY;
			if (targetCarX < -ROAD_HALF_W + CAR_HALF_W + 0.15)
				targetCarX = -ROAD_HALF_W + CAR_HALF_W + 0.15;
			if (targetCarX > ROAD_HALF_W - CAR_HALF_W - 0.15)
				targetCarX = ROAD_HALF_W - CAR_HALF_W - 0.15;
			lastDragX = e.relX;
			e.propagate = false;
		};
		interactive.onRelease = function(_:Event) {
			dragging = false;
		};
	}

	public function setScene3D(scene:Scene) {
		s3d = scene;
	}

	function makeCube():h3d.prim.Polygon {
		var p = new Cube(1, 1, 1, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function currentSpeed():Float {
		var t = if (elapsedTime > SPEED_RAMP_TIME) 1.0 else elapsedTime / SPEED_RAMP_TIME;
		return ROAD_SPEED_START + (ROAD_SPEED_MAX - ROAD_SPEED_START) * t;
	}

	function currentSpawnInterval():Float {
		var t = if (elapsedTime > SPEED_RAMP_TIME) 1.0 else elapsedTime / SPEED_RAMP_TIME;
		return SPAWN_INTERVAL_START + (SPAWN_INTERVAL_MIN - SPAWN_INTERVAL_START) * t;
	}

	function setup3D() {
		if (s3d == null)
			return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);

		s3d.camera.pos.set(0, 3.5, -5);
		s3d.camera.target.set(0, 0.5, 12);
		if (s3d.camera.up != null)
			s3d.camera.up.set(0, 1, 0);
		s3d.camera.fovY = 45;
		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.4, 0.8, 0.3), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null)
			amb.ambientLight.set(0.5, 0.5, 0.55);

		var roadPrim = new Cube(ROAD_HALF_W * 2 + 0.4, 0.12, 80, true);
		roadPrim.unindex();
		roadPrim.addNormals();
		road = new Mesh(roadPrim, s3d);
		road.material.color.setColor(0x333840);
		road.material.shadows = false;
		road.setPosition(0, -0.06, 30);
		sceneObjects.push(road);

		var grassW = 12.0;
		var grassPrim = new Cube(grassW, 0.1, 80, true);
		grassPrim.unindex();
		grassPrim.addNormals();
		grassLeft = new Mesh(grassPrim, s3d);
		grassLeft.material.color.setColor(0x2d7a2d);
		grassLeft.material.shadows = false;
		grassLeft.setPosition(-ROAD_HALF_W - grassW / 2 - 0.1, -0.08, 30);
		sceneObjects.push(grassLeft);

		grassRight = new Mesh(grassPrim, s3d);
		grassRight.material.color.setColor(0x2d7a2d);
		grassRight.material.shadows = false;
		grassRight.setPosition(ROAD_HALF_W + grassW / 2 + 0.1, -0.08, 30);
		sceneObjects.push(grassRight);

		var edgeW = 0.12;
		var edgePrim = new Cube(edgeW, 0.14, 80, true);
		edgePrim.unindex();
		edgePrim.addNormals();
		roadLineLeft = new Mesh(edgePrim, s3d);
		roadLineLeft.material.color.setColor(0xFFFFFF);
		roadLineLeft.material.shadows = false;
		roadLineLeft.setPosition(-ROAD_HALF_W, -0.01, 30);
		sceneObjects.push(roadLineLeft);

		roadLineRight = new Mesh(edgePrim, s3d);
		roadLineRight.material.color.setColor(0xFFFFFF);
		roadLineRight.material.shadows = false;
		roadLineRight.setPosition(ROAD_HALF_W, -0.01, 30);
		sceneObjects.push(roadLineRight);

		dashLines = [];
		var dashPrim = new Cube(0.08, 0.13, 1.2, true);
		dashPrim.unindex();
		dashPrim.addNormals();
		var dashSpacing = 3.5;
		var dashCount = 24;
		for (lane in 1...LANE_COUNT) {
			var laneX = -ROAD_HALF_W + lane * (ROAD_HALF_W * 2 / LANE_COUNT);
			for (i in 0...dashCount) {
				var d = new Mesh(dashPrim, s3d);
				d.material.color.setColor(0xDDDDDD);
				d.material.shadows = false;
				d.setPosition(laneX, -0.01, i * dashSpacing);
				sceneObjects.push(d);
				dashLines.push(d);
			}
		}

		playerCar = new Mesh(makeCube(), s3d);
		playerCar.material.color.setColor(0xE74C3C);
		playerCar.material.shadows = false;
		playerCar.scaleX = 0.9;
		playerCar.scaleY = 0.35;
		playerCar.scaleZ = 1.6;
		sceneObjects.push(playerCar);

		playerRoof = new Mesh(makeCube(), s3d);
		playerRoof.material.color.setColor(0xC0392B);
		playerRoof.material.shadows = false;
		playerRoof.scaleX = 0.7;
		playerRoof.scaleY = 0.25;
		playerRoof.scaleZ = 0.8;
		sceneObjects.push(playerRoof);
	}

	static var OBSTACLE_COLORS:Array<Int> = [0x2980B9, 0x27AE60, 0x8E44AD, 0xF39C12, 0x7F8C8D];

	function spawnObstacle() {
		if (s3d == null)
			return;

		var lane = Std.int(Math.random() * LANE_COUNT);
		var laneW = ROAD_HALF_W * 2 / LANE_COUNT;
		var x = -ROAD_HALF_W + laneW / 2 + lane * laneW;
		x += (Math.random() - 0.5) * (laneW * 0.3);

		var colorIdx = Std.int(Math.random() * OBSTACLE_COLORS.length);
		var color = OBSTACLE_COLORS[colorIdx];

		var mesh = new Mesh(makeCube(), s3d);
		mesh.material.color.setColor(color);
		mesh.material.shadows = false;
		mesh.scaleX = 0.85;
		mesh.scaleY = 0.32;
		mesh.scaleZ = 1.4;
		mesh.setPosition(x, 0, 50);
		sceneObjects.push(mesh);

		var roofMesh = new Mesh(makeCube(), s3d);
		roofMesh.material.color.setColor(Std.int(color * 0.8));
		roofMesh.material.shadows = false;
		roofMesh.scaleX = 0.65;
		roofMesh.scaleY = 0.22;
		roofMesh.scaleZ = 0.7;
		roofMesh.setPosition(x, 0.27, 50);
		sceneObjects.push(roofMesh);

		obstacles.push({mesh: mesh, roof: roofMesh, x: x, z: 50, colorIdx: colorIdx});
	}

	function hitTest():Bool {
		for (o in obstacles) {
			if (o.z < -HIT_MARGIN_Z || o.z > HIT_MARGIN_Z)
				continue;
			if (Math.abs(o.x - carX) < CAR_HALF_W + OBSTACLE_HALF_W)
				return true;
		}
		return false;
	}

	function drawExplosion2D() {
		explosionG.clear();
		if (explosionT <= 0 || explosionT >= EXPLOSION_DURATION)
			return;
		var t = explosionT / EXPLOSION_DURATION;
		var cx = designW / 2;
		var cy = designH * 0.7;
		var r = 30 + t * 80;
		var alpha = 1 - t * t;
		explosionG.beginFill(0xFF6600, alpha * 0.9);
		explosionG.drawCircle(cx, cy, r);
		explosionG.endFill();
		explosionG.beginFill(0xFFCC00, alpha * 0.6);
		explosionG.drawCircle(cx, cy, r * 0.5);
		explosionG.endFill();
		explosionG.beginFill(0xFFFFFF, alpha * 0.3);
		explosionG.drawCircle(cx, cy, r * 0.2);
		explosionG.endFill();
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		targetCarX = 0;
		carX = 0;
		spawnTimer = 0.8;
		started = false;
		gameOver = false;
		exploding = false;
		explosionT = -1;
		score = 0;
		elapsedTime = 0;
		dashOffset = 0;
		scoreText.text = "0";
		instructText.visible = true;
		speedText.text = "";
		for (o in obstacles) {
			o.mesh.remove();
			o.roof.remove();
		}
		obstacles = [];
		setup3D();
		if (playerCar != null) {
			playerCar.setPosition(0, 0.17, 2);
			playerRoof.setPosition(0, 0.45, 2.1);
		}
	}

	public function dispose() {
		for (o in sceneObjects)
			o.remove();
		sceneObjects = [];
		obstacles = [];
		dashLines = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId():String
		return "car-racer-3d";

	public function getTitle():String
		return "Corrida";

	public function update(dt:Float) {
		if (ctx == null)
			return;
		if (exploding) {
			explosionT += dt;
			drawExplosion2D();
			if (explosionT >= EXPLOSION_DURATION) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			return;
		}
		if (gameOver)
			return;
		if (!started || playerCar == null)
			return;

		elapsedTime += dt;
		var speed = currentSpeed();

		carX += (targetCarX - carX) * (1 - Math.exp(-STEER_SMOOTH * dt));
		playerCar.setPosition(carX, 0.17, 2);
		playerRoof.setPosition(carX, 0.45, 2.1);

		for (o in obstacles) {
			o.z -= speed * dt;
			o.mesh.setPosition(o.x, 0.16, o.z);
			o.roof.setPosition(o.x, 0.43, o.z + 0.1);
		}

		dashOffset += speed * dt;
		var dashSpacing = 3.5;
		var totalDashLen = dashSpacing * 24;
		dashOffset = dashOffset % dashSpacing;
		var dashIdx = 0;
		var dashCount = 24;
		for (lane in 1...LANE_COUNT) {
			var laneX = -ROAD_HALF_W + lane * (ROAD_HALF_W * 2 / LANE_COUNT);
			for (i in 0...dashCount) {
				if (dashIdx < dashLines.length) {
					var dz = i * dashSpacing - dashOffset;
					dashLines[dashIdx].setPosition(laneX, -0.01, dz);
					dashIdx++;
				}
			}
		}

		var i = obstacles.length - 1;
		while (i >= 0) {
			if (obstacles[i].z < -4) {
				obstacles[i].mesh.remove();
				obstacles[i].roof.remove();
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
				ctx.feedback.shake3D(0.5, 0.3, 14);
				ctx.feedback.flash(0xFF6600, 0.2);
			}
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = currentSpawnInterval();
			spawnObstacle();
		}

		var kmh = Std.int(speed * 8);
		speedText.text = Std.string(kmh) + " km/h";
	}
}
