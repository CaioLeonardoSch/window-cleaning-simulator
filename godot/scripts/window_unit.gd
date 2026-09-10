extends Node3D
## Constrói moldura, fachada e interior do escritório em runtime, com geometria primitiva
## (seção 4 do plano — troque por meshes de verdade quando houver arte). Mantém
## window_unit.tscn pequeno: só a subárvore de Glass/SubViewport é hand-authored lá.

const GLASS_SIZE := Vector2(1.6, 1.2)
const GLASS_CENTER_Y := 1.55
const FRAME_PROFILE := 0.06
const ROOM_W := 6.0
const ROOM_H := 3.0
const ROOM_D := 4.0

func _ready() -> void:
	_build_frame()
	_build_facade()
	_build_interior()

func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = box_name
	inst.mesh = box_mesh
	inst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	inst.material_override = mat
	parent.add_child(inst)
	return inst

func _build_frame() -> void:
	var frame := Node3D.new()
	frame.name = "Frame"
	add_child(frame)
	var hw := GLASS_SIZE.x * 0.5
	var hh := GLASS_SIZE.y * 0.5
	var col := Color(0.15, 0.16, 0.18)
	var depth := 0.08
	_box(frame, "Top", Vector3(GLASS_SIZE.x + FRAME_PROFILE * 2.0, FRAME_PROFILE, depth),
		Vector3(0, GLASS_CENTER_Y + hh + FRAME_PROFILE * 0.5, 0), col)
	_box(frame, "Bottom", Vector3(GLASS_SIZE.x + FRAME_PROFILE * 2.0, FRAME_PROFILE, depth),
		Vector3(0, GLASS_CENTER_Y - hh - FRAME_PROFILE * 0.5, 0), col)
	_box(frame, "Left", Vector3(FRAME_PROFILE, GLASS_SIZE.y, depth),
		Vector3(-hw - FRAME_PROFILE * 0.5, GLASS_CENTER_Y, 0), col)
	_box(frame, "Right", Vector3(FRAME_PROFILE, GLASS_SIZE.y, depth),
		Vector3(hw + FRAME_PROFILE * 0.5, GLASS_CENTER_Y, 0), col)

func _build_facade() -> void:
	_box(self, "Facade", Vector3(ROOM_W + 2.0, ROOM_H + 1.5, 0.15),
		Vector3(0, GLASS_CENTER_Y - 0.2, -0.12), Color(0.55, 0.5, 0.42))

func _build_interior() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)

	var wall_col := Color(0.88, 0.87, 0.82)
	var back_z := -ROOM_D
	_box(interior, "Floor", Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0, -0.05, back_z * 0.5), Color(0.6, 0.56, 0.5))
	_box(interior, "Ceiling", Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0, ROOM_H + 0.05, back_z * 0.5), wall_col)
	_box(interior, "BackWall", Vector3(ROOM_W, ROOM_H, 0.1), Vector3(0, ROOM_H * 0.5, back_z), wall_col)
	_box(interior, "LeftWall", Vector3(0.1, ROOM_H, ROOM_D), Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, back_z * 0.5), wall_col)
	_box(interior, "RightWall", Vector3(0.1, ROOM_H, ROOM_D), Vector3(ROOM_W * 0.5, ROOM_H * 0.5, back_z * 0.5), wall_col)

	_box(interior, "Table", Vector3(1.4, 0.75, 0.7), Vector3(0.0, 0.375, back_z + 1.3), Color(0.42, 0.3, 0.2))
	_box(interior, "Monitor", Vector3(0.5, 0.35, 0.05), Vector3(0.0, 0.75 + 0.2, back_z + 1.05), Color(0.05, 0.05, 0.06))
	_box(interior, "MonitorStand", Vector3(0.08, 0.2, 0.08), Vector3(0.0, 0.75 + 0.1, back_z + 1.2), Color(0.1, 0.1, 0.1))

	for side in [-1.6, 1.6]:
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%s" % side
		lamp.position = Vector3(side, ROOM_H - 0.15, back_z * 0.5)
		lamp.light_energy = 4.0
		lamp.omni_range = 5.0
		interior.add_child(lamp)
		_box(interior, "LampFixture%s" % side, Vector3(0.3, 0.05, 0.3), lamp.position + Vector3(0, 0.05, 0), Color(1.0, 0.98, 0.9))
