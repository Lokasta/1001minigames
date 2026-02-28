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
	Color Match: conecte pares de cores iguais sem cruzar caminhos.
	Estilo Flow Free. Timer de 30s, puzzles ficam mais complexos.
**/
class ColorMatch implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var TIMER_MAX = 30.0;

	static var COLORS:Array<Int> = [
		0xE74C3C, // vermelho
		0x3498DB, // azul
		0x2ECC71, // verde
		0xF1C40F, // amarelo
		0x9B59B6, // roxo
		0xE67E22, // laranja
		0x1ABC9C, // turquesa
		0xE91E63, // rosa
	];

	final contentObj:h2d.Object;
	var ctx:MinigameContext;

	var gridG:Graphics;
	var pathG:Graphics;
	var endpointG:Graphics;
	var timerG:Graphics;
	var hudG:Graphics;
	var interactive:Interactive;

	var scoreText:Text;
	var levelText:Text;

	// Grid state
	var gridSize:Int;
	var numPairs:Int;
	var cells:Array<Int>; // -1 = empty, 0+ = color index of path occupying it
	var endpoints:Array<Int>; // -1 = not endpoint, 0+ = color index
	var paths:Array<Array<Int>>; // per color: array of cell indices forming path

	// Drag state
	var dragging:Bool;
	var dragColor:Int;
	var dragPath:Array<Int>;

	// Game state
	var score:Int;
	var timer:Float;
	var started:Bool;
	var gameOver:Bool;
	var level:Int;

	// Layout
	var gridOffX:Float;
	var gridOffY:Float;
	var cellSize:Float;

	public var content(get, never):h2d.Object;

	inline function get_content()
		return contentObj;

	public function new() {
		contentObj = new h2d.Object();
		contentObj.visible = false;

		gridG = new Graphics(contentObj);
		pathG = new Graphics(contentObj);
		endpointG = new Graphics(contentObj);
		timerG = new Graphics(contentObj);
		hudG = new Graphics(contentObj);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.textAlign = Right;
		scoreText.x = DESIGN_W - 14;
		scoreText.y = 22;
		scoreText.scale(2.0);

		levelText = new Text(hxd.res.DefaultFont.get(), contentObj);
		levelText.textAlign = Left;
		levelText.x = 14;
		levelText.y = 28;
		levelText.scale(1.0);
		levelText.textColor = 0xAAAAAAA;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = onPush;
		interactive.onMove = onMove;
		interactive.onRelease = onRelease;
		interactive.onReleaseOutside = onRelease;

		cells = [];
		endpoints = [];
		paths = [];
		dragPath = [];
		dragging = false;
		dragColor = -1;
		score = 0;
		timer = TIMER_MAX;
		started = false;
		gameOver = false;
		level = 1;
		gridSize = 5;
		numPairs = 3;
		cellSize = 0;
		gridOffX = 0;
		gridOffY = 0;
	}

	public function setOnLose(c:MinigameContext) {
		ctx = c;
	}

	public function start() {
		score = 0;
		timer = TIMER_MAX;
		started = false;
		gameOver = false;
		level = 1;
		scoreText.text = "0";
		generatePuzzle();
	}

	public function dispose() {
		ctx = null;
	}

	public function getMinigameId():String
		return "color-match";

	public function getTitle():String
		return "Color Match";

	// --- Puzzle Generation ---

	function getLevelParams() {
		if (level <= 3) {
			gridSize = 5;
			numPairs = 3;
		} else if (level <= 6) {
			gridSize = 5;
			numPairs = 4;
		} else if (level <= 9) {
			gridSize = 6;
			numPairs = 4;
		} else {
			gridSize = 6;
			numPairs = 5;
		}
	}

	function generatePuzzle() {
		getLevelParams();

		var totalCells = gridSize * gridSize;
		cells = [];
		endpoints = [];
		paths = [];

		var i = 0;
		while (i < totalCells) {
			cells.push(-1);
			endpoints.push(-1);
			i++;
		}

		i = 0;
		while (i < numPairs) {
			paths.push([]);
			i++;
		}

		// Generate solvable puzzle by laying random paths then keeping only endpoints
		var placed = 0;
		var attempts = 0;
		var tempCells:Array<Int> = [];
		var tempEndpoints:Array<Array<Int>> = [];

		while (placed < numPairs && attempts < 200) {
			attempts++;

			// Reset
			tempCells = [];
			tempEndpoints = [];
			i = 0;
			while (i < totalCells) {
				tempCells.push(-1);
				i++;
			}
			placed = 0;

			var colorIdx = 0;
			while (colorIdx < numPairs) {
				var path = generateRandomPath(tempCells, 3 + Std.int(Math.random() * 4));
				if (path != null && path.length >= 3) {
					for (cellIdx in path)
						tempCells[cellIdx] = colorIdx;
					tempEndpoints.push([path[0], path[path.length - 1]]);
					placed++;
				} else {
					break;
				}
				colorIdx++;
			}
		}

		// Set endpoints from generated paths
		if (placed >= numPairs) {
			i = 0;
			while (i < numPairs) {
				endpoints[tempEndpoints[i][0]] = i;
				endpoints[tempEndpoints[i][1]] = i;
				i++;
			}
		} else {
			// Fallback: place random pairs
			placeFallbackEndpoints();
		}

		// Reset cells (paths are for player to discover)
		i = 0;
		while (i < totalCells) {
			cells[i] = -1;
			i++;
		}

		// Reset paths
		i = 0;
		while (i < paths.length) {
			paths[i] = [];
			i++;
		}

		// Compute layout
		var maxGridPx = Math.min(DESIGN_W - 30, DESIGN_H - 160);
		cellSize = Math.floor(maxGridPx / gridSize);
		var gridPx = cellSize * gridSize;
		gridOffX = (DESIGN_W - gridPx) / 2;
		gridOffY = (DESIGN_H - gridPx) / 2 + 20;

		if (!started)
			started = true;

		drawGrid();
		drawPaths();
		drawEndpoints();
	}

	function generateRandomPath(occupied:Array<Int>, minLen:Int):Array<Int> {
		var totalCells = gridSize * gridSize;

		// Find a free starting cell
		var freeCells:Array<Int> = [];
		var ci = 0;
		while (ci < totalCells) {
			if (occupied[ci] == -1)
				freeCells.push(ci);
			ci++;
		}
		if (freeCells.length < minLen)
			return null;

		var startIdx = Std.int(Math.random() * freeCells.length);
		var start = freeCells[startIdx];

		// Random walk
		var path:Array<Int> = [start];
		var visited = new haxe.ds.IntMap<Bool>();
		visited.set(start, true);

		var maxSteps = minLen + Std.int(Math.random() * 3);
		var step = 0;
		while (step < maxSteps) {
			var current = path[path.length - 1];
			var cx = current % gridSize;
			var cy = Std.int(current / gridSize);
			var neighbors:Array<Int> = [];

			if (cx > 0 && !visited.exists(current - 1) && occupied[current - 1] == -1)
				neighbors.push(current - 1);
			if (cx < gridSize - 1 && !visited.exists(current + 1) && occupied[current + 1] == -1)
				neighbors.push(current + 1);
			if (cy > 0 && !visited.exists(current - gridSize) && occupied[current - gridSize] == -1)
				neighbors.push(current - gridSize);
			if (cy < gridSize - 1 && !visited.exists(current + gridSize) && occupied[current + gridSize] == -1)
				neighbors.push(current + gridSize);

			if (neighbors.length == 0)
				break;

			var next = neighbors[Std.int(Math.random() * neighbors.length)];
			path.push(next);
			visited.set(next, true);
			step++;
		}

		if (path.length < minLen)
			return null;
		return path;
	}

	function placeFallbackEndpoints() {
		// Simple fallback: place pairs on opposite edges
		var placed = 0;
		var ci = 0;
		while (placed < numPairs && ci < 50) {
			ci++;
			var a = Std.int(Math.random() * gridSize * gridSize);
			var b = Std.int(Math.random() * gridSize * gridSize);
			if (a == b || endpoints[a] != -1 || endpoints[b] != -1)
				continue;
			// Ensure minimum distance
			var ax = a % gridSize;
			var ay = Std.int(a / gridSize);
			var bx = b % gridSize;
			var by = Std.int(b / gridSize);
			var dist = Math.abs(ax - bx) + Math.abs(ay - by);
			if (dist < 2)
				continue;
			endpoints[a] = placed;
			endpoints[b] = placed;
			placed++;
		}
	}

	// --- Drawing ---

	function drawGrid() {
		gridG.clear();

		// Background
		gridG.beginFill(0x1A1A2E, 1.0);
		gridG.drawRect(0, 0, DESIGN_W, DESIGN_H);
		gridG.endFill();

		// Grid cells
		var row = 0;
		while (row < gridSize) {
			var col = 0;
			while (col < gridSize) {
				var x = gridOffX + col * cellSize;
				var y = gridOffY + row * cellSize;
				var shade = if ((row + col) % 2 == 0) 0x16213E else 0x1A2744;
				gridG.beginFill(shade, 1.0);
				gridG.drawRoundedRect(x + 1, y + 1, cellSize - 2, cellSize - 2, 4);
				gridG.endFill();
				col++;
			}
			row++;
		}
	}

	function drawPaths() {
		pathG.clear();

		var colorIdx = 0;
		while (colorIdx < paths.length) {
			var path = paths[colorIdx];
			if (path.length < 2) {
				colorIdx++;
				continue;
			}
			var color = COLORS[colorIdx % COLORS.length];
			var lineW = cellSize * 0.4;

			// Draw path segments
			var si = 0;
			while (si < path.length - 1) {
				var c1 = path[si];
				var c2 = path[si + 1];
				var x1 = gridOffX + (c1 % gridSize) * cellSize + cellSize / 2;
				var y1 = gridOffY + Std.int(c1 / gridSize) * cellSize + cellSize / 2;
				var x2 = gridOffX + (c2 % gridSize) * cellSize + cellSize / 2;
				var y2 = gridOffY + Std.int(c2 / gridSize) * cellSize + cellSize / 2;

				pathG.beginFill(color, 0.6);
				if (Math.abs(x2 - x1) > 1) {
					// Horizontal
					var minX = Math.min(x1, x2) - lineW / 2;
					var maxX = Math.max(x1, x2) + lineW / 2;
					pathG.drawRoundedRect(minX, y1 - lineW / 2, maxX - minX, lineW, lineW / 3);
				} else {
					// Vertical
					var minY = Math.min(y1, y2) - lineW / 2;
					var maxY = Math.max(y1, y2) + lineW / 2;
					pathG.drawRoundedRect(x1 - lineW / 2, minY, lineW, maxY - minY, lineW / 3);
				}
				pathG.endFill();
				si++;
			}

			// Draw circles at each path cell for smoother look
			var pi = 0;
			while (pi < path.length) {
				var c = path[pi];
				var px = gridOffX + (c % gridSize) * cellSize + cellSize / 2;
				var py = gridOffY + Std.int(c / gridSize) * cellSize + cellSize / 2;
				pathG.beginFill(color, 0.6);
				pathG.drawCircle(px, py, lineW / 2);
				pathG.endFill();
				pi++;
			}
			colorIdx++;
		}

		// Draw active drag path
		if (dragging && dragPath.length >= 2 && dragColor >= 0) {
			var color = COLORS[dragColor % COLORS.length];
			var lineW = cellSize * 0.4;
			var di = 0;
			while (di < dragPath.length - 1) {
				var c1 = dragPath[di];
				var c2 = dragPath[di + 1];
				var x1 = gridOffX + (c1 % gridSize) * cellSize + cellSize / 2;
				var y1 = gridOffY + Std.int(c1 / gridSize) * cellSize + cellSize / 2;
				var x2 = gridOffX + (c2 % gridSize) * cellSize + cellSize / 2;
				var y2 = gridOffY + Std.int(c2 / gridSize) * cellSize + cellSize / 2;

				pathG.beginFill(color, 0.8);
				if (Math.abs(x2 - x1) > 1) {
					var minX = Math.min(x1, x2) - lineW / 2;
					var maxX = Math.max(x1, x2) + lineW / 2;
					pathG.drawRoundedRect(minX, y1 - lineW / 2, maxX - minX, lineW, lineW / 3);
				} else {
					var minY = Math.min(y1, y2) - lineW / 2;
					var maxY = Math.max(y1, y2) + lineW / 2;
					pathG.drawRoundedRect(x1 - lineW / 2, minY, lineW, maxY - minY, lineW / 3);
				}
				pathG.endFill();
				di++;
			}
			var dj = 0;
			while (dj < dragPath.length) {
				var c = dragPath[dj];
				var px = gridOffX + (c % gridSize) * cellSize + cellSize / 2;
				var py = gridOffY + Std.int(c / gridSize) * cellSize + cellSize / 2;
				pathG.beginFill(color, 0.8);
				pathG.drawCircle(px, py, lineW / 2);
				pathG.endFill();
				dj++;
			}
		}
	}

	function drawEndpoints() {
		endpointG.clear();

		var i = 0;
		while (i < endpoints.length) {
			if (endpoints[i] >= 0) {
				var col = i % gridSize;
				var row = Std.int(i / gridSize);
				var cx = gridOffX + col * cellSize + cellSize / 2;
				var cy = gridOffY + row * cellSize + cellSize / 2;
				var color = COLORS[endpoints[i] % COLORS.length];
				var radius = cellSize * 0.32;

				// Outer glow
				endpointG.beginFill(color, 0.25);
				endpointG.drawCircle(cx, cy, radius + 4);
				endpointG.endFill();

				// Main circle
				endpointG.beginFill(color, 1.0);
				endpointG.drawCircle(cx, cy, radius);
				endpointG.endFill();

				// Inner highlight
				endpointG.beginFill(0xFFFFFF, 0.3);
				endpointG.drawCircle(cx - radius * 0.2, cy - radius * 0.2, radius * 0.4);
				endpointG.endFill();
			}
			i++;
		}
	}

	function drawHud() {
		hudG.clear();

		// Score bg
		hudG.beginFill(0x000000, 0.35);
		hudG.drawRoundedRect(DESIGN_W - 70, 14, 60, 38, 8);
		hudG.endFill();

		// Timer bar
		var barW = DESIGN_W - 30.0;
		var barH = 8.0;
		var barX = 15.0;
		var barY = 8.0;
		var pct = timer / TIMER_MAX;

		// BG
		timerG.clear();
		timerG.beginFill(0x333333, 0.5);
		timerG.drawRoundedRect(barX, barY, barW, barH, 4);
		timerG.endFill();

		// Fill
		var timerColor = if (pct > 0.5) 0x2ECC71 else if (pct > 0.25) 0xF1C40F else 0xE74C3C;
		timerG.beginFill(timerColor, 0.85);
		timerG.drawRoundedRect(barX, barY, barW * pct, barH, 4);
		timerG.endFill();
	}

	// --- Input ---

	function cellFromPos(px:Float, py:Float):Int {
		var col = Std.int((px - gridOffX) / cellSize);
		var row = Std.int((py - gridOffY) / cellSize);
		if (col < 0 || col >= gridSize || row < 0 || row >= gridSize)
			return -1;
		return row * gridSize + col;
	}

	function onPush(e:Event) {
		if (gameOver || !started)
			return;

		var cell = cellFromPos(e.relX, e.relY);
		if (cell < 0)
			return;

		// Check if tapping an endpoint
		if (endpoints[cell] >= 0) {
			var color = endpoints[cell];
			// Clear existing path for this color
			clearPathForColor(color);
			dragging = true;
			dragColor = color;
			dragPath = [cell];
			cells[cell] = color;
			drawPaths();
			e.propagate = false;
			return;
		}

		// Check if tapping on an existing path to clear it
		if (cells[cell] >= 0) {
			var color = cells[cell];
			clearPathForColor(color);
			drawPaths();
			e.propagate = false;
		}
	}

	function onMove(e:Event) {
		if (!dragging || dragColor < 0)
			return;

		var cell = cellFromPos(e.relX, e.relY);
		if (cell < 0)
			return;

		var lastCell = dragPath[dragPath.length - 1];
		if (cell == lastCell)
			return;

		// Check adjacency
		if (!isAdjacent(lastCell, cell))
			return;

		// Check if going back on own path
		if (dragPath.length >= 2 && cell == dragPath[dragPath.length - 2]) {
			// Undo last step
			var removed = dragPath.pop();
			if (removed != null)
				cells[removed] = -1;
			drawPaths();
			return;
		}

		// Can't go into a cell occupied by another color (unless it's our endpoint)
		if (cells[cell] >= 0 && cells[cell] != dragColor)
			return;

		// If cell is occupied by our own color but not in dragPath, skip
		if (cells[cell] == dragColor) {
			var inPath = false;
			for (pc in dragPath) {
				if (pc == cell) {
					inPath = true;
					break;
				}
			}
			if (!inPath)
				return;
		}

		// Can always enter our own endpoint
		if (endpoints[cell] >= 0 && endpoints[cell] != dragColor)
			return;

		// Don't cross other paths - cell must be free or our endpoint
		if (cells[cell] != -1 && endpoints[cell] != dragColor)
			return;

		dragPath.push(cell);
		cells[cell] = dragColor;
		drawPaths();

		// Check if we reached the other endpoint
		if (endpoints[cell] == dragColor && dragPath.length >= 2) {
			// Path complete for this color
			paths[dragColor] = dragPath.copy();
			dragging = false;
			dragColor = -1;
			dragPath = [];
			drawPaths();
			drawEndpoints();

			// Check if puzzle is solved
			if (isPuzzleSolved()) {
				onPuzzleSolved();
			}
		}
	}

	function onRelease(e:Event) {
		if (!dragging)
			return;

		// Check if path ends on the matching endpoint
		if (dragPath.length >= 2) {
			var lastCell = dragPath[dragPath.length - 1];
			if (endpoints[lastCell] == dragColor) {
				paths[dragColor] = dragPath.copy();
				dragging = false;
				dragColor = -1;
				dragPath = [];
				drawPaths();
				if (isPuzzleSolved())
					onPuzzleSolved();
				return;
			}
		}

		// Incomplete path - clear it
		clearDragPath();
		dragging = false;
		dragColor = -1;
		dragPath = [];
		drawPaths();
	}

	function isAdjacent(a:Int, b:Int):Bool {
		var ax = a % gridSize;
		var ay = Std.int(a / gridSize);
		var bx = b % gridSize;
		var by = Std.int(b / gridSize);
		return (Math.abs(ax - bx) + Math.abs(ay - by)) == 1;
	}

	function clearPathForColor(color:Int) {
		// Clear cells
		var i = 0;
		while (i < cells.length) {
			if (cells[i] == color)
				cells[i] = -1;
			i++;
		}
		if (color < paths.length)
			paths[color] = [];
	}

	function clearDragPath() {
		for (cell in dragPath) {
			// Don't clear endpoints
			if (endpoints[cell] < 0)
				cells[cell] = -1;
			else
				cells[cell] = -1;
		}
	}

	function isPuzzleSolved():Bool {
		var i = 0;
		while (i < numPairs) {
			if (i >= paths.length || paths[i].length < 2)
				return false;
			i++;
		}
		return true;
	}

	function onPuzzleSolved() {
		score++;
		level++;
		scoreText.text = Std.string(score);

		if (ctx != null && ctx.feedback != null)
			ctx.feedback.flash(0x2ECC71, 0.2);

		generatePuzzle();
	}

	// --- Update ---

	public function update(dt:Float) {
		if (ctx == null || gameOver)
			return;
		if (!started)
			return;

		timer -= dt;
		if (timer <= 0) {
			timer = 0;
			gameOver = true;
			if (ctx != null) {
				ctx.lose(score, getMinigameId());
				ctx = null;
			}
			return;
		}

		drawHud();
	}
}
