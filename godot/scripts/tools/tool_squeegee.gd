class_name ToolSqueegee
extends CleaningTool
## Rodo: lâmina retangular orientada pelo eixo dominante do movimento; remove sujeira
## proporcional à lubrificação; em vidro seco piora. Port de tools.js `squeegee`.

const HALF_BLADE_M := 0.217
const HALF_THICK_M := 0.02

func apply(sim: GrimeSim, stroke: Dictionary) -> Array[Dictionary]:
	var delta: Vector2 = stroke.delta
	var vertical: bool = absf(delta.x) >= absf(delta.y)
	var hw: float = HALF_THICK_M if vertical else HALF_BLADE_M
	var hh: float = HALF_BLADE_M if vertical else HALF_THICK_M

	var removed := 0.0
	sim.each_in_rect(stroke.uv, hw, hh, func(i: int, f: float) -> void:
		var lube: float = clampf(sim.soap[i] * 2.6 + sim.water[i] * 1.2, 0.0, 1.0)
		var before: float = sim.grime[i]
		sim.grime[i] = clampf(sim.grime[i] * (1.0 - 0.95 * lube * f), 0.0, 1.0)
		sim.soap[i] = clampf(sim.soap[i] * (1.0 - 0.92 * f), 0.0, 1.0)
		sim.water[i] = clampf(sim.water[i] * (1.0 - 0.88 * f), 0.0, 1.0)
		if lube < 0.08 and sim.grime[i] > 0.05:
			sim.grime[i] = minf(0.75, sim.grime[i] + 0.008 * f)
		removed += before - sim.grime[i]
	)

	var rot: float = 0.0 if vertical else PI / 2.0
	return [{
		"uv": stroke.uv, "half_w": hw, "half_h": hh, "rotation": rot,
		"strength": clampf(removed * 3.0, 0.0, 1.0), "type": "blade",
	}]
