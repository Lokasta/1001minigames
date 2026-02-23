package shared;

/**
	Funções de easing para animações (juice).
	Entrada t em [0, 1]; saída geralmente em [0, 1].
**/
class Easing {
	/** t^3 — suave no fim (bom para “sai de cena”). */
	public static inline function easeOutCubic(t: Float): Float {
		var u = 1 - t;
		return 1 - u * u * u;
	}

	/** Acelera no início. */
	public static inline function easeInCubic(t: Float): Float {
		return t * t * t;
	}

	/** Suave no início e no fim. */
	public static inline function easeInOutCubic(t: Float): Float {
		return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
	}

	/** Back overshoot — sai um pouco e volta (bom para “pop”). */
	public static inline function easeOutBack(t: Float, overshoot: Float = 1.70158): Float {
		var c = overshoot + 1;
		return 1 + c * Math.pow(t - 1, 3) + overshoot * Math.pow(t - 1, 2);
	}

	/** Elástico no fim. */
	public static inline function easeOutElastic(t: Float): Float {
		if (t <= 0) return 0;
		if (t >= 1) return 1;
		var p = 0.3;
		return Math.pow(2, -10 * t) * Math.sin((t - p / 4) * (2 * Math.PI) / p) + 1;
	}
}
