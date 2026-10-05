extends PanelContainer
class_name StudioCommandPalette

@onready var _search: LineEdit = %Search
@onready var _list: ItemList = %Commands
var _commands: Array[Dictionary] = []

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_palette()
		get_viewport().set_input_as_handled()

func _ready() -> void:
	_commands = [
		{"title": "Playtest", "hint": "Start a preview ready check", "action": &"play"},
		{"title": "Publish", "hint": "Open the publish window", "action": &"publish"},
		{"title": "Save Version", "hint": "Save a named version", "action": &"save_version"},
		{"title": "Restore Version", "hint": "Open version restore", "action": &"restore"},
		{"title": "Asset Browser", "hint": "Toggle the asset browser", "action": &"assets"},
		{"title": "Undo", "hint": "Undo the last edit", "action": &"undo"},
		{"title": "Redo", "hint": "Redo the last edit", "action": &"redo"},
		{"title": "Close", "hint": "Close this palette", "action": &"close"}
	]
	_search.text_changed.connect(_on_search_changed)
	_search.text_submitted.connect(_on_search_submitted)
	_list.item_activated.connect(_on_item_activated)
	_refresh_list()
	hide()

func open_palette() -> void:
	_search.clear()
	_refresh_list()
	show()
	_search.grab_focus()
	if _list.item_count > 0:
		_list.select(0)

func close_palette() -> void:
	hide()
	_search.release_focus()

func _refresh_list() -> void:
	_list.clear()
	var query := _search.text.strip_edges().to_lower()
	for command in _commands:
		if query.is_empty() or str(command.title).to_lower().contains(query) or str(command.hint).to_lower().contains(query):
			var index := _list.add_item(str(command.title))
			_list.set_item_tooltip(index, str(command.hint))
	if _list.item_count > 0:
		_list.select(0)

func _selected_command() -> Dictionary:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return {}
	var query := _search.text.strip_edges().to_lower()
	var visible_commands: Array[Dictionary] = []
	for command in _commands:
		if query.is_empty() or str(command.title).to_lower().contains(query) or str(command.hint).to_lower().contains(query):
			visible_commands.append(command)
	return visible_commands[selected[0]] if selected[0] < visible_commands.size() else {}

func _on_search_changed(_text: String) -> void:
	_refresh_list()

func _on_search_submitted(_text: String) -> void:
	_execute(_selected_command())

func _on_item_activated(index: int) -> void:
	if index >= 0 and index < _list.item_count:
		_list.select(index)
	_execute(_selected_command())

func _execute(command: Dictionary) -> void:
	if command.is_empty():
		return
	var creator := get_parent()
	if not creator:
		close_palette()
		return
	match command.get("action", &""):
		&"play":
			creator._on_build_toolbar_playtest_requested()
		&"publish":
			creator._on_build_toolbar_publish_button_pressed()
		&"save_version":
			creator._on_build_toolbar_save_version_button_pressed()
		&"restore":
			creator._on_build_toolbar_restore_button_pressed()
		&"assets":
			creator.toggle_asset_browser_visibility()
		&"undo":
			creator.undo_redo.undo()
		&"redo":
			creator.undo_redo.redo()
	close_palette()
