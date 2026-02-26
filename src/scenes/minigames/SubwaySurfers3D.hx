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
	Subway Surfers em 3D: 3 faixas, swipe esq/dir para trocar, swipe cima = pular, swipe baixo = rolar.
	Obstáculos altos = pular; baixos = rolar. Bateu = perde.
**/
class SubwaySurfers3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var LANE_W = 1.4;
	static var SPEED_START = 12.0;
	static var SPEED_MAX = 24.0;
	static var SPEED_RAMP = 50.0;
	static var SPAWN_INTERVAL_START = 1.3;
	static var SPAWN_INTERVAL_MIN = 0.6;
	static var JUMP_V0 = 10.0;
	static var GRAVITY = 24.0;
	static var ROLL_DURATION = 0.55;
	static var SWIPE_THRESHOLD = 35;
	static var FAST_FALL_VY = -22.0;
	static var PLAYER_BASE_Y = 0.0;
	static var PLAYER_Z = 2.0;
	static var LANE_SWITCH_SPEED = 12.0;

	var s3d:Scene;
	final contentObj:h2d.Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var scoreText:Text;
	var instructText:Text;
	var crashG:Graphics;
	var interactive:Interactive;
	var sceneObjects:Array<h3d.scene.Object>;
	var ground:Mesh;
	var wallLeft:Mesh;
	var wallRight:Mesh;
	var playerBody:Mesh;
	var playerHead:Mesh;
	var playerLegs:Mesh;
	var laneLines:Array<Mesh>;
	var sleepers:Array<Mesh>;
	var obstacles:Array<{mesh:Mesh, topMesh:Mesh, lane:Int, z:Float, high:Bool}>;

	var playerLane:Int;
	var playerVisualX:Float;
	var playerY:Float;
	var playerVy:Float;
	var rollT:Float;
	var wantSlideOnLand:Bool;
	var spawnTimer:Float;
	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var elapsedTime:Float;
	var sleeperOffset:Float;
	var crashTimer:Float;
	var touchStartX:Float;
	var touchStartY:Float;
	var savedCamPos:Vector;
	var savedCamTarget:Vector;
	var savedCamUp:Vector;

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
		laneLines = [];
		sleepers = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();
		savedCamUp = new Vector();

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 18;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Deslize para desviar";
		instructText.x = designW / 2;
		instructText.y = 50;
		instructText.scale(1.2);
		instructText.textAlign = Center;
		instructText.textColor = 0xFFFFFF;
		instructText.visible = true;

		crashG = new Graphics(contentObj);

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			if (!started) {
				started = true;
				instructText.visible = false;
			}
			touchStartX = e.relX;
			touchStartY = e.relY;
			e.propagate = false;
		};
		interactive.onRelease = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			if (Math.abs(dx) > SWIPE_THRESHOLD && Math.abs(dx) >= Math.abs(dy)) {
				if (dx < 0 && playerLane > -1)
					playerLane--;
				else if (dx > 0 && playerLane < 1)
					playerLane++;
				e.propagate = false;
			} else if (dy < -SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (playerY <= 0.01) {
					playerVy = JUMP_V0;
					if (rollT > 0)
						rollT = 0;
				}
				e.propagate = false;
			} else if (dy > SWIPE_THRESHOLD && Math.abs(dy) >= Math.abs(dx)) {
				if (playerY > 0.01) {
					playerVy = FAST_FALL_VY;
					wantSlideOnLand = true;
				} else if (rollT <= 0) {
					rollT = ROLL_DURATION;
				}
				e.propagate = false;
			}
		};
	}

	public function setScene3D(scene:Scene) {
		s3d = scene;
	}

	inline function laneToX(lane:Int):Float
		return lane * LANE_W;

	function buildPrim():h3d.prim.Polygon {
		var p = new Cube(1, 1, 1, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function currentSpeed():Float {
		var t = if (elapsedTime > SPEED_RAMP) 1.0 else elapsedTime / SPEED_RAMP;
		return SPEED_START + (SPEED_MAX - SPEED_START) * t;
	}

	function currentSpawnInterval():Float {
		var t = if (elapsedTime > SPEED_RAMP) 1.0 else elapsedTime / SPEED_RAMP;
		return SPAWN_INTERVAL_START + (SPAWN_INTERVAL_MIN - SPAWN_INTERVAL_START) * t;
	}

	function setup3D() {
		if (s3d == null)
			return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		if (s3d.camera.up != null)
			savedCamUp.load(s3d.camera.up);

		s3d.camera.pos.set(0, 3.0, -4);
		s3d.camera.target.set(0, 0.8, 14);
		if (s3d.camera.up != null)
			s3d.camera.up.set(0, 1, 0);
		s3d.camera.fovY = 50;
		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.3, 0.8, 0.3), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null)
			amb.ambientLight.set(0.5, 0.5, 0.55);

		var trackW = LANE_W * 3 + 1.0;
		var floorPrim = new Cube(trackW, 0.15, 60, true);
		floorPrim.unindex();
		floorPrim.addNormals();
		ground = new Mesh(floorPrim, s3d);
		ground.material.color.setColor(0x4a4a4a);
		ground.material.shadows = false;
		ground.setPosition(0, -0.075, 22);
		sceneObjects.push(ground);

		var wallH = 2.5;
		var wallD = 60.0;
		var wallPrim = new Cube(0.3, wallH, wallD, true);
		wallPrim.unindex();
		wallPrim.addNormals();

		var wallOffset = trackW / 2 + 0.15;
		wallLeft = new Mesh(wallPrim, s3d);
		wallLeft.material.color.setColor(0x8B4513);
		wallLeft.material.shadows = false;
		wallLeft.setPosition(-wallOffset, wallH / 2, 22);
		sceneObjects.push(wallLeft);

		wallRight = new Mesh(wallPrim, s3d);
		wallRight.material.color.setColor(0x8B4513);
		wallRight.material.shadows = false;
		wallRight.setPosition(wallOffset, wallH / 2, 22);
		sceneObjects.push(wallRight);

		laneLines = [];
		var linePrim = new Cube(0.06, 0.16, 60, true);
		linePrim.unindex();
		linePrim.addNormals();
		for (i in 0...4) {
			var lx = -LANE_W * 1.5 + i * LANE_W;
			var line = new Mesh(linePrim, s3d);
			line.material.color.setColor(0xCCCC00);
			line.material.shadows = false;
			line.setPosition(lx, 0.01, 22);
			sceneObjects.push(line);
			laneLines.push(line);
		}

		sleepers = [];
		var sleeperPrim = new Cube(trackW - 0.2, 0.12, 0.2, true);
		sleeperPrim.unindex();
		sleeperPrim.addNormals();
		var sleeperSpacing = 2.0;
		for (i in 0...32) {
			var sl = new Mesh(sleeperPrim, s3d);
			sl.material.color.setColor(0x5C4033);
			sl.material.shadows = false;
			sl.setPosition(0, -0.01, i * sleeperSpacing);
			sceneObjects.push(sl);
			sleepers.push(sl);
		}

		playerBody = new Mesh(buildPrim(), s3d);
		playerBody.material.color.setColor(0x2ECC71);
		playerBody.material.shadows = false;
		playerBody.scaleX = 0.5;
		playerBody.scaleY = 0.7;
		playerBody.scaleZ = 0.4;
		sceneObjects.push(playerBody);

		playerHead = new Mesh(buildPrim(), s3d);
		playerHead.material.color.setColor(0xFFDBAC);
		playerHead.material.shadows = false;
		playerHead.scaleX = 0.35;
		playerHead.scaleY = 0.35;
		playerHead.scaleZ = 0.35;
		sceneObjects.push(playerHead);

		playerLegs = new Mesh(buildPrim(), s3d);
		playerLegs.material.color.setColor(0x2980B9);
		playerLegs.material.shadows = false;
		playerLegs.scaleX = 0.45;
		playerLegs.scaleY = 0.45;
		playerLegs.scaleZ = 0.35;
		sceneObjects.push(playerLegs);
	}

	function spawnObstacle() {
		if (s3d == null)
			return;
		var lane = Std.int(Math.random() * 3) - 1;
		var high = Math.random() > 0.45;

		var mesh = new Mesh(buildPrim(), s3d);
		mesh.material.shadows = false;
		var topMesh:Mesh = null;

		if (high) {
			mesh.material.color.setColor(0xE74C3C);
			mesh.scaleX = 1.1;
			mesh.scaleY = 1.5;
			mesh.scaleZ = 0.6;
			mesh.setPosition(laneToX(lane), 0.75, 45);

			topMesh = new Mesh(buildPrim(), s3d);
			topMesh.material.color.setColor(0xC0392B);
			topMesh.material.shadows = false;
			topMesh.scaleX = 1.2;
			topMesh.scaleY = 0.15;
			topMesh.scaleZ = 0.7;
			topMesh.setPosition(laneToX(lane), 1.57, 45);
			sceneObjects.push(topMesh);
		} else {
			mesh.material.color.setColor(0xF39C12);
			mesh.scaleX = 1.0;
			mesh.scaleY = 0.35;
			mesh.scaleZ = 0.8;
			mesh.setPosition(laneToX(lane), 0.17, 45);
		}

		sceneObjects.push(mesh);
		obstacles.push({mesh: mesh, topMesh: topMesh, lane: lane, z: 45, high: high});
	}

	function hitTest():Bool {
		var rolling = rollT > 0;
		var pY = PLAYER_BASE_Y + playerY;
		for (o in obstacles) {
			var relZ = o.z - PLAYER_Z;
			if (relZ > 0.8 || relZ < -0.8)
				continue;
			if (o.lane != playerLane)
				continue;
			if (o.high) {
				if (pY < 0.8)
					return true;
			} else {
				if (!rolling && pY < 0.4)
					return true;
			}
		}
		return false;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		playerLane = 0;
		playerVisualX = 0;
		playerY = 0;
		playerVy = 0;
		rollT = 0;
		wantSlideOnLand = false;
		spawnTimer = 0.8;
		score = 0;
		gameOver = false;
		started = false;
		elapsedTime = 0;
		sleeperOffset = 0;
		crashTimer = -1;
		for (o in obstacles) {
			o.mesh.remove();
			if (o.topMesh != null)
				o.topMesh.remove();
		}
		obstacles = [];
		scoreText.text = "0";
		instructText.visible = true;
		crashG.clear();
		setup3D();
	}

	public function dispose() {
		for (o in sceneObjects)
			o.remove();
		sceneObjects = [];
		obstacles = [];
		laneLines = [];
		sleepers = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
			if (savedCamUp != null && s3d.camera.up != null)
				s3d.camera.up.load(savedCamUp);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId():String
		return "subway-surfers-3d";

	public function getTitle():String
		return "Subway Surfers";

	public function update(dt:Float) {
		if (ctx == null)
			return;
		if (gameOver) {
			if (crashTimer >= 0) {
				crashTimer += dt;
				var t = crashTimer / 0.5;
				if (t < 1) {
					var alpha = (1 - t) * 0.6;
					crashG.clear();
					crashG.beginFill(0xFF3300, alpha);
					crashG.drawRect(0, 0, designW, designH);
					crashG.endFill();
				} else {
					crashG.clear();
					ctx.lose(score, getMinigameId());
					ctx = null;
				}
			}
			return;
		}
		if (s3d == null || playerBody == null)
			return;
		if (!started)
			return;

		elapsedTime += dt;
		var speed = currentSpeed();

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
		if (rollT > 0)
			rollT -= dt;

		var targetX = laneToX(playerLane);
		playerVisualX += (targetX - playerVisualX) * (1 - Math.exp(-LANE_SWITCH_SPEED * dt));

		var pY = PLAYER_BASE_Y + playerY;
		var rolling = rollT > 0;

		if (rolling) {
			playerBody.setPosition(playerVisualX, pY + 0.2, PLAYER_Z);
			playerBody.scaleY = 0.25;
			playerHead.setPosition(playerVisualX, pY + 0.35, PLAYER_Z + 0.25);
			playerHead.scaleY = 0.2;
			playerLegs.setPosition(playerVisualX, pY + 0.12, PLAYER_Z - 0.15);
			playerLegs.scaleY = 0.15;
		} else {
			playerBody.setPosition(playerVisualX, pY + 0.7, PLAYER_Z);
			playerBody.scaleY = 0.7;
			playerHead.setPosition(playerVisualX, pY + 1.22, PLAYER_Z);
			playerHead.scaleY = 0.35;
			playerLegs.setPosition(playerVisualX, pY + 0.22, PLAYER_Z);
			playerLegs.scaleY = 0.45;
		}

		for (o in obstacles) {
			o.z -= speed * dt;
			o.mesh.setPosition(laneToX(o.lane), o.mesh.y, o.z);
			if (o.topMesh != null)
				o.topMesh.setPosition(laneToX(o.lane), o.topMesh.y, o.z);
		}

		sleeperOffset += speed * dt;
		var sleeperSpacing = 2.0;
		sleeperOffset = sleeperOffset % sleeperSpacing;
		for (i in 0...sleepers.length) {
			var sz = i * sleeperSpacing - sleeperOffset;
			sleepers[i].setPosition(0, -0.01, sz);
		}

		var i = obstacles.length - 1;
		while (i >= 0) {
			if (obstacles[i].z < -3) {
				obstacles[i].mesh.remove();
				if (obstacles[i].topMesh != null)
					obstacles[i].topMesh.remove();
				obstacles.splice(i, 1);
				score++;
				scoreText.text = Std.string(score);
			}
			i--;
		}

		if (hitTest()) {
			gameOver = true;
			crashTimer = 0;
			if (ctx != null && ctx.feedback != null) {
				ctx.feedback.shake3D(0.4, 0.3, 14);
				ctx.feedback.flash(0xFFFFFF, 0.1);
			}
			return;
		}

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = currentSpawnInterval();
			spawnObstacle();
		}
	}
}
