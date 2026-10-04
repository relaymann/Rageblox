extends Control

signal request_script_editor_visibility(visible: bool)
signal request_save_script_as_asset(script_instance: ScriptInstance)
signal request_track_recently_used_space_script(script_instance: ScriptInstance)

var _script_instance: LuauScriptInstance

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _code: CodeEdit = $Panel/Margin/VBox/Code
@onready var _save: Button = $Panel/Margin/VBox/Buttons/Save
@onready var _asset: Button = $Panel/Margin/VBox/Buttons/SaveAsset


func _ready() -> void:
	visible = false
	_code.syntax_highlighter = _make_highlighter()


func load_from_script_instance(script_instance: LuauScriptInstance) -> void:
	_script_instance = script_instance
	_title.text = "Luau — " + script_instance.script_name
	_code.text = script_instance.get_source_code()
	_save.disabled = false
	_asset.disabled = false
	visible = true


func request_close() -> bool:
	visible = false
	_script_instance = null
	request_script_editor_visibility.emit(false)
	return true


func save() -> void:
	if not _script_instance:
		return
	_script_instance.set_source_code(_code.text)
	_save.disabled = true
	request_track_recently_used_space_script.emit(_script_instance)


func _on_code_text_changed() -> void:
	_save.disabled = false


func _on_save_pressed() -> void:
	save()


func _on_save_asset_pressed() -> void:
	save()
	request_save_script_as_asset.emit(_script_instance)


func _on_close_pressed() -> void:
	request_close()


func _make_highlighter() -> SyntaxHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.95, 0.8, 0.45)
	h.symbol_color = Color(0.75, 0.8, 0.9)
	h.function_color = Color(0.45, 0.8, 1.0)
	h.member_variable_color = Color(0.7, 0.9, 0.7)
	for keyword in ["and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while"]:
		h.add_keyword_color(keyword, Color(1.0, 0.55, 0.8))
	h.add_color_region("--", "", Color(0.45, 0.55, 0.5), true)
	h.add_color_region('"', '"', Color(0.75, 0.85, 0.45))
	h.add_color_region("'", "'", Color(0.75, 0.85, 0.45))
	return h
