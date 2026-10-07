class_name RageBloxStudioStart
extends Control

const ACCENT := Color(0.82, 0.07, 0.12, 1.0)
const ACCENT_HOVER := Color(1.0, 0.12, 0.18, 1.0)
const BG := Color(0.035, 0.038, 0.045, 1.0)
const SIDEBAR := Color(0.048, 0.050, 0.058, 1.0)
const CARD := Color(0.075, 0.078, 0.088, 1.0)
const CARD_HOVER := Color(0.095, 0.098, 0.11, 1.0)
const TEXT := Color(0.94, 0.95, 0.97, 1.0)
const MUTED := Color(0.60, 0.63, 0.69, 1.0)

const STUDIO_ROOT := "RageBlox/Experiences"
const RECENTS_FILE := "user://rageblox_studio_recent.json"

var _content: VBoxContainer
var _name_edit: LineEdit
var _template: String = "Baseplate"
var _status: Label
var _recent: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_recents()
	_build()
	_show_home()

func _panel(color: Color, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	var normal := _panel(ACCENT if primary else CARD)
	var hover := _panel(ACCENT_HOVER if primary else CARD_HOVER)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 230
	sidebar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sidebar.set_anchor_and_offset(SIDE_RIGHT, 0.0, 230.0)
	sidebar.add_theme_stylebox_override("panel", _panel(SIDEBAR, 0))
	add_child(sidebar)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.add_theme_constant_override("margin_left", 20)
	nav.add_theme_constant_override("margin_right", 20)
	nav.add_theme_constant_override("margin_top", 28)
	nav.add_theme_constant_override("margin_bottom", 24)
	sidebar.add_child(nav)

	var brand := Label.new()
	brand.text = "RAGEBLOX"
	brand.add_theme_font_size_override("font_size", 25)
	brand.add_theme_color_override("font_color", TEXT)
	nav.add_child(brand)
	var sub := Label.new()
	sub.text = "STUDIO"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", ACCENT)
	nav.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 28
	nav.add_child(spacer)

	var home := _button("  Home")
	home.pressed.connect(_show_home)
	nav.add_child(home)
	var create := _button("  Create")
	create.pressed.connect(_show_create)
	nav.add_child(create)
	var recent := _button("  Recent")
	recent.pressed.connect(_show_recent)
	nav.add_child(recent)

	var info_spacer := Control.new()
	info_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(info_spacer)

	var footer := Label.new()
	footer.text = "Creator tools\nLuau • Multiplayer • 3D\nReignited for creators"
	footer.add_theme_color_override("font_color", MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nav.add_child(footer)

	var main := MarginContainer.new()
	main.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	main.set_anchor_and_offset(SIDE_LEFT, 0.0, 230.0)
	main.set_anchor_and_offset(SIDE_RIGHT, 1.0, -36.0)
	main.add_theme_constant_override("margin_left", 48)
	main.add_theme_constant_override("margin_right", 48)
	main.add_theme_constant_override("margin_top", 34)
	main.add_theme_constant_override("margin_bottom", 30)
	add_child(main)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	main.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "Welcome to RageBlox Studio"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var version := Label.new()
	version.text = "BETA"
	version.add_theme_color_override("font_color", ACCENT)
	top.add_child(version)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	outer.add_child(_content)

	_status = Label.new()
	_status.add_theme_color_override("font_color", MUTED)
	outer.add_child(_status)

func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()

func _heading(text: String, detail := "") -> void:
	var h := VBoxContainer.new()
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	h.add_child(title)
	if not detail.is_empty():
		var d := Label.new()
		d.text = detail
		d.add_theme_color_override("font_color", MUTED)
		h.add_child(d)
	_content.add_child(h)

func _show_home() -> void:
	_clear()
	_heading("Start creating", "Build an experience without choosing folders or hunting for project files.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	for item in [
		["Baseplate", "A clean 3D starting place for your next experience."],
		["Obby", "A ready-to-edit movement and checkpoint course."],
		["Empty World", "A minimal world for advanced creators."],
		["Multiplayer Arena", "A network-ready arena layout for multiplayer testing."]
	]:
		var card := _card(str(item[0]), str(item[1]), "Create")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		card.get_node("Row/Action").pressed.connect(func(): _begin_create(str(item[0])))
	_heading("Recent experiences", "Your projects are managed by RageBlox Studio.")
	_build_recent_cards()

func _show_create() -> void:
	_clear()
	_heading("Create a new experience", "RageBlox handles the project folder, project file and starter scene automatically.")
	var form := PanelContainer.new()
	form.add_theme_stylebox_override("panel", _panel(CARD))
	_content.add_child(form)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_theme_constant_override("margin_left", 24)
	box.add_theme_constant_override("margin_right", 24)
	box.add_theme_constant_override("margin_top", 22)
	box.add_theme_constant_override("margin_bottom", 22)
	form.add_child(box)
	var label := Label.new()
	label.text = "Experience name"
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "My First Experience"
	_name_edit.custom_minimum_size.y = 44
	box.add_child(_name_edit)
	var templates := HBoxContainer.new()
	templates.add_theme_constant_override("separation", 8)
	box.add_child(templates)
	for name in ["Baseplate", "Obby", "Empty World", "Multiplayer Arena"]:
		var b := _button(name, name == _template)
		b.pressed.connect(func(): _template = name; _show_create())
		templates.add_child(b)
	var create := _button("Create Experience", true)
	create.pressed.connect(_create_experience)
	box.add_child(create)
	var note := Label.new()
	note.text = "Projects are stored in your RageBlox Studio library. You never need to select a directory manually."
	note.add_theme_color_override("font_color", MUTED)
	box.add_child(note)

func _show_recent() -> void:
	_clear()
	_heading("Recent experiences", "Open a project directly in RageBlox Studio.")
	_build_recent_cards()

func _build_recent_cards() -> void:
	if _recent.is_empty():
		_content.add_child(_card("No experiences yet", "Click Create to make your first RageBlox experience.", "Create"))
		_content.get_child(_content.get_child_count() - 1).get_node("Row/Action").pressed.connect(_show_create)
		return
	for item in _recent:
		var title := str(item.get("name", "Untitled Experience"))
		var path := str(item.get("path", ""))
		var card := _card(title, path, "Open")
		_content.add_child(card)
		card.get_node("Row/Action").pressed.connect(func(): _open_editor(path))

func _card(title_text: String, detail: String, action_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(CARD))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 18)
	row.add_theme_constant_override("margin_left", 20)
	row.add_theme_constant_override("margin_right", 20)
	row.add_theme_constant_override("margin_top", 16)
	row.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TEXT)
	labels.add_child(title)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_color_override("font_color", MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail_label)
	row.add_child(labels)
	var action := _button(action_text)
	action.name = "Action"
	action.custom_minimum_size.x = 130
	row.add_child(action)
	return panel

func _begin_create(template: String) -> void:
	_template = template
	_show_create()

func _safe_slug(value: String) -> String:
	var slug := value.strip_edges().to_lower().replace(" ", "_")
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var out := ""
	for c in slug:
		if allowed.contains(c):
			out += c
	return out.trim_suffix("_")

func _create_experience() -> void:
	if not is_instance_valid(_name_edit):
		return
	var display_name := _name_edit.text.strip_edges()
	if display_name.is_empty():
		_status.text = "Give your experience a name first."
		return
	var slug := _safe_slug(display_name)
	if slug.is_empty():
		_status.text = "That name cannot be used as an experience folder."
		return
	var root := OS.get_user_data_dir().path_join(STUDIO_ROOT).path_join(slug)
	var err := DirAccess.make_dir_recursive_absolute(root)
	if err != OK:
		_status.text = "Could not create the experience library folder (%s)." % error_string(err)
		return
	var project := _project_file(display_name)
	var scene := _scene_file(display_name)
	if not _write_file(root.path_join("project.godot"), project) or not _write_file(root.path_join("main.tscn"), scene):
		_status.text = "Could not finish creating the experience."
		return
	_add_recent(display_name, root)
	_open_editor(root)

func _project_file(display_name: String) -> String:
	return "; RageBlox Studio experience\n; Managed automatically by RageBlox Studio.\nconfig_version=5\n\n[application]\nconfig/name=%s\nrun/main_scene="res://main.tscn"\n\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\nwindow/stretch/mode="canvas_items"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n\n[rageblox]\ncreator_primary_language="Luau"\ntemplate="%s"\n" % [_quote(display_name), _template];

func _scene_file(display_name: String) -> String:
	return '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://world.gd" id="1"]\n\n[node name="Experience" type="Node3D"]\n\n[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n\n[node name="CreatorStart" type="Label" parent="."]\ntext = "RageBlox Experience: %s"\n' % display_name.replace('"', "\\"")

func _quote(value: String) -> String:
	return '"' + value.replace("\\", "\\\\").replace('"', "\\"") + '"'

func _write_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true

func _open_editor(project_path: String) -> void:
	if project_path.is_empty():
		return
	var editor := _find_editor()
	if editor.is_empty():
		_status.text = "RageBlox Editor was not found beside Studio. Put MirrorGodotEditorWindows.exe next to this launcher."
		return
	var pid := OS.create_process(editor, ["--editor", "--path", project_path])
	if pid == -1:
		_status.text = "RageBlox Editor could not be started."
		return
	_status.text = "Opening %s in RageBlox Studio…" % project_path.get_file()
	await get_tree().create_timer(0.45).timeout
	get_tree().quit()

func _find_editor() -> String:
	var base := OS.get_executable_path().get_base_dir()
	var candidates := []
	if OS.get_name() == "Windows":
		candidates = ["MirrorGodotEditorWindows.exe", "RageBloxEditor.exe"]
	elif OS.get_name() == "macOS":
		candidates = ["MirrorGodotEditorMac.app/Contents/MacOS/Godot", "RageBloxEditor.app/Contents/MacOS/Godot"]
	else:
		candidates = ["MirrorGodotEditorLinux.x86_64", "RageBloxEditor"]
	for candidate in candidates:
		var path := base.path_join(candidate)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return path
	var configured := OS.get_environment("RAGEBLOX_EDITOR_PATH")
	return configured if not configured.is_empty() else ""

func _load_recents() -> void:
	_recent.clear()
	if not FileAccess.file_exists(RECENTS_FILE):
		return
	var file := FileAccess.open(RECENTS_FILE, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		_recent = parsed

func _save_recents() -> void:
	var file := FileAccess.open(RECENTS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_recent))
		file.close()

func _add_recent(display_name: String, path: String) -> void:
	_recent = _recent.filter(func(item): return str(item.get("path", "")) != path)
	_recent.push_front({"name": display_name, "path": path})
	if _recent.size() > 12:
		_recent.resize(12)
	_save_recents()
