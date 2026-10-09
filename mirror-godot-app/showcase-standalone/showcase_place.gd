extends Node3D

const WORLD_SCENE_PATH := "res://rageblox_showcase.tscn"
const STARTUP_TIMEOUT_SECONDS := 12.0

var _world: Node3D
var _interactable: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _camera_pivot: Node3D
var _e_was_down := false
var _yaw := 180.0
var _pitch := -12.0
var _mouse_captured := false
var _world_ready := false
var _loading_panel: ColorRect
var _loading_label: Label

func _ready() -> void:
	DisplayServer.window_set_title("RageBlox Showcase")
	RenderingServer.set_default_clear_color(Color(0.012, 0.016, 0.025))
	_create_player()
	_create_hud()
	_show_loading("Loading RageBlox Showcase…")
	_capture_mouse(false)
	call_deferred("_initialize_showcase")
	_startup_watchdog()

func _initialize_showcase() -> void:
	# Let the first frame draw the loading UI before any procedural world work.
	await get_tree().process_frame
	var world_scene := load(WORLD_SCENE_PATH) as PackedScene
	if world_scene == null:
		_show_startup_error("The Showcase world could not be loaded.\nThe build is missing or failed to parse a Showcase resource.")
		return
	_world = world_scene.instantiate() as Node3D
	if not is_instance_valid(_world):
		_show_startup_error("The Showcase world could not be instantiated.")
		return
	_world.name = "ShowcaseWorld"
	add_child(_world)
	await get_tree().process_frame
	_interactable = _world.get_node_or_null("DoorSwitch") as Node3D
	_world_ready = true
	_show_loading("")
	_capture_mouse(true)

func _startup_watchdog() -> void:
	await get_tree().create_timer(STARTUP_TIMEOUT_SECONDS).timeout
	if not _world_ready and is_instance_valid(_loading_panel):
		_show_startup_error("Showcase startup timed out.\nPress Esc to exit and report this build.")

func _create_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "ShowcasePlayer"
	_player.position = Vector3(0, 2.0, 5)
	add_child(_player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	_player.add_child(shape)
	var body_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.55
	body.height = 1.8
	body_mesh.mesh = body
	body_mesh.position.y = 0.9
	body_mesh.material_override = _player_material()
	_player.add_child(body_mesh)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0, 1.25, 0)
	_player.add_child(_camera_pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 7.0
	arm.margin = 0.3
	arm.collision_mask = 1
	_camera_pivot.add_child(arm)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 70.0
	arm.add_child(_camera)

func _player_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.88, 0.94)
	return material

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ShowcaseHUD"
	add_child(layer)

	_loading_panel = ColorRect.new()
	_loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_panel.color = Color(0.012, 0.016, 0.025, 0.96)
	_loading_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_loading_panel)

	_loading_label = Label.new()
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading_label.position = Vector2(-430, -55)
	_loading_label.size = Vector2(860, 110)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 24)
	_loading_panel.add_child(_loading_label)

	var panel := ColorRect.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(540, 104)
	panel.color = Color(0.02, 0.025, 0.04, 0.86)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(20, 14)
	title.text = "RAGEBLOX SHOWCASE"
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)
	var help := Label.new()
	help.position = Vector2(20, 49)
	help.text = "WASD move  •  Space jump  •  Mouse camera  •  Esc release mouse"
	help.add_theme_font_size_override("font_size", 15)
	panel.add_child(help)

func _show_loading(message: String) -> void:
	if not is_instance_valid(_loading_panel) or not is_instance_valid(_loading_label):
		return
	_loading_label.text = message
	_loading_panel.visible = not message.is_empty()
	if message.is_empty():
		_loading_label.modulate = Color.WHITE
		return
	_loading_label.modulate = Color(0.92, 0.93, 0.97)

func _show_startup_error(message: String) -> void:
	_world_ready = false
	if is_instance_valid(_loading_panel):
		_loading_panel.visible = true
		_loading_panel.color = Color(0.06, 0.012, 0.018, 0.98)
	if is_instance_valid(_loading_label):
		_loading_label.text = "RAGEBLOX SHOWCASE\n\n" + message
		_loading_label.modulate = Color(1.0, 0.45, 0.48)
	_capture_mouse(false)
	push_error(message)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		_yaw -= event.relative.x * 0.12
		_pitch = clamp(_pitch - event.relative.y * 0.08, -55.0, 30.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _world_ready:
		_capture_mouse(true)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _mouse_captured:
			_capture_mouse(false)
		else:
			get_tree().quit()

func _capture_mouse(captured: bool) -> void:
	_mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or not _world_ready:
		return
	_player.rotation_degrees.y = _yaw
	if is_instance_valid(_camera_pivot):
		_camera_pivot.rotation_degrees.x = _pitch
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	input = input.normalized()
	var direction := (Basis(Vector3.UP, deg_to_rad(_yaw)) * Vector3(input.x, 0, input.y)).normalized()
	_player.velocity.x = move_toward(_player.velocity.x, direction.x * 8.0, 30.0 * delta)
	_player.velocity.z = move_toward(_player.velocity.z, direction.z * 8.0, 30.0 * delta)
	if not _player.is_on_floor():
		_player.velocity.y -= 22.0 * delta
	elif Input.is_key_pressed(KEY_SPACE):
		_player.velocity.y = 9.0
	else:
		_player.velocity.y = 0.0
	_player.move_and_slide()

	var e_down := Input.is_key_pressed(KEY_E)
	if e_down and not _e_was_down and is_instance_valid(_interactable):
		if _player.global_position.distance_to(_interactable.global_position) <= 5.0:
			_interactable.call("click_panel")
	_e_was_down = e_down

	if _player.global_position.y < -10.0:
		_player.global_position = Vector3(0, 2, 5)
		_player.velocity = Vector3.ZERO
