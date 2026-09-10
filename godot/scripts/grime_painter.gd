class_name GrimePainter
extends Node2D
## Pintor do SubViewport (seção 5 do plano): consome a fila de brush stamps das ferramentas
## e desenha uma vez por frame com blend subtrativo. Não guarda lógica de jogo — só aparência.
## Pincéis (brush_soft / brush_blade) são gerados em runtime; troque por assets/*.png depois
## se quiser mais detalhe artístico (ver seção 4 do plano).

const VP_SIZE := Vector2(1024.0, 768.0)

var _pending: Array[Dictionary] = []
var _brush_soft: ImageTexture
var _brush_blade: ImageTexture

var _repaint_texture: ImageTexture = null

func _ready() -> void:
	_brush_soft = _make_radial_brush(128)
	_brush_blade = _make_rect_brush(48, 220)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	material = mat

## Radial, mesmo falloff da simulação CPU (1 - d^2*0.75) para o pincel bater com a lógica.
func _make_radial_brush(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var dx: float = (x + 0.5 - c) / c
			var dy: float = (y + 0.5 - c) / c
			var d2: float = dx * dx + dy * dy
			var a: float = clampf(1.0 - d2 * 0.75, 0.0, 1.0) if d2 <= 1.0 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

## Retangular, feather nas pontas (mesma curva de each_in_rect) — a lâmina do rodo.
func _make_rect_brush(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	for y in h:
		var ty: float = absf(y + 0.5 - cy) / cy
		var fy: float = 1.0 if ty < 0.75 else clampf((1.0 - ty) * 4.0, 0.0, 1.0)
		for x in w:
			var tx: float = absf(x + 0.5 - cx) / cx
			var fx: float = 1.0 if tx < 0.75 else clampf((1.0 - tx) * 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(fx * fy, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Enfileira os stamps devolvidos por CleaningTool.apply(); convertidos de metros/UV pra pixel.
func queue_stamps(stamps: Array[Dictionary], glass_size: Vector2) -> void:
	if stamps.is_empty():
		return
	for s in stamps:
		if s.strength <= 0.0:
			continue
		_pending.append(_to_pixel_stamp(s, glass_size))
	if not _pending.is_empty():
		queue_redraw()

func _to_pixel_stamp(s: Dictionary, glass_size: Vector2) -> Dictionary:
	var uv: Vector2 = s.uv
	var pos := Vector2(uv.x * VP_SIZE.x, uv.y * VP_SIZE.y)
	if s.type == "soft":
		var r_px: float = (float(s.radius) / glass_size.x) * VP_SIZE.x
		return {"pos": pos, "rot": float(s.rotation), "size": Vector2(r_px, r_px) * 2.0,
			"strength": float(s.strength), "tex": _brush_soft}
	var w_px: float = (float(s.half_w) / glass_size.x) * VP_SIZE.x * 2.0
	var h_px: float = (float(s.half_h) / glass_size.y) * VP_SIZE.y * 2.0
	return {"pos": pos, "rot": float(s.rotation), "size": Vector2(w_px, h_px),
		"strength": float(s.strength), "tex": _brush_blade}

func _draw() -> void:
	if _repaint_texture != null:
		var prev_mat := material
		material = null
		draw_texture_rect(_repaint_texture, Rect2(Vector2.ZERO, VP_SIZE), false)
		material = prev_mat
		_repaint_texture = null

	for s in _pending:
		draw_set_transform(s.pos, s.rot, Vector2.ONE)
		var rect := Rect2(-s.size * 0.5, s.size)
		draw_texture_rect(s.tex, rect, false, Color(1.0, 1.0, 1.0, s.strength))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pending.clear()

## Rede de segurança (seção 8): reconstrói a máscara inteira a partir da grade CPU 128x80 —
## borrada, sem detalhe fino, mas correta. Chamar em NOTIFICATION_APPLICATION_RESUMED, troca
## de resolução e volta de pausa.
func repaint_from_cpu(sim: GrimeSim) -> void:
	var img := Image.create_from_data(GrimeSim.COLS, GrimeSim.ROWS, false, Image.FORMAT_RF, sim.grime_bytes())
	_repaint_texture = ImageTexture.create_from_image(img)
	_pending.clear()
	queue_redraw()
