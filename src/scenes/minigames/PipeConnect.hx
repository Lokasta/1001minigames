package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

/**
	Pipe Connect — gire os canos para conectar a fonte até a saída antes da água chegar.
	Grid 5x5. Toque num cano para girar 90°. Água avança a cada tick.
**/
class PipeConnect implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var COLS = 5;
	static var ROWS = 5;
	static var CELL = 56;
	static var GAP = 4;
	static var GRID_TOP = 155;
	static var WATER_TICK = 0.6; // seconds between water advancing
	static var TIME_LIMIT = 30.0;

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var gridG:Graphics;
	var waterG:Graphics;
	var timerBarG:Graphics;
	var titleText:Text;
	var scoreText:Text;
	var levelText:Text;
	var hintText:Text;

	// Grid data
	var pipes:Array<PipeCell>;
	var cellInteractives:Array<Interactive>;

	// Game state
	var gameOver:Bool;
	var timeLeft:Float;
	var waterTimer:Float;
	var waterCells:Array<Bool>; // which cells have water
	var waterFrontier:Array<Int>; // cells to expand from next tick
	var score:Int;
	var level:Int;
	var sourceIdx:Int; // left edge, middle row
	var sinkIdx:Int; // right edge, middle row
	var completed:Bool; // path connected
	var rng:hxd.Rand;

	// Rotate animation
	var rotateAnims:Array<{idx:Int, fromRot:Int, progress:Float}>;

	// Win flash
	var winFlashTimer:Float;

	public var content(get, never):Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new Object();
		contentObj.visible = false;

		bg = new Graphics(contentObj);
		drawBackground();

		titleText = new Text(hxd.res.DefaultFont.get(), contentObj);
		titleText.text = "PIPE CONNECT";
		titleText.textAlign = Center;
		titleText.x = DESIGN_W / 2;
		titleText.y = 20;
		titleText.scale(1.8);
		titleText.textColor = 0xFFFFFF;

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.textAlign = Center;
		scoreText.x = DESIGN_W / 2;
		scoreText.y = 55;
		scoreText.scale(2.0);
		scoreText.textColor = 0x44DDFF;

		levelText = new Text(hxd.res.DefaultFont.get(), contentObj);
		levelText.text = "Level 1";
		levelText.textAlign = Center;
		levelText.x = DESIGN_W / 2;
		levelText.y = 85;
		levelText.textColor = 0x9BA4C4;

		timerBarG = new Graphics(contentObj);

		hintText = new Text(hxd.res.DefaultFont.get(), contentObj);
		hintText.text = "Tap pipes to rotate!";
		hintText.textAlign = Center;
		hintText.x = DESIGN_W / 2;
		hintText.y = DESIGN_H - 60;
		hintText.textColor = 0x667788;

		gridG = new Graphics(contentObj);
		waterG = new Graphics(contentObj);

		pipes = [];
		cellInteractives = [];
		rotateAnims = [];
		waterCells = [];
		waterFrontier = [];

		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		gameOver = false;
		timeLeft = TIME_LIMIT;
		waterTimer = 0;
		score = 0;
		level = 1;
		completed = false;
		winFlashTimer = 0;

		// Source = left-center, Sink = right-center
		sourceIdx = idx(0, Std.int(ROWS / 2));
		sinkIdx = idx(COLS - 1, Std.int(ROWS / 2));

		buildGrid();
		createInteractives();
	}

	inline function idx(col:Int, row:Int):Int
		return row * COLS + col;

	inline function colOf(i:Int):Int
		return i % COLS;

	inline function rowOf(i:Int):Int
		return Std.int(i / COLS);

	function buildGrid():Void {
		pipes = [];
		waterCells = [];
		waterFrontier = [];

		// Step 1: Generate a valid path from source to sink using random walk
		var path = generatePath();

		// Step 2: Assign pipe types along the path
		for (i in 0...COLS * ROWS) {
			pipes.push({type: Empty, rotation: 0});
			waterCells.push(false);
		}

		for (pi in 0...path.length) {
			var ci = path[pi];
			var prevDir = -1;
			var nextDir = -1;

			if (pi > 0) prevDir = directionFrom(path[pi - 1], ci);
			if (pi < path.length - 1) nextDir = directionFrom(path[pi + 1], ci);

			// For source/sink endpoints, consider the edge direction
			if (pi == 0) prevDir = 2; // comes from left
			if (pi == path.length - 1) nextDir = 0; // goes to right

			var ptype = pipeForDirections(prevDir, nextDir);
			pipes[ci] = ptype;
		}

		// Step 3: Fill empty cells with random non-empty pipes (visual noise)
		for (i in 0...COLS * ROWS) {
			if (pipes[i].type == Empty) {
				var t = rng.random(3);
				var r = rng.random(4);
				pipes[i] = {type: t == 0 ? Straight : (t == 1 ? Bend : Cross), rotation: r};
			}
		}

		// Step 4: Scramble rotations (except don't scramble Cross pipes since they look same)
		for (i in 0...COLS * ROWS) {
			if (pipes[i].type != Cross) {
				pipes[i].rotation = (pipes[i].rotation + 1 + rng.random(3)) % 4;
			}
		}

		// Init water at source
		waterCells[sourceIdx] = true;
		waterFrontier = [sourceIdx];
		waterTimer = WATER_TICK;
	}

	function generatePath():Array<Int> {
		// BFS-inspired random walk from source to sink
		var visited = new Map<Int, Bool>();
		var parent = new Map<Int, Int>();
		var stack = [sourceIdx];
		visited.set(sourceIdx, true);

		while (stack.length > 0) {
			var current = stack[stack.length - 1];
			if (current == sinkIdx) break;

			// Get unvisited neighbors
			var neighbors:Array<Int> = [];
			var cc = colOf(current);
			var cr = rowOf(current);
			if (cc + 1 < COLS && !visited.exists(idx(cc + 1, cr))) neighbors.push(idx(cc + 1, cr));
			if (cc - 1 >= 0 && !visited.exists(idx(cc - 1, cr))) neighbors.push(idx(cc - 1, cr));
			if (cr + 1 < ROWS && !visited.exists(idx(cc, cr + 1))) neighbors.push(idx(cc, cr + 1));
			if (cr - 1 >= 0 && !visited.exists(idx(cc, cr - 1))) neighbors.push(idx(cc, cr - 1));

			if (neighbors.length == 0) {
				stack.pop();
				continue;
			}

			// Bias towards moving right (towards sink)
			var chosen:Int;
			var rightNeighbor = -1;
			for (n in neighbors) {
				if (colOf(n) > cc) {
					rightNeighbor = n;
					break;
				}
			}
			if (rightNeighbor >= 0 && rng.random(3) > 0) {
				chosen = rightNeighbor;
			} else {
				chosen = neighbors[rng.random(neighbors.length)];
			}

			visited.set(chosen, true);
			parent.set(chosen, current);
			stack.push(chosen);
		}

		// Reconstruct path
		var path:Array<Int> = [];
		var cur = sinkIdx;
		while (cur != sourceIdx) {
			path.push(cur);
			if (!parent.exists(cur)) {
				// Fallback: straight line
				path = [];
				var row = Std.int(ROWS / 2);
				for (c in 0...COLS) path.push(idx(c, row));
				return path;
			}
			cur = parent.get(cur);
		}
		path.push(sourceIdx);
		path.reverse();
		return path;
	}

	// Direction: 0=right, 1=down, 2=left, 3=up
	function directionFrom(from:Int, to:Int):Int {
		var dc = colOf(to) - colOf(from);
		var dr = rowOf(to) - rowOf(from);
		if (dc == 1) return 0;
		if (dc == -1) return 2;
		if (dr == 1) return 1;
		return 3;
	}

	function pipeForDirections(dir1:Int, dir2:Int):PipeCell {
		// Normalize so dir1 <= dir2
		var a = dir1 < dir2 ? dir1 : dir2;
		var b = dir1 < dir2 ? dir2 : dir1;

		// Straight: connects opposite sides
		if ((a == 0 && b == 2) || (a == 2 && b == 0)) return {type: Straight, rotation: 0};
		if ((a == 1 && b == 3) || (a == 3 && b == 1)) return {type: Straight, rotation: 1};

		// Bend: connects adjacent sides
		// right+down
		if (a == 0 && b == 1) return {type: Bend, rotation: 0};
		// down+left
		if (a == 1 && b == 2) return {type: Bend, rotation: 1};
		// left+up
		if (a == 2 && b == 3) return {type: Bend, rotation: 2};
		// up+right
		if ((a == 0 && b == 3) || (a == 3 && b == 0)) return {type: Bend, rotation: 3};

		// Fallback cross
		return {type: Cross, rotation: 0};
	}

	function createInteractives():Void {
		for (inter in cellInteractives)
			inter.remove();
		cellInteractives = [];

		var gridW = COLS * (CELL + GAP) - GAP;
		var offsetX = (DESIGN_W - gridW) / 2;

		for (i in 0...COLS * ROWS) {
			var col = colOf(i);
			var row = rowOf(i);
			var cx = offsetX + col * (CELL + GAP);
			var cy = GRID_TOP + row * (CELL + GAP);

			var inter = new Interactive(CELL, CELL, contentObj);
			inter.x = cx;
			inter.y = cy;
			final ci = i;
			inter.onClick = function(_) onCellTap(ci);
			cellInteractives.push(inter);
		}
	}

	function onCellTap(i:Int):Void {
		if (gameOver || completed) return;
		if (pipes[i].type == Cross) return; // cross looks same rotated
		pipes[i].rotation = (pipes[i].rotation + 1) % 4;
		rotateAnims.push({idx: i, fromRot: (pipes[i].rotation + 3) % 4, progress: 0});

		// Check if path is complete
		if (checkPath()) {
			completed = true;
			winFlashTimer = 0.8;
			score += 50 + Std.int(timeLeft * 3);
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.flash(0x44DDFF, 0.2);
		}
	}

	// Returns the openings of a pipe: array of directions (0=right,1=down,2=left,3=up)
	function getOpenings(p:PipeCell):Array<Int> {
		var base:Array<Int>;
		switch (p.type) {
			case Straight:
				base = [0, 2]; // right, left
			case Bend:
				base = [0, 1]; // right, down
			case Cross:
				base = [0, 1, 2, 3];
			case Empty:
				return [];
		}
		// Apply rotation
		var result:Array<Int> = [];
		for (d in base)
			result.push((d + p.rotation) % 4);
		return result;
	}

	function hasOpening(p:PipeCell, dir:Int):Bool {
		for (d in getOpenings(p))
			if (d == dir) return true;
		return false;
	}

	function neighborIdx(i:Int, dir:Int):Int {
		var c = colOf(i);
		var r = rowOf(i);
		switch (dir) {
			case 0:
				return c + 1 < COLS ? idx(c + 1, r) : -1;
			case 1:
				return r + 1 < ROWS ? idx(c, r + 1) : -1;
			case 2:
				return c - 1 >= 0 ? idx(c - 1, r) : -1;
			case 3:
				return r - 1 >= 0 ? idx(c, r - 1) : -1;
			default:
				return -1;
		}
	}

	function opposite(dir:Int):Int
		return (dir + 2) % 4;

	function checkPath():Bool {
		// BFS from source checking connections
		var visited = new Map<Int, Bool>();
		var queue = [sourceIdx];
		visited.set(sourceIdx, true);

		// Source must have left opening (from outside)
		if (!hasOpening(pipes[sourceIdx], 2)) return false;

		while (queue.length > 0) {
			var cur = queue.shift();
			if (cur == sinkIdx && hasOpening(pipes[sinkIdx], 0)) return true;

			for (dir in getOpenings(pipes[cur])) {
				var ni = neighborIdx(cur, dir);
				if (ni < 0 || visited.exists(ni)) continue;
				if (hasOpening(pipes[ni], opposite(dir))) {
					visited.set(ni, true);
					queue.push(ni);
				}
			}
		}
		return false;
	}

	function advanceWater():Void {
		var newFrontier:Array<Int> = [];

		for (fi in waterFrontier) {
			for (dir in getOpenings(pipes[fi])) {
				var ni = neighborIdx(fi, dir);
				if (ni < 0 || waterCells[ni]) continue;
				if (hasOpening(pipes[ni], opposite(dir))) {
					waterCells[ni] = true;
					newFrontier.push(ni);
				}
			}
		}

		waterFrontier = newFrontier;

		// If water reached sink, we win (even if not fully connected path - water found a way)
		if (waterCells[sinkIdx] && !completed) {
			completed = true;
			winFlashTimer = 0.8;
			score += 50 + Std.int(timeLeft * 3);
			if (ctx != null && ctx.feedback != null)
				ctx.feedback.flash(0x44DDFF, 0.2);
		}

		// If no more frontier and sink not reached, water is stuck
	}

	function drawBackground():Void {
		bg.clear();
		var steps = 16;
		for (i in 0...steps) {
			var t = i / steps;
			var r = Std.int(8 + t * 10);
			var g = Std.int(14 + t * 18);
			var b = Std.int(28 + t * 24);
			var color = (r << 16) | (g << 8) | b;
			var yStart = Std.int(DESIGN_H * t);
			var yEnd = Std.int(DESIGN_H * (t + 1.0 / steps)) + 1;
			bg.beginFill(color);
			bg.drawRect(0, yStart, DESIGN_W, yEnd - yStart);
			bg.endFill();
		}
	}

	function drawGrid():Void {
		gridG.clear();
		var gridW = COLS * (CELL + GAP) - GAP;
		var offsetX = (DESIGN_W - gridW) / 2;

		// Source/sink indicators
		var srcRow = Std.int(ROWS / 2);
		var srcY = GRID_TOP + srcRow * (CELL + GAP) + CELL / 2;

		// Source arrow (left)
		gridG.beginFill(0x44AAFF, 0.8);
		gridG.moveTo(offsetX - 18, srcY - 8);
		gridG.lineTo(offsetX - 6, srcY);
		gridG.lineTo(offsetX - 18, srcY + 8);
		gridG.lineTo(offsetX - 18, srcY - 8);
		gridG.endFill();

		// Sink arrow (right)
		var sinkX = offsetX + gridW;
		gridG.beginFill(0x44DD66, 0.8);
		gridG.moveTo(sinkX + 6, srcY);
		gridG.lineTo(sinkX + 18, srcY - 8);
		gridG.lineTo(sinkX + 18, srcY + 8);
		gridG.lineTo(sinkX + 6, srcY);
		gridG.endFill();

		for (i in 0...COLS * ROWS) {
			var col = colOf(i);
			var row = rowOf(i);
			var cx = offsetX + col * (CELL + GAP);
			var cy = GRID_TOP + row * (CELL + GAP);
			var p = pipes[i];

			var hasWater = waterCells[i];

			// Cell background
			if (hasWater) {
				gridG.beginFill(0x0A2A3A, 0.9);
			} else {
				gridG.beginFill(0x1A1A30, 0.8);
			}
			gridG.drawRect(cx, cy, CELL, CELL);
			gridG.endFill();

			// Border
			var borderColor = hasWater ? 0x2288AA : 0x333355;
			gridG.lineStyle(1, borderColor, 0.6);
			gridG.drawRect(cx, cy, CELL, CELL);
			gridG.lineStyle();

			// Draw pipe
			drawPipe(gridG, cx + CELL / 2, cy + CELL / 2, p, hasWater);
		}
	}

	function drawPipe(g:Graphics, cx:Float, cy:Float, p:PipeCell, hasWater:Bool):Void {
		if (p.type == Empty) return;

		var pipeW = 12.0;
		var halfCell = CELL / 2.0;
		var pipeColor = hasWater ? 0x44AAFF : 0x667788;
		var pipeAlpha = hasWater ? 0.9 : 0.7;

		var openings = getOpenings(p);

		// Draw pipe segments from center to each opening direction
		for (dir in openings) {
			var dx = 0.0;
			var dy = 0.0;
			var w = 0.0;
			var h = 0.0;

			switch (dir) {
				case 0: // right
					dx = 0;
					dy = -pipeW / 2;
					w = halfCell;
					h = pipeW;
				case 1: // down
					dx = -pipeW / 2;
					dy = 0;
					w = pipeW;
					h = halfCell;
				case 2: // left
					dx = -halfCell;
					dy = -pipeW / 2;
					w = halfCell;
					h = pipeW;
				case 3: // up
					dx = -pipeW / 2;
					dy = -halfCell;
					w = pipeW;
					h = halfCell;
			}

			g.beginFill(pipeColor, pipeAlpha);
			g.drawRect(cx + dx, cy + dy, w, h);
			g.endFill();
		}

		// Center joint
		g.beginFill(pipeColor, pipeAlpha);
		g.drawRect(cx - pipeW / 2, cy - pipeW / 2, pipeW, pipeW);
		g.endFill();

		// Water glow in center
		if (hasWater) {
			g.beginFill(0x88DDFF, 0.3);
			g.drawCircle(cx, cy, pipeW * 0.6);
			g.endFill();
		}
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		gameOver = false;
		timeLeft = TIME_LIMIT;
		waterTimer = WATER_TICK;
		score = 0;
		level = 1;
		completed = false;
		winFlashTimer = 0;
		rotateAnims = [];
		buildGrid();
	}

	function nextLevel():Void {
		level++;
		completed = false;
		winFlashTimer = 0;
		timeLeft = Math.min(timeLeft + 10, TIME_LIMIT); // bonus time
		waterTimer = WATER_TICK;
		rotateAnims = [];
		buildGrid();
	}

	function endGame():Void {
		if (ctx != null) {
			ctx.lose(score, getMinigameId());
			ctx = null;
		}
	}

	public function update(dt:Float):Void {
		if (ctx == null) return;

		if (!gameOver) {
			timeLeft -= dt;
			if (timeLeft <= 0) {
				timeLeft = 0;
				gameOver = true;
				endGame();
				return;
			}
		}

		// Water advancing
		if (!completed && !gameOver) {
			waterTimer -= dt;
			if (waterTimer <= 0) {
				waterTimer = WATER_TICK;
				advanceWater();
			}
		}

		// Win flash / next level
		if (completed) {
			winFlashTimer -= dt;
			if (winFlashTimer <= 0) {
				nextLevel();
				return;
			}
		}

		// Rotate animations
		for (a in rotateAnims) {
			a.progress += dt * 6.0;
			if (a.progress >= 1.0) a.progress = 1.0;
		}
		rotateAnims = rotateAnims.filter(function(a) return a.progress < 1.0);

		// Timer bar
		timerBarG.clear();
		var barY = 115;
		var barH = 6;
		var barMaxW = DESIGN_W - 40;
		timerBarG.beginFill(0x222244, 0.6);
		timerBarG.drawRect(20, barY, barMaxW, barH);
		timerBarG.endFill();
		var ratio = timeLeft / TIME_LIMIT;
		var barColor = ratio > 0.3 ? 0x44AAFF : (ratio > 0.15 ? 0xFFAA00 : 0xFF3333);
		timerBarG.beginFill(barColor, 0.9);
		timerBarG.drawRect(20, barY, barMaxW * ratio, barH);
		timerBarG.endFill();

		// Water progress indicator (small dots)
		var waterCount = 0;
		for (w in waterCells)
			if (w) waterCount++;

		drawGrid();

		scoreText.text = Std.string(score);
		levelText.text = "Level " + level;

		// Pulse title when low time
		if (timeLeft < 8 && !gameOver && !completed) {
			var pulse = Math.sin(timeLeft * 8) * 0.5 + 0.5;
			titleText.textColor = pulse > 0.5 ? 0xFF4444 : 0xFFFFFF;
		} else if (completed) {
			titleText.textColor = 0x44DD66;
		} else {
			titleText.textColor = 0xFFFFFF;
		}

		// Hint fades out after a few seconds
		if (timeLeft < TIME_LIMIT - 5) {
			hintText.alpha = Math.max(0, hintText.alpha - dt);
		}
	}

	public function dispose() {
		for (inter in cellInteractives)
			inter.remove();
		contentObj.removeChildren();
		ctx = null;
	}

	public function getMinigameId():String
		return "pipe-connect";

	public function getTitle():String
		return "Pipe Connect";
}

private typedef PipeCell = {
	type:PipeType,
	rotation:Int, // 0-3 (clockwise 90° increments)
};

private enum PipeType {
	Empty;
	Straight; // connects opposite sides (0-2 or 1-3)
	Bend; // connects adjacent sides (L-shape)
	Cross; // connects all 4 sides
}
