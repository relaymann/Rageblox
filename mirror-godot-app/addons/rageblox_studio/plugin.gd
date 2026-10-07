@tool
extends EditorPlugin

const ACCENT := Color("#d7192f")
const BG := Color("#17181c")
const PANEL := Color("#202228")
const PANEL_2 := Color("#282a31")
const TEXT := Color("#f2f3f5")
const MUTED := Color("#9ca1ad")

var toolbar: HBoxContainer
var explorer: VBoxContainer
var properties: VBoxContainer
var toolbox: VBoxContainer
var bottom: VBoxContainer
var explorer_tree: Tree
var property_list: VBoxContainer
var status_label: Label
var selection: EditorSelection

func _enter_tree() -> void:
	_build_toolbar()
	_build_explorer()
	_build_properties()
	_build_toolbox()
	_build_bottom()
	selection = get_editor_interface().get_selection()
	selection.selection_changed.connect(_refresh_selection)
	call_deferred("_refresh_all")

func _exit_tree() -> void:
	if selection and selection.selection_changed.is_connected(_refresh_selection):
		selection.selection_changed.disconnect(_refresh_selection)
	for c in [toolbar, explorer, properties, toolbox]:
		if is_instance_valid(c):
			remove_control_from_docks(c)
			c.queue_free()
	if is_instance_valid(bottom):
		remove_control_from_bottom_panel(bottom)
		bottom.queue_free()

func _style(color: Color, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(1, 1, 1, 0.06)
	return s

func _button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_stylebox_override("normal", _style(ACCENT if primary else PANEL_2))
	b.add_theme_stylebox_override("hover", _style(Color("#ee2a42") if primary else Color("#333640")))
	b.add_theme_stylebox_override("pressed", _style(Color("#b51227")))
	return b

func _label(text: String, size := 13, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	var brand = _label("RAGEBLOX", 15, TEXT)
	toolbar.add_child(brand)
	var studio = _label("  STUDIO", 11, ACCENT)
	toolbar.add_child(studio)
	var sep = VSeparator.new()
	sep.custom_minimum_size.x = 12
	toolbar.add_child(sep)
	for spec in [
		["Home", "_home"],
		["Model", "_model"],
		["Avatar", "_avatar"],
		["UI", "_ui"],
		["View", "_view"],
		["Script", "_script"]
	]:
		var b := _button(spec[0])
		b.pressed.connect(Callable(self, spec[1]))
		toolbar.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var play := _button("▶  Play", true)
	play.pressed.connect(_play)
	toolbar.add_child(play)
	var stop := _button("■  Stop")
	stop.pressed.connect(_stop)
	toolbar.add_child(stop)
	var save := _button("Save")
	save.pressed.connect(_save)
	toolbar.add_child(save)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar)

func _dock_header(title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 34
	var t := _label(title, 13, TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var menu := _button("⋯")
	menu.custom_minimum_size.x = 32
	h.add_child(menu)
	return h

func _build_explorer() -> void:
	explorer = VBoxContainer.new()
	explorer.custom_minimum_size = Vector2(250, 360)
	explorer.add_child(_dock_header("Explorer"))
	explorer_tree = Tree.new()
	explorer_tree.hide_root = true
	explorer_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	explorer_tree.item_selected.connect(_tree_selected)
	explorer.add_child(explorer_tree)
	add_control_to_dock(DOCK_SLOT_LEFT_UR, explorer)

func _build_properties() -> void:
	properties = VBoxContainer.new()
	properties.custom_minimum_size = Vector2(285, 360)
	properties.add_child(_dock_header("Properties"))
	var filter := LineEdit.new()
	filter.placeholder_text = "Filter properties"
	filter.custom_minimum_size.y = 30
	properties.add_child(filter)
	property_list = VBoxContainer.new()
	property_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(property_list)
	properties.add_child(scroll)
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, properties)

func _build_toolbox() -> void:
	toolbox = VBoxContainer.new()
	toolbox.custom_minimum_size = Vector2(250, 300)
	toolbox.add_child(_dock_header("Toolbox"))
	var search := LineEdit.new()
	search.placeholder_text = "Search objects, parts, assets…"
	toolbox.add_child(search)
	var grid := GridContainer.new()
	grid.columns = 2
	for spec in [
		["Part", "MeshInstance3D"], ["Spawn", "Marker3D"],
		["Light", "DirectionalLight3D"], ["Camera", "Camera3D"],
		["Folder", "Node3D"], ["UI", "Control"]
	]:
		var b := _button("＋ " + spec[0])
		b.pressed.connect(func(): _insert_node(spec[1], spec[0]))
		grid.add_child(b)
	toolbox.add_child(grid)
	var hint := _label("Drag-and-drop assets and insert objects into the selected parent.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toolbox.add_child(hint)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, toolbox)

func _build_bottom() -> void:
	bottom = VBoxContainer.new()
	bottom.custom_minimum_size.y = 180
	bottom.add_child(_label("RageBlox Output", 13, TEXT))
	status_label = _label("Ready — RageBlox Studio", 12, MUTED)
	bottom.add_child(status_label)
	var tip := _label("Luau creator runtime • Multiplayer • Asset pipeline • Playtest", 11, MUTED)
	bottom.add_child(tip)
	add_control_to_bottom_panel(bottom, "RageBlox")

func _refresh_all() -> void:
	_refresh_tree()
	_refresh_selection()

func _refresh_tree() -> void:
	if not is_instance_valid(explorer_tree):
		return
	explorer_tree.clear()
	var root_node := get_editor_interface().get_edited_scene_root()
	if root_node == null:
		return
	var root_item := explorer_tree.create_item()
	root_item.set_text(0, root_node.name)
	root_item.set_metadata(0, root_node)
	_add_tree_children(root_item, root_node)

func _add_tree_children(parent_item: TreeItem, node: Node) -> void:
	for child in node.get_children():
		var item := parent_item.create_child()
		item.set_text(0, child.name)
		item.set_metadata(0, child)
		_add_tree_children(item, child)

func _tree_selected() -> void:
	var item := explorer_tree.get_selected()
	if item == null:
		return
	var node = item.get_metadata(0)
	if node is Node:
		selection.clear()
		selection.add_node(node)
		get_editor_interface().inspect_object(node)

func _refresh_selection() -> void:
	if not is_instance_valid(property_list):
		return
	for c in property_list.get_children():
		c.queue_free()
	var nodes := selection.get_selected_nodes() if selection else []
	if nodes.is_empty():
		property_list.add_child(_label("Select an object in the viewport or Explorer.", 12, MUTED))
		return
	var node: Node = nodes[0]
	property_list.add_child(_label(node.name, 16, TEXT))
	property_list.add_child(_label(node.get_class(), 11, ACCENT))
	for p in node.get_property_list():
		if p.get("usage", 0) & PROPERTY_USAGE_EDITOR:
			var row := HBoxContainer.new()
			var name := _label(str(p.get("name", "")), 11, MUTED)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			var value := _label(str(node.get(p.get("name", ""))), 11, TEXT)
			row.add_child(value)
			property_list.add_child(row)

func _insert_node(type_name: String, display_name: String) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var parent: Node = root
	var nodes := selection.get_selected_nodes() if selection else []
	if not nodes.is_empty():
		parent = nodes[0]
	var node := ClassDB.instantiate(type_name)
	if node == null:
		status_label.text = "Could not create " + display_name + "."
		return
	node.name = display_name
	parent.add_child(node)
	node.owner = root
	get_editor_interface().mark_scene_as_unsaved()
	_refresh_tree()
	selection.clear()
	selection.add_node(node)
	status_label.text = "Created " + display_name + " in Explorer."

func _play() -> void:
	get_editor_interface().play_main_scene()
	status_label.text = "Playtest started."

func _stop() -> void:
	get_editor_interface().stop_playing_scene()
	status_label.text = "Playtest stopped."

func _save() -> void:
	var err := get_editor_interface().save_scene()
	status_label.text = "Saved." if err == OK else "Save failed."

func _home() -> void:
	status_label.text = "RageBlox Studio — Home"

func _model() -> void:
	get_editor_interface().set_main_screen_editor("3D")
	status_label.text = "Model tools ready."

func _avatar() -> void:
	status_label.text = "Avatar tools selected."

func _ui() -> void:
	get_editor_interface().set_main_screen_editor("2D")
	status_label.text = "UI editor selected."

func _view() -> void:
	get_editor_interface().set_main_screen_editor("3D")
	status_label.text = "3D viewport selected."

func _script() -> void:
	get_editor_interface().set_main_screen_editor("Script")
	status_label.text = "Luau/GDScript editor selected."
