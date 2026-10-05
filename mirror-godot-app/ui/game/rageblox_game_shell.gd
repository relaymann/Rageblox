extends CanvasLayer

const ACCENT := Color(0.78, 0.09, 0.12, 1)
const PANEL := Color(0.055, 0.06, 0.07, 0.97)
const MUTED := Color(0.67, 0.68, 0.71, 1)

var _root: Control
var _players_panel: PanelContainer
var _chat_panel: PanelContainer
var _menu_panel: PanelContainer
var _status: Label
var _chat_log: VBoxContainer
var _chat_input: LineEdit

func _ready() -> void:
	layer = 80
	_build()
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()
	RageBloxBetaPlatform.social_changed.connect(_refresh_players)
	RageBloxBetaPlatform.chat_message_received.connect(_append_chat)
	RageBloxBetaPlatform.connection_state_changed.connect(_refresh_status)
	visibility_changed.connect(func(): if visible: _refresh_all())
	_refresh_all()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var menu := Button.new()
	menu.text = "☰"
	menu.tooltip_text = "RageBlox Menu"
	menu.position = Vector2(18, 18)
	menu.custom_minimum_size = Vector2(52, 42)
	menu.pressed.connect(_toggle_menu)
	_root.add_child(menu)
	var players := Button.new()
	players.text = "Players"
	players.position = Vector2(82, 18)
	players.custom_minimum_size = Vector2(92, 42)
	players.pressed.connect(_toggle_players)
	_root.add_child(players)
	var chat := Button.new()
	chat.text = "Chat"
	chat.position = Vector2(182, 18)
	chat.custom_minimum_size = Vector2(82, 42)
	chat.pressed.connect(_toggle_chat)
	_root.add_child(chat)
	_status = Label.new()
	_status.position = Vector2(280, 27)
	_status.add_theme_color_override("font_color", MUTED)
	_root.add_child(_status)
	_players_panel = _make_panel(Vector2(280, 64), Vector2(320, 520))
	_root.add_child(_players_panel)
	_build_players()
	_chat_panel = _make_panel(Vector2(18, 72), Vector2(430, 500))
	_root.add_child(_chat_panel)
	_build_chat()
	_menu_panel = _make_panel(Vector2(18, 72), Vector2(360, 520))
	_root.add_child(_menu_panel)
	_build_menu()
	_players_panel.hide()
	_chat_panel.hide()
	_menu_panel.hide()

func _make_panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.08)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _build_players() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_players_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Players"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	scroll.add_child(list)

func _build_chat() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_chat_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Experience Chat"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_chat_log = VBoxContainer.new()
	scroll.add_child(_chat_log)
	var row := HBoxContainer.new()
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Message…"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(_send_chat)
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = "Send"
	send.pressed.connect(func(): _send_chat(_chat_input.text))
	row.add_child(send)
	var full := Button.new()
	full.text = "Full chat"
	full.pressed.connect(_open_existing_chat)
	box.add_child(row)
	box.add_child(full)

func _build_menu() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_menu_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "RageBlox"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_add_menu_button(box, "Resume", _close_panels)
	_add_menu_button(box, "Settings", _show_settings)
	_add_menu_button(box, "Player List", _toggle_players)
	_add_menu_button(box, "Respawn / Reset", _respawn)
	_add_menu_button(box, "Reconnect", _reconnect)
	_add_menu_button(box, "Leave Experience", _leave)
	_add_menu_button(box, "Social Overlay", _open_social)
	_add_menu_button(box, "Platform Home", _return_home)

func _add_menu_button(parent: VBoxContainer, label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	parent.add_child(b)

func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	_players_panel.hide()
	_chat_panel.hide()
	if _menu_panel.visible:
		_menu_panel.get_child(0).get_child(0).get_child(1).grab_focus()

func _toggle_players() -> void:
	_players_panel.visible = not _players_panel.visible
	_chat_panel.hide()
	if _players_panel.visible:
		_refresh_players()

func _toggle_chat() -> void:
	_chat_panel.visible = not _chat_panel.visible
	_players_panel.hide()
	if _chat_panel.visible:
		_refresh_chat()

func _close_panels() -> void:
	_menu_panel.hide()
	_players_panel.hide()
	_chat_panel.hide()

func _refresh_players() -> void:
	if not is_instance_valid(_players_panel):
		return
	var list: VBoxContainer = _players_panel.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/List")
	if not list:
		return
	for child in list.get_children():
		child.queue_free()
	for player in RageBloxBetaPlatform.get_players():
		var row := Label.new()
		row.text = "%s  •  %s" % [str(player.get("name", "Player")), "Online" if bool(player.get("online", true)) else "Offline"]
		row.custom_minimum_size.y = 34
		list.add_child(row)

func _refresh_chat() -> void:
	for child in _chat_log.get_children():
		child.queue_free()
	for message in RageBloxBetaPlatform.get_chat_messages():
		_append_chat(message)

func _append_chat(message: Dictionary) -> void:
	if not is_instance_valid(_chat_log):
		return
	var label := Label.new()
	label.text = "%s: %s" % [str(message.get("sender", "Player")), str(message.get("body", ""))]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log.add_child(label)

func _send_chat(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	RageBloxBetaPlatform.send_chat("You", clean)
	_chat_input.clear()
	_open_existing_chat()

func _open_existing_chat() -> void:
	if GameUI.instance and is_instance_valid(GameUI.instance.chat_ui):
		GameUI.instance.chat_ui.show()
	_close_panels()

func _show_settings() -> void:
	_close_panels()
	if GameUI.instance and GameUI.instance.main_menu_ui:
		GameUI.instance.main_menu_ui.change_page(&"Settings")
		GameUI.instance.main_menu_ui.show()
		hide()

func _respawn() -> void:
	if is_instance_valid(PlayerData.get_local_player()):
		PlayerData.get_local_player().respawn_player()
	_close_panels()

func _reconnect() -> void:
	var current := str(RageBloxServices.current_experience)
	RageBloxBetaPlatform.set_connection_state(&"reconnecting")
	if not current.is_empty():
		Zone.client.quit_to_main_menu()
		await get_tree().create_timer(0.25).timeout
		Zone.client.start_join_play_space_by_space_id(current)
	else:
		RageBloxBetaPlatform.set_connection_state(&"failed")
	_notify("Reconnect", "Reconnect requested.")

func _leave() -> void:
	RageBloxBetaPlatform.set_connection_state(&"disconnected")
	Zone.client.quit_to_main_menu()
	_close_panels()

func _open_social() -> void:
	_close_panels()
	if GameUI.instance and GameUI.instance.main_menu_ui:
		GameUI.instance.main_menu_ui.change_page(&"RageBloxHub")
		GameUI.instance.main_menu_ui.show()
		var hub = GameUI.instance.main_menu_ui.get_page_from_name("RageBloxHub")
		if hub and hub.has_method("_select_tab"):
			hub._select_tab("social")
		hide()

func _return_home() -> void:
	_close_panels()
	Zone.client.quit_to_main_menu()

func _refresh_status(state: StringName) -> void:
	if is_instance_valid(_status):
		_status.text = "● %s" % str(state).capitalize()

func _notify(title: String, body: String) -> void:
	if is_instance_valid(Notify):
		Notify.info(title, body)

func _refresh_all() -> void:
	_refresh_players()
	_refresh_chat()
	_refresh_status(RageBloxBetaPlatform.connection_state)

func blocks_gameplay_input() -> bool:
	return _menu_panel.visible or _players_panel.visible or _chat_panel.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_main_menu") and visible:
		_toggle_menu()
		get_viewport().set_input_as_handled()

func _layout_for_viewport() -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := clampf(viewport_size.x * 0.018, 12.0, 28.0)
	var top := margin
	var button_height := 42.0
	var x := margin
	for child in _root.get_children():
		if child is Button and child.text in ["☰", "Players", "Chat"]:
			child.position = Vector2(x, top)
			child.size = Vector2(maxf(72.0, child.custom_minimum_size.x), button_height)
			x += child.size.x + 8.0
	if is_instance_valid(_status):
		_status.position = Vector2(x + 8.0, top + 11.0)
	if is_instance_valid(_players_panel):
		_players_panel.position = Vector2(maxf(margin, viewport_size.x - 340.0 - margin), top + button_height + 12.0)
		_players_panel.size = Vector2(minf(320.0, maxf(240.0, viewport_size.x - 2.0 * margin)), minf(520.0, maxf(280.0, viewport_size.y - 120.0)))
	if is_instance_valid(_chat_panel):
		_chat_panel.position = Vector2(margin, top + button_height + 12.0)
		_chat_panel.size = Vector2(minf(430.0, maxf(280.0, viewport_size.x - 2.0 * margin)), minf(500.0, maxf(280.0, viewport_size.y - 120.0)))
	if is_instance_valid(_menu_panel):
		_menu_panel.position = Vector2(margin, top + button_height + 12.0)
		_menu_panel.size = Vector2(minf(360.0, maxf(260.0, viewport_size.x - 2.0 * margin)), minf(520.0, maxf(320.0, viewport_size.y - 120.0)))
