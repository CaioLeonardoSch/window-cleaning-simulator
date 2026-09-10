extends Node3D
## Mouse gira a cabeça, mira fixa no centro, ferramenta é viewmodel (seção 2 do plano).

const MOUSE_SENS := 0.0022
const PITCH_LIMIT := 1.2217  # ~70°
const AIM_DISTANCE := 3.0
const GLASS_LAYER := 2  # tem que bater com window_pane.gd: GLASS_LAYER_BIT
const EYE_HEIGHT := 1.65

# Limites do andaime (scaffold.tscn: plataforma 3.00x0.80m, guarda-corpo em z=1.15).
# Sem CharacterBody3D/colisão própria — só clamp na posição, é o suficiente pra não
# atravessar o vidro (z baixo) nem o corrimão (z alto) nem cair pelas pontas (x).
const PLATFORM_X_RANGE := Vector2(-1.2, 1.2)
const PLATFORM_Z_RANGE := Vector2(0.45, 1.0)
const MOVE_SPEED := 1.3

const TOOL_NAMES := ["Borrifador (1)", "Esponja (2)", "Rodo (3)"]

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var viewmodel: Node3D = $CameraRig/Camera3D/Viewmodel
@onready var aim_marker: MeshInstance3D = $CameraRig/Camera3D/AimMarker

var active_window = null  # window_pane.gd (StaticBody3D "Glass"), achado via grupo
var tools: Array[CleaningTool] = []
var active_tool_index := 0
var _prev_uv := Vector2(-1, -1)
var _last_look := Vector2.ZERO
var _sway_time := 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tools = [ToolSpray.new(), ToolSponge.new(), ToolSqueegee.new()]
	var panes := get_tree().get_nodes_in_group("window_pane")
	if not panes.is_empty():
		active_window = panes[0]
	_set_active_tool(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_y(-event.relative.x * MOUSE_SENS)
		var pitch: float = camera.rotation.x - event.relative.y * MOUSE_SENS
		camera.rotation.x = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("tool_1"):
		_set_active_tool(0)
	elif event.is_action_pressed("tool_2"):
		_set_active_tool(1)
	elif event.is_action_pressed("tool_3"):
		_set_active_tool(2)
	elif event.is_action_pressed("reset") and active_window != null:
		active_window.reset_window()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_move(delta)
	_sway_viewmodel(delta)
	_sway_scaffold(delta)

	var hit := _aim()
	if hit.is_empty():
		aim_marker.visible = false
		_prev_uv = Vector2(-1, -1)
		return

	aim_marker.visible = true
	aim_marker.global_position = hit.position

	if active_window == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not Input.is_action_pressed("clean"):
		_prev_uv = Vector2(-1, -1)
		return

	var uv: Vector2 = active_window.point_to_uv(hit.position)
	if _prev_uv.x < 0.0:
		_prev_uv = uv

	var stroke := {
		"uv": uv, "uv_prev": _prev_uv,
		"delta": uv - _prev_uv, "dist": uv.distance_to(_prev_uv),
		"dt": delta, "sub": 1,
	}
	active_window.apply_tool(tools[active_tool_index], stroke)
	_prev_uv = uv

## Anda pela plataforma do andaime (WASD), relativo pra onde a câmera olha (yaw) — W sempre
## "pra frente da tela", não um eixo fixo do mundo. Nada de física ainda, só clamp nos limites
## da plataforma. Sem movimento vertical (plano: fora de escopo da v0).
func _move(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input.y += 1.0
	if Input.is_action_pressed("move_back"):
		input.y -= 1.0
	if Input.is_action_pressed("move_left"):
		input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input.x += 1.0
	if input == Vector2.ZERO:
		return
	input = input.normalized()

	var basis := camera_rig.global_transform.basis
	var forward: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right: Vector3 = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var move: Vector3 = (forward * input.y + right * input.x) * MOVE_SPEED * delta

	position.x = clampf(position.x + move.x, PLATFORM_X_RANGE.x, PLATFORM_X_RANGE.y)
	position.z = clampf(position.z + move.z, PLATFORM_Z_RANGE.x, PLATFORM_Z_RANGE.y)
	position.y = EYE_HEIGHT

## Raycast do centro da tela (seção 6.2 do plano) — a mira é sempre o centro, não o mouse.
func _aim() -> Dictionary:
	var vp := get_viewport()
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	var from: Vector3 = camera.project_ray_origin(center)
	var to: Vector3 = from + camera.project_ray_normal(center) * AIM_DISTANCE
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = GLASS_LAYER
	return camera.get_world_3d().direct_space_state.intersect_ray(params)

func _set_active_tool(i: int) -> void:
	active_tool_index = i
	for c in viewmodel.get_child_count():
		viewmodel.get_child(c).visible = (c == i)

func _sway_viewmodel(delta: float) -> void:
	var look := Vector2(camera_rig.rotation.y, camera.rotation.x)
	var vel: Vector2 = (look - _last_look) / maxf(delta, 0.0001)
	_last_look = look
	var target_rot := Vector3(-vel.y * 0.02, -vel.x * 0.02, 0.0)
	viewmodel.rotation = viewmodel.rotation.lerp(target_rot, clampf(delta * 8.0, 0.0, 1.0))

## Balanço lento do andaime (etapa 7 do plano) — como o raio de mira sai da câmera, ele
## balança junto e continua correto (seção 2 do plano), sem precisar realinhar nada.
func _sway_scaffold(delta: float) -> void:
	_sway_time += delta
	var x: float = sin(_sway_time * 0.6) * 0.012 + sin(_sway_time * 0.37) * 0.006
	var y: float = sin(_sway_time * 0.5 + 1.3) * 0.008
	camera_rig.position = Vector3(x, y, 0.0)
	camera_rig.rotation.z = sin(_sway_time * 0.45) * 0.006
