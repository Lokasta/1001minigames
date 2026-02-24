package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class PacMan implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var TILE = 20;
	static var COLS = 15;
	static var ROWS = 19;
	static var OFFSET_X = 30;
	static var OFFSET_Y = 130;
	static var PAC_SPEED = 80.0;
	static var GHOST_SPEED = 65.0;
	static var GHOST_SCARED_SPEED = 40.0;
	static var POWER_DURATION = 6.0;
	static var SWIPE_MIN = 15.0;

	static var MAZE:Array<String> = [
		"###############",
		"#......#......#",
		"#.##.#.#.#.##.#",
		"#o#...........#",
		"#.#.##.#.##.#.#",
		"#......#......#",
		"###.##.#.##.###",
		"   .#.....#.   ",
		"###.#..G..#.###",
		"#......#......#",
		"#.##.#.#.#.##.#",
		"#..#...P...#..#",
		"##.#.#.#.#.#.##",
		"#......#......#",
		"#.#.##...##.#.#",
		"#o#...........#",
		"#.##.#.#.#.##.#",
		"#......#......#",
		"###############",
	];

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gameG:Graphics;
	var scoreText:Text;
	var interactive:Interactive;

	var pacX:Float;
	var pacY:Float;
	var pacDir:Int; // 0=right,1=down,2=left,3=up
	var nextDir:Int;
	var mouthAnim:Float;
	var score:Int;
	var gameOver:Bool;
	var started:Bool;
	var totalDots:Int;

	var touchStartX:Float;
	var touchStartY:Float;
	var touching:Bool;

	var powerTimer:Float;

	var ghosts:Array<{x:Float, y:Float, dir:Int, color:Int, scared:Bool, respawnTimer:Float, lastTx:Int, lastTy:Int}>;
	var dots:Array<Array<Int>>; // 0=empty, 1=dot, 2=power
	var walls:Array<Array<Bool>>;

	var ghostStartX:Int;
	var ghostStartY:Int;

	var rng:hxd.Rand;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		rng = new hxd.Rand(77);

		bg = new Graphics(contentObj);
		bg.beginFill(0x0A0A1A);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();

		gameG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = DESIGN_W / 2 - 20;
		scoreText.y = 30;
		scoreText.scale(2.0);

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(e) {
			if (gameOver || ctx == null)
				return;
			if (!started)
				started = true;
			touching = true;
			touchStartX = e.relX;
			touchStartY = e.relY;
		};
		interactive.onRelease = function(e) {
			if (!touching)
				return;
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist >= SWIPE_MIN) {
				if (Math.abs(dx) > Math.abs(dy)) {
					nextDir = dx > 0 ? 0 : 2;
				} else {
					nextDir = dy > 0 ? 1 : 3;
				}
			}
			touching = false;
		};
		interactive.onReleaseOutside = function(e) {
			if (!touching)
				return;
			var dx = e.relX - touchStartX;
			var dy = e.relY - touchStartY;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist >= SWIPE_MIN) {
				if (Math.abs(dx) > Math.abs(dy)) {
					nextDir = dx > 0 ? 0 : 2;
				} else {
					nextDir = dy > 0 ? 1 : 3;
				}
			}
			touching = false;
		};

		// Parse maze
		walls = [];
		dots = [];
		ghostStartX = 7;
		ghostStartY = 8;
		totalDots = 0;
		pacX = 7;
		pacY = 11;

		for (row in 0...ROWS) {
			walls.push([]);
			dots.push([]);
			var line = MAZE[row];
			for (col in 0...COLS) {
				var ch = line.charAt(col);
				switch (ch) {
					case "#":
						walls[row].push(true);
						dots[row].push(0);
					case ".":
						walls[row].push(false);
						dots[row].push(1);
						totalDots++;
					case "o":
						walls[row].push(false);
						dots[row].push(2);
						totalDots++;
					case "P":
						walls[row].push(false);
						dots[row].push(0);
						pacX = col;
						pacY = row;
					case "G":
						walls[row].push(false);
						dots[row].push(0);
						ghostStartX = col;
						ghostStartY = row;
					default:
						walls[row].push(false);
						dots[row].push(0);
				}
			}
		}

		ghosts = [];
		pacDir = 2;
		nextDir = 2;
		mouthAnim = 0;
		score = 0;
		gameOver = true;
		started = false;
		powerTimer = 0;
		touching = false;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	function isWall(col:Int, row:Int):Bool {
		// Tunnel wrapping
		if (col < 0 || col >= COLS) return false;
		if (row < 0 || row >= ROWS) return true;
		return walls[row][col];
	}

	function dirDx(d:Int):Int {
		return d == 0 ? 1 : (d == 2 ? -1 : 0);
	}

	function dirDy(d:Int):Int {
		return d == 1 ? 1 : (d == 3 ? -1 : 0);
	}

	function canMove(tileX:Int, tileY:Int, dir:Int):Bool {
		var nx = tileX + dirDx(dir);
		var ny = tileY + dirDy(dir);
		// Tunnel
		if (nx < 0 || nx >= COLS) return true;
		return !isWall(nx, ny);
	}

	function wrapX(x:Float):Float {
		if (x < -0.5) return x + COLS;
		if (x >= COLS - 0.5) return x - COLS;
		return x;
	}

	public function start() {
		// Reset dots from maze
		totalDots = 0;
		for (row in 0...ROWS) {
			for (col in 0...COLS) {
				var ch = MAZE[row].charAt(col);
				switch (ch) {
					case ".":
						dots[row][col] = 1;
						totalDots++;
					case "o":
						dots[row][col] = 2;
						totalDots++;
					default:
						dots[row][col] = 0;
				}
			}
		}

		pacX = 7;
		pacY = 11;
		pacDir = 2;
		nextDir = 2;
		mouthAnim = 0;
		score = 0;
		gameOver = false;
		started = false;
		powerTimer = 0;
		touching = false;
		scoreText.text = "0";

		ghosts = [];
		var ghostColors = [0xFF0000, 0xFFB8FF, 0x00FFFF];
		var offsets = [-1, 0, 1];
		for (i in 0...3) {
			var gx = ghostStartX + offsets[i];
			ghosts.push({
				x: gx * 1.0,
				y: ghostStartY * 1.0,
				dir: 3,
				color: ghostColors[i],
				scared: false,
				respawnTimer: 0,
				lastTx: -1,
				lastTy: -1
			});
		}

		draw();
	}

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started) {
			draw();
			return;
		}

		mouthAnim += dt * 8;

		// Power timer
		if (powerTimer > 0) {
			powerTimer -= dt;
			if (powerTimer <= 0) {
				powerTimer = 0;
				for (g in ghosts) g.scared = false;
			}
		}

		// Move pac-man
		movePac(dt);

		// Move ghosts
		for (g in ghosts) {
			if (g.respawnTimer > 0) {
				g.respawnTimer -= dt;
				if (g.respawnTimer <= 0) {
					g.x = ghostStartX;
					g.y = ghostStartY;
					g.dir = 3;
					g.respawnTimer = 0;
					g.lastTx = -1;
					g.lastTy = -1;
				}
				continue;
			}
			moveGhost(g, dt);
		}

		// Eat dots
		var tileX = Math.round(pacX);
		var tileY = Math.round(pacY);
		if (tileX >= 0 && tileX < COLS && tileY >= 0 && tileY < ROWS) {
			var d = dots[tileY][tileX];
			if (d == 1) {
				dots[tileY][tileX] = 0;
				score++;
				scoreText.text = Std.string(score);
			} else if (d == 2) {
				dots[tileY][tileX] = 0;
				score++;
				scoreText.text = Std.string(score);
				// Power mode
				powerTimer = POWER_DURATION;
				for (g in ghosts) g.scared = true;
				if (ctx != null && ctx.feedback != null)
					ctx.feedback.flash(0x4444FF, 0.15);
			}
		}

		// Check collisions pac vs ghosts
		for (g in ghosts) {
			if (g.respawnTimer > 0) continue;
			var dx = pacX - g.x;
			var dy = pacY - g.y;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist < 0.6) {
				if (g.scared) {
					// Eat ghost
					g.respawnTimer = 3.0;
					g.scared = false;
					score += 10;
					scoreText.text = Std.string(score);
					if (ctx != null && ctx.feedback != null)
						ctx.feedback.shake2D(0.1, 2);
				} else {
					endGame();
					return;
				}
			}
		}

		draw();
	}

	function movePac(dt:Float) {
		var speed = PAC_SPEED * dt / TILE;
		var tileX = Math.round(pacX);
		var tileY = Math.round(pacY);

		// At tile center, try to turn
		var distToCenter = Math.abs(pacX - tileX) + Math.abs(pacY - tileY);
		if (distToCenter < 0.15) {
			if (nextDir != pacDir && canMove(tileX, tileY, nextDir)) {
				pacDir = nextDir;
				pacX = tileX;
				pacY = tileY;
			}
		}

		// Move in current direction
		var nx = pacX + dirDx(pacDir) * speed;
		var ny = pacY + dirDy(pacDir) * speed;

		// Check wall ahead
		var nextTileX = tileX + dirDx(pacDir);
		var nextTileY = tileY + dirDy(pacDir);

		// Tunnel wrap
		if (nextTileX < 0 || nextTileX >= COLS) {
			pacX = nx;
			pacY = ny;
			pacX = wrapX(pacX);
			return;
		}

		if (isWall(nextTileX, nextTileY)) {
			// Don't go past center of current tile toward wall
			var centerX:Float = tileX;
			var centerY:Float = tileY;
			if (pacDir == 0 && nx > centerX) { pacX = centerX; return; }
			if (pacDir == 2 && nx < centerX) { pacX = centerX; return; }
			if (pacDir == 1 && ny > centerY) { pacY = centerY; return; }
			if (pacDir == 3 && ny < centerY) { pacY = centerY; return; }
		}

		pacX = nx;
		pacY = ny;
		pacX = wrapX(pacX);
	}

	function moveGhost(g:{x:Float, y:Float, dir:Int, color:Int, scared:Bool, respawnTimer:Float, lastTx:Int, lastTy:Int}, dt:Float) {
		var speed = (g.scared ? GHOST_SCARED_SPEED : GHOST_SPEED) * dt / TILE;
		var tileX = Math.round(g.x);
		var tileY = Math.round(g.y);

		var distToCenter = Math.abs(g.x - tileX) + Math.abs(g.y - tileY);
		var isNewTile = (tileX != g.lastTx || tileY != g.lastTy);

		if (distToCenter < 0.15 && isNewTile) {
			// Arrived at a new tile center — pick direction
			g.x = tileX;
			g.y = tileY;
			g.lastTx = tileX;
			g.lastTy = tileY;

			var dirs = [];
			var reverse = (g.dir + 2) % 4;
			for (d in 0...4) {
				if (d == reverse) continue;
				if (canMove(tileX, tileY, d)) dirs.push(d);
			}

			if (dirs.length == 0) {
				if (canMove(tileX, tileY, reverse))
					dirs.push(reverse);
				else
					return;
			}

			if (g.scared) {
				// Flee: pick direction that maximizes distance from pac-man
				if (rng.rand() < 0.7) {
					var bestDir = dirs[0];
					var bestDist = -1.0;
					for (d in dirs) {
						var fnx = tileX + dirDx(d);
						var fny = tileY + dirDy(d);
						var fdx = fnx - pacX;
						var fdy = fny - pacY;
						var dist = fdx * fdx + fdy * fdy;
						if (dist > bestDist) {
							bestDist = dist;
							bestDir = d;
						}
					}
					g.dir = bestDir;
				} else {
					g.dir = dirs[rng.random(dirs.length)];
				}
			} else {
				// Chase: 50% bias toward pac-man, 50% random
				if (rng.rand() < 0.5) {
					var bestDir = dirs[0];
					var bestDist = 999.0;
					for (d in dirs) {
						var cnx = tileX + dirDx(d);
						var cny = tileY + dirDy(d);
						var cdx = cnx - pacX;
						var cdy = cny - pacY;
						var dist = cdx * cdx + cdy * cdy;
						if (dist < bestDist) {
							bestDist = dist;
							bestDir = d;
						}
					}
					g.dir = bestDir;
				} else {
					g.dir = dirs[rng.random(dirs.length)];
				}
			}
		}

		// Move
		var nx = g.x + dirDx(g.dir) * speed;
		var ny = g.y + dirDy(g.dir) * speed;

		// Tunnel wrap
		var nextTileX = tileX + dirDx(g.dir);
		if (nextTileX < 0 || nextTileX >= COLS) {
			g.x = nx;
			g.y = ny;
			if (g.x < -0.5) g.x += COLS;
			if (g.x >= COLS - 0.5) g.x -= COLS;
			return;
		}

		var nextTileY = tileY + dirDy(g.dir);
		if (isWall(nextTileX, nextTileY)) {
			var centerX:Float = tileX;
			var centerY:Float = tileY;
			if (g.dir == 0 && nx > centerX) { g.x = centerX; return; }
			if (g.dir == 2 && nx < centerX) { g.x = centerX; return; }
			if (g.dir == 1 && ny > centerY) { g.y = centerY; return; }
			if (g.dir == 3 && ny < centerY) { g.y = centerY; return; }
		}

		g.x = nx;
		g.y = ny;
	}

	function endGame() {
		gameOver = true;
		if (ctx != null && ctx.feedback != null)
			ctx.feedback.shake2D(0.2, 4);
		ctx.lose(score, getMinigameId());
		ctx = null;
	}

	function tileToScreenX(tx:Float):Float {
		return OFFSET_X + tx * TILE + TILE / 2;
	}

	function tileToScreenY(ty:Float):Float {
		return OFFSET_Y + ty * TILE + TILE / 2;
	}

	function draw() {
		gameG.clear();

		// Draw walls
		for (row in 0...ROWS) {
			for (col in 0...COLS) {
				if (walls[row][col]) {
					gameG.beginFill(0x2244CC);
					gameG.drawRect(OFFSET_X + col * TILE + 1, OFFSET_Y + row * TILE + 1, TILE - 2, TILE - 2);
					gameG.endFill();
				}
			}
		}

		// Draw dots
		for (row in 0...ROWS) {
			for (col in 0...COLS) {
				var d = dots[row][col];
				if (d == 1) {
					gameG.beginFill(0xFFFFFF);
					gameG.drawCircle(tileToScreenX(col), tileToScreenY(row), 2);
					gameG.endFill();
				} else if (d == 2) {
					// Power pellet - pulsing
					var pulse = 4.0 + Math.sin(mouthAnim * 0.5) * 1.5;
					gameG.beginFill(0xFFFFFF);
					gameG.drawCircle(tileToScreenX(col), tileToScreenY(row), pulse);
					gameG.endFill();
				}
			}
		}

		// Draw ghosts
		for (g in ghosts) {
			if (g.respawnTimer > 0) continue;
			var gx = tileToScreenX(g.x);
			var gy = tileToScreenY(g.y);
			var color = g.scared ? 0x4444FF : g.color;
			// Body
			gameG.beginFill(color);
			gameG.drawCircle(gx, gy - 2, 8);
			gameG.drawRect(gx - 8, gy - 2, 16, 10);
			gameG.endFill();
			// Wavy bottom
			gameG.beginFill(color);
			for (i in 0...3) {
				gameG.drawCircle(gx - 6 + i * 6, gy + 8, 3);
			}
			gameG.endFill();
			// Eyes
			var eyeColor = g.scared ? 0xFFFFFF : 0xFFFFFF;
			gameG.beginFill(eyeColor);
			gameG.drawCircle(gx - 3, gy - 3, 3);
			gameG.drawCircle(gx + 3, gy - 3, 3);
			gameG.endFill();
			// Pupils
			if (!g.scared) {
				var pdx = dirDx(g.dir) * 1.5;
				var pdy = dirDy(g.dir) * 1.5;
				gameG.beginFill(0x000088);
				gameG.drawCircle(gx - 3 + pdx, gy - 3 + pdy, 1.5);
				gameG.drawCircle(gx + 3 + pdx, gy - 3 + pdy, 1.5);
				gameG.endFill();
			}
		}

		// Draw pac-man
		var px = tileToScreenX(pacX);
		var py = tileToScreenY(pacY);
		var mouthOpen = Math.abs(Math.sin(mouthAnim)) * 0.8;
		var angle = switch (pacDir) {
			case 0: 0.0;
			case 1: Math.PI / 2;
			case 2: Math.PI;
			case 3: -Math.PI / 2;
			default: 0.0;
		};

		// Draw as filled arc (circle with mouth wedge)
		gameG.beginFill(0xFFFF00);
		var segments = 20;
		var startAngle = angle + mouthOpen * 0.5;
		var endAngle = angle + Math.PI * 2 - mouthOpen * 0.5;
		var r = 9.0;
		gameG.moveTo(px, py);
		var step = (endAngle - startAngle) / segments;
		for (i in 0...segments + 1) {
			var a = startAngle + step * i;
			gameG.lineTo(px + Math.cos(a) * r, py + Math.sin(a) * r);
		}
		gameG.lineTo(px, py);
		gameG.endFill();

		// Power timer indicator
		if (powerTimer > 0) {
			var barW = 100.0 * (powerTimer / POWER_DURATION);
			gameG.beginFill(0x4444FF, 0.6);
			gameG.drawRect(DESIGN_W / 2 - 50, OFFSET_Y - 15, barW, 5);
			gameG.endFill();
		}

		// "Swipe to start" hint
		if (!started) {
			var hintText = new Text(hxd.res.DefaultFont.get(), gameG);
			hintText.text = "Swipe to start!";
			hintText.x = DESIGN_W / 2 - 45;
			hintText.y = OFFSET_Y + ROWS * TILE + 20;
			hintText.scale(1.2);
		}
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "pacman";

	public function getTitle():String
		return "Pac-Man";
}
