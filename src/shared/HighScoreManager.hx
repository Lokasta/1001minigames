package shared;

class HighScoreManager {
	static var _instance:HighScoreManager;

	public static function getInstance():HighScoreManager {
		if (_instance == null)
			_instance = new HighScoreManager();
		return _instance;
	}

	var scores:Map<String, Int>;

	function new() {
		scores = new Map();
		load();
	}

	function load():Void {
		var raw:Null<String> = null;
		#if js
		try {
			raw = js.Browser.getLocalStorage().getItem("toktok_highscores");
		} catch (_:Dynamic) {}
		#elseif sys
		try {
			if (sys.FileSystem.exists("highscores.json"))
				raw = sys.io.File.getContent("highscores.json");
		} catch (_:Dynamic) {}
		#end
		if (raw != null) {
			try {
				var obj:Dynamic = haxe.Json.parse(raw);
				var fields = Reflect.fields(obj);
				for (key in fields) {
					var val:Dynamic = Reflect.field(obj, key);
					if (Std.isOfType(val, Int) || Std.isOfType(val, Float))
						scores.set(key, Std.int(val));
				}
			} catch (_:Dynamic) {
				scores = new Map();
			}
		}
	}

	function save():Void {
		var obj:Dynamic = {};
		for (key => val in scores)
			Reflect.setField(obj, key, val);
		var json = haxe.Json.stringify(obj);
		#if js
		try {
			js.Browser.getLocalStorage().setItem("toktok_highscores", json);
		} catch (_:Dynamic) {}
		#elseif sys
		try {
			sys.io.File.saveContent("highscores.json", json);
		} catch (_:Dynamic) {}
		#end
	}

	public function getHighScore(minigameId:String):Int {
		var val = scores.get(minigameId);
		return val != null ? val : 0;
	}

	public function submitScore(minigameId:String, score:Int):{highScore:Int, isNewRecord:Bool} {
		var prev = getHighScore(minigameId);
		if (score > prev) {
			scores.set(minigameId, score);
			save();
			return {highScore: score, isNewRecord: true};
		}
		return {highScore: prev, isNewRecord: false};
	}
}
