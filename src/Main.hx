import core.GameFlow;

class Main extends hxd.App {
	static var DESIGN_W = 360;
	static var DESIGN_H = 640;

	var gameFlow: GameFlow;

	override function init() {
		s2d.scaleMode = h2d.ScaleMode.LetterBox(DESIGN_W, DESIGN_H);

		gameFlow = new GameFlow(s2d, DESIGN_W, DESIGN_H, s3d);

		// Registrar minigames (nome para debug menu + factory)
		gameFlow.registerMinigame("Flappy Bird", function() return new scenes.minigames.FlappyBird());
		gameFlow.registerMinigame("Dino Runner", function() return new scenes.minigames.DinoRunner());
		gameFlow.registerMinigame("Cobrinha", function() return new scenes.minigames.SnakeGame());
		gameFlow.registerMinigame("Guitar Hero", function() return new scenes.minigames.GuitarHero());
		gameFlow.registerMinigame("Fruit Ninja", function() return new scenes.minigames.FruitNinja());
		gameFlow.registerMinigame("Pênalti 3D", function() return new scenes.minigames.PenaltyShootout3D());
		gameFlow.registerMinigame("Corrida", function() return new scenes.minigames.CarRacer3D());
		gameFlow.registerMinigame("Whack-a-Mole", function() return new scenes.minigames.WhackAMole());
		gameFlow.registerMinigame("Simon Says", function() return new scenes.minigames.SimonSays());
		gameFlow.registerMinigame("Subway Surfers 3D", function() return new scenes.minigames.SubwaySurfers3D());
		gameFlow.registerMinigame("Pong", function() return new scenes.minigames.Pong());
		gameFlow.registerMinigame("Space Invaders", function() return new scenes.minigames.SpaceInvaders());
		gameFlow.registerMinigame("Asteroids", function() return new scenes.minigames.Asteroids());
		gameFlow.registerMinigame("Pac-Man", function() return new scenes.minigames.PacMan());
		gameFlow.registerMinigame("Tetris", function() return new scenes.minigames.Tetris());
		gameFlow.registerMinigame("Tap the Color", function() return new scenes.minigames.TapTheColor());
		gameFlow.registerMinigame("Knife Hit", function() return new scenes.minigames.KnifeHit());
		gameFlow.registerMinigame("Stack", function() return new scenes.minigames.Stack());
		gameFlow.registerMinigame("Timing Ball", function() return new scenes.minigames.TimingBall());
		gameFlow.registerMinigame("Red Light Green Light", function() return new scenes.minigames.RedLightGreenLight());
	}

	override function onResize() {
		if (gameFlow != null) gameFlow.resize(Std.int(s2d.width), Std.int(s2d.height));
	}

	override function render(e: h3d.Engine) {
		var w = e.width;
		var h = e.height;
		var scale = Math.min(w / DESIGN_W, h / DESIGN_H);
		var vw = Math.round(scale * DESIGN_W);
		var vh = Math.round(scale * DESIGN_H);
		var vx = Math.round((w - vw) / 2);
		var vy = Math.round((h - vh) / 2);

		// 2D primeiro (background), depois 3D (na frente dos elementos 2D)
		s2d.render(e);
		if (gameFlow != null && gameFlow.isCurrentMinigame3D()) {
			e.setRenderZone(vx, vy, vw, vh);
		}
		s3d.render(e);
		if (gameFlow != null && gameFlow.isCurrentMinigame3D()) {
			e.setRenderZone();
		}
	}

	override function update(dt: Float) {
		if (gameFlow != null) gameFlow.update(dt);
	}

	static function main() {
		new Main();
	}
}
