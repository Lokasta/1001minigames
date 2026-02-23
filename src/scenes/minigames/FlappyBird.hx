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
	Flappy Bird: tap para bater asas, desvie dos canos.
	Score = quantos canos passou.
**/
class FlappyBird implements IMinigameSceneWithLose implements IMinigameUpdatable {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;
	static var GRAVITY = 760;
	static var FLAP_STRENGTH = -300;
	static var BIRD_R = 14;
	static var BIRD_X = 80;
	static var PIPE_W = 56;
	static var PIPE_GAP = 140;
	static var PIPE_SPEED = 160;
	static var PIPE_SPAWN_INTERVAL = 1.8;
	static var FLOOR_H = 60;
	static var CEILING = 40;

	final contentObj: Object;
	var ctx: MinigameContext;
	var designW: Int;
	var designH: Int;

	var bg: Graphics;
	var birdG: Graphics;
	var pipesG: Graphics;
	var scoreText: Text;
	var interactive: Interactive;

	var birdY: Float;
	var birdVy: Float;
	var started: Bool;
	var score: Int;
	var pipes: Array<Pipe>;
	var spawnTimer: Float;
	var gameOver: Bool;

	public var content(get, never): Object;
	inline function get_content() return contentObj;

	public function new() {
		designW = DESIGN_W;
		designH = DESIGN_H;
		contentObj = new Object();
		contentObj.visible = false;
		pipes = [];

		// Fundo
		bg = new Graphics(contentObj);
		bg.beginFill(0x87CEEB);
		bg.drawRect(0, 0, designW, designH);
		bg.endFill();
		// Chão
		bg.beginFill(0xDEB887);
		bg.drawRect(0, designH - FLOOR_H, designW, FLOOR_H);
		bg.endFill();

		// Canos (desenho dinâmico em update)
		pipesG = new Graphics(contentObj);

		// Passarinho (círculo amarelo)
		birdG = new Graphics(contentObj);
		drawBird(BIRD_X, designH / 2);

		scoreText = new Text(hxd.res.DefaultFont.get(), contentObj);
		scoreText.text = "0";
		scoreText.x = designW / 2 - 20;
		scoreText.y = 30;
		scoreText.scale(1.8);

		interactive = new Interactive(designW, designH, contentObj);
		interactive.onClick = function(_) {
			if (gameOver || ctx == null) return;
			if (!started) started = true;
			birdVy = FLAP_STRENGTH;
		};
	}

	function drawBird(x: Float, y: Float) {
		birdG.clear();
		birdG.beginFill(0xF4D03F);
		birdG.drawCircle(x, y, BIRD_R);
		birdG.endFill();
		// Olho
		birdG.beginFill(0x000000);
		birdG.drawCircle(x + 6, y - 2, 3);
		birdG.endFill();
	}

	function spawnPipe() {
		var gapH = PIPE_GAP;
		var minGapY = CEILING + 40;
		var maxGapY = designH - FLOOR_H - gapH - 40;
		var gapY = minGapY + Math.random() * (maxGapY - minGapY);
		pipes.push({
			x: designW + PIPE_W,
			gapY: gapY,
			gapH: gapH,
			scored: false
		});
	}

	function drawPipes() {
		pipesG.clear();
		for (p in pipes) {
			// Cano de cima
			pipesG.beginFill(0x2ECC71);
			pipesG.drawRect(p.x, 0, PIPE_W, p.gapY);
			pipesG.endFill();
			pipesG.lineStyle(2, 0x27AE60);
			pipesG.drawRect(p.x, 0, PIPE_W, p.gapY);
			// Cano de baixo
			var bottomY = p.gapY + p.gapH;
			pipesG.beginFill(0x2ECC71);
			pipesG.drawRect(p.x, bottomY, PIPE_W, designH - bottomY);
			pipesG.endFill();
			pipesG.lineStyle(2, 0x27AE60);
			pipesG.drawRect(p.x, bottomY, PIPE_W, designH - bottomY);
		}
	}

	function hitPipe(): Bool {
		var bx = BIRD_X;
		var by = birdY;
		var r = BIRD_R - 2;
		for (p in pipes) {
			if (p.x + PIPE_W < bx - r) continue;
			if (p.x > bx + r) continue;
			if (by - r < p.gapY) return true;
			if (by + r > p.gapY + p.gapH) return true;
		}
		return false;
	}

	public function setOnLose(c: MinigameContext) {
		ctx = c;
	}

	public function start() {
		birdY = designH / 2;
		birdVy = 0;
		started = false;
		score = 0;
		gameOver = false;
		pipes = [];
		spawnTimer = 0.3;
		scoreText.text = "0";
		drawBird(BIRD_X, birdY);
		drawPipes();
	}

	public function dispose() {
		interactive.remove();
		contentObj.removeChildren();
		ctx = null;
		pipes = [];
	}

	public function getMinigameId(): String return "flappy-bird";
	public function getTitle(): String return "Flappy Bird";

	public function update(dt: Float) {
		if (ctx == null || gameOver) return;

		if (!started) {
			// Pequena animação de “esperando tap”
			birdY = designH / 2 + Math.sin(haxe.Timer.stamp() * 3) * 8;
			drawBird(BIRD_X, birdY);
			return;
		}

		birdVy += GRAVITY * dt;
		birdY += birdVy * dt;

		if (birdY - BIRD_R < CEILING || birdY + BIRD_R > designH - FLOOR_H) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		if (hitPipe()) {
			gameOver = true;
			ctx.lose(score, getMinigameId());
			ctx = null;
			return;
		}

		// Mover canos
		for (p in pipes) p.x -= PIPE_SPEED * dt;
		// Marcar score ao passar o centro do cano
		for (p in pipes) {
			if (!p.scored && p.x + PIPE_W / 2 < BIRD_X) {
				p.scored = true;
				score++;
				scoreText.text = Std.string(score);
			}
		}
		// Remover canos fora da tela
		while (pipes.length > 0 && pipes[0].x + PIPE_W < 0) pipes.shift();

		spawnTimer -= dt;
		if (spawnTimer <= 0) {
			spawnTimer = PIPE_SPAWN_INTERVAL;
			spawnPipe();
		}

		drawBird(BIRD_X, birdY);
		drawPipes();
	}
}

private typedef Pipe = {
	var x: Float;
	var gapY: Float;
	var gapH: Float;
	var scored: Bool;
}
