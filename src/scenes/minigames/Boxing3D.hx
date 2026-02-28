package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
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
	Boxing 3D — luta de boxe em primeira pessoa.
	Tap esquerda/direita da tela = jab esquerdo/direito.
	Swipe para baixo = esquiva abaixando.
	Swipe para esquerda/direita = esquiva lateral.
	Oponente ataca em padrões cada vez mais rápidos.
	Acerte quando ele estiver aberto, esquive quando ele atacar.
**/
class Boxing3D implements IMinigameSceneWithLose implements IMinigameUpdatable implements IMinigame3D {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var MAX_HP = 5;
	static var PUNCH_DURATION = 0.25;
	static var DODGE_DURATION = 0.35;
	static var ENEMY_ATTACK_WIND = 0.5; // windup time
	static var ENEMY_ATTACK_STRIKE = 0.15;
	static var ENEMY_RECOVERY = 0.4;
	static var ENEMY_STUN_TIME = 0.5;
	static var COMBO_WINDOW = 0.8;
	static var SWIPE_MIN = 30.0;

	var s3d:Scene;
	final contentObj:Object;
	var ctx:MinigameContext;
	var savedCamPos:Vector;
	var savedCamTarget:Vector;

	var sceneObjects:Array<h3d.scene.Object>;

	// HUD
	var hudG:Graphics;
	var aimG:Graphics;
	var interactive:Interactive;
	var scoreText:Text;
	var comboText:Text;
	var hintText:Text;
	var resultText:Text;
	var hpPlayerG:Graphics;
	var hpEnemyG:Graphics;

	// Enemy body parts (3D)
	var enemyHead:Mesh;
	var enemyTorso:Mesh;
	var enemyArmL:Mesh;
	var enemyArmR:Mesh;
	var enemyGloveL:Mesh;
	var enemyGloveR:Mesh;
	var enemyLegL:Mesh;
	var enemyLegR:Mesh;
	var enemyShadow:Mesh;
	var enemyParts:Array<Mesh>;

	// Player body (over-the-shoulder 3rd person)
	var playerHead:Mesh;
	var playerTorso:Mesh;
	var playerArmL:Mesh;
	var playerArmR:Mesh;
	var playerGloveL:Mesh;
	var playerGloveR:Mesh;
	var playerLegL:Mesh;
	var playerLegR:Mesh;
	var playerShadow:Mesh;
	var playerParts:Array<Mesh>;

	// Ring
	var ringFloor:Mesh;
	var ropes:Array<Mesh>;

	// Game state
	var gameOver:Bool;
	var gameOverTimer:Float;
	var score:Int;
	var combo:Int;
	var comboTimer:Float;
	var playerHP:Int;
	var enemyHP:Int;
	var round:Int;
	var totalTime:Float;

	// Player action
	var playerState:PlayerAction;
	var playerActionTimer:Float;
	var playerPunchSide:Int; // 0=left, 1=right
	var playerDodgeDir:Int; // 0=duck, 1=left, 2=right

	// Enemy AI
	var enemyState:EnemyAction;
	var enemyActionTimer:Float;
	var enemyAttackSide:Int; // 0=left, 1=right
	var enemyIdleTimer:Float;
	var enemyAttackInterval:Float;
	var enemyStunTimer:Float;
	var enemySwayAngle:Float;
	var enemyHitFlash:Float;

	// Touch tracking
	var touchStartX:Float;
	var touchStartY:Float;
	var touchDown:Bool;
	var touchHandled:Bool;

	// Camera bob
	var camBobTime:Float;

	// Round transition
	var roundTransTimer:Float;
	var roundTransActive:Bool;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;
		sceneObjects = [];
		enemyParts = [];
		playerParts = [];
		ropes = [];
		savedCamPos = new Vector();
		savedCamTarget = new Vector();

		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		// HUD
		hudG = new Graphics(contentObj);
		aimG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 8;
		scoreText.scale(2.2);
		scoreText.textColor = 0xFFDD44;

		comboText = new Text(hxd.res.DefaultFont.get(), contentObj);
		comboText.text = "";
		comboText.textAlign = Center;
		comboText.x = DESIGN_W / 2;
		comboText.y = 42;
		comboText.scale(1.4);
		comboText.textColor = 0xFF8844;
		comboText.alpha = 0;

		hintText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hintText.text = "Tap to punch, swipe to dodge!";
		hintText.textAlign = Center;
		hintText.x = DESIGN_W / 2;
		hintText.y = DESIGN_H - 50;
		hintText.textColor = 0x667788;

		resultText = new Text(hxd.res.DefaultFont.get(), contentObj);
		resultText.text = "";
		resultText.textAlign = Center;
		resultText.x = DESIGN_W / 2;
		resultText.y = DESIGN_H * 0.38;
		resultText.scale(2.5);
		resultText.textColor = 0x44DD66;
		resultText.alpha = 0;

		hpPlayerG = new Graphics(contentObj);
		hpEnemyG = new Graphics(contentObj);

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = onPush;
		interactive.onMove = onMove;
		interactive.onRelease = onRelease;
		interactive.onReleaseOutside = onRelease;

		// Init state
		gameOver = false;
		gameOverTimer = 0;
		score = 0;
		combo = 0;
		comboTimer = 0;
		playerHP = MAX_HP;
		enemyHP = MAX_HP;
		round = 1;
		totalTime = 0;
		playerState = PIdle;
		playerActionTimer = 0;
		playerPunchSide = 0;
		playerDodgeDir = 0;
		enemyState = EIdle;
		enemyActionTimer = 0;
		enemyAttackSide = 0;
		enemyIdleTimer = 0;
		enemyAttackInterval = 2.0;
		enemyStunTimer = 0;
		enemySwayAngle = 0;
		enemyHitFlash = 0;
		touchStartX = 0;
		touchStartY = 0;
		touchDown = false;
		touchHandled = false;
		camBobTime = 0;
		roundTransTimer = 0;
		roundTransActive = false;
	}

	function onPush(e:Event):Void {
		if (gameOver || roundTransActive) return;
		touchStartX = e.relX;
		touchStartY = e.relY;
		touchDown = true;
		touchHandled = false;
		e.propagate = false;
	}

	function onMove(e:Event):Void {
		if (!touchDown || touchHandled || gameOver) return;
		var dx = e.relX - touchStartX;
		var dy = e.relY - touchStartY;
		var dist = Math.sqrt(dx * dx + dy * dy);

		if (dist > SWIPE_MIN) {
			touchHandled = true;
			// Determine swipe direction
			if (Math.abs(dy) > Math.abs(dx) && dy > 0) {
				// Swipe down = duck
				startDodge(0);
			} else if (dx < 0) {
				// Swipe left
				startDodge(1);
			} else {
				// Swipe right
				startDodge(2);
			}
		}
	}

	function onRelease(e:Event):Void {
		if (!touchDown || gameOver) {
			touchDown = false;
			return;
		}
		touchDown = false;
		if (touchHandled) return;

		// Tap = punch
		var side = e.relX < DESIGN_W / 2 ? 0 : 1;
		startPunch(side);
	}

	function startPunch(side:Int):Void {
		if (playerState != PIdle) return;
		playerState = PPunching;
		playerActionTimer = 0;
		playerPunchSide = side;

		// Check if enemy is hittable
		if (enemyState == EIdle || enemyState == EWindup) {
			// Hit!
			enemyHP--;
			score += 10 + combo * 5;
			combo++;
			comboTimer = COMBO_WINDOW;
			enemyStunTimer = ENEMY_STUN_TIME;
			enemyState = EStunned;
			enemyActionTimer = 0;
			enemyHitFlash = 0.2;

			if (ctx != null && ctx.feedback != null)
				ctx.feedback.shake2D(0.1, 3);

			if (enemyHP <= 0) {
				// KO! Next round
				score += 50 + round * 20;
				startRoundTransition();
			}
		}

		hintText.alpha = 0;
	}

	function startDodge(dir:Int):Void {
		if (playerState != PIdle) return;
		playerState = PDodging;
		playerActionTimer = 0;
		playerDodgeDir = dir;
		hintText.alpha = 0;
	}

	function startRoundTransition():Void {
		roundTransActive = true;
		roundTransTimer = 0;
		resultText.text = "KO!";
		resultText.textColor = 0xFF4444;
		resultText.alpha = 1.0;
	}

	function nextRound():Void {
		round++;
		enemyHP = MAX_HP;
		enemyState = EIdle;
		enemyActionTimer = 0;
		enemyIdleTimer = 0;
		enemyStunTimer = 0;
		enemyAttackInterval = Math.max(0.8, 2.0 - round * 0.15);
		roundTransActive = false;
		resultText.alpha = 0;
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

	public function setScene3D(scene:Scene) {
		s3d = scene;
	}

	function setupCamera():Void {
		if (s3d == null) return;
		// Over-the-shoulder: behind and above the player
		s3d.camera.pos.set(0.3, 2.2, -2.2);
		s3d.camera.target.set(0, 1.2, 0.8);
		s3d.camera.fovY = 42;
	}

	function setup3D():Void {
		if (s3d == null) return;
		savedCamPos.load(s3d.camera.pos);
		savedCamTarget.load(s3d.camera.target);
		setupCamera();
		s3d.camera.screenRatio = DESIGN_W / DESIGN_H;

		// Lighting
		var light = new h3d.scene.fwd.DirLight(new Vector(0.2, 0.8, -0.3), s3d);
		light.enableSpecular = true;
		sceneObjects.push(light);
		var amb = cast(s3d.lightSystem, h3d.scene.fwd.LightSystem);
		if (amb != null)
			amb.ambientLight.set(0.45, 0.4, 0.42);

		buildRing();
		buildEnemy();
		buildPlayer();
	}

	function buildRing():Void {
		// Ring floor
		var floorPrim = makeCubePrim(8, 0.1, 8);
		ringFloor = new Mesh(floorPrim, s3d);
		ringFloor.material.color.setColor(0x4A6A8A);
		ringFloor.material.shadows = false;
		ringFloor.setPosition(0, -0.05, 0);
		sceneObjects.push(ringFloor);

		// Canvas center
		var canvasPrim = makeCubePrim(6, 0.02, 6);
		var canvas = new Mesh(canvasPrim, s3d);
		canvas.material.color.setColor(0xD4C5A0);
		canvas.material.shadows = false;
		canvas.setPosition(0, 0.01, 0);
		sceneObjects.push(canvas);

		// Corner posts
		var postPositions = [
			{x: -3.0, z: -3.0},
			{x: 3.0, z: -3.0},
			{x: -3.0, z: 3.0},
			{x: 3.0, z: 3.0},
		];
		for (pp in postPositions) {
			var post = new Mesh(makeCubePrim(0.12, 1.6, 0.12), s3d);
			post.material.color.setColor(0xAA2222);
			post.material.shadows = false;
			post.setPosition(pp.x, 0.8, pp.z);
			sceneObjects.push(post);
		}

		// Ropes (3 horizontal on each side)
		ropes = [];
		var ropeH = [0.5, 1.0, 1.5];
		for (h in ropeH) {
			// Left side
			var ropeL = new Mesh(makeCubePrim(0.04, 0.04, 6), s3d);
			ropeL.material.color.setColor(0xEEEEEE);
			ropeL.material.shadows = false;
			ropeL.setPosition(-3.0, h, 0);
			sceneObjects.push(ropeL);
			ropes.push(ropeL);

			// Right side
			var ropeR = new Mesh(makeCubePrim(0.04, 0.04, 6), s3d);
			ropeR.material.color.setColor(0xEEEEEE);
			ropeR.material.shadows = false;
			ropeR.setPosition(3.0, h, 0);
			sceneObjects.push(ropeR);
			ropes.push(ropeR);

			// Back
			var ropeB = new Mesh(makeCubePrim(6, 0.04, 0.04), s3d);
			ropeB.material.color.setColor(0xEEEEEE);
			ropeB.material.shadows = false;
			ropeB.setPosition(0, h, 3.0);
			sceneObjects.push(ropeB);
			ropes.push(ropeB);

			// Front (behind player)
			var ropeF = new Mesh(makeCubePrim(6, 0.04, 0.04), s3d);
			ropeF.material.color.setColor(0xEEEEEE);
			ropeF.material.shadows = false;
			ropeF.setPosition(0, h, -3.0);
			sceneObjects.push(ropeF);
			ropes.push(ropeF);
		}
	}

	function buildEnemy():Void {
		enemyParts = [];
		var bodyColor = 0xCC2222; // Red trunks
		var skinColor = 0xC4956A;
		var gloveColor = 0xCC3333; // Red gloves

		// Torso
		enemyTorso = new Mesh(makeCubePrim(0.55, 0.65, 0.3), s3d);
		enemyTorso.material.color.setColor(skinColor);
		enemyTorso.material.shadows = false;
		sceneObjects.push(enemyTorso);
		enemyParts.push(enemyTorso);

		// Head
		enemyHead = new Mesh(makeSpherePrim(10), s3d);
		enemyHead.material.color.setColor(skinColor);
		enemyHead.material.shadows = false;
		enemyHead.setScale(0.18);
		sceneObjects.push(enemyHead);
		enemyParts.push(enemyHead);

		// Left arm
		enemyArmL = new Mesh(makeCubePrim(0.14, 0.5, 0.14), s3d);
		enemyArmL.material.color.setColor(skinColor);
		enemyArmL.material.shadows = false;
		sceneObjects.push(enemyArmL);
		enemyParts.push(enemyArmL);

		// Right arm
		enemyArmR = new Mesh(makeCubePrim(0.14, 0.5, 0.14), s3d);
		enemyArmR.material.color.setColor(skinColor);
		enemyArmR.material.shadows = false;
		sceneObjects.push(enemyArmR);
		enemyParts.push(enemyArmR);

		// Left glove
		enemyGloveL = new Mesh(makeSpherePrim(8), s3d);
		enemyGloveL.material.color.setColor(gloveColor);
		enemyGloveL.material.shadows = false;
		enemyGloveL.setScale(0.11);
		sceneObjects.push(enemyGloveL);
		enemyParts.push(enemyGloveL);

		// Right glove
		enemyGloveR = new Mesh(makeSpherePrim(8), s3d);
		enemyGloveR.material.color.setColor(gloveColor);
		enemyGloveR.material.shadows = false;
		enemyGloveR.setScale(0.11);
		sceneObjects.push(enemyGloveR);
		enemyParts.push(enemyGloveR);

		// Legs
		enemyLegL = new Mesh(makeCubePrim(0.16, 0.5, 0.16), s3d);
		enemyLegL.material.color.setColor(bodyColor);
		enemyLegL.material.shadows = false;
		sceneObjects.push(enemyLegL);
		enemyParts.push(enemyLegL);

		enemyLegR = new Mesh(makeCubePrim(0.16, 0.5, 0.16), s3d);
		enemyLegR.material.color.setColor(bodyColor);
		enemyLegR.material.shadows = false;
		sceneObjects.push(enemyLegR);
		enemyParts.push(enemyLegR);

		// Shadow
		enemyShadow = new Mesh(makeSpherePrim(8), s3d);
		enemyShadow.material.color.setColor(0x2A2A3A);
		enemyShadow.material.shadows = false;
		enemyShadow.scaleX = 0.4;
		enemyShadow.scaleY = 0.01;
		enemyShadow.scaleZ = 0.25;
		sceneObjects.push(enemyShadow);
		enemyParts.push(enemyShadow);

		positionEnemy(0, 0, 0, 0, 0);
	}

	function buildPlayer():Void {
		playerParts = [];
		var skinColor = 0xD4A574;
		var trunksColor = 0x2244AA; // Blue trunks
		var gloveColor = 0x2255CC; // Blue gloves

		// Torso
		playerTorso = new Mesh(makeCubePrim(0.55, 0.65, 0.3), s3d);
		playerTorso.material.color.setColor(skinColor);
		playerTorso.material.shadows = false;
		sceneObjects.push(playerTorso);
		playerParts.push(playerTorso);

		// Head
		playerHead = new Mesh(makeSpherePrim(10), s3d);
		playerHead.material.color.setColor(skinColor);
		playerHead.material.shadows = false;
		playerHead.setScale(0.17);
		sceneObjects.push(playerHead);
		playerParts.push(playerHead);

		// Left arm
		playerArmL = new Mesh(makeCubePrim(0.14, 0.5, 0.14), s3d);
		playerArmL.material.color.setColor(skinColor);
		playerArmL.material.shadows = false;
		sceneObjects.push(playerArmL);
		playerParts.push(playerArmL);

		// Right arm
		playerArmR = new Mesh(makeCubePrim(0.14, 0.5, 0.14), s3d);
		playerArmR.material.color.setColor(skinColor);
		playerArmR.material.shadows = false;
		sceneObjects.push(playerArmR);
		playerParts.push(playerArmR);

		// Left glove
		playerGloveL = new Mesh(makeSpherePrim(8), s3d);
		playerGloveL.material.color.setColor(gloveColor);
		playerGloveL.material.shadows = false;
		playerGloveL.setScale(0.11);
		sceneObjects.push(playerGloveL);
		playerParts.push(playerGloveL);

		// Right glove
		playerGloveR = new Mesh(makeSpherePrim(8), s3d);
		playerGloveR.material.color.setColor(gloveColor);
		playerGloveR.material.shadows = false;
		playerGloveR.setScale(0.11);
		sceneObjects.push(playerGloveR);
		playerParts.push(playerGloveR);

		// Legs
		playerLegL = new Mesh(makeCubePrim(0.16, 0.5, 0.16), s3d);
		playerLegL.material.color.setColor(trunksColor);
		playerLegL.material.shadows = false;
		sceneObjects.push(playerLegL);
		playerParts.push(playerLegL);

		playerLegR = new Mesh(makeCubePrim(0.16, 0.5, 0.16), s3d);
		playerLegR.material.color.setColor(trunksColor);
		playerLegR.material.shadows = false;
		sceneObjects.push(playerLegR);
		playerParts.push(playerLegR);

		// Shadow
		playerShadow = new Mesh(makeSpherePrim(8), s3d);
		playerShadow.material.color.setColor(0x2A2A3A);
		playerShadow.material.shadows = false;
		playerShadow.scaleX = 0.4;
		playerShadow.scaleY = 0.01;
		playerShadow.scaleZ = 0.25;
		sceneObjects.push(playerShadow);
		playerParts.push(playerShadow);

		positionPlayer(0, 0, -1);
	}

	function positionEnemy(sway:Float, guardUp:Float, hitRecoil:Float, punchExtendL:Float, punchExtendR:Float):Void {
		var baseX = sway * 0.3;
		var baseY = 0.0;
		var baseZ = 0.8;

		var recoilZ = hitRecoil * 0.3;
		var recoilY = hitRecoil * -0.1;

		// Torso
		var torsoY = baseY + 0.85 + recoilY;
		enemyTorso.setPosition(baseX, torsoY, baseZ + recoilZ);
		enemyTorso.setRotation(hitRecoil * 0.2, sway * 0.1, sway * 0.15);

		// Head
		var headY = torsoY + 0.5 + recoilY * 0.5;
		enemyHead.setPosition(baseX + sway * 0.05, headY, baseZ + recoilZ);

		// Arms — guard position
		var guardOff = guardUp * 0.15;

		// Left arm + glove
		var laX = baseX - 0.35;
		var laY = torsoY - 0.05 + guardOff;
		var laZ = baseZ - 0.15 + recoilZ - punchExtendL * 1.2;
		enemyArmL.setPosition(laX, laY, laZ);
		enemyArmL.setRotation(punchExtendL * 0.5, 0, 0.3 - guardUp * 0.2);
		enemyGloveL.setPosition(laX - 0.02, laY + 0.2 + guardOff, laZ - 0.12 - punchExtendL * 0.4);

		// Right arm + glove
		var raX = baseX + 0.35;
		var raY = torsoY - 0.05 + guardOff;
		var raZ = baseZ - 0.15 + recoilZ - punchExtendR * 1.2;
		enemyArmR.setPosition(raX, raY, raZ);
		enemyArmR.setRotation(punchExtendR * 0.5, 0, -0.3 + guardUp * 0.2);
		enemyGloveR.setPosition(raX + 0.02, raY + 0.2 + guardOff, raZ - 0.12 - punchExtendR * 0.4);

		// Legs
		var legSpread = 0.15 + Math.abs(sway) * 0.05;
		enemyLegL.setPosition(baseX - legSpread, baseY + 0.25, baseZ + recoilZ * 0.3);
		enemyLegR.setPosition(baseX + legSpread, baseY + 0.25, baseZ + recoilZ * 0.3);

		// Shadow
		enemyShadow.setPosition(baseX, 0.01, baseZ);
	}

	function positionPlayer(punchL:Float, punchR:Float, dodgeDir:Int):Void {
		var baseX = 0.0;
		var baseY = 0.0;
		var baseZ = -0.8; // player stands closer to camera

		var dodgeOffX = 0.0;
		var dodgeOffY = 0.0;
		if (dodgeDir == 0) dodgeOffY = -0.3; // duck
		if (dodgeDir == 1) dodgeOffX = -0.4; // lean left
		if (dodgeDir == 2) dodgeOffX = 0.4; // lean right

		var lean = dodgeOffX * 0.4; // body lean angle

		// Torso
		var torsoY = baseY + 0.85 + dodgeOffY;
		playerTorso.setPosition(baseX + dodgeOffX, torsoY, baseZ);
		playerTorso.setRotation(0, 0, lean);

		// Head
		var headY = torsoY + 0.48 + dodgeOffY * 0.2;
		playerHead.setPosition(baseX + dodgeOffX, headY, baseZ);

		// Guard up
		var guardOff = 0.15;

		// Left arm + glove
		var laX = baseX + dodgeOffX - 0.35;
		var laY = torsoY - 0.05 + guardOff;
		var laZ = baseZ - 0.15 - punchL * 1.5;
		playerArmL.setPosition(laX, laY, laZ);
		playerArmL.setRotation(punchL * 0.5, 0, 0.3);
		playerGloveL.setPosition(laX - 0.02, laY + 0.2 + guardOff, laZ - 0.12 - punchL * 0.5);

		// Right arm + glove
		var raX = baseX + dodgeOffX + 0.35;
		var raY = torsoY - 0.05 + guardOff;
		var raZ = baseZ - 0.15 - punchR * 1.5;
		playerArmR.setPosition(raX, raY, raZ);
		playerArmR.setRotation(punchR * 0.5, 0, -0.3);
		playerGloveR.setPosition(raX + 0.02, raY + 0.2 + guardOff, raZ - 0.12 - punchR * 0.5);

		// Legs
		var legSpread = 0.15;
		playerLegL.setPosition(baseX + dodgeOffX - legSpread, baseY + 0.25, baseZ);
		playerLegR.setPosition(baseX + dodgeOffX + legSpread, baseY + 0.25, baseZ);

		// Shadow
		playerShadow.setPosition(baseX + dodgeOffX, 0.01, baseZ);
	}

	function drawHUD():Void {
		hudG.clear();

		// Background strip
		hudG.beginFill(0x000000, 0.4);
		hudG.drawRect(0, 0, DESIGN_W, 70);
		hudG.endFill();

		// Round indicator
		hudG.beginFill(0xFFFFFF, 0.15);
		hudG.drawRect(DESIGN_W / 2 - 30, 60, 60, 16);
		hudG.endFill();

		// HP bars
		hpPlayerG.clear();
		hpEnemyG.clear();

		// Player HP — bottom-left
		var phX = 12.0;
		var phY = DESIGN_H - 28.0;
		var hpW = 80.0;
		var hpH = 8.0;
		hpPlayerG.beginFill(0x333344, 0.7);
		hpPlayerG.drawRect(phX, phY, hpW, hpH);
		hpPlayerG.endFill();
		var pRatio = playerHP / MAX_HP;
		var pColor = pRatio > 0.4 ? 0x2255CC : 0xFF4444;
		hpPlayerG.beginFill(pColor, 0.9);
		hpPlayerG.drawRect(phX, phY, hpW * pRatio, hpH);
		hpPlayerG.endFill();

		// Enemy HP — top area
		var ehX = 15.0;
		var ehY = 62.0;
		var ehW = DESIGN_W - 30.0;
		hpEnemyG.beginFill(0x333344, 0.7);
		hpEnemyG.drawRect(ehX, ehY, ehW, hpH);
		hpEnemyG.endFill();
		var eRatio = enemyHP / MAX_HP;
		var eColor = eRatio > 0.4 ? 0xCC2222 : 0xFF8844;
		hpEnemyG.beginFill(eColor, 0.9);
		hpEnemyG.drawRect(ehX, ehY, ehW * eRatio, hpH);
		hpEnemyG.endFill();

		// "PLAYER" / "ENEMY" labels
		// (scores already shown via scoreText)
	}

	function drawPunchFlash():Void {
		aimG.clear();

		// Enemy hit flash
		if (enemyHitFlash > 0) {
			aimG.beginFill(0xFFFFFF, enemyHitFlash * 0.3);
			aimG.drawRect(0, 0, DESIGN_W, DESIGN_H);
			aimG.endFill();
		}

		// Player hit flash (red tint)
		if (playerState == PHit) {
			var hitAlpha = Math.max(0, 1.0 - playerActionTimer * 4.0) * 0.25;
			aimG.beginFill(0xFF0000, hitAlpha);
			aimG.drawRect(0, 0, DESIGN_W, DESIGN_H);
			aimG.endFill();
		}

		// Danger indicator when enemy is winding up
		if (enemyState == EWindup) {
			var windProgress = enemyActionTimer / ENEMY_ATTACK_WIND;
			var pulse = Math.sin(windProgress * Math.PI * 4) * 0.5 + 0.5;
			var warnAlpha = windProgress * 0.06 * pulse;
			aimG.beginFill(0xFF4444, warnAlpha);
			aimG.drawRect(0, 0, DESIGN_W, DESIGN_H);
			aimG.endFill();

			// Exclamation mark
			if (windProgress > 0.5) {
				var exAlpha = (windProgress - 0.5) * 2.0 * pulse;
				var exSide = enemyAttackSide == 0 ? DESIGN_W * 0.3 : DESIGN_W * 0.7;
				aimG.beginFill(0xFF4444, exAlpha * 0.8);
				aimG.drawCircle(exSide, DESIGN_H * 0.35, 14);
				aimG.endFill();
			}
		}
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		gameOver = false;
		gameOverTimer = 0;
		score = 0;
		combo = 0;
		comboTimer = 0;
		playerHP = MAX_HP;
		enemyHP = MAX_HP;
		round = 1;
		totalTime = 0;
		playerState = PIdle;
		playerActionTimer = 0;
		enemyState = EIdle;
		enemyActionTimer = 0;
		enemyIdleTimer = 0;
		enemyAttackInterval = 2.0;
		enemyStunTimer = 0;
		enemySwayAngle = 0;
		enemyHitFlash = 0;
		camBobTime = 0;
		roundTransTimer = 0;
		roundTransActive = false;
		resultText.alpha = 0;
		hintText.alpha = 1.0;

		setup3D();
	}

	public function update(dt:Float):Void {
		if (ctx == null) return;
		totalTime += dt;
		camBobTime += dt;

		// Round transition
		if (roundTransActive) {
			roundTransTimer += dt;
			if (roundTransTimer > 2.0) {
				nextRound();
			}
			// Animate enemy falling
			var fall = Math.min(roundTransTimer / 0.8, 1.0);
			positionEnemy(0, 0, fall * 3.0, 0, 0);
			drawHUD();
			drawPunchFlash();
			return;
		}

		if (gameOver) {
			gameOverTimer += dt;
			if (gameOverTimer > 1.5 && ctx != null) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			drawHUD();
			drawPunchFlash();
			return;
		}

		// Player action timers
		playerActionTimer += dt;
		switch (playerState) {
			case PPunching:
				if (playerActionTimer >= PUNCH_DURATION) {
					playerState = PIdle;
					playerActionTimer = 0;
				}
			case PDodging:
				if (playerActionTimer >= DODGE_DURATION) {
					playerState = PIdle;
					playerActionTimer = 0;
				}
			case PHit:
				if (playerActionTimer >= 0.4) {
					playerState = PIdle;
					playerActionTimer = 0;
				}
			case PIdle:
		}

		// Combo timer
		if (comboTimer > 0) {
			comboTimer -= dt;
			if (comboTimer <= 0) {
				combo = 0;
			}
		}

		// Enemy AI
		enemyActionTimer += dt;
		switch (enemyState) {
			case EIdle:
				enemyIdleTimer += dt;
				if (enemyIdleTimer >= enemyAttackInterval) {
					enemyIdleTimer = 0;
					enemyState = EWindup;
					enemyActionTimer = 0;
					enemyAttackSide = rng.random(2);
				}

			case EWindup:
				if (enemyActionTimer >= ENEMY_ATTACK_WIND) {
					enemyState = EStriking;
					enemyActionTimer = 0;
				}

			case EStriking:
				if (enemyActionTimer >= ENEMY_ATTACK_STRIKE) {
					// Check if player dodged
					var dodged = false;
					if (playerState == PDodging) {
						dodged = true; // any dodge works
					}

					if (!dodged) {
						// Player gets hit!
						playerHP--;
						playerState = PHit;
						playerActionTimer = 0;
						combo = 0;
						comboTimer = 0;

						if (ctx != null && ctx.feedback != null)
							ctx.feedback.shake2D(0.2, 5);

						if (playerHP <= 0) {
							gameOver = true;
							gameOverTimer = 0;
							resultText.text = "KNOCKED OUT!";
							resultText.textColor = 0xFF4444;
							resultText.alpha = 1.0;
							return;
						}
					} else {
						// Counter opportunity - bonus points for dodging
						score += 5;
					}

					enemyState = ERecovery;
					enemyActionTimer = 0;
				}

			case ERecovery:
				if (enemyActionTimer >= ENEMY_RECOVERY) {
					enemyState = EIdle;
					enemyActionTimer = 0;
					enemyIdleTimer = 0;
				}

			case EStunned:
				enemyStunTimer -= dt;
				if (enemyStunTimer <= 0) {
					enemyState = EIdle;
					enemyActionTimer = 0;
					enemyIdleTimer = 0;
				}
		}

		// Enemy hit flash decay
		if (enemyHitFlash > 0) enemyHitFlash -= dt * 2.0;

		// Enemy sway
		enemySwayAngle += dt * 1.5;
		var sway = Math.sin(enemySwayAngle) * 0.3;

		// Enemy pose based on state
		var guardUp = 0.0;
		var hitRecoil = 0.0;
		var punchL = 0.0;
		var punchR = 0.0;

		switch (enemyState) {
			case EIdle:
				guardUp = 0.5 + Math.sin(totalTime * 2.0) * 0.1;
			case EWindup:
				var wind = enemyActionTimer / ENEMY_ATTACK_WIND;
				guardUp = 0.5 - wind * 0.3;
				if (enemyAttackSide == 0) punchL = -wind * 0.3;
				else punchR = -wind * 0.3;
				sway *= 0.3;
			case EStriking:
				var strike = enemyActionTimer / ENEMY_ATTACK_STRIKE;
				if (enemyAttackSide == 0) punchL = strike;
				else punchR = strike;
				sway = 0;
			case ERecovery:
				var rec = enemyActionTimer / ENEMY_RECOVERY;
				guardUp = rec * 0.5;
			case EStunned:
				hitRecoil = Math.max(0, enemyStunTimer / ENEMY_STUN_TIME);
				sway = Math.sin(totalTime * 12) * 0.2 * hitRecoil;
		}

		positionEnemy(sway, guardUp, hitRecoil, punchL, punchR);

		// Player gloves
		var ppL = 0.0;
		var ppR = 0.0;
		var dodgeD = -1;

		switch (playerState) {
			case PPunching:
				var t = playerActionTimer / PUNCH_DURATION;
				var punchT = t < 0.4 ? t / 0.4 : 1.0 - (t - 0.4) / 0.6;
				if (playerPunchSide == 0) ppL = punchT;
				else ppR = punchT;
			case PDodging:
				dodgeD = playerDodgeDir;
			case PHit:
				// Gloves drop slightly
				dodgeD = 0;
			case PIdle:
		}

		positionPlayer(ppL, ppR, dodgeD);

		// Camera — subtle over-the-shoulder, follows player dodge gently
		if (s3d != null) {
			var bobX = Math.sin(camBobTime * 1.2) * 0.01;
			var bobY = Math.sin(camBobTime * 2.4) * 0.005;
			var camX = 0.3 + bobX;
			var camY = 2.2 + bobY;
			var camZ = -2.2;
			var targetX = 0.0;
			var targetY = 1.2;

			// Gently follow player dodge
			if (playerState == PDodging) {
				var dT = Math.min(playerActionTimer / DODGE_DURATION, 1.0);
				var dodgeEase = Math.sin(dT * Math.PI);
				if (playerDodgeDir == 0) {
					camY -= dodgeEase * 0.15;
					targetY -= dodgeEase * 0.1;
				}
				if (playerDodgeDir == 1) {
					camX -= dodgeEase * 0.15;
					targetX -= dodgeEase * 0.1;
				}
				if (playerDodgeDir == 2) {
					camX += dodgeEase * 0.15;
					targetX += dodgeEase * 0.1;
				}
			}

			// Subtle hit shake
			if (playerState == PHit) {
				var hT = playerActionTimer * 10.0;
				camX += Math.sin(hT) * 0.04;
				camY += Math.cos(hT * 1.3) * 0.02;
			}

			s3d.camera.pos.set(camX, camY, camZ);
			s3d.camera.target.set(targetX, targetY, 0.8);
		}

		// Flash on enemy
		if (enemyHitFlash > 0 && enemyHead != null) {
			var flashInt = Std.int(enemyHitFlash * 10) % 2;
			var col = flashInt == 0 ? 0xFFFFFF : 0xC4956A;
			enemyHead.material.color.setColor(col);
		} else if (enemyHead != null) {
			enemyHead.material.color.setColor(0xC4956A);
		}

		// HUD
		scoreText.text = Std.string(score);
		if (combo > 1) {
			comboText.text = combo + "x COMBO";
			comboText.alpha = Math.min(1.0, comboTimer * 3.0);
		} else {
			comboText.alpha = 0;
		}

		// Hint fades
		if (totalTime > 3.0 && hintText.alpha > 0) {
			hintText.alpha = Math.max(0, hintText.alpha - dt);
		}

		drawHUD();
		drawPunchFlash();
	}

	public function dispose() {
		for (o in sceneObjects)
			o.remove();
		sceneObjects = [];
		enemyParts = [];
		playerParts = [];
		ropes = [];
		if (s3d != null && savedCamPos != null) {
			s3d.camera.pos.load(savedCamPos);
			s3d.camera.target.load(savedCamTarget);
		}
		contentObj.removeChildren();
		ctx = null;
		s3d = null;
	}

	public function getMinigameId():String
		return "boxing-3d";

	public function getTitle():String
		return "Boxing";
}

private enum PlayerAction {
	PIdle;
	PPunching;
	PDodging;
	PHit;
}

private enum EnemyAction {
	EIdle;
	EWindup;
	EStriking;
	ERecovery;
	EStunned;
}
