class_name ToolSponge
extends CleaningTool
## Esponja: só age em movimento e proporcional à água; nunca zera sozinha (deixa película
## pro rodo). Port de tools.js `sponge`.

const RADIUS_M := 0.088
const MIN_MOVE_UV := 0.001  # ~0.6px no protótipo (0.6 / 620)

func apply(sim: GrimeSim, stroke: Dictionary) -> Array[Dictionary]:
	if stroke.dist < MIN_MOVE_UV:
		return []
	var removed := 0.0
	sim.each_in_circle(stroke.uv, RADIUS_M, func(i: int, f: float) -> void:
		var wet: float = clampf(sim.water[i] / 0.25, 0.0, 1.0)
		if sim.grime[i] > 0.12:
			var before: float = sim.grime[i]
			sim.grime[i] = maxf(0.12, sim.grime[i] - 0.07 * wet * f)
			removed += before - sim.grime[i]
		sim.soap[i] = clampf(sim.soap[i] + 0.07 * wet * f, 0.0, 1.0)
		sim.water[i] = clampf(sim.water[i] - 0.02 * f, 0.0, 1.0)
	)
	return [{
		"uv": stroke.uv, "radius": RADIUS_M, "rotation": 0.0,
		"strength": clampf(removed * 4.0, 0.0, 1.0), "type": "soft",
	}]
