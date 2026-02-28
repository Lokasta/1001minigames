package scenes.minigames;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;
import hxd.Event;
import h3d.scene.Scene;
import h3d.scene.Mesh;
import h3d.prim.Cube;
import h3d.prim.Sphere;
import h3d.Vector;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;
import core.IMinigame3D;

/**
	Penalti em 3D: arraste na tela para mirar, solte para chutar.
	Swipe force = shot power. Swipe angle = curve/spin.
	After-touch: tilt finger after release to bend the ball mid-flight.
	Goleiro escolhe L/C/R. Defendeu = perde. Gol = +1 e nova cobranca.
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
	static var POST_W = 0.15;
	static var POST_DEPTH = 0.15;
	static var RESULT_DURATION_GOAL = 1.4;
	static var RESULT_DURATION_SAVE = 1.6;
	static var RESULT_DURATION_MISS = 1.0;
	static var GOAL_DEPTH = 1.8;

	var s3d:Scene;
	final contentObj:h2d.Object;
	var ctx:MinigameContext;
	var designW:Int;
	var designH:Int;

	var scoreText:Text;
	var scoreLabelText:Text;
	var resultText:Text;
	var resultSubText:Text;
	var instructText:Text;
	var powerG:h2d.Graphics;
	var aimG:h2d.Graphics;
	var hudBg:h2d.Graphics;
	var interactive:Interactive;
	var sceneObjects:Array<h3d.scene.Object>;
	var ground:Mesh;
	var goalLeft:Mesh;
	var goalRight:Mesh;
	var goalBar:Mesh;
	var ball:Mesh;
	var ballShadow:Mesh;
	var savedCamPos:Vector;
	var savedCamTarget:Vector;

	// Keeper body parts
	var keeperHead:Mesh;
	var keeperTorso:Mesh;
	var keeperArmL:Mesh;
	var keeperArmR:Mesh;
	var keeperLegL:Mesh;
	var keeperLegR:Mesh;
	var keeperParts:Array<Mesh>;

	// Net meshes
	var netMeshes:Array<Mesh>;

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
	var keeperDiveAngle:Float;
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
	var failures:Int;
	static var MAX_FAILURES = 3;

	// Result animation
	var resultScale:Float;
	var resultBounce:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new h2d.Object();
		contentObj.visible = false;
		sceneObjects = [];
		netMeshes = [];
		keeperParts = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		// HUD background strip
		hudBg = new h2d.Graphics(contentObj);

		// Score display
		scoreLabelText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreLabelText.text = "GOLS";
		scoreLabelText.x = designW - 14;
		scoreLabelText.y = 10;
		scoreLabelText.scale(0.9);
		scoreLabelText.textAlign = Right;
		scoreLabelText.textColor = 0xAADDAA;

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW - 14;
		scoreText.y = 22;
		scoreText.scale(2.2);
		scoreText.textAlign = Right;

		// Failures indicator
		resultText = new Text(hxd.res.DefaultFont.get(), contentObj);
		resultText.text = "";
		resultText.x = designW / 2;
		resultText.y = 70;
		resultText.scale(3.5);
		resultText.textAlign = Center;
		resultText.visible = false;

		resultSubText = new Text(hxd.res.DefaultFont.get(), contentObj);
		resultSubText.text = "";
		resultSubText.x = designW / 2;
		resultSubText.y = 110;
		resultSubText.scale(1.2);
		resultSubText.textAlign = Center;
		resultSubText.visible = false;

		instructText = new Text(hxd.res.DefaultFont.get(), contentObj);
		instructText.text = "Arraste para chutar";
		instructText.x = designW / 2;
		instructText.y = designH - 80;
		instructText.scale(1.3);
		instructText.textAlign = Center;
		instructText.visible = false;
		instructText.textColor = 0xFFFFFF;

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
		keeperDiveAngle = 0;
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
		failures = 0;
		resultScale = 1.0;
		resultBounce = 0;
	}

	public function setScene3D(scene:Scene) {
		s3d = scene;
	}

	function setupCamera() {
		if (s3d == null)
			return;
		s3d.camera.pos.set(0, 3.8, -20);
		s3d.camera.target.set(0, 1.2, 0);
		s3d.camera.fovY = 32;
	}

	function makeCubePrim(w:Float, h:Float, d:Float):h3d.prim.Polygon {
		var p = new Cube(w, h, d, true);
		p.unindex();
		p.addNormals();
		return p;
	}

	function makeSpherePrim(segments:Int):h3d.prim.Polygon {
		var p = new Sphere(1, segments, segments);
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

		var light = new h3d.scene.fwd.DirLight(new Vector(0.3, 0.7, 0.5), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null)
			amb.ambientLight.set(0.55, 0.6, 0.55);

		buildField();
		buildGoal();
		buildNet();
		buildBall();
		buildKeeper();
	}

	function buildField() {
		// Main ground - dark green base
		var floorPrim = makeCubePrim(24, 0.2, 40);
		ground = new Mesh(floorPrim, s3d);
		ground.material.color.setColor(0x2E8B2E);
		ground.material.shadows = false;
		ground.setPosition(0, -0.1, -8);
		sceneObjects.push(ground);

		// Grass stripes - alternating lighter green
		var stripeCount = 8;
		var stripeW = 24.0;
		var stripeD = 40.0 / stripeCount;
		var i = 0;
		while (i < stripeCount) {
			if (i % 2 == 0) {
				i++;
				continue;
			}
			var sp = makeCubePrim(stripeW, 0.01, stripeD);
			var stripe = new Mesh(sp, s3d);
			stripe.material.color.setColor(0x3A9D3A);
			stripe.material.shadows = false;
			stripe.setPosition(0, 0.005, -8 + (i - stripeCount / 2) * stripeD + stripeD / 2);
			sceneObjects.push(stripe);
			i++;
		}

		// Field markings (thin white lines)
		// Penalty area box
		var boxW = GOAL_WIDTH + 3.0;
		var boxD = 6.0;
		var lineH = 0.02;
		var lineThick = 0.06;

		// Front line of box
		var frontLine = new Mesh(makeCubePrim(boxW, lineH, lineThick), s3d);
		frontLine.material.color.setColor(0xFFFFFF);
		frontLine.material.shadows = false;
		frontLine.setPosition(0, 0.01, -boxD);
		sceneObjects.push(frontLine);

		// Left side of box
		var leftLine = new Mesh(makeCubePrim(lineThick, lineH, boxD), s3d);
		leftLine.material.color.setColor(0xFFFFFF);
		leftLine.material.shadows = false;
		leftLine.setPosition(-boxW / 2, 0.01, -boxD / 2);
		sceneObjects.push(leftLine);

		// Right side of box
		var rightLine = new Mesh(makeCubePrim(lineThick, lineH, boxD), s3d);
		rightLine.material.color.setColor(0xFFFFFF);
		rightLine.material.shadows = false;
		rightLine.setPosition(boxW / 2, 0.01, -boxD / 2);
		sceneObjects.push(rightLine);

		// Penalty spot
		var spotPrim = new Sphere(1, 8, 8);
		spotPrim.unindex();
		spotPrim.addNormals();
		var spot = new Mesh(spotPrim, s3d);
		spot.material.color.setColor(0xFFFFFF);
		spot.material.shadows = false;
		spot.setScale(0.08);
		spot.setPosition(0, 0.03, BALL_START_Z);
		sceneObjects.push(spot);

		// Goal line
		var goalLine = new Mesh(makeCubePrim(GOAL_WIDTH + 2.0, lineH, lineThick), s3d);
		goalLine.material.color.setColor(0xFFFFFF);
		goalLine.material.shadows = false;
		goalLine.setPosition(0, 0.01, 0.0);
		sceneObjects.push(goalLine);

		// Center circle arc (partial, just the visible part)
		var arcSegments = 12;
		var arcRadius = 3.5;
		var j = 0;
		while (j < arcSegments) {
			var angle1 = (j / arcSegments) * Math.PI;
			var angle2 = ((j + 1) / arcSegments) * Math.PI;
			var x1 = Math.cos(angle1) * arcRadius;
			var z1 = Math.sin(angle1) * arcRadius;
			var x2 = Math.cos(angle2) * arcRadius;
			var z2 = Math.sin(angle2) * arcRadius;
			var segLen = Math.sqrt((x2 - x1) * (x2 - x1) + (z2 - z1) * (z2 - z1));
			var segAngle = Math.atan2(z2 - z1, x2 - x1);
			var seg = new Mesh(makeCubePrim(segLen, lineH, lineThick), s3d);
			seg.material.color.setColor(0xFFFFFF);
			seg.material.shadows = false;
			seg.setPosition((x1 + x2) / 2, 0.01, -(z1 + z2) / 2 - boxD);
			seg.setRotation(0, -segAngle, 0);
			sceneObjects.push(seg);
			j++;
		}
	}

	function buildGoal() {
		var postH = GOAL_HEIGHT + POST_W;

		// Left post
		var leftPrim = makeCubePrim(POST_W, postH, POST_DEPTH);
		goalLeft = new Mesh(leftPrim, s3d);
		goalLeft.material.color.setColor(0xF0F0F0);
		goalLeft.material.shadows = false;
		goalLeft.setPosition(-GOAL_WIDTH / 2 - POST_W / 2, postH / 2, 0.0);
		sceneObjects.push(goalLeft);

		// Right post
		var rightPrim = makeCubePrim(POST_W, postH, POST_DEPTH);
		goalRight = new Mesh(rightPrim, s3d);
		goalRight.material.color.setColor(0xF0F0F0);
		goalRight.material.shadows = false;
		goalRight.setPosition(GOAL_WIDTH / 2 + POST_W / 2, postH / 2, 0.0);
		sceneObjects.push(goalRight);

		// Crossbar
		var barPrim = makeCubePrim(GOAL_WIDTH + POST_W * 2, POST_W, POST_DEPTH);
		goalBar = new Mesh(barPrim, s3d);
		goalBar.material.color.setColor(0xF0F0F0);
		goalBar.material.shadows = false;
		goalBar.setPosition(0, GOAL_HEIGHT + POST_W / 2, 0.0);
		sceneObjects.push(goalBar);

		// Side depth bars (goal depth)
		var depthL = new Mesh(makeCubePrim(POST_W, POST_W, GOAL_DEPTH), s3d);
		depthL.material.color.setColor(0xE0E0E0);
		depthL.material.shadows = false;
		depthL.setPosition(-GOAL_WIDTH / 2 - POST_W / 2, GOAL_HEIGHT + POST_W / 2, GOAL_DEPTH / 2);
		sceneObjects.push(depthL);

		var depthR = new Mesh(makeCubePrim(POST_W, POST_W, GOAL_DEPTH), s3d);
		depthR.material.color.setColor(0xE0E0E0);
		depthR.material.shadows = false;
		depthR.setPosition(GOAL_WIDTH / 2 + POST_W / 2, GOAL_HEIGHT + POST_W / 2, GOAL_DEPTH / 2);
		sceneObjects.push(depthR);

		// Back bottom bar
		var backBar = new Mesh(makeCubePrim(GOAL_WIDTH + POST_W * 2, POST_W, POST_DEPTH), s3d);
		backBar.material.color.setColor(0xD0D0D0);
		backBar.material.shadows = false;
		backBar.setPosition(0, POST_W / 2, GOAL_DEPTH);
		sceneObjects.push(backBar);
	}

	function buildNet() {
		// Net: grid of thin vertical and horizontal lines on back and sides
		var netColor = 0xCCCCCC;
		var netThick = 0.02;

		// Back net - vertical lines
		var netCols = 14;
		var spacing = GOAL_WIDTH / netCols;
		var i = 0;
		while (i <= netCols) {
			var x = -GOAL_WIDTH / 2 + i * spacing;
			var vLine = new Mesh(makeCubePrim(netThick, GOAL_HEIGHT, netThick), s3d);
			vLine.material.color.setColor(netColor);
			vLine.material.shadows = false;
			vLine.material.mainPass.depthWrite = true;
			vLine.setPosition(x, GOAL_HEIGHT / 2, GOAL_DEPTH);
			sceneObjects.push(vLine);
			netMeshes.push(vLine);
			i++;
		}

		// Back net - horizontal lines
		var netRows = 6;
		var rowSpacing = GOAL_HEIGHT / netRows;
		var j = 0;
		while (j <= netRows) {
			var y = j * rowSpacing;
			var hLine = new Mesh(makeCubePrim(GOAL_WIDTH, netThick, netThick), s3d);
			hLine.material.color.setColor(netColor);
			hLine.material.shadows = false;
			hLine.setPosition(0, y, GOAL_DEPTH);
			sceneObjects.push(hLine);
			netMeshes.push(hLine);
			j++;
		}

		// Side nets (left and right) - simplified diagonal lines
		var sideLines = 5;
		var k = 0;
		while (k <= sideLines) {
			var t = k / sideLines;
			var z = t * GOAL_DEPTH;
			var y = GOAL_HEIGHT * (1 - t * 0.3);

			// Left side vertical
			var lvLine = new Mesh(makeCubePrim(netThick, y, netThick), s3d);
			lvLine.material.color.setColor(netColor);
			lvLine.material.shadows = false;
			lvLine.setPosition(-GOAL_WIDTH / 2, y / 2, z);
			sceneObjects.push(lvLine);
			netMeshes.push(lvLine);

			// Right side vertical
			var rvLine = new Mesh(makeCubePrim(netThick, y, netThick), s3d);
			rvLine.material.color.setColor(netColor);
			rvLine.material.shadows = false;
			rvLine.setPosition(GOAL_WIDTH / 2, y / 2, z);
			sceneObjects.push(rvLine);
			netMeshes.push(rvLine);
			k++;
		}

		// Top net - depth lines
		var topLines = 8;
		var tl = 0;
		while (tl <= topLines) {
			var tx = -GOAL_WIDTH / 2 + (tl / topLines) * GOAL_WIDTH;
			var topLine = new Mesh(makeCubePrim(netThick, netThick, GOAL_DEPTH), s3d);
			topLine.material.color.setColor(netColor);
			topLine.material.shadows = false;
			topLine.setPosition(tx, GOAL_HEIGHT, GOAL_DEPTH / 2);
			sceneObjects.push(topLine);
			netMeshes.push(topLine);
			tl++;
		}
	}

	function buildBall() {
		// Proper sphere ball
		var ballPrim = makeSpherePrim(16);
		ball = new Mesh(ballPrim, s3d);
		ball.material.color.setColor(0xFAFAFA);
		ball.material.shadows = false;
		ball.setScale(BALL_RADIUS);
		sceneObjects.push(ball);

		// Ball shadow (flat dark circle on ground)
		var shadowPrim = new Sphere(1, 12, 12);
		shadowPrim.unindex();
		shadowPrim.addNormals();
		ballShadow = new Mesh(shadowPrim, s3d);
		ballShadow.material.color.setColor(0x1A4A1A);
		ballShadow.material.shadows = false;
		ballShadow.scaleX = 0.3;
		ballShadow.scaleY = 0.01;
		ballShadow.scaleZ = 0.3;
		ballShadow.setPosition(0, 0.02, BALL_START_Z);
		sceneObjects.push(ballShadow);
	}

	function buildKeeper() {
		keeperParts = [];
		var bodyColor = 0x22AA44; // Green jersey
		var pantsColor = 0x111111; // Black shorts
		var skinColor = 0xDEB887; // Skin tone
		var gloveColor = 0xFF8C00; // Orange gloves

		// Torso
		keeperTorso = new Mesh(makeCubePrim(0.6, 0.7, 0.3), s3d);
		keeperTorso.material.color.setColor(bodyColor);
		keeperTorso.material.shadows = false;
		sceneObjects.push(keeperTorso);
		keeperParts.push(keeperTorso);

		// Head
		var headPrim = makeSpherePrim(10);
		keeperHead = new Mesh(headPrim, s3d);
		keeperHead.material.color.setColor(skinColor);
		keeperHead.material.shadows = false;
		keeperHead.setScale(0.18);
		sceneObjects.push(keeperHead);
		keeperParts.push(keeperHead);

		// Left arm
		keeperArmL = new Mesh(makeCubePrim(0.15, 0.6, 0.15), s3d);
		keeperArmL.material.color.setColor(bodyColor);
		keeperArmL.material.shadows = false;
		sceneObjects.push(keeperArmL);
		keeperParts.push(keeperArmL);

		// Right arm
		keeperArmR = new Mesh(makeCubePrim(0.15, 0.6, 0.15), s3d);
		keeperArmR.material.color.setColor(bodyColor);
		keeperArmR.material.shadows = false;
		sceneObjects.push(keeperArmR);
		keeperParts.push(keeperArmR);

		// Left leg
		keeperLegL = new Mesh(makeCubePrim(0.18, 0.55, 0.18), s3d);
		keeperLegL.material.color.setColor(pantsColor);
		keeperLegL.material.shadows = false;
		sceneObjects.push(keeperLegL);
		keeperParts.push(keeperLegL);

		// Right leg
		keeperLegR = new Mesh(makeCubePrim(0.18, 0.55, 0.18), s3d);
		keeperLegR.material.color.setColor(pantsColor);
		keeperLegR.material.shadows = false;
		sceneObjects.push(keeperLegR);
		keeperParts.push(keeperLegR);

		// Gloves (small spheres at hand positions)
		var gloveL = new Mesh(makeSpherePrim(6), s3d);
		gloveL.material.color.setColor(gloveColor);
		gloveL.material.shadows = false;
		gloveL.setScale(0.09);
		sceneObjects.push(gloveL);
		keeperParts.push(gloveL);

		var gloveR = new Mesh(makeSpherePrim(6), s3d);
		gloveR.material.color.setColor(gloveColor);
		gloveR.material.shadows = false;
		gloveR.setScale(0.09);
		sceneObjects.push(gloveR);
		keeperParts.push(gloveR);

		positionKeeper(0, 0);
	}

	function positionKeeper(x:Float, diveAngle:Float) {
		if (keeperParts.length < 8)
			return;
		var baseY = 0.0;
		var baseZ = 0.3;
		var lean = diveAngle; // radians, negative = left, positive = right
		var cosL = Math.cos(lean);
		var sinL = Math.sin(lean);

		// Torso center
		var torsoY = baseY + 0.55 + 0.35;
		var torsoX = x + sinL * 0.2;
		var torsoYOff = torsoY * cosL;
		keeperTorso.setPosition(torsoX, torsoYOff, baseZ);
		keeperTorso.setRotation(0, 0, lean);

		// Head
		var headY = torsoYOff + 0.45 * cosL;
		var headX = torsoX + 0.45 * sinL;
		keeperHead.setPosition(headX, headY, baseZ);

		// Arms - spread up and out when diving
		var armSpread = Math.abs(lean) * 1.5;
		var armUpAngle = 0.5 + armSpread;

		// Left arm
		var laX = torsoX - 0.37 * cosL - Math.sin(armUpAngle) * 0.3;
		var laY = torsoYOff + Math.cos(armUpAngle) * 0.3;
		keeperArmL.setPosition(laX, laY, baseZ);
		keeperArmL.setRotation(0, 0, lean + armUpAngle * 0.5);

		// Right arm
		var raX = torsoX + 0.37 * cosL + Math.sin(armUpAngle) * 0.3;
		var raY = torsoYOff + Math.cos(armUpAngle) * 0.3;
		keeperArmR.setPosition(raX, raY, baseZ);
		keeperArmR.setRotation(0, 0, lean - armUpAngle * 0.5);

		// Legs
		var legY = baseY + 0.275;
		keeperLegL.setPosition(x - 0.12 + sinL * 0.1, legY * cosL, baseZ);
		keeperLegL.setRotation(0, 0, lean * 0.3);
		keeperLegR.setPosition(x + 0.12 + sinL * 0.1, legY * cosL, baseZ);
		keeperLegR.setRotation(0, 0, lean * 0.3);

		// Gloves at hand tips
		keeperParts[6].setPosition(laX - Math.sin(armUpAngle + lean) * 0.2, laY + Math.cos(armUpAngle) * 0.15, baseZ);
		keeperParts[7].setPosition(raX + Math.sin(armUpAngle - lean) * 0.2, raY + Math.cos(armUpAngle) * 0.15, baseZ);
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
		keeperDiveAngle = 0;

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
		resultSubText.visible = false;
		state = Flying3D;
	}

	function clampF(v:Float, min:Float, max:Float):Float {
		return v < min ? min : (v > max ? max : v);
	}

	function checkCollisions() {
		var r = BALL_RADIUS;
		var hw = POST_W / 2 + r;
		var postH = GOAL_HEIGHT + POST_W;

		var postZMin = -POST_DEPTH / 2 - r;
		var postZMax = POST_DEPTH / 2 + r;

		// Left post
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

		// Right post
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

		// Crossbar
		var barY = GOAL_HEIGHT + POST_W / 2;
		var barHalfW = (GOAL_WIDTH + POST_W * 2) / 2 + r;
		if (ballZ >= postZMin && ballZ <= postZMax && Math.abs(ballX) < barHalfW) {
			if (Math.abs(ballY - barY) < hw) {
				ballVy = -Math.abs(ballVy) * BOUNCE_DAMPING;
				ballVz = -Math.abs(ballVz) * BOUNCE_DAMPING;
				ballY = barY - hw;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.shake2D(0.1, 2);
			}
		}

		// Keeper collision (approximate with torso area)
		var kHalfW = 0.45 + r;
		var kHalfH = 0.7 + r;
		var kHalfD = 0.2 + r;
		var kCenterY = 0.9;
		var kCenterZ = 0.3;
		if (Math.abs(ballX - keeperX) < kHalfW && Math.abs(ballY - kCenterY) < kHalfH && Math.abs(ballZ - kCenterZ) < kHalfD) {
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
		keeperDiveAngle = 0;
		if (ball != null) {
			ball.setPosition(ballX, ballY, ballZ);
			ball.setRotation(0, 0, 0);
		}
		if (ballShadow != null)
			ballShadow.setPosition(ballX, 0.02, ballZ);
		keeperX = 0;
		keeperTargetX = 0;
		keeperDiveTimer = 0;
		positionKeeper(0, 0);
		setupCamera();
		instructText.visible = true;
	}

	function drawHud() {
		hudBg.clear();

		// Score background pill
		hudBg.beginFill(0x000000, 0.35);
		hudBg.drawRoundedRect(designW - 70, 6, 64, 42, 8);
		hudBg.endFill();

		// Failures indicator (X marks)
		var fX = 12.0;
		var fY = 14.0;
		var i = 0;
		while (i < MAX_FAILURES) {
			if (i < failures) {
				// Red X for used
				hudBg.beginFill(0xFF4444, 0.9);
			} else {
				// Gray circle for remaining
				hudBg.beginFill(0xFFFFFF, 0.3);
			}
			hudBg.drawCircle(fX + i * 18, fY, 6);
			hudBg.endFill();
			i++;
		}
	}

	function drawAim() {
		aimG.clear();

		if (state == Aiming3D) {
			var swDx = aimEndX - aimStartX;
			var swDy = aimEndY - aimStartY;
			var swipeLen = Math.sqrt(swDx * swDx + swDy * swDy);

			// Swipe trail - dotted line effect
			var dots = Std.int(swipeLen / 12);
			if (dots < 2)
				dots = 2;
			var i = 0;
			while (i < dots) {
				var t = i / (dots - 1);
				var px = aimStartX + swDx * t;
				var py = aimStartY + swDy * t;
				var dotSize = 2 + t * 3;
				var alpha = 0.3 + t * 0.6;
				aimG.beginFill(0xFFDD00, alpha);
				aimG.drawCircle(px, py, dotSize);
				aimG.endFill();
				i++;
			}

			// Target reticle with crosshair
			aimG.lineStyle(2, 0xFFDD00, 0.7);
			aimG.drawCircle(aimEndX, aimEndY, 14);
			aimG.lineStyle(1.5, 0xFFDD00, 0.5);
			aimG.moveTo(aimEndX - 20, aimEndY);
			aimG.lineTo(aimEndX + 20, aimEndY);
			aimG.moveTo(aimEndX, aimEndY - 20);
			aimG.lineTo(aimEndX, aimEndY + 20);
			aimG.lineStyle(0);

			// Center dot
			aimG.beginFill(0xFFDD00, 0.9);
			aimG.drawCircle(aimEndX, aimEndY, 3);
			aimG.endFill();
		}

		// After-touch visual
		if (state == Flying3D && touching && afterTouchActive) {
			var adx = touchCurX - afterTouchStartX;
			var ady = touchCurY - afterTouchStartY;
			var adist = Math.sqrt(adx * adx + ady * ady);

			// Outer ring
			aimG.lineStyle(2, 0x00CCFF, 0.2);
			aimG.drawCircle(afterTouchStartX, afterTouchStartY, 40);
			aimG.lineStyle(0);

			// Inner glow
			aimG.beginFill(0x00CCFF, 0.12);
			aimG.drawCircle(afterTouchStartX, afterTouchStartY, 30);
			aimG.endFill();

			if (adist > 5) {
				var clampDist = Math.min(adist, 60.0);
				var nx = adx / adist * clampDist;
				var ny = ady / adist * clampDist;
				// Arrow with gradient thickness
				aimG.lineStyle(3, 0x00CCFF, 0.6);
				aimG.moveTo(afterTouchStartX, afterTouchStartY);
				aimG.lineTo(afterTouchStartX + nx, afterTouchStartY + ny);
				aimG.lineStyle(0);
				// Arrow tip triangle
				var tipSize = 7.0;
				var angle = Math.atan2(ny, nx);
				var tipX = afterTouchStartX + nx;
				var tipY = afterTouchStartY + ny;
				aimG.beginFill(0x00CCFF, 0.7);
				aimG.moveTo(tipX + Math.cos(angle) * tipSize, tipY + Math.sin(angle) * tipSize);
				aimG.lineTo(tipX + Math.cos(angle + 2.5) * tipSize * 0.6, tipY + Math.sin(angle + 2.5) * tipSize * 0.6);
				aimG.lineTo(tipX + Math.cos(angle - 2.5) * tipSize * 0.6, tipY + Math.sin(angle - 2.5) * tipSize * 0.6);
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

		// Power bar at bottom - rounded with glow
		var barW = 140.0;
		var barH = 10.0;
		var barX = designW / 2 - barW / 2;
		var barY = designH - 45.0;

		// Background
		powerG.beginFill(0x000000, 0.4);
		powerG.drawRoundedRect(barX - 2, barY - 2, barW + 4, barH + 4, 6);
		powerG.endFill();

		// Fill - smooth gradient green -> yellow -> red
		var color = if (power < 0.4) 0x44DD44 else if (power < 0.7) 0xFFCC00 else 0xFF4444;
		powerG.beginFill(color, 0.85);
		powerG.drawRoundedRect(barX, barY, barW * power, barH, 4);
		powerG.endFill();

		// Power label
		var powerPct = Std.int(power * 100);
		// Tick marks
		powerG.lineStyle(1, 0xFFFFFF, 0.3);
		var tick = 0;
		while (tick < 5) {
			var tx = barX + (tick / 4) * barW;
			powerG.moveTo(tx, barY - 1);
			powerG.lineTo(tx, barY + barH + 1);
			tick++;
		}
		powerG.lineStyle(0);
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		started = false;
		score = 0;
		gameOver = false;
		failures = 0;
		state = Idle3D;
		touching = false;
		resultTimer = 0;
		resultDuration = 0;
		lastGoal = false;
		lastSaved = false;
		camFollowT = 0;
		keeperDiveAngle = 0;
		resultScale = 1.0;
		resultBounce = 0;
		scoreText.text = "0";
		resultText.visible = false;
		resultSubText.visible = false;
		instructText.visible = true;
		setup3D();
		setupCamera();
		resetBall();
		drawHud();
		drawAim();
		powerG.clear();
	}

	public function dispose() {
		for (o in sceneObjects)
			o.remove();
		sceneObjects = [];
		netMeshes = [];
		keeperParts = [];
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
		return "Penalti 3D";

	function showResult(text:String, subText:String, color:Int) {
		resultText.text = text;
		resultText.textColor = color;
		resultText.visible = true;
		resultText.alpha = 0.0;
		resultScale = 2.0;
		resultBounce = 0;
		resultSubText.text = subText;
		resultSubText.textColor = color;
		resultSubText.visible = subText.length > 0;
		resultSubText.alpha = 0.0;
		instructText.visible = false;
		drawHud();
	}

	function updateCameraFollow(dt:Float) {
		if (s3d == null)
			return;
		camFollowT += dt;
		var progress = clampF(camFollowT / 0.9, 0, 1);
		var ease = progress * progress * (3 - 2 * progress);
		var followZ = -20.0 + ease * 8.0;
		var followY = 3.8 - ease * 0.6;
		s3d.camera.pos.set(0, followY, followZ);
		s3d.camera.target.set(0, 1.2 + ease * 0.2, 0);
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started || ball == null) {
			drawAim();
			return;
		}

		if (state == Result3D) {
			resultTimer += dt;

			// Animate result text - bounce in
			resultBounce += dt;
			var bounceT = clampF(resultBounce / 0.3, 0, 1);
			var easeOut = 1 - (1 - bounceT) * (1 - bounceT);
			resultScale = 1.0 + (1 - easeOut) * 1.5;
			resultText.setScale(3.5 * (1 / resultScale));
			resultText.alpha = easeOut;
			resultSubText.alpha = clampF((resultBounce - 0.15) / 0.2, 0, 1);

			// Fade out at end
			if (resultTimer > resultDuration - 0.3) {
				var fadeAlpha = clampF((resultDuration - resultTimer) / 0.3, 0, 1);
				resultText.alpha = fadeAlpha;
				resultSubText.alpha = fadeAlpha;
			}

			if (resultTimer >= resultDuration) {
				resultText.visible = false;
				resultSubText.visible = false;
				if (failures >= MAX_FAILURES) {
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

			// Ground bounce
			if (ballZ < 0 && ballY < BALL_RADIUS) {
				ballY = BALL_RADIUS;
				ballVy = Math.abs(ballVy) * 0.3;
			}

			checkCollisions();

			// Ball spin rotation
			ballSpinAngle += BALL_SPIN_SPEED * dt;
			ball.setPosition(ballX, ballY, ballZ);
			ball.setRotation(ballSpinAngle, ballSpinAngle * 0.7, 0);

			// Shadow follows ball - scales with height
			if (ballShadow != null) {
				var shadowScale = clampF(0.35 - ballY * 0.03, 0.1, 0.4);
				var shadowAlpha = clampF(1.0 - ballY * 0.15, 0.2, 0.7);
				ballShadow.setPosition(ballX, 0.02, ballZ);
				ballShadow.scaleX = shadowScale;
				ballShadow.scaleZ = shadowScale;
				ballShadow.scaleY = 0.01;
				ballShadow.material.color.setColor(Std.int(0x1A * shadowAlpha) << 16 | Std.int(0x4A * shadowAlpha) << 8 | Std.int(0x1A * shadowAlpha));
			}

			updateCameraFollow(dt);

			// Keeper dive
			keeperDiveTimer += dt;
			var diveDelay = 0.15 + (1 - shotPower) * 0.2;
			if (keeperDiveTimer > diveDelay) {
				keeperX += (keeperTargetX - keeperX) * Math.min(1, KEEPER_DIVE_SPEED * dt);
				// Dive lean angle
				var targetAngle = 0.0;
				if (keeperTargetX < -0.5)
					targetAngle = 0.6;
				else if (keeperTargetX > 0.5)
					targetAngle = -0.6;
				keeperDiveAngle += (targetAngle - keeperDiveAngle) * Math.min(1, 6.0 * dt);
				positionKeeper(keeperX, keeperDiveAngle);
			}

			if (!shotChecked && ballZ >= -0.3) {
				shotChecked = true;
				var inGoal = ballX >= -GOAL_WIDTH / 2 && ballX <= GOAL_WIDTH / 2 && ballY >= 0 && ballY <= GOAL_HEIGHT;
				var margin = 0.55;
				var saved = inGoal && ballX >= keeperX - margin && ballX <= keeperX + margin;

				if (saved) {
					failures++;
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.3, 5);
					lastSaved = true;
					lastGoal = false;
					showResult("DEFENDEU!", failures + "/" + MAX_FAILURES, 0xFF4444);
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
					showResult("GOL!", "", 0x44FF44);
					resultTimer = 0;
					resultDuration = RESULT_DURATION_GOAL;
					state = Result3D;
					return;
				} else {
					failures++;
					lastGoal = false;
					lastSaved = false;
					showResult("FORA!", failures + "/" + MAX_FAILURES, 0xFFAA00);
					resultTimer = 0;
					resultDuration = RESULT_DURATION_MISS;
					state = Result3D;
					return;
				}
			}

			if (ballZ > 20 || ballY < -5 || flightTime > 3.0) {
				failures++;
				lastGoal = false;
				lastSaved = false;
				showResult("FORA!", failures + "/" + MAX_FAILURES, 0xFFAA00);
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
