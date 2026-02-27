package scenes.minigames;

import h2d.Object;
import h2d.Graphics;
import h2d.Text;
import h2d.Interactive;
import core.IMinigameScene;
import core.MinigameContext;
import core.IMinigameSceneWithLose;
import core.IMinigameUpdatable;

class Stack implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var BLOCK_H = 22;
	static var START_W = 140.0;
	static var MIN_W = 8.0;
	static var BASE_Y = 560.0; // bottom of the stack area
	static var STACK_X = 180.0; // center X
	static var SPEED_START = 100.0;
	static var SPEED_MAX = 380.0;
	static var SPEED_RAMP_BLOCKS = 35;
	static var WIDTH_SHRINK_PER_BLOCK = 1.2; // block gets this much narrower each time (capped by MIN_W)

	final contentObj:Object;
	var ctx:MinigameContext;

	var bg:Graphics;
	var scoreBg:Graphics;
	var stackG:Graphics;
	var movingG:Graphics;
	var cutG:Graphics;
	var scoreText:Text;
	var instructText:Text;
	var interactive:Interactive;

	var score:Int;
	var gameOver:Bool;
	var started:Bool;

	// Stack of placed blocks: {x, w} (center x, width)
	var placedBlocks:Array<{x:Float, w:Float}>;

	// Moving block
	var movX:Float;
	var movW:Float;
	var movDir:Int; // 1 = right, -1 = left
	var movSpeed:Float;
	var currentY:Float; // Y position of moving block

	// Camera offset (scrolls up as stack grows)
	var camY:Float;
	var camTargetY:Float;

	// Cut piece animation
	var cutPiece:{x:Float, y:Float, w:Float, vx:Float, vy:Float, alpha:Float};

	// Perfect streak
	var perfectStreak:Int;
	static var PERFECT_TOLERANCE = 3.0;

	// Flash feedback
	var flashTimer:Float;
	var flashColor:Int;

	// Colors - gradient from warm to cool as stack grows
	var rng:hxd.Rand;

	public var content(get, never):Object;

	function get_content():Object
		return contentObj;

	public function new() {
		contentObj = new Object();
		rng = new hxd.Rand(42);

		bg = new Graphics(contentObj);
		scoreBg = new Graphics(contentObj);
		stackG = new Graphics(contentObj);
		cutG = new Graphics(contentObj);
		movingG = new Graphics(contentObj);

		var font = hxd.res.DefaultFont.get();
		scoreText = new Text(font, contentObj);
		scoreText.textAlign = Center;
		scoreText.x = STACK_X;
		scoreText.y = 30;
		scoreText.scale(2.5);
		scoreText.textColor = 0xFFFFFF;

		instructText = new Text(font, contentObj);
		instructText.textAlign = Center;
		instructText.x = STACK_X;
		instructText.y = 520;
		instructText.scale(1.0);
		instructText.textColor = 0xAAAAFF;
		instructText.text = "TAP when block is over the stack!";
		instructText.alpha = 0;

		interactive = new Interactive(DESIGN_W, DESIGN_H, contentObj);
		interactive.onPush = function(_) onTap();

		placedBlocks = [];
		cutPiece = null;
		score = 0;
		gameOver = true;
		started = false;
		camY = 0;
		camTargetY = 0;
		perfectStreak = 0;
		flashTimer = 0;
		flashColor = 0xFFFFFF;
	}

	public function setOnLose(ctx:MinigameContext):Void {
		this.ctx = ctx;
	}

	public function start():Void {
		score = 0;
		gameOver = false;
		started = false;
		camY = 0;
		camTargetY = 0;
		perfectStreak = 0;
		flashTimer = 0;
		cutPiece = null;
		rng = new hxd.Rand(Std.int(haxe.Timer.stamp() * 1000) & 0x7FFFFFFF);

		placedBlocks = [];
		placedBlocks.push({x: STACK_X, w: START_W});

		// First moving block: same width as base, enters from a random side
		movW = START_W;
		movDir = rng.random(2) == 0 ? 1 : -1;
		movX = movDir > 0 ? -movW / 2 : DESIGN_W + movW / 2;
		movSpeed = SPEED_START;
		currentY = BASE_Y - BLOCK_H;

		// Camera target: keep moving block at screen Y ~380 so view scrolls up as tower grows
		camTargetY = currentY - 380;

		scoreText.text = "0";
		instructText.alpha = 1.0;
		started = true;

		drawBg();
		redrawStack();
		drawMoving();
	}

	function getBlockColor(index:Int):Int {
		// Cycle through vibrant colors
		var colors = [
			0xE74C3C, // red
			0xE67E22, // orange
			0xF1C40F, // yellow
			0x2ECC71, // green
			0x1ABC9C, // teal
			0x3498DB, // blue
			0x9B59B6, // purple
			0xE91E63, // pink
		];
		return colors[index % colors.length];
	}

	function drawBg():Void {
		bg.clear();
		bg.beginFill(0x0D0A18);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		bg.beginFill(0x15102A);
		bg.drawRect(0, 0, DESIGN_W, DESIGN_H);
		bg.endFill();
		// Soft gradient center (stack zone)
		bg.beginFill(0x1E1635, 0.6);
		bg.drawRect(0, 200, DESIGN_W, 400);
		bg.endFill();
		// Vignette
		bg.beginFill(0x000000, 0.4);
		bg.drawRect(0, 0, DESIGN_W, 60);
		bg.drawRect(0, DESIGN_H - 100, DESIGN_W, 100);
		bg.drawRect(0, 0, 40, DESIGN_H);
		bg.drawRect(DESIGN_W - 40, 0, 40, DESIGN_H);
		bg.endFill();
	}

	function redrawStack():Void {
		stackG.clear();

		var startIdx = 0;
		var visibleBlocks = Std.int(BASE_Y / BLOCK_H) + 3;
		if (placedBlocks.length > visibleBlocks) {
			startIdx = placedBlocks.length - visibleBlocks;
		}

		for (i in startIdx...placedBlocks.length) {
			var blk = placedBlocks[i];
			var by = BASE_Y - (i) * BLOCK_H - camY;
			if (by > DESIGN_H + BLOCK_H || by < -BLOCK_H) continue;

			var col = getBlockColor(i);
			var lx = blk.x - blk.w / 2;
			// Drop shadow under block
			stackG.beginFill(0x000000, 0.25);
			stackG.drawRect(lx + 3, by + 3, blk.w, BLOCK_H);
			stackG.endFill();
			// Darker base (bevel bottom)
			var dr = Std.int(Math.max(0, (col >> 16 & 0xFF) - 35));
			var dg = Std.int(Math.max(0, (col >> 8 & 0xFF) - 35));
			var db = Std.int(Math.max(0, (col & 0xFF) - 35));
			stackG.beginFill((dr << 16) | (dg << 8) | db);
			stackG.drawRect(lx, by + BLOCK_H - 4, blk.w, 4);
			stackG.endFill();
			// Main fill
			stackG.beginFill(col);
			stackG.drawRect(lx, by, blk.w, BLOCK_H - 4);
			stackG.endFill();
			// Top highlight (shine)
			var hr = Std.int(Math.min(255, (col >> 16 & 0xFF) + 55));
			var hg = Std.int(Math.min(255, (col >> 8 & 0xFF) + 55));
			var hb = Std.int(Math.min(255, (col & 0xFF) + 55));
			stackG.beginFill((hr << 16) | (hg << 8) | hb, 0.7);
			stackG.drawRect(lx, by, blk.w, 4);
			stackG.endFill();
			// Right edge shadow
			stackG.beginFill(0x000000, 0.2);
			stackG.drawRect(blk.x + blk.w / 2 - 4, by, 4, BLOCK_H);
			stackG.endFill();
		}
	}

	function drawMoving():Void {
		movingG.clear();
		if (gameOver) return;

		var col = getBlockColor(placedBlocks.length);
		var my = currentY - camY;
		var lx = movX - movW / 2;
		// Glow behind moving block
		movingG.beginFill(col, 0.2);
		movingG.drawRect(lx - 4, my - 2, movW + 8, BLOCK_H + 4);
		movingG.endFill();
		// Shadow
		movingG.beginFill(0x000000, 0.3);
		movingG.drawRect(lx + 3, my + 3, movW, BLOCK_H);
		movingG.endFill();
		// Main
		movingG.beginFill(col);
		movingG.drawRect(lx, my, movW, BLOCK_H - 3);
		movingG.endFill();
		var hr = Std.int(Math.min(255, (col >> 16 & 0xFF) + 50));
		var hg = Std.int(Math.min(255, (col >> 8 & 0xFF) + 50));
		var hb = Std.int(Math.min(255, (col & 0xFF) + 50));
		movingG.beginFill((hr << 16) | (hg << 8) | hb, 0.8);
		movingG.drawRect(lx, my, movW, 4);
		movingG.endFill();
	}

	function drawCutPiece():Void {
		cutG.clear();
		if (cutPiece == null) return;
		var col = getBlockColor(placedBlocks.length - 1);
		var cx = cutPiece.x - cutPiece.w / 2;
		var cy = cutPiece.y - camY;
		cutG.beginFill(0x000000, cutPiece.alpha * 0.3);
		cutG.drawRect(cx + 2, cy + 2, cutPiece.w, BLOCK_H);
		cutG.endFill();
		cutG.beginFill(col, cutPiece.alpha);
		cutG.drawRect(cx, cy, cutPiece.w, BLOCK_H);
		cutG.endFill();
	}

	function onTap():Void {
		if (gameOver) return;

		// Fade instruction after first tap
		if (instructText.alpha > 0) {
			instructText.alpha = 0;
		}

		var prev = placedBlocks[placedBlocks.length - 1];

		// Calculate overlap
		var movLeft = movX - movW / 2;
		var movRight = movX + movW / 2;
		var prevLeft = prev.x - prev.w / 2;
		var prevRight = prev.x + prev.w / 2;

		var overlapLeft = Math.max(movLeft, prevLeft);
		var overlapRight = Math.min(movRight, prevRight);
		var overlapW = overlapRight - overlapLeft;

		if (overlapW <= 0) {
			gameOver = true;
			cutPiece = {
				x: movX,
				y: currentY,
				w: movW,
				vx: movDir * 80.0,
				vy: 0,
				alpha: 1.0
			};
			movingG.clear();
			if (ctx != null) {
				ctx.feedback.flash(0xFF3322, 0.25);
				ctx.feedback.shake2D(0.35, 12);
				ctx.lose(score, getMinigameId());
			}
			return;
		}

		// Check for perfect placement
		var diff = Math.abs(movX - prev.x);
		if (diff < PERFECT_TOLERANCE) {
			// Perfect! Keep same width, snap to center
			overlapW = movW;
			overlapLeft = prev.x - movW / 2;
			overlapRight = prev.x + movW / 2;
			perfectStreak++;
			flashTimer = 0.3;
			flashColor = 0xFFFFFF;

			// Grow width slightly on streak
			if (perfectStreak >= 3) {
				overlapW = Math.min(overlapW + 4, START_W);
			}

			placedBlocks.push({x: prev.x, w: overlapW});
		} else {
			perfectStreak = 0;
			var newCenterX = overlapLeft + overlapW / 2;

			// Cut piece animation
			var cutSide = movX > prev.x ? 1 : -1;
			var cutW = movW - overlapW;
			var cutCenterX:Float;
			if (cutSide > 0) {
				cutCenterX = overlapRight + cutW / 2;
			} else {
				cutCenterX = overlapLeft - cutW / 2;
			}
			cutPiece = {
				x: cutCenterX,
				y: currentY,
				w: cutW,
				vx: cutSide * 80.0,
				vy: 0,
				alpha: 1.0
			};

			placedBlocks.push({x: newCenterX, w: overlapW});
		}

		score++;
		scoreText.text = Std.string(score);

		if (ctx != null && ctx.feedback != null) {
			ctx.feedback.shake2D(0.08, 3);
			if (perfectStreak > 0) ctx.feedback.flash(0xFFFFFF, 0.06);
		}

		// Next block: overlap width, then shrink slightly for difficulty (never below MIN_W)
		var nextW = overlapW - WIDTH_SHRINK_PER_BLOCK;
		movW = nextW < MIN_W ? MIN_W : nextW;
		currentY -= BLOCK_H;

		// Camera follows the top: camY = currentY - 380 so moving block stays at screen Y 380.
		// When tower is very high, currentY is negative, so camTargetY is negative — that's correct.
		camTargetY = currentY - 380;

		// Difficulty: speed increases with score
		var speedT = Math.min(score / SPEED_RAMP_BLOCKS, 1.0);
		movSpeed = SPEED_START + (SPEED_MAX - SPEED_START) * speedT;
		movSpeed = movSpeed + score * 2; // extra speed every block

		// Alternate start side
		var lastPlaced = placedBlocks[placedBlocks.length - 1];
		movDir = rng.random(2) == 0 ? 1 : -1;
		movX = movDir > 0 ? -movW / 2 : DESIGN_W + movW / 2;

		redrawStack();
		drawMoving();
	}

	public function update(dt:Float):Void {
		if (gameOver && !started) {
			// Pre-start: fade instruction in
			if (instructText.alpha < 1.0) {
				instructText.alpha = Math.min(1.0, instructText.alpha + dt * 2.0);
			}
			return;
		}

		if (!gameOver && started) {
			// Move block
			movX += movDir * movSpeed * dt;

			// Bounce off edges
			var halfW = movW / 2;
			if (movX + halfW > DESIGN_W + 20) {
				movX = DESIGN_W + 20 - halfW;
				movDir = -1;
			} else if (movX - halfW < -20) {
				movX = -20 + halfW;
				movDir = 1;
			}

			drawMoving();
		}

		// Smooth camera scroll
		if (Math.abs(camY - camTargetY) > 0.5) {
			camY += (camTargetY - camY) * 6.0 * dt;
			redrawStack();
			drawMoving();
		}

		// Animate cut piece
		if (cutPiece != null) {
			cutPiece.x += cutPiece.vx * dt;
			cutPiece.vy += 400 * dt; // gravity
			cutPiece.y += cutPiece.vy * dt;
			cutPiece.alpha -= dt * 2.0;
			if (cutPiece.alpha <= 0) {
				cutPiece = null;
				cutG.clear();
			} else {
				drawCutPiece();
			}
		}

		if (flashTimer > 0) flashTimer -= dt;

		// Score pill + position
		scoreBg.clear();
		scoreBg.beginFill(0x000000, 0.35);
		scoreBg.drawRoundedRect(STACK_X - 42, 14, 84, 36, 18);
		scoreBg.endFill();
		scoreBg.beginFill(0xFFFFFF, 0.12);
		scoreBg.drawRoundedRect(STACK_X - 42, 14, 84, 36, 18);
		scoreBg.endFill();
		scoreText.y = 30;
	}

	public function dispose():Void {
		contentObj.remove();
	}

	public function getMinigameId():String
		return "stack";

	public function getTitle():String
		return "Stack";
}
