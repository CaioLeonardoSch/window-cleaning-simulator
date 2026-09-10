class_name ToolSpray
extends CleaningTool
## Borrifador: só molha o vidro, não tira sujeira sozinho — isso fica pra esponja/rodo
## (as três etapas precisam ser necessárias, não só a preferida). Diverge de tools.js `spray`
## de propósito: lá o borrifador também raspava um fiapo de sujeira, mas isso deixava dar
## pra limpar a janela inteira só segurando o borrifador.

const RADIUS_M := 0.14

func apply(sim: GrimeSim, stroke: Dictionary) -> Array[Dictionary]:
	var amount: float = (2.2 * stroke.dt) / float(stroke.sub)
	sim.each_in_circle(stroke.uv, RADIUS_M, func(i: int, f: float) -> void:
		sim.water[i] = clampf(sim.water[i] + amount * f, 0.0, 1.0)
	)
	return []
