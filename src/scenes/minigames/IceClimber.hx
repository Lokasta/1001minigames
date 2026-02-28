package scenes.minigames;

import h2d.Object;
import h2d.Text;
import h2d.Graphics;
import h2d.Interactive;
import hxd.Event;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Ice Climber: Doodle Jump style. Pule de plataforma em plataforma
	subindo infinitamente. Tilt/drag para mover horizontalmente.
	Plataformas especiais, monstros e power-ups conforme sobe.
**/
class IceClimber implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;

	// Physics
	static var JUMP_FORCE = -420.0;
	static var GRAVITY = 800.0;
	static var MOVE_SPEED = 220.0;
	static var MAX_FALL_SPEED = 500.0;
	static var PLAYER_W = 24.0;
	static var PLAYER_H = 30.0;
	static var PLAT_W = 60.0;
	static var PLAT_H = 10.0;
	static var SPRING_JUMP = -620.0;

	// Generation
	static var PLAT_SPACING_MIN = 50.0;
	static var PLAT_SPACING_MAX = 90.0;
	static var INITIAL_PLATFORMS = 12;
	static var SCREEN_TOP_MARGIN = 80.0;

	final contentObj:h2d.Object;
	var ctx:MinigameContext;

	var gameG:Graphics;
	var bgG:Graphics;
	var hudG:Graphics;
	var interactive:Interactive;

	var scoreText:Text;
	var heightText:Text;

	// Player state
	var playerX:Float;
	var playerY:Float;
	var playerVx:Float;
	var playerVy:Float;
	var playerFacing:Int; // 1 = right, -1 = left
	var isJumping:Bool;
	var playerAlive:Bool;

	// Camera
	var cameraY:Float;
	var highestY:Float;

	// Platforms
	var platforms:Array<Platform>;
	var nextPlatY:Float;

	// Monsters
	var monsters:Array<Monster>;

	// Particles (stars on jump, trail)
	var particles:Array<Particle>;

	// Input
	var touching:Bool;
	var touchX:Float;
	var touchStartX:Float;
	var playerTargetVx:Float;

	// Game
	var score:Int;
	var maxHeight:Float;
	var started:Bool;
	var gameOver:Bool;
	var difficulty:Float; // 0..1 ramps up with height

	// Visual
	var bgStars:Array<{x:Float, y:Float, size:Float, bright:Float}>;
	var snowflakes:Array<{x:Float, y:Float, vx:Float, vy:Float, size:Float}>;
	var jumpSquash:Float;
	var landBounce:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new h2d.Object();
		contentObj.visible = false;

		bgG = new Graphics(contentObj);
		gameG = new Graphics(contentObj);
		hudG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.textAlign = Right;
		scoreText.x = DESIGN_W - 14;
		scoreText.y = 22;
		scoreText.scale(2.0);
		scoreText.textColor = 0xFFFFFF;

		heightText = new Text(hxd.res.DefaultFont.get(), contentObj);
		heightText.textAlign = Left;
		heightText.x = 14;
		heightText.y = 12;
		heightText.scale(0.9);
		heightText.textColor = 0x99CCFF;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e:Event) {
			touching = true;
			touchX = e.relX;
			touchStartX = e.relX;
			if (!started)
				started = true;
			e.propagate = false;
		};
		interactive.onMove = function(e:Event) {
			if (touching)
				touchX = e.relX;
		};
		interactive.onRelease = function(e:Event) {
			touching = false;
			playerTargetVx = 0;
		};
		interactive.onReleaseOutside = function(e:Event) {
			touching = false;
			playerTargetVx = 0;
		};

		platforms = [];
		monsters = [];
		particles = [];
		bgStars = [];
		snowflakes = [];

		playerX = DESIGN_W / 2;
		playerY = 0;
		playerVx = 0;
		playerVy = 0;
		playerFacing = 1;
		isJumping = false;
		playerAlive = true;
		cameraY = 0;
		highestY = 0;
		nextPlatY = 0;
		touching = false;
		touchX = 0;
		touchStartX = 0;
		playerTargetVx = 0;
		score = 0;
		maxHeight = 0;
		started = false;
		gameOver = false;
		difficulty = 0;
		jumpSquash = 0;
		landBounce = 0;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		score = 0;
		maxHeight = 0;
		started = false;
		gameOver = false;
		playerAlive = true;
		difficulty = 0;
		jumpSquash = 0;
		landBounce = 0;

		playerX = DESIGN_W / 2;
		playerY = DESIGN_H - 80;
		playerVx = 0;
		playerVy = 0;
		playerFacing = 1;
		cameraY = 0;
		highestY = playerY;

		platforms = [];
		monsters = [];
		particles = [];

		// Starting platform under player
		platforms.push({
			x: DESIGN_W / 2 - PLAT_W / 2,
			y: DESIGN_H - 50,
			w: PLAT_W * 1.3,
			type: PNormal,
			timer: 0,
			broken: false,
			hasSpring: false,
			hasCoin: true,
			coinCollected: false
		});

		// Generate initial platforms
		nextPlatY = DESIGN_H - 120;
		var i = 0;
		while (i < INITIAL_PLATFORMS) {
			generatePlatform();
			i++;
		}

		// Generate bg stars
		bgStars = [];
		var si = 0;
		while (si < 40) {
			bgStars.push({
				x: Math.random() * DESIGN_W,
				y: Math.random() * DESIGN_H * 3,
				size: 1 + Math.random() * 2,
				bright: 0.3 + Math.random() * 0.7
			});
			si++;
		}

		// Snowflakes
		snowflakes = [];
		var fi = 0;
		while (fi < 20) {
			snowflakes.push({
				x: Math.random() * DESIGN_W,
				y: Math.random() * DESIGN_H,
				vx: -15 + Math.random() * 30,
				vy: 20 + Math.random() * 40,
				size: 1 + Math.random() * 3
			});
			fi++;
		}

		scoreText.text = "0";
		heightText.text = "0m";
		drawAll();
	}

	public function dispose() {
		ctx = null;
	}

	public function getMinigameId():String
		return "ice-climber";

	public function getTitle():String
		return "Ice Climber";

	// --- Platform Generation ---

	function generatePlatform() {
		var x = 10 + Math.random() * (DESIGN_W - PLAT_W - 20);
		var spacing = PLAT_SPACING_MIN + Math.random() * (PLAT_SPACING_MAX - PLAT_SPACING_MIN);
		// Increase spacing slightly with difficulty
		spacing += difficulty * 20;
		nextPlatY -= spacing;

		var type:PlatType = PNormal;
		var r = Math.random();

		if (difficulty > 0.15 && r < 0.12) {
			type = PBreaking;
		} else if (difficulty > 0.3 && r < 0.22) {
			type = PMoving;
		} else if (difficulty > 0.5 && r < 0.08) {
			type = PIcy;
		}

		var hasSpring = difficulty > 0.1 && Math.random() < 0.08;
		var hasCoin = Math.random() < 0.3;
		var w = PLAT_W;
		if (difficulty > 0.4)
			w = PLAT_W - difficulty * 10;
		if (w < 40)
			w = 40;

		platforms.push({
			x: x,
			y: nextPlatY,
			w: w,
			type: type,
			timer: Math.random() * 6.28, // phase for moving platforms
			broken: false,
			hasSpring: hasSpring,
			hasCoin: hasCoin,
			coinCollected: false
		});

		// Monsters
		if (difficulty > 0.25 && Math.random() < 0.06) {
			monsters.push({
				x: 10 + Math.random() * (DESIGN_W - 30),
				y: nextPlatY - 40 - Math.random() * 30,
				vx: 30 + Math.random() * 40,
				w: 22,
				h: 22,
				alive: true
			});
		}
	}

	// --- Update ---

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started) {
			drawAll();
			return;
		}

		// Cap dt to avoid physics explosions
		if (dt > 0.05)
			dt = 0.05;

		updateInput(dt);
		updatePlayer(dt);
		updatePlatforms(dt);
		updateMonsters(dt);
		updateParticles(dt);
		updateCamera(dt);
		updateSnowflakes(dt);
		checkDeath();

		// Update difficulty based on height
		difficulty = Math.min(maxHeight / 8000, 1.0);

		// Generate new platforms as we climb
		while (nextPlatY > cameraY - DESIGN_H * 0.5) {
			generatePlatform();
		}

		// Remove platforms/monsters far below
		cleanupOffscreen();

		drawAll();
	}

	function updateInput(dt:Float) {
		if (touching) {
			// Drag from center = direction
			var dx = touchX - DESIGN_W / 2;
			playerTargetVx = (dx / (DESIGN_W / 2)) * MOVE_SPEED;
			if (playerTargetVx > 0)
				playerFacing = 1;
			else if (playerTargetVx < 0)
				playerFacing = -1;
		} else {
			playerTargetVx = 0;
		}
	}

	function updatePlayer(dt:Float) {
		// Smooth horizontal movement
		playerVx += (playerTargetVx - playerVx) * Math.min(1, 12 * dt);

		// Gravity
		playerVy += GRAVITY * dt;
		if (playerVy > MAX_FALL_SPEED)
			playerVy = MAX_FALL_SPEED;

		playerX += playerVx * dt;
		playerY += playerVy * dt;

		// Wrap horizontally
		if (playerX < -PLAYER_W / 2)
			playerX = DESIGN_W + PLAYER_W / 2;
		else if (playerX > DESIGN_W + PLAYER_W / 2)
			playerX = -PLAYER_W / 2;

		// Squash/stretch animation
		if (jumpSquash > 0) {
			jumpSquash -= dt * 5;
			if (jumpSquash < 0)
				jumpSquash = 0;
		}
		if (landBounce > 0) {
			landBounce -= dt * 6;
			if (landBounce < 0)
				landBounce = 0;
		}

		// Platform collision (only when falling)
		if (playerVy > 0) {
			for (p in platforms) {
				if (p.broken)
					continue;
				var px = p.x;
				if (p.type == PMoving)
					px = p.x + Math.sin(p.timer) * 50;

				var playerBottom = playerY + PLAYER_H / 2;
				var prevBottom = playerBottom - playerVy * dt;

				if (playerX + PLAYER_W / 2 > px && playerX - PLAYER_W / 2 < px + p.w) {
					if (prevBottom <= p.y && playerBottom >= p.y) {
						// Land on platform
						playerY = p.y - PLAYER_H / 2;

						if (p.type == PBreaking) {
							p.broken = true;
							spawnParticles(playerX, p.y, 0x8ECAE6, 6);
							if (ctx != null && ctx.feedback != null)
								ctx.feedback.shake2D(0.05, 1);
							continue;
						}

						if (p.hasSpring && !p.broken) {
							playerVy = SPRING_JUMP;
							jumpSquash = 1.0;
							spawnParticles(playerX, playerY + PLAYER_H / 2, 0xFF6B6B, 8);
							if (ctx != null && ctx.feedback != null)
								ctx.feedback.shake2D(0.06, 2);
						} else {
							playerVy = JUMP_FORCE;
							jumpSquash = 0.6;
							landBounce = 1.0;
						}

						if (p.type == PIcy) {
							playerVx += (Math.random() - 0.5) * 150;
						}

						if (p.hasCoin && !p.coinCollected) {
							p.coinCollected = true;
							score += 5;
							spawnParticles(px + p.w / 2, p.y - 15, 0xFFD700, 5);
						}

						spawnParticles(playerX, playerY + PLAYER_H / 2, 0xFFFFFF, 3);
					}
				}
			}
		}

		// Update height score
		var height = (DESIGN_H - 80 - playerY);
		if (height > maxHeight) {
			maxHeight = height;
			score = Std.int(maxHeight / 10);
			scoreText.text = Std.string(score);
			heightText.text = Std.int(maxHeight / 20) + "m";
		}
	}

	function updatePlatforms(dt:Float) {
		for (p in platforms) {
			if (p.type == PMoving) {
				p.timer += dt * 1.8;
			}
		}
	}

	function updateMonsters(dt:Float) {
		for (m in monsters) {
			if (!m.alive)
				continue;
			m.x += m.vx * dt;
			if (m.x < 0 || m.x > DESIGN_W - m.w)
				m.vx = -m.vx;

			// Collision with player
			if (playerAlive) {
				var dx = Math.abs(playerX - (m.x + m.w / 2));
				var dy = Math.abs(playerY - (m.y + m.h / 2));
				if (dx < (PLAYER_W + m.w) / 2 && dy < (PLAYER_H + m.h) / 2) {
					// If falling onto monster from above, kill it
					if (playerVy > 0 && playerY < m.y) {
						m.alive = false;
						playerVy = JUMP_FORCE * 0.8;
						score += 20;
						scoreText.text = Std.string(score);
						spawnParticles(m.x + m.w / 2, m.y + m.h / 2, 0xFF4444, 10);
						if (ctx != null && ctx.feedback != null)
							ctx.feedback.shake2D(0.1, 3);
					} else {
						// Hit by monster
						playerAlive = false;
						playerVy = -200;
						if (ctx != null && ctx.feedback != null)
							ctx.feedback.shake2D(0.3, 5);
					}
				}
			}
		}
	}

	function updateCamera(dt:Float) {
		// Camera follows player upward, never goes back down
		var targetCam = playerY - DESIGN_H * 0.35;
		if (targetCam < cameraY) {
			cameraY += (targetCam - cameraY) * Math.min(1, 8 * dt);
		}
	}

	function updateParticles(dt:Float) {
		var i = particles.length - 1;
		while (i >= 0) {
			var p = particles[i];
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vy += 200 * dt;
			p.life -= dt;
			if (p.life <= 0)
				particles.splice(i, 1);
			i--;
		}
	}

	function updateSnowflakes(dt:Float) {
		for (s in snowflakes) {
			s.x += s.vx * dt;
			s.y += s.vy * dt;
			if (s.y > DESIGN_H + 10) {
				s.y = -5;
				s.x = Math.random() * DESIGN_W;
			}
			if (s.x < -5)
				s.x = DESIGN_W + 5;
			if (s.x > DESIGN_W + 5)
				s.x = -5;
		}
	}

	function checkDeath() {
		if (!playerAlive) {
			gameOver = true;
			if (ctx != null) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			return;
		}
		// Fell below screen
		if (playerY > cameraY + DESIGN_H + 50) {
			gameOver = true;
			if (ctx != null) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
		}
	}

	function cleanupOffscreen() {
		var bottomLimit = cameraY + DESIGN_H + 200;
		var i = platforms.length - 1;
		while (i >= 0) {
			if (platforms[i].y > bottomLimit)
				platforms.splice(i, 1);
			i--;
		}
		i = monsters.length - 1;
		while (i >= 0) {
			if (monsters[i].y > bottomLimit || !monsters[i].alive)
				monsters.splice(i, 1);
			i--;
		}
	}

	function spawnParticles(x:Float, y:Float, color:Int, count:Int) {
		var i = 0;
		while (i < count) {
			var angle = Math.random() * Math.PI * 2;
			var speed = 40 + Math.random() * 100;
			particles.push({
				x: x,
				y: y,
				vx: Math.cos(angle) * speed,
				vy: Math.sin(angle) * speed - 50,
				life: 0.4 + Math.random() * 0.4,
				maxLife: 0.8,
				color: color,
				size: 2 + Math.random() * 3
			});
			i++;
		}
	}

	// --- Drawing ---

	function drawAll() {
		drawBackground();
		drawGame();
		drawHud();
	}

	function drawBackground() {
		bgG.clear();

		// Gradient background - darker as you go higher
		var heightPct = Math.min(maxHeight / 5000, 1.0);
		var topR = Std.int(0x0A * (1 - heightPct * 0.5));
		var topG2 = Std.int(0x0F + heightPct * 0x05);
		var topB = Std.int(0x2E + heightPct * 0x15);
		var topColor = (topR << 16) | (topG2 << 8) | topB;

		bgG.beginFill(topColor);
		bgG.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bgG.endFill();

		// Bottom gradient (lighter)
		var gradH = DESIGN_H * 0.4;
		var steps = 8;
		var si = 0;
		while (si < steps) {
			var t = si / steps;
			var alpha = (1 - t) * 0.15;
			bgG.beginFill(0x1A3A5C, alpha);
			bgG.drawRect(0, DESIGN_H - gradH + t * gradH, DESIGN_W, gradH / steps + 1);
			bgG.endFill();
			si++;
		}

		// Stars (parallax)
		for (star in bgStars) {
			var sy = star.y - cameraY * 0.15;
			sy = sy % (DESIGN_H * 3);
			if (sy < 0)
				sy += DESIGN_H * 3;
			if (sy > DESIGN_H)
				continue;
			var twinkle = (Math.sin(star.bright * 10 + cameraY * 0.01) + 1) * 0.5;
			bgG.beginFill(0xFFFFFF, star.bright * 0.3 + twinkle * 0.3);
			bgG.drawCircle(star.x, sy, star.size);
			bgG.endFill();
		}

		// Snowflakes
		for (s in snowflakes) {
			bgG.beginFill(0xFFFFFF, 0.4);
			bgG.drawCircle(s.x, s.y, s.size);
			bgG.endFill();
		}
	}

	function drawGame() {
		gameG.clear();

		// Platforms
		for (p in platforms) {
			if (p.broken)
				continue;
			var px = p.x;
			if (p.type == PMoving)
				px = p.x + Math.sin(p.timer) * 50;

			var sy = p.y - cameraY;
			if (sy < -20 || sy > DESIGN_H + 20)
				continue;

			switch (p.type) {
				case PNormal:
					// Main platform body
					gameG.beginFill(0x4ECDC4, 1.0);
					gameG.drawRoundedRect(px, sy, p.w, PLAT_H, 5);
					gameG.endFill();
					// Top highlight
					gameG.beginFill(0x7EDCD6, 1.0);
					gameG.drawRoundedRect(px + 2, sy, p.w - 4, 3, 2);
					gameG.endFill();
					// Snow on top
					gameG.beginFill(0xFFFFFF, 0.7);
					gameG.drawRoundedRect(px + 4, sy - 2, p.w - 8, 4, 3);
					gameG.endFill();

				case PBreaking:
					// Cracked look
					gameG.beginFill(0x8ECAE6, 0.7);
					gameG.drawRoundedRect(px, sy, p.w, PLAT_H, 4);
					gameG.endFill();
					// Crack lines
					gameG.lineStyle(1, 0x5AA3C7, 0.6);
					gameG.moveTo(px + p.w * 0.3, sy);
					gameG.lineTo(px + p.w * 0.4, sy + PLAT_H);
					gameG.moveTo(px + p.w * 0.7, sy);
					gameG.lineTo(px + p.w * 0.6, sy + PLAT_H);
					gameG.lineStyle(0);

				case PMoving:
					gameG.beginFill(0xFFB347, 1.0);
					gameG.drawRoundedRect(px, sy, p.w, PLAT_H, 5);
					gameG.endFill();
					// Arrows
					gameG.beginFill(0xFFD280, 1.0);
					gameG.drawRoundedRect(px + 2, sy, p.w - 4, 3, 2);
					gameG.endFill();
					// Direction indicators
					gameG.beginFill(0xCC8030, 0.5);
					var arrowX = px + p.w / 2;
					gameG.moveTo(arrowX - 8, sy + 5);
					gameG.lineTo(arrowX - 3, sy + 3);
					gameG.lineTo(arrowX - 3, sy + 7);
					gameG.moveTo(arrowX + 8, sy + 5);
					gameG.lineTo(arrowX + 3, sy + 3);
					gameG.lineTo(arrowX + 3, sy + 7);
					gameG.endFill();

				case PIcy:
					gameG.beginFill(0xB8E0F7, 0.8);
					gameG.drawRoundedRect(px, sy, p.w, PLAT_H, 5);
					gameG.endFill();
					// Ice shine
					gameG.beginFill(0xFFFFFF, 0.4);
					gameG.drawRoundedRect(px + 5, sy + 1, p.w * 0.3, 3, 2);
					gameG.endFill();
					gameG.beginFill(0xFFFFFF, 0.25);
					gameG.drawRoundedRect(px + p.w * 0.5, sy + 2, p.w * 0.2, 2, 1);
					gameG.endFill();
			}

			// Spring
			if (p.hasSpring) {
				var sx = px + p.w / 2;
				// Spring coil
				gameG.beginFill(0xFF6B6B, 1.0);
				gameG.drawRoundedRect(sx - 6, sy - 12, 12, 12, 3);
				gameG.endFill();
				gameG.beginFill(0xFF9999, 1.0);
				gameG.drawRoundedRect(sx - 4, sy - 10, 8, 3, 2);
				gameG.endFill();
				// Arrow up
				gameG.beginFill(0xFFFFFF, 0.7);
				gameG.moveTo(sx, sy - 14);
				gameG.lineTo(sx - 3, sy - 10);
				gameG.lineTo(sx + 3, sy - 10);
				gameG.endFill();
			}

			// Coin
			if (p.hasCoin && !p.coinCollected) {
				var coinX = px + p.w / 2;
				var coinY = sy - 18;
				var bobble = Math.sin(p.timer * 2 + px) * 3;
				gameG.beginFill(0xFFD700, 1.0);
				gameG.drawCircle(coinX, coinY + bobble, 6);
				gameG.endFill();
				gameG.beginFill(0xFFF176, 1.0);
				gameG.drawCircle(coinX - 1, coinY + bobble - 1, 3);
				gameG.endFill();
			}
		}

		// Monsters
		for (m in monsters) {
			if (!m.alive)
				continue;
			var my = m.y - cameraY;
			if (my < -30 || my > DESIGN_H + 30)
				continue;

			// Body
			gameG.beginFill(0xE74C3C, 1.0);
			gameG.drawRoundedRect(m.x, my, m.w, m.h, 6);
			gameG.endFill();

			// Eyes
			gameG.beginFill(0xFFFFFF, 1.0);
			gameG.drawCircle(m.x + m.w * 0.3, my + m.h * 0.35, 4);
			gameG.drawCircle(m.x + m.w * 0.7, my + m.h * 0.35, 4);
			gameG.endFill();
			gameG.beginFill(0x000000, 1.0);
			var eyeDir = m.vx > 0 ? 1 : -1;
			gameG.drawCircle(m.x + m.w * 0.3 + eyeDir * 1.5, my + m.h * 0.35, 2);
			gameG.drawCircle(m.x + m.w * 0.7 + eyeDir * 1.5, my + m.h * 0.35, 2);
			gameG.endFill();

			// Angry mouth
			gameG.lineStyle(1.5, 0x000000, 0.8);
			gameG.moveTo(m.x + m.w * 0.3, my + m.h * 0.7);
			gameG.lineTo(m.x + m.w * 0.5, my + m.h * 0.6);
			gameG.lineTo(m.x + m.w * 0.7, my + m.h * 0.7);
			gameG.lineStyle(0);

			// Spikes on top
			var spikes = 3;
			var spi = 0;
			while (spi < spikes) {
				var spikeX = m.x + (spi + 0.5) * (m.w / spikes);
				gameG.beginFill(0xC0392B, 1.0);
				gameG.moveTo(spikeX - 3, my);
				gameG.lineTo(spikeX, my - 5);
				gameG.lineTo(spikeX + 3, my);
				gameG.endFill();
				spi++;
			}
		}

		// Particles
		for (p in particles) {
			var py = p.y - cameraY;
			if (py < -10 || py > DESIGN_H + 10)
				continue;
			var alpha = p.life / p.maxLife;
			gameG.beginFill(p.color, alpha);
			gameG.drawCircle(p.x, py, p.size * alpha);
			gameG.endFill();
		}

		// Player
		if (playerAlive) {
			var py = playerY - cameraY;
			var halfW = PLAYER_W / 2;
			var halfH = PLAYER_H / 2;

			// Squash/stretch
			var scaleX = 1.0;
			var scaleY = 1.0;
			if (jumpSquash > 0) {
				scaleX = 1.0 + jumpSquash * 0.15;
				scaleY = 1.0 - jumpSquash * 0.15;
			}
			if (landBounce > 0) {
				scaleX = 1.0 + landBounce * 0.1;
				scaleY = 1.0 - landBounce * 0.1;
			}

			var drawW = halfW * scaleX;
			var drawH = halfH * scaleY;

			// Shadow under player
			gameG.beginFill(0x000000, 0.15);
			gameG.drawEllipse(playerX, py + drawH + 2, drawW * 0.8, 3);
			gameG.endFill();

			// Body (rounded blob)
			gameG.beginFill(0x5B86E5, 1.0);
			gameG.drawRoundedRect(playerX - drawW, py - drawH, drawW * 2, drawH * 2, 8);
			gameG.endFill();

			// Belly
			gameG.beginFill(0x8BB4F0, 1.0);
			gameG.drawRoundedRect(playerX - drawW * 0.6, py - drawH * 0.3, drawW * 1.2, drawH * 1.0, 6);
			gameG.endFill();

			// Eyes
			var eyeOffX = playerFacing * 2;
			gameG.beginFill(0xFFFFFF, 1.0);
			gameG.drawCircle(playerX - 5 + eyeOffX, py - drawH * 0.3, 5);
			gameG.drawCircle(playerX + 5 + eyeOffX, py - drawH * 0.3, 5);
			gameG.endFill();

			// Pupils
			gameG.beginFill(0x1A1A2E, 1.0);
			gameG.drawCircle(playerX - 5 + eyeOffX + playerFacing * 2, py - drawH * 0.3, 2.5);
			gameG.drawCircle(playerX + 5 + eyeOffX + playerFacing * 2, py - drawH * 0.3, 2.5);
			gameG.endFill();

			// Mouth
			if (playerVy < -100) {
				// Happy jumping face - open mouth
				gameG.beginFill(0xFF6B6B, 0.8);
				gameG.drawCircle(playerX + eyeOffX, py + drawH * 0.15, 3.5);
				gameG.endFill();
			} else {
				// Smile
				gameG.lineStyle(1.5, 0x3A5AA0, 0.8);
				var mouthX = playerX + eyeOffX;
				var mouthY = py + drawH * 0.2;
				gameG.moveTo(mouthX - 4, mouthY);
				gameG.lineTo(mouthX - 2, mouthY + 2);
				gameG.lineTo(mouthX + 2, mouthY + 2);
				gameG.lineTo(mouthX + 4, mouthY);
				gameG.lineStyle(0);
			}

			// Ice pick / hat
			gameG.beginFill(0xE74C3C, 1.0);
			gameG.drawRoundedRect(playerX - drawW * 0.7, py - drawH - 3, drawW * 1.4, 6, 3);
			gameG.endFill();
			// Hat top
			gameG.beginFill(0xC0392B, 1.0);
			gameG.drawRoundedRect(playerX - drawW * 0.4, py - drawH - 8, drawW * 0.8, 7, 3);
			gameG.endFill();

			// Feet
			var footBob = Math.sin(cameraY * 0.1) * 2;
			gameG.beginFill(0x3A5AA0, 1.0);
			gameG.drawRoundedRect(playerX - drawW * 0.7, py + drawH - 3 + footBob, 8, 6, 3);
			gameG.drawRoundedRect(playerX + drawW * 0.7 - 8, py + drawH - 3 - footBob, 8, 6, 3);
			gameG.endFill();
		}
	}

	function drawHud() {
		hudG.clear();

		// Score bg
		hudG.beginFill(0x000000, 0.35);
		hudG.drawRoundedRect(DESIGN_W - 70, 14, 60, 38, 8);
		hudG.endFill();

		// Height label bg
		hudG.beginFill(0x000000, 0.25);
		hudG.drawRoundedRect(8, 8, 55, 22, 6);
		hudG.endFill();

		// Instruction at start
		if (!started) {
			hudG.beginFill(0x000000, 0.4);
			hudG.drawRoundedRect(DESIGN_W / 2 - 90, DESIGN_H / 2 + 40, 180, 30, 8);
			hudG.endFill();
		}
	}
}

// --- Types ---

private typedef Platform = {
	x:Float,
	y:Float,
	w:Float,
	type:PlatType,
	timer:Float,
	broken:Bool,
	hasSpring:Bool,
	hasCoin:Bool,
	coinCollected:Bool
};

private typedef Monster = {
	x:Float,
	y:Float,
	vx:Float,
	w:Float,
	h:Float,
	alive:Bool
};

private typedef Particle = {
	x:Float,
	y:Float,
	vx:Float,
	vy:Float,
	life:Float,
	maxLife:Float,
	color:Int,
	size:Float
};

private enum PlatType {
	PNormal;
	PBreaking;
	PMoving;
	PIcy;
}
