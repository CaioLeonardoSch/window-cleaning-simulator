extends StaticBody3D
## Orquestra a limpeza de UM vidro: raycast->UV entra por point_to_uv(), a CPU (GrimeSim)
## manda no jogo, a GPU (GrimePainter/shader) manda na aparência. Seção 3 do plano.

const GLASS_LAYER_BIT := 2  # camada de física "glass" (bit 2)
const WIN_CLEAN := 0.999  # completude só conta 100% limpo — sem meio-termo na v0

@export var glass_size: Vector2 = Vector2(1.6, 1.2)

@onready var mesh: MeshInstance3D = $GlassMesh
@onready var sub_viewport: SubViewport = $SubViewport
@onready var initial_noise: TextureRect = $SubViewport/InitialNoise
@onready var painter: GrimePainter = $SubViewport/GrimePainter

var sim: GrimeSim
var _fluid_tex: ImageTexture
var _material: ShaderMaterial
var _confirmed_clean := false
var _noise_frames_left := 2

func _ready() -> void:
	add_to_group("window_pane")
	collision_layer = GLASS_LAYER_BIT
	collision_mask = 0

	sim = GrimeSim.new(glass_size)

	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER

	_material = mesh.get_surface_override_material(0) as ShaderMaterial
	_material.set_shader_parameter("grime_tex", sub_viewport.get_texture())

	var fluid_img := Image.create_from_data(GrimeSim.COLS, GrimeSim.ROWS, false, Image.FORMAT_RGF, sim.fluid_bytes())
	_fluid_tex = ImageTexture.create_from_image(fluid_img)
	_material.set_shader_parameter("fluid_tex", _fluid_tex)

	initial_noise.texture = _make_noise_texture(256, 192)
	initial_noise.stretch_mode = TextureRect.STRETCH_SCALE

## Textura de ruído fina só pra "sujar" visualmente o vidro no 1º frame (seção 5 do plano) —
## independente da resolução 128x80 da grade CPU. Baixa resolução (256x192) pra ficar barato
## no load; o TextureRect esticado + filtro linear já borra o suficiente.
func _make_noise_texture(w: int, h: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.045
	var img := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			var v: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			img.set_pixel(x, y, Color(v, 0.0, 0.0))
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	sim.step(delta)
	var img := Image.create_from_data(GrimeSim.COLS, GrimeSim.ROWS, false, Image.FORMAT_RGF, sim.fluid_bytes())
	_fluid_tex.update(img)

	# Some frames após o load: some a textura de ruído inicial (o clear off segura o que
	# ela desenhou, seção 5 do plano).
	if _noise_frames_left > 0:
		_noise_frames_left -= 1
		if _noise_frames_left == 0:
			initial_noise.visible = false

	if not _confirmed_clean:
		var st := sim.stats()
		if st.clean >= WIN_CLEAN:
			_confirm_clean()

## Converte um ponto global (do raycast) pra UV 0..1 do vidro (pseudocódigo da seção 6.2).
func point_to_uv(p: Vector3) -> Vector2:
	var l: Vector3 = global_transform.affine_inverse() * p
	return Vector2(l.x / glass_size.x + 0.5, 0.5 - l.y / glass_size.y)

func apply_tool(tool: CleaningTool, stroke: Dictionary) -> void:
	var stamps := tool.apply(sim, stroke)
	painter.queue_stamps(stamps, glass_size)

func stats() -> Dictionary:
	return sim.stats()

## Única leitura de volta da GPU (seção 3): um get_image() de confirmação quando a CPU
## declara limpo, só pra conferir que não sobrou mancha visível que a grade grossa não pegou.
## Um stall de frame na tela de conclusão é irrelevante.
func _confirm_clean() -> void:
	_confirmed_clean = true
	var img := sub_viewport.get_texture().get_image()
	var avg := 0.0
	var samples := 0
	var step := 8
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			avg += img.get_pixel(x, y).r
			samples += 1
	avg /= maxf(1.0, float(samples))
	if avg > 0.15:
		push_warning("window_pane: divergência CPU/GPU na confirmação de limpeza (média %.3f)" % avg)

## Rede de segurança da seção 8 — chamar ao voltar de pausa/resize/foreground.
func repaint_from_cpu() -> void:
	painter.repaint_from_cpu(sim)

## Reinicia a sujeira (tecla `reset`). sim.reset() sozinho não bastava: a máscara GPU
## (grime_painter) só acumula estamparia subtrativa, então sem repintar ela o vidro
## continuava aparecendo limpo mesmo com a grade CPU de volta suja.
func reset_window() -> void:
	sim.reset()
	_confirmed_clean = false
	painter.repaint_from_cpu(sim)
