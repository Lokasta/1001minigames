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
	Pênalti em 3D: arraste na tela para mirar, solte para chutar.
	Goleiro escolhe L/C/R. Defendeu = perde. Gol = +1 e nova cobrança.
**/
class PenaltyShootout3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GOAL_WIDTH = 5.0;
	static var GOAL_HEIGHT = 2.0;
	static var BALL_START_Z = -14.0;
	static var BALL_SPEED = 22.0;
	static var KEEPER_DIVE_SPEED = 8.0;
	static var KEEPER_ZONE_W = 1.8;
	static var MIN_DRAG_SQ = 400.0;

	var s3d: Scene;
	final contentObj: h2d.Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var scoreText: Text;
	var aimG: h2d.Graphics;
	var interactive: Interactive;
	var sceneObjects: Array<h3d.scene.Object>;
	var ground: Mesh;
	var goalLeft: Mesh;
	var goalRight: Mesh;
	var goalBar: Mesh;
	var ball: Mesh;
	var keeper: Mesh;
	var savedCamPos: Vector;
	var savedCamTarget: Vector;

	var ballX: Float;
	var ballY: Float;
	var ballZ: Float;
	var ballVx: Float;
	var ballVy: Float;
	var ballVz: Float;
	var keeperX: Float;
	var keeperTargetX: Float;
	var aimStartX: Float;
	var aimStartY: Float;
	var aimEndX: Float;
	var aimEndY: Float;
	var state: PenaltyState3D;
	var started: Bool;
	var score: Int;
	var gameOver: Bool;
	var keeperZone: Int;

	public var content(get, never): h2d.Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new h2d.Object();
		contentObj.visible = false;
		sceneObjects = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 50;
		scoreText.y = 18;
		scoreText.scale(1.6);
		scoreText.textAlign = Right;

		aimG = new h2d.Graphics(contentObj);
		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e: Event) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			if (state != Idle3D) return;
			aimStartX = e.relX;
			aimStartY = e.relY;
			aimEndX = e.relX;
			aimEndY = e.relY;
			state = Aiming3D;
			e.propagate = false;
		};
		interactive.onMove = function(e: Event) {
			if (state != Aiming3D) return;
			aimEndX = e.relX;
			aimEndY = e.relY;
		};
		interactive.onRelease = function(e: Event) {
			if (state != Aiming3D) return;
			var dx = aimEndX - aimStartX;
			var dy = aimEndY - aimStartY;
			if (dx * dx + dy * dy < MIN_DRAG_SQ) {
				state = Idle3D;
				e.propagate = false;
				return;
			}
			launchShot();
			e.propagate = false;
		};
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
		s3d.camera.pos.set(0, 3.5, BALL_START_Z - 2);
		s3d.camera.target.set(0, 1, 0);
		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.3, 0.6, 0.4), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null) amb.ambientLight.set(0.6, 0.65, 0.6);

		// Gramado horizontal: largo em X, fino em Y, fundo em Z
		var floorPrim = new Cube(22, 0.3, 18, true);
		floorPrim.unindex();
		floorPrim.addNormals();
		ground = new Mesh(floorPrim, s3d);
		ground.material.color.setColor(0x2d7a2d);
		ground.material.shadows = false;
		ground.setPosition(0, -0.15, -6);
		sceneObjects.push(ground);

		var postW = 0.25;
		var postH = GOAL_HEIGHT + 0.3;
		var postD = 0.25;
		var leftPrim = new Cube(postW, postH, postD, true);
		leftPrim.unindex();
		leftPrim.addNormals();
		goalLeft = new Mesh(leftPrim, s3d);
		goalLeft.material.color.setColor(0xFFFFFF);
		goalLeft.material.shadows = false;
		goalLeft.setPosition(-GOAL_WIDTH / 2 - postW / 2, postH / 2 - 0.15, 0.05);
		sceneObjects.push(goalLeft);

		var rightPrim = new Cube(postW, postH, postD, true);
		rightPrim.unindex();
		rightPrim.addNormals();
		goalRight = new Mesh(rightPrim, s3d);
		goalRight.material.color.setColor(0xFFFFFF);
		goalRight.material.shadows = false;
		goalRight.setPosition(GOAL_WIDTH / 2 + postW / 2, postH / 2 - 0.15, 0.05);
		sceneObjects.push(goalRight);

		var barPrim = new Cube(GOAL_WIDTH + postW * 2 + 0.2, postW, postD, true);
		barPrim.unindex();
		barPrim.addNormals();
		goalBar = new Mesh(barPrim, s3d);
		goalBar.material.color.setColor(0xFFFFFF);
		goalBar.material.shadows = false;
		goalBar.setPosition(0, GOAL_HEIGHT + postW / 2, 0.05);
		sceneObjects.push(goalBar);

		var ballPrim = makeCube();
		ball = new Mesh(ballPrim, s3d);
		ball.material.color.setColor(0xFFFFFF);
		ball.material.shadows = false;
		ball.setScale(0.35);
		sceneObjects.push(ball);

		var keeperPrim = new Cube(1.0, 1.4, 0.5, true);
		keeperPrim.unindex();
		keeperPrim.addNormals();
		keeper = new Mesh(keeperPrim, s3d);
		keeper.material.color.setColor(0x1a5fb4);
		keeper.material.shadows = false;
		keeper.setScale(1.1);
		keeper.setPosition(0, 0.75, 0.2);
		sceneObjects.push(keeper);
	}

	function launchShot() {
		var targetX = (aimEndX / designW - 0.5) * (GOAL_WIDTH * 0.9);
		var targetY = 0.3 + (1 - aimEndY / designH) * (GOAL_HEIGHT * 0.85);
		targetX = targetX < -GOAL_WIDTH / 2 + 0.3 ? -GOAL_WIDTH / 2 + 0.3 : (targetX > GOAL_WIDTH / 2 - 0.3 ? GOAL_WIDTH / 2 - 0.3 : targetX);
		targetY = targetY < 0.2 ? 0.2 : (targetY > GOAL_HEIGHT - 0.2 ? GOAL_HEIGHT - 0.2 : targetY);

		keeperZone = Std.int(Math.random() * 3);
		keeperTargetX = (keeperZone - 1) * (GOAL_WIDTH / 2.2);

		ballX = 0;
		ballY = 0.25;
		ballZ = BALL_START_Z;
		var dx = targetX - ballX;
		var dy = targetY - ballY;
		var dz = 0 - ballZ;
		var len = Math.sqrt(dx * dx + dy * dy + dz * dz);
		if (len < 0.01) len = 0.01;
		ballVx = (dx / len) * BALL_SPEED;
		ballVy = (dy / len) * BALL_SPEED;
		ballVz = (dz / len) * BALL_SPEED;

		state = Shooting3D;
	}

	function drawAim() {
		aimG.clear();
		if (state != Aiming3D) return;
		aimG.lineStyle(4, 0xFFDD00, 0.9);
		aimG.moveTo(aimStartX, aimStartY);
		aimG.lineTo(aimEndX, aimEndY);
		aimG.lineStyle(0);
		aimG.beginFill(0xFFDD00, 0.6);
		aimG.drawCircle(aimEndX, aimEndY, 10);
		aimG.endFill();
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		ballX = 0;
		ballY = 0.25;
		ballZ = BALL_START_Z;
		keeperX = 0;
		keeperTargetX = 0;
		started = false;
		score = 0;
		gameOver = false;
		state = Idle3D;
		scoreText.text = "0";
		setup3D();
		if (ball != null) {
			ball.setPosition(ballX, ballY, ballZ);
			ball.setRotation(0, 0, 0);
		}
		if (keeper != null) keeper.setPosition(0, 0.75, 0.2);
		drawAim();
	}

	public function dispose() {
		for (o in sceneObjects) o.remove();
		sceneObjects = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId(): String return "penalty-shootout-3d";
	public function getTitle(): String return "Pênalti";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;
		if (!started || ball == null || keeper == null) {
			drawAim();
			return;
		}

		if (state == Shooting3D) {
			ballX += ballVx * dt;
			ballY += ballVy * dt;
			ballZ += ballVz * dt;
			ball.setPosition(ballX, ballY, ballZ);

			keeperX += (keeperTargetX - keeperX) * Math.min(1, KEEPER_DIVE_SPEED * dt);
			keeper.setPosition(keeperX, 0.75, 0.2);

			if (ballZ >= -0.3) {
				var inGoal = ballX >= -GOAL_WIDTH / 2 && ballX <= GOAL_WIDTH / 2 && ballY >= 0 && ballY <= GOAL_HEIGHT;
				var margin = 0.55;
				var ballInKeeperZone = inGoal && ballX >= keeperX - margin && ballX <= keeperX + margin;
				if (ballInKeeperZone) {
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				}
				if (inGoal) {
					score++;
					scoreText.text = Std.string(score);
				}
				state = Idle3D;
				ballX = 0;
				ballY = 0.25;
				ballZ = BALL_START_Z;
				ball.setPosition(ballX, ballY, ballZ);
				keeperX = 0;
				keeperTargetX = 0;
				keeper.setPosition(0, 0.75, 0.2);
			} else if (ballZ < BALL_START_Z - 2) {
				state = Idle3D;
				ballX = 0;
				ballY = 0.25;
				ballZ = BALL_START_Z;
				ball.setPosition(ballX, ballY, ballZ);
				keeperX = 0;
				keeperTargetX = 0;
				keeper.setPosition(0, 0.75, 0.2);
			}
		}

		drawAim();
	}
}

private enum PenaltyState3D {
	Idle3D;
	Aiming3D;
	Shooting3D;
}
