class_name GrimeSim
extends RefCounted
## Port de web-prototype/js/grid.js. Grade CPU 128x80 em UV do vidro (0..1).
## É a verdade do jogo — a GPU (grime_painter.gd) só cuida da aparência.

const COLS := 128
const ROWS := 80

var glass_size: Vector2
var cell_size: Vector2
var n: int
var grime: PackedFloat32Array
var water: PackedFloat32Array
var soap: PackedFloat32Array
var foam: PackedFloat32Array
var initial_grime: float = 1.0

func _init(p_glass_size: Vector2) -> void:
	glass_size = p_glass_size
	cell_size = Vector2(glass_size.x / COLS, glass_size.y / ROWS)
	n = COLS * ROWS
	grime = PackedFloat32Array()
	grime.resize(n)
	water = PackedFloat32Array()
	water.resize(n)
	soap = PackedFloat32Array()
	soap.resize(n)
	foam = _value_noise(26, 18)
	reset()

## Ruído de valor bilinear — mesmo algoritmo do protótipo (valueNoise em grid.js).
func _value_noise(fx: int, fy: int) -> PackedFloat32Array:
	var gw := fx + 1
	var gh := fy + 1
	var g := PackedFloat32Array()
	g.resize(gw * gh)
	for i in g.size():
		g[i] = randf()

	var out := PackedFloat32Array()
	out.resize(COLS * ROWS)
	for y in ROWS:
		var v: float = (float(y) / float(ROWS - 1)) * fy
		var y0: int = mini(gh - 2, int(floor(v)))
		var ty: float = v - y0
		var sy: float = ty * ty * (3.0 - 2.0 * ty)
		for x in COLS:
			var u: float = (float(x) / float(COLS - 1)) * fx
			var x0: int = mini(gw - 2, int(floor(u)))
			var tx: float = u - x0
			var sx: float = tx * tx * (3.0 - 2.0 * tx)
			var a: float = g[y0 * gw + x0]
			var b: float = g[y0 * gw + x0 + 1]
			var c: float = g[(y0 + 1) * gw + x0]
			var d: float = g[(y0 + 1) * gw + x0 + 1]
			out[y * COLS + x] = lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)
	return out

## Sujeira inicial: base + fino + crosta nos cantos + escorridos de chuva (port de reset() em grid.js).
func reset() -> void:
	var base := _value_noise(7, 5)
	var fine := _value_noise(21, 14)
	var total := 0.0

	for y in ROWS:
		var v: float = float(y) / float(ROWS - 1)
		for x in COLS:
			var u: float = float(x) / float(COLS - 1)
			var i: int = y * COLS + x

			var g: float = 0.38 + 0.34 * base[i] + 0.16 * fine[i]

			var edge: float = 1.0 - minf(1.0, minf(u, 1.0 - u) * 5.0) * minf(1.0, minf(v, 1.0 - v) * 5.0)
			g += 0.3 * edge * edge

			var drip: float = sin(u * PI * 11.0 + base[i] * 3.0) * 0.5 + 0.5
			g += 0.18 * pow(drip, 3.0) * v

			g = clampf(g, 0.0, 1.0)
			grime[i] = g
			water[i] = 0.0
			soap[i] = 0.0
			total += g

	initial_grime = maxf(0.001, total / float(n))

## Percorre células dentro de um círculo. center_uv em 0..1, radius_m em metros.
## fn(indice, falloff 0..1)
func each_in_circle(center_uv: Vector2, radius_m: float, fn: Callable) -> void:
	var cx: float = center_uv.x * COLS
	var cy: float = center_uv.y * ROWS
	var rx: float = radius_m / cell_size.x
	var ry: float = radius_m / cell_size.y
	if rx <= 0.0 or ry <= 0.0:
		return

	var x0: int = maxi(0, int(floor(cx - rx)))
	var x1: int = mini(COLS - 1, int(ceil(cx + rx)))
	var y0: int = maxi(0, int(floor(cy - ry)))
	var y1: int = mini(ROWS - 1, int(ceil(cy + ry)))

	for gy in range(y0, y1 + 1):
		var dy: float = (gy + 0.5 - cy) / ry
		for gx in range(x0, x1 + 1):
			var dx: float = (gx + 0.5 - cx) / rx
			var d2: float = dx * dx + dy * dy
			if d2 > 1.0:
				continue
			fn.call(gy * COLS + gx, 1.0 - d2 * 0.75)

## Percorre células dentro de um retângulo (lâmina do rodo), em UV/metros.
func each_in_rect(center_uv: Vector2, half_w_m: float, half_h_m: float, fn: Callable) -> void:
	var cx: float = center_uv.x * COLS
	var cy: float = center_uv.y * ROWS
	var rx: float = half_w_m / cell_size.x
	var ry: float = half_h_m / cell_size.y
	if rx <= 0.0 or ry <= 0.0:
		return

	var x0: int = maxi(0, int(floor(cx - rx)))
	var x1: int = mini(COLS - 1, int(ceil(cx + rx)))
	var y0: int = maxi(0, int(floor(cy - ry)))
	var y1: int = mini(ROWS - 1, int(ceil(cy + ry)))

	for gy in range(y0, y1 + 1):
		var ty: float = absf(gy + 0.5 - cy) / ry
		if ty > 1.0:
			continue
		var fy: float = 1.0 if ty < 0.75 else (1.0 - ty) * 4.0
		for gx in range(x0, x1 + 1):
			var tx: float = absf(gx + 0.5 - cx) / rx
			if tx > 1.0:
				continue
			var fx: float = 1.0 if tx < 0.75 else (1.0 - tx) * 4.0
			fn.call(gy * COLS + gx, clampf(fx * fy, 0.0, 1.0))

## Água escorre para baixo, última linha pinga fora, água/sabão secam devagar.
func step(dt: float) -> void:
	var flow: float = minf(0.2, dt * 0.7)

	for y in range(ROWS - 2, -1, -1):
		for x in COLS:
			var i: int = y * COLS + x
			var w: float = water[i]
			if w > 0.3:
				var move: float = (w - 0.3) * flow * 0.9
				water[i] = w - move
				water[i + COLS] = clampf(water[i + COLS] + move, 0.0, 1.0)

	var drain: float = maxf(0.0, 1.0 - dt * 0.5)
	for x2 in COLS:
		water[(ROWS - 1) * COLS + x2] *= drain

	var dry_w: float = maxf(0.0, 1.0 - dt * 0.015)
	var dry_s: float = maxf(0.0, 1.0 - dt * 0.008)
	for j in n:
		water[j] *= dry_w
		soap[j] *= dry_s

## Sujeira média, resíduo (água+sabão) e % limpo — mesmas fórmulas de grid.js stats().
func stats() -> Dictionary:
	var g := 0.0
	var r := 0.0
	for i in n:
		g += grime[i]
		r += soap[i] + water[i] * 0.6
	g /= float(n)
	r /= float(n)
	return {
		"grime": g,
		"residue": clampf(r, 0.0, 1.0),
		"clean": clampf((initial_grime - g) / initial_grime, 0.0, 1.0),
	}

## Água (R) e sabão (G) intercalados, para upload em um único FORMAT_RGF (seção 3 do plano).
func fluid_bytes() -> PackedByteArray:
	var interleaved := PackedFloat32Array()
	interleaved.resize(n * 2)
	for i in n:
		interleaved[i * 2] = water[i]
		interleaved[i * 2 + 1] = soap[i]
	return interleaved.to_byte_array()

## Sujeira crua, para a rede de segurança repaint_from_cpu (seção 8 do plano).
func grime_bytes() -> PackedByteArray:
	return grime.to_byte_array()
