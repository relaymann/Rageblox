# Boot scene and bootup script are loaded and
# only executed when app is started.
class_name Game
extends Node

static var popups = []

func _set_rageblox_window_icon() -> void:
	var icon_texture := load("res://art/icons/rageblox_icon.png") as Texture2D
	if icon_texture:
		var icon_image := icon_texture.get_image()
		if icon_image:
			DisplayServer.window_set_icon(icon_image)


func _start_client():
	_set_rageblox_window_icon()
	DisplayServer.window_set_title(ProjectSettings.get_setting("application/config/window_name", "RageBlox"))
	Cursors.setup()
	if ProjectSettings.get_setting("feature_flags/disable_login", false):
		LoginService.setup_deeplink_login(get_tree())
	else:
		var login_code: bool = ProjectSettings.get_setting("feature_flags/force_enable_login_code", false)
		if not login_code:
			GameUI.instance.login_ui.start_login_ui()
			GameUI.instance.login_ui.show()
	Deeplinking.setup()
	await Zone.wait_till_notifications_ready()
	await Zone.wait_till_deeplink_ready()
	var notification_ui = Notify.get_notifications_ui()
	var is_closable = ProjectSettings.get_setting("mirror/critical_app_error/is_closable", true)


	Zone.client.join_server_start.connect(func():
		for popup in popups:
			if not is_instance_valid(popup):
				continue
			popup.hide()
			var parent = popup.get_parent()
			parent.remove_child(popup)
			popup.queue_free()
		popups.clear())

	print("------------------------- Checking for update -------------------------------")
	# make request for version from server
	Net.version_client.get_client_version()
	var version = await Net.version_client.version_received
	if ProjectSettings.get_setting("feature_flags/check_version_on_start", false) and version != Util.get_version_string():
		critical_error(Client.JOINER_ERRORS.VERSION_MISMATCH, "Your client is out of date, please update it to %s from %s" % [version, Util.get_version_string()] )
		return
	if ProjectSettings.get_setting("feature_flags/disable_login", false) and not Zone.client.is_client_connected_to_server():
		var title = ProjectSettings.get_setting("mirror/disable_login/notify/title",
			"Please open The Mirror web app"
		)
		var description = ProjectSettings.get_setting("mirror/disable_login/notify/description",
			"Please click this link below to open your browser \n[url]https://in.themirror.space/[/url]\n"
		)
		popups.append(notification_ui.notify(
			title, description,
			null, true, false
		))


static func critical_error(error: Client.JOINER_ERRORS, description) -> void:
	var contextual_errors = ProjectSettings.get_setting("feature_flags/show_error_solution", true)
	var error_solution = Zone.client.get_error_solution(error)
	var error_status: String = Client.JOINER_ERRORS.keys()[error]
	var error_name = error_status.replace("_", " ")
	var notification_ui = Notify.get_notifications_ui()

	var is_closable = ProjectSettings.get_setting("mirror/critical_app_error/is_closable", true)
	if contextual_errors:
		push_error("Criticial Error: ", error_name, ", ", description, " solution: ", error_solution)
		var popup = notification_ui.notify(
			str(error_name),
			description + "\n\n" + error_solution,
			null, true, is_closable
		)
		popups.append(popup)
		return

	var error_string = ProjectSettings.get_setting("mirror/critical_app_error/error_string", "")
	push_error("Critical Error: ", error_name, error_string)
	var popup = notification_ui.notify(
		str(error_name),
		description +
		(error_string % str(error_status) if error_string.contains("%s") else error_string),
		null, true, is_closable
	)
	popups.append(popup)


## This GLTF stuff can be anywhere as long as it runs when the game starts.
func _setup_gltf() -> void:
	var ext = GLTFDocumentExtensionMirrorModelPrimitive.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionMirrorEquipable.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionOMISeat.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionOMISpawnPoint.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionOMIPhysicsJoint.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionOMIVehicle.new()
	GLTFDocument.register_gltf_document_extension(ext)
	ext = GLTFDocumentExtensionVRMNodeConstraint.new()
	GLTFDocument.register_gltf_document_extension(ext)


func _complete_bootup():
	Zone.bootup_completed = true
	Zone.completed_booting.emit()


const _SPACE_SCENE_START_TIMEOUT_SECONDS := 10.0


func _wait_for_space_scene_ready() -> bool:
	var deadline := Time.get_ticks_msec() + int(_SPACE_SCENE_START_TIMEOUT_SECONDS * 1000.0)
	while not is_instance_valid(Zone.Scene):
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


func _ready() -> void:
	if "--rageblox-studio" in OS.get_cmdline_args() or bool(ProjectSettings.get_setting("rageblox_studio/studio_launcher", false)):
		var studio_scene := load("res://scenes/studio_start.tscn")
		var studio_ui := studio_scene.instantiate()
		get_tree().root.add_child(studio_ui)
		return
	GameUI._root_node = get_node("/root/")
	_setup_gltf()
	if Util.is_host_commandline() or Util.is_headless_server():
		if await _start_server():
			_complete_bootup()
		else:
			push_error("RageBlox server failed to start; refusing to fall through into client mode.")
			get_tree().quit(1)
		return
	_start_client()
	_complete_bootup()


func _start_server() -> bool:
	await LoginService.server_login_if_required(get_tree())
	# SpaceScene must exist before the server populates built-in spaces.
	Zone.change_to_space_scene()
	if not await _wait_for_space_scene_ready():
		push_error("SpaceScene did not initialize before the server startup deadline.")
		return false
	if Zone.start_server():
		DisplayServer.window_set_title("RageBlox Dedicated Server")
		_setup_server_window()
		var properties = {}
		properties.cpu_info = OS.get_processor_name()
		properties.cpu_cores = OS.get_processor_count()
		Analytics.track_event(AnalyticsEvent.TYPE.SERVER_STARTUP, properties)
		return true
	return false


func _setup_server_window():
	var use_server_camera = ProjectSettings.get_setting("mirror/use_server_camera")
	if use_server_camera:
		DisplayServer.window_set_size(Vector2(400, 250))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		DisplayServer.window_set_size(Vector2(100, 60))
