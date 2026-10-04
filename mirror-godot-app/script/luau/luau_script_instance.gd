class_name LuauScriptInstance
extends ScriptInstance

const MAX_SOURCE_LENGTH := 65536
const RUNTIME_NODE_PREFIX := "__RageBloxLuau_"

var _source_code: String = ""
var _runtime_script: Node


func setup_script_entity_data(script_entity_data: Dictionary) -> void:
	super(script_entity_data)
	_source_code = String(script_entity_data.get("code", ""))
	if _source_code.length() > MAX_SOURCE_LENGTH:
		_source_code = _source_code.left(MAX_SOURCE_LENGTH)
	_ensure_runtime_script()


func serialize_script_entity_data() -> Dictionary:
	return {
		"code": _source_code,
		"id": script_id,
		"name": script_name,
		"type": "Luau",
	}


func serialize_script_instance_to_json() -> Dictionary:
	var ret := super()
	ret["type"] = "Luau"
	ret.sort()
	return ret


func get_source_code() -> String:
	return _source_code


func set_source_code(source_code: String) -> void:
	if source_code.length() > MAX_SOURCE_LENGTH:
		Notify.error("Luau Script", "The script is too large. Maximum size is 64 KB.")
		return
	_source_code = source_code
	_ensure_runtime_script()
	script_data_contents_changed()


func can_execute() -> bool:
	return super() and Zone.is_host() and not Engine.is_editor_hint()


func cleanup_script_instance() -> void:
	_remove_runtime_script()
	super()


func is_script_instance_setup() -> bool:
	return not _source_code.is_empty() or not script_id.is_empty()


func sync_script_inst_params_with_script_data() -> void:
	# Luau uses normal signal connections and Roblox-style events directly.
	entry_parameters = {}


func update_script_entity_data_from_network(script_entity_data: Dictionary) -> void:
	setup_script_entity_data(script_entity_data)
	script_entity_data_updated_from_network.emit()


func create_inspector_parameter_input(_entry_id: String, _parameter_port_array: Array) -> void:
	# Luau does not use the legacy GDScript entry-input system.
	pass


func get_default_value_of_entry_inspector_parameter(_entry_id: String, _parameter_name: String) -> Variant:
	return null


func _remove_runtime_script() -> void:
	if is_instance_valid(_runtime_script):
		_runtime_script.queue_free()
	_runtime_script = null


func _ensure_runtime_script() -> void:
	if not can_execute() or not is_instance_valid(target_node):
		_remove_runtime_script()
		return
	if _source_code.is_empty():
		_remove_runtime_script()
		return

	_remove_runtime_script()

	if not ClassDB.class_exists("ServerScript") or not ClassDB.class_exists("LuauScript"):
		push_error("RageBlox Luau runtime is not loaded. Run infrastructure_scripts/setup-luau.sh and restart Godot.")
		return

	var luau_resource = ClassDB.instantiate("LuauScript")
	var server_script = ClassDB.instantiate("ServerScript")
	if luau_resource == null or server_script == null:
		push_error("RageBlox could not create the Luau runtime objects.")
		return

	luau_resource.set_source_code(_source_code)
	server_script.set_codigo_luau(luau_resource)
	server_script.set_script_id(script_id)
	server_script.set_enabled(script_enabled)
	server_script.name = RUNTIME_NODE_PREFIX + script_id

	target_node.add_child(server_script)
	_runtime_script = server_script


func reload_source_code() -> void:
	_ensure_runtime_script()
