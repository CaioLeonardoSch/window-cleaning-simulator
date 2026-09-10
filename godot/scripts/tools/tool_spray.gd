class_name ToolSpray
extends CleaningTool
## Borrifador: molha o vidro, tira só um fiapo de sujeira sozinho. Port de tools.js `spray`.

const RADIUS_M := 0.14

func apply(sim: GrimeSim, stroke: Dictionary) -> Array[Dictionary]:
	var amount: float = (2.2 * stroke.dt) / float(stroke.sub)
	sim.each_in_circle(stroke.uv, RADIUS_M, func(i: int, f: float) -> void:
		sim.water[i] = clampf(sim.water[i] + amount * f, 0.0, 1.0)
		sim.grime[i] = clampf(sim.grime[i] - amount * 0.06 * f, 0.0, 1.0)
	)
	return [{
		"uv": stroke.uv, "radius": RADIUS_M, "rotation": 0.0,
		"strength": clampf(amount * 0.5, 0.0, 1.0), "type": "soft",
	}]
