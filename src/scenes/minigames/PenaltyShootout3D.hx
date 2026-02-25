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
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;
import core.IMinigame3D;

/**
	Pênalti em 3D: arraste na tela para mirar, solte para chutar.
	Swipe force = shot power. Swipe angle = curve/spin.
	After-touch: tilt finger after release to bend the ball mid-flight.
	Goleiro escolhe L/C/R. Defendeu = perde. Gol = +1 e nova cobrança.
**/
class PenaltyShootout3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GOAL_WIDTH = 5.0;
	static var GOAL_HEIGHT = 2.0;
	static var BALL_START_Z = -14.0;
	static var BALL_SPEED_MIN = 10.0;
	static var BALL_SPEED_MAX = 18.0;
	static var GRAVITY = -6.0;
	static var AFTERTOUCH_STRENGTH = 8.0;
	static var KEEPER_DIVE_SPEED = 8.0;
	static var MIN_DRAG_SQ = 400.0;
	static var BALL_SPIN_SPEED = 12.0;
	static var BALL_RADIUS = 0.18;
	static var BOUNCE_DAMPING = 0.6;
	static var POST_W = 0.25;
	static var RESULT_DURATION_GOAL = 1.4;
	static var RESULT_DURATION_SAVE = 1.6;
	static var RESULT_DURATION_MISS = 1.0;

	var s3d:Scene;
	final contentObj:h2d.Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var scoreText:Text;
	var resultText:Text;
	var instructText:Text;
	var powerG:h2d.Graphics;
	var aimG:h2d.Graphics;
	var interactive:Interactive;
	var sceneObjects:Array<h3d.scene.Object>;
	var ground:Mesh;
	var goalLeft:Mesh;
	var goalRight:Mesh;
	var goalBar:Mesh;
	var ball:Mesh;
	var keeper:Mesh;
	var savedCamPos:Vector;
	var savedCamTarget:Vector;

	var ballX:Float;
	var ballY:Float;
	var ballZ:Float;
	var ballVx:Float;
	var ballVy:Float;
	var ballVz:Float;
	var ballCurve:Float;
	var ballSpinAngle:Float;
	var shotPower:Float;
	var flightTime:Float;
	var keeperX:Float;
	var keeperTargetX:Float;
	var keeperDiveTimer:Float;
	var aimStartX:Float;
	var aimStartY:Float;
	var aimEndX:Float;
	var aimEndY:Float;
	var touchCurX:Float;
	var touchCurY:Float;
	var afterTouchStartX:Float;
	var afterTouchStartY:Float;
	var afterTouchActive:Bool;
	var touching:Bool;
	var state:PenaltyState3D;
	var started:Bool;
	var score:Int;
	var gameOver:Bool;
	var keeperZone:Int;
	var resultTimer:Float;
	var resultDuration:Float;
	var shotChecked:Bool;
	var lastGoal:Bool;
	var lastSaved:Bool;
	var camFollowT:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

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

		resultText = new Text(hxd.res.DefaultFont.get(), contentObj);
		resultText.text = "";
		resultText.x = designW / 2;
		resultText.y = designH * 0.35;
		resultText.scale(3.0);
		resultText.textAlign = Center;
		resultText.visible = false;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Arraste para chutar";
		instructText.x = designW / 2;
		instructText.y = designH - 60;
		instructText.scale(1.2);
		instructText.textAlign = Center;
		instructText.visible = false;

		powerG = new h2d.Graphics(contentObj);
		aimG = new h2d.Graphics(contentObj);
		interactive = new Interactive(designW, designH, contentObj);
		interactive.onPush = function(e:Event) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			if (state == Flying3D) {
				touching = true;
				afterTouchActive = true;
				afterTouchStartX = e.relX;
				afterTouchStartY = e.relY;
				touchCurX = e.relX;
				touchCurY = e.relY;
				e.propagate = false;
				return;
			}
			if (state != Idle3D)
				return;
			aimStartX = e.relX;
			aimStartY = e.relY;
			aimEndX = e.relX;
			aimEndY = e.relY;
			touching = true;
			touchCurX = e.relX;
			touchCurY = e.relY;
			state = Aiming3D;
			instructText.visible = false;
			e.propagate = false;
		};
		interactive.onMove = function(e:Event) {
			if (state == Aiming3D) {
				aimEndX = e.relX;
				aimEndY = e.relY;
			}
			if (touching) {
				touchCurX = e.relX;
				touchCurY = e.relY;
			}
		};
		interactive.onRelease = function(e:Event) {
			if (state == Aiming3D) {
				var dx = aimEndX - aimStartX;
				var dy = aimEndY - aimStartY;
				if (dx * dx + dy * dy < MIN_DRAG_SQ) {
					state = Idle3D;
					touching = false;
					instructText.visible = true;
					e.propagate = false;
					return;
				}
				launchShot();
				e.propagate = false;
			}
			touching = false;
		};
		interactive.onReleaseOutside = function(e:Event) {
			if (state == Aiming3D) {
				var dx = aimEndX - aimStartX;
				var dy = aimEndY - aimStartY;
				if (dx * dx + dy * dy >= MIN_DRAG_SQ) {
					launchShot();
				} else {
					state = Idle3D;
					instructText.visible = true;
				}
			}
			touching = false;
		};

		ballX = 0;
		ballY = 0.25;
		ballZ = BALL_START_Z;
		ballVx = 0;
		ballVy = 0;
		ballVz = 0;
		ballCurve = 0;
		ballSpinAngle = 0;
		shotPower = 0;
		flightTime = 0;
		keeperX = 0;
		keeperTargetX = 0;
		keeperDiveTimer = 0;
		touching = false;
		state = Idle3D;
		started = false;
		score = 0;
		gameOver = false;
		keeperZone = 0;
		resultTimer = 0;
		resultDuration = 0;
		lastGoal = false;
		lastSaved = false;
		camFollowT = 0;
	}

	public function setScene3D(scene:Scene) {
		s3d = scene;
	}

	function setupCamera() {
		if (s3d == null)
			return;
		s3d.camera.pos.set(0, 5, -20);
		s3d.camera.target.set(0, 1.0, -1);
		s3d.camera.fovY = 30;
	}

	function makeCube():h3d.prim.Polygon {
		var p = new Cube(1, 1, 1, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function setup3D() {
		if (s3d == null)
			return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		setupCamera();

		s3d.camera.screenRatio = designW / designH;

		var light = new h3d.scene.fwd.DirLight(new Vector(0.3, 0.6, 0.4), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null)
			amb.ambientLight.set(0.6, 0.65, 0.6);

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
		var swDx = aimEndX - aimStartX;
		var swDy = aimEndY - aimStartY;
		var swipeLen = Math.sqrt(swDx * swDx + swDy * swDy);

		var maxSwipe = 250.0;
		shotPower = Math.min(swipeLen / maxSwipe, 1.0);
		var speed = BALL_SPEED_MIN + (BALL_SPEED_MAX - BALL_SPEED_MIN) * shotPower;

		var targetX = (aimEndX / designW - 0.5) * (GOAL_WIDTH * 1.8);
		var targetY = 0.2 + (1 - aimEndY / designH) * (GOAL_HEIGHT * 1.6);

		ballCurve = 0;

		keeperZone = Std.int(Math.random() * 3);
		keeperTargetX = (keeperZone - 1) * (GOAL_WIDTH / 2.2);
		keeperDiveTimer = 0;

		ballX = 0;
		ballY = 0.25;
		ballZ = BALL_START_Z;
		flightTime = 0;
		ballSpinAngle = 0;
		shotChecked = false;
		camFollowT = 0;

		var dz = 0.0 - ballZ;
		var travelTime = Math.abs(dz) / speed;
		var baseVy = (targetY - ballY - 0.5 * GRAVITY * travelTime * travelTime) / travelTime;
		var arcBonus = (1.0 - shotPower * 0.5) * 1.2;

		ballVx = (targetX - ballX) / travelTime;
		ballVy = baseVy + arcBonus;
		ballVz = speed;

		instructText.visible = false;
		resultText.visible = false;
		state = Flying3D;
	}

	function clampF(v:Float, min:Float, max:Float):Float {
		return v < min ? min : (v > max ? max : v);
	}

	function checkCollisions() {
		var r = BALL_RADIUS;
		var hw = POST_W / 2 + r;
		var postH = GOAL_HEIGHT + 0.3;

		// Goal post Z range (posts are at z=0.05, depth POST_W)
		var postZMin = 0.05 - POST_W / 2 - r;
		var postZMax = 0.05 + POST_W / 2 + r;

		// Left post: center X = -GOAL_WIDTH/2 - POST_W/2, Y from 0 to postH
		var leftPostX = -GOAL_WIDTH / 2 - POST_W / 2;
		if (ballZ >= postZMin && ballZ <= postZMax && ballY >= -r && ballY <= postH + r) {
			if (Math.abs(ballX - leftPostX) < hw) {
				ballVx = Math.abs(ballVx) * BOUNCE_DAMPING;
				ballVz = -Math.abs(ballVz) * BOUNCE_DAMPING;
				ballX = leftPostX + hw;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.1, 2);
			}
		}

		// Right post: center X = GOAL_WIDTH/2 + POST_W/2
		var rightPostX = GOAL_WIDTH / 2 + POST_W / 2;
		if (ballZ >= postZMin && ballZ <= postZMax && ballY >= -r && ballY <= postH + r) {
			if (Math.abs(ballX - rightPostX) < hw) {
				ballVx = -Math.abs(ballVx) * BOUNCE_DAMPING;
				ballVz = -Math.abs(ballVz) * BOUNCE_DAMPING;
				ballX = rightPostX - hw;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.1, 2);
			}
		}

		// Crossbar: center Y = GOAL_HEIGHT + POST_W/2, spans full goal width
		var barY = GOAL_HEIGHT + POST_W / 2;
		var barHalfW = (GOAL_WIDTH + POST_W * 2 + 0.2) / 2 + r;
		if (ballZ >= postZMin && ballZ <= postZMax && Math.abs(ballX) < barHalfW) {
			if (Math.abs(ballY - barY) < hw) {
				ballVy = -Math.abs(ballVy) * BOUNCE_DAMPING;
				ballVz = -Math.abs(ballVz) * BOUNCE_DAMPING;
				ballY = barY - hw;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.1, 2);
			}
		}

		// Keeper: position (keeperX, 0.75, 0.2), base size (1.0, 1.4, 0.5) * scale 1.1
		var kHalfW = 0.55 + r;
		var kHalfH = 0.77 + r;
		var kHalfD = 0.275 + r;
		var kCenterY = 0.75;
		var kCenterZ = 0.2;
		if (Math.abs(ballX - keeperX) < kHalfW && Math.abs(ballY - kCenterY) < kHalfH && Math.abs(ballZ - kCenterZ) < kHalfD) {
			// Bounce back and sideways
			ballVz = -Math.abs(ballVz) * BOUNCE_DAMPING;
			ballVx += (ballX - keeperX) * 3.0;
			ballVy = Math.abs(ballVy) * 0.3 + 2.0;
			ballZ = kCenterZ - kHalfD;
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.15, 3);
		}
	}

	function resetBall() {
		afterTouchActive = false;
		touching = false;
		ballX = 0;
		ballY = 0.25;
		ballZ = BALL_START_Z;
		ballVx = 0;
		ballVy = 0;
		ballVz = 0;
		ballCurve = 0;
		ballSpinAngle = 0;
		flightTime = 0;
		camFollowT = 0;
		if (ball != null)
			ball.setPosition(ballX, ballY, ballZ);
		keeperX = 0;
		keeperTargetX = 0;
		keeperDiveTimer = 0;
		if (keeper != null)
			keeper.setPosition(0, 0.75, 0.2);
		setupCamera();
		instructText.visible = true;
	}

	function drawAim() {
		aimG.clear();

		if (state == Aiming3D) {
			var swDx = aimEndX - aimStartX;
			var swDy = aimEndY - aimStartY;
			var swipeLen = Math.sqrt(swDx * swDx + swDy * swDy);

			// Draw swipe line with thickness based on power
			var thickness = 2 + (swipeLen / 300.0) * 4;
			aimG.lineStyle(thickness, 0xFFDD00, 0.9);
			aimG.moveTo(aimStartX, aimStartY);
			aimG.lineTo(aimEndX, aimEndY);
			aimG.lineStyle(0);

			// Draw target reticle
			aimG.beginFill(0xFFDD00, 0.6);
			aimG.drawCircle(aimEndX, aimEndY, 10);
			aimG.endFill();
		}

		// After-touch visual: show drag direction while ball is flying
		if (state == Flying3D && touching && afterTouchActive) {
			var adx = touchCurX - afterTouchStartX;
			var ady = touchCurY - afterTouchStartY;
			var adist = Math.sqrt(adx * adx + ady * ady);

			// Glowing circle at touch point
			aimG.beginFill(0x00CCFF, 0.25);
			aimG.drawCircle(afterTouchStartX, afterTouchStartY, 35);
			aimG.endFill();

			// Direction arrow showing force
			if (adist > 5) {
				var clampDist = Math.min(adist, 60.0);
				var nx = adx / adist * clampDist;
				var ny = ady / adist * clampDist;
				// Arrow line
				aimG.lineStyle(3, 0x00CCFF, 0.7);
				aimG.moveTo(afterTouchStartX, afterTouchStartY);
				aimG.lineTo(afterTouchStartX + nx, afterTouchStartY + ny);
				aimG.lineStyle(0);
				// Arrow tip
				aimG.beginFill(0x00CCFF, 0.7);
				aimG.drawCircle(afterTouchStartX + nx, afterTouchStartY + ny, 5);
				aimG.endFill();
			}
		}
	}

	function drawPowerBar() {
		powerG.clear();
		if (state != Aiming3D)
			return;

		var swDx = aimEndX - aimStartX;
		var swDy = aimEndY - aimStartY;
		var swipeLen = Math.sqrt(swDx * swDx + swDy * swDy);
		var power = Math.min(swipeLen / 300.0, 1.0);

		// Power bar at bottom
		var barW = 120.0;
		var barH = 8.0;
		var barX = designW / 2 - barW / 2;
		var barY = designH - 40.0;

		// Background
		powerG.beginFill(0x333333, 0.6);
		powerG.drawRect(barX, barY, barW, barH);
		powerG.endFill();

		// Fill with gradient green -> yellow -> red
		var color = if (power < 0.5) 0x44FF44 else if (power < 0.8) 0xFFDD00 else 0xFF4444;
		powerG.beginFill(color, 0.8);
		powerG.drawRect(barX, barY, barW * power, barH);
		powerG.endFill();
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		started = false;
		score = 0;
		gameOver = false;
		state = Idle3D;
		touching = false;
		resultTimer = 0;
		resultDuration = 0;
		lastGoal = false;
		lastSaved = false;
		camFollowT = 0;
		scoreText.text = "0";
		resultText.visible = false;
		instructText.visible = true;
		setup3D();
		setupCamera();
		resetBall();
		drawAim();
		powerG.clear();
	}

	public function dispose() {
		for (o in sceneObjects)
			o.remove();
		sceneObjects = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		ctx = null;
		s3d = null;
	}

	public function getMinigameId():String
		return "penalty-shootout-3d";

	public function getTitle():String
		return "Pênalti";

	function showResult(text:String, color:Int) {
		resultText.text = text;
		resultText.color = h3d.Vector4.fromColor(color);
		resultText.visible = true;
	}

	function updateCameraFollow(dt:Float) {
		if (s3d == null)
			return;
		camFollowT += dt;
		var progress = clampF(camFollowT / 1.2, 0, 1);
		var ease = progress * progress * (3 - 2 * progress);
		var followZ = -20.0 + ease * 6.0;
		var followY = 5.0 - ease * 1.5;
		s3d.camera.pos.set(0, followY, followZ);
		s3d.camera.target.set(0, 1.0 + ease * 0.3, -1);
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started || ball == null || keeper == null) {
			drawAim();
			return;
		}

		if (state == Result3D) {
			resultTimer += dt;
			var alpha = 1.0;
			if (resultTimer > resultDuration - 0.3)
				alpha = clampF((resultDuration - resultTimer) / 0.3, 0, 1);
			resultText.alpha = alpha;

			if (resultTimer >= resultDuration) {
				resultText.visible = false;
				if (lastSaved) {
					gameOver = true;
					ctx.lose(score, getMinigameId());
					ctx = null;
					return;
				}
				state = Idle3D;
				resetBall();
			}
			return;
		}

		if (state == Flying3D) {
			flightTime += dt;

			if (touching && afterTouchActive) {
				var afterDx = (touchCurX - afterTouchStartX) / designW;
				var afterDy = (touchCurY - afterTouchStartY) / designH;
				ballVx += afterDx * AFTERTOUCH_STRENGTH * dt;
				ballVy -= afterDy * AFTERTOUCH_STRENGTH * 0.5 * dt;
			}

			ballVy += GRAVITY * dt;

			ballX += ballVx * dt;
			ballY += ballVy * dt;
			ballZ += ballVz * dt;

			if (ballZ < 0 && ballY < 0.2) {
				ballY = 0.2;
				ballVy = Math.abs(ballVy) * 0.3;
			}

			checkCollisions();

			ball.setPosition(ballX, ballY, ballZ);

			updateCameraFollow(dt);

			keeperDiveTimer += dt;
			var diveDelay = 0.15 + (1 - shotPower) * 0.2;
			if (keeperDiveTimer > diveDelay) {
				keeperX += (keeperTargetX - keeperX) * Math.min(1, KEEPER_DIVE_SPEED * dt);
				keeper.setPosition(keeperX, 0.75, 0.2);
			}

			if (!shotChecked && ballZ >= -0.3) {
				shotChecked = true;
				var inGoal = ballX >= -GOAL_WIDTH / 2 && ballX <= GOAL_WIDTH / 2 && ballY >= 0 && ballY <= GOAL_HEIGHT;
				var margin = 0.55;
				var saved = inGoal && ballX >= keeperX - margin && ballX <= keeperX + margin;

				if (saved) {
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.3, 5);
					lastSaved = true;
					lastGoal = false;
					showResult("DEFENDEU!", 0xFF4444);
					resultTimer = 0;
					resultDuration = RESULT_DURATION_SAVE;
					state = Result3D;
					return;
				}

				if (inGoal) {
					score++;
					scoreText.text = Std.string(score);
					lastGoal = true;
					lastSaved = false;
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.15, 3);
					showResult("GOL!", 0x44FF44);
					resultTimer = 0;
					resultDuration = RESULT_DURATION_GOAL;
					state = Result3D;
					return;
				} else {
					lastGoal = false;
					lastSaved = false;
					showResult("FORA!", 0xFFDD00);
					resultTimer = 0;
					resultDuration = RESULT_DURATION_MISS;
					state = Result3D;
					return;
				}
			}

			if (ballZ > 20 || ballY < -5 || flightTime > 3.0) {
				lastGoal = false;
				lastSaved = false;
				showResult("FORA!", 0xFFDD00);
				resultTimer = 0;
				resultDuration = RESULT_DURATION_MISS;
				state = Result3D;
			}
		}

		drawAim();
		drawPowerBar();
	}
}

private enum PenaltyState3D {
	Idle3D;
	Aiming3D;
	Flying3D;
	Result3D;
}
