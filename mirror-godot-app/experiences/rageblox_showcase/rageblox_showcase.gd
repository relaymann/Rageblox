extends Node3D
class_name RageBloxShowcase

const ACCENT := Color(0.78, 0.09, 0.12)
const DARK := Color(0.055, 0.06, 0.07)
const LIGHT := Color(0.78, 0.8, 0.84)
const GROUND := Color(0.18, 0.2, 0.23)
const PLATFORM := Color(0.26, 0.28, 0.32)

func _ready() -> void:
	_build_ground()
	_build_plaza()
	_build_movement_course()
	_build_interaction_area()
	_build_signage()

func _material(color: Color, emission := Color.TRANSPARENT) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.4
	return material

func _box(parent: Node, name: String, position: Vector3, size: Vector3, color: Color, collision := true) -> Node3D:
	var body := StaticBody3D.new() if collision else Node3D.new()
	body.name = name
	body.position = position
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return body

func _label(parent: Node, text: String, position: Vector3, color := LIGHT, size := 1.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 48
	label.pixel_size = 0.004 * size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)

func _build_ground() -> void:
	_box(self, "Ground", Vector3(0, -0.5, 0), Vector3(72, 1, 72), GROUND)
	_box(self, "NorthWall", Vector3(0, 3, -36), Vector3(72, 6, 1), DARK)
	_box(self, "SouthWall", Vector3(0, 3, 36), Vector3(72, 6, 1), DARK)
	_box(self, "EastWall", Vector3(36, 3, 0), Vector3(1, 6, 72), DARK)
	_box(self, "WestWall", Vector3(-36, 3, 0), Vector3(1, 6, 72), DARK)

func _build_plaza() -> void:
	_box(self, "Plaza", Vector3(0, 0.2, 0), Vector3(22, 0.4, 18), PLATFORM)
	var spawn := Node3D.new()
	spawn.name = "ShowcaseSpawn"
	spawn.position = Vector3(0, 0.5, 5)
	spawn.rotation_degrees.y = 180.0
	spawn.set_meta(&"OMI_spawn_point", {"team": ""})
	spawn.add_user_signal(&"player_spawned_here")
	add_child(spawn)
	_box(self, "RageBloxPillarL", Vector3(-8, 3.5, -6), Vector3(2, 7, 2), DARK)
	_box(self, "RageBloxPillarR", Vector3(8, 3.5, -6), Vector3(2, 7, 2), DARK)
	_box(self, "AccentBeam", Vector3(0, 6.5, -6), Vector3(18, 1, 2), ACCENT)
	_label(self, "RAGEBLOX", Vector3(0, 4.2, -7.1), Color.WHITE, 1.4)
	_label(self, "SHOWCASE", Vector3(0, 2.8, -7.1), Color(0.72, 0.74, 0.78), 0.8)

func _build_movement_course() -> void:
	_label(self, "MOVEMENT", Vector3(-21, 2.2, -17), Color.WHITE, 0.9)
	for i in 6:
		var height := 0.8 + i * 0.55
		_box(self, "JumpPlatform%d" % i, Vector3(-21 + i * 4.5, height, -12), Vector3(3.2, 0.6, 3.2), PLATFORM)
	_box(self, "HighPlatform", Vector3(10, 5.0, -18), Vector3(8, 0.8, 8), PLATFORM)
	_box(self, "HighPlatformStep", Vector3(4, 2.0, -18), Vector3(4, 0.8, 4), PLATFORM)
	_label(self, "JUMP + CAMERA TEST", Vector3(-9, 1.8, -17), Color(0.72, 0.74, 0.78), 0.65)
	_label(self, "FALL / RESPAWN", Vector3(10, 6.0, -18), Color(0.9, 0.35, 0.38), 0.65)

func _build_interaction_area() -> void:
	_box(self, "InteractionFloor", Vector3(0, 0.3, 18), Vector3(20, 0.6, 12), DARK)
	_label(self, "INTERACTION TEST", Vector3(0, 3.0, 13.0), Color.WHITE, 0.85)
	var door := _box(self, "TestDoor", Vector3(0, 2.5, 22), Vector3(6, 5, 0.8), ACCENT)
	var button := preload("res://experiences/rageblox_showcase/showcase_interactable.gd").new()
	button.name = "DoorSwitch"
	button.position = Vector3(0, 1.2, 17)
	button.door_path = NodePath("../TestDoor")
	add_child(button)
	_box(button, "ButtonTop", Vector3(0, 0.35, 0), Vector3(1.4, 0.25, 1.4), ACCENT)
	_label(button, "E  OPEN / CLOSE", Vector3(0, 1.0, 0), Color.WHITE, 0.5)
	_label(self, "Try the switch, then walk through the door.", Vector3(0, 2.0, 14.7), Color(0.72, 0.74, 0.78), 0.5)
	_box(self, "DoorRoomBack", Vector3(0, 2.5, 29), Vector3(20, 5, 0.8), DARK)

func _build_signage() -> void:
	_label(self, "Explore the map to test movement, jumping, camera, interaction and respawn.", Vector3(0, 1.7, 9), Color(0.72, 0.74, 0.78), 0.55)
