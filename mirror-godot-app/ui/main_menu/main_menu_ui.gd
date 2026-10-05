class_name MainMenuUI
extends Control


signal page_changed(page_name: StringName)
signal subpage_changed(subpage_name: StringName)

const HISTORY_MAX_SIZE = 5
const BACK_SFX = preload("res://ui/main_menu/audio/back_close.wav")
const TAB_SELECT_SFX = preload("res://audio/select_tab.wav")

@onready var _pages: Control = $Pages
@onready var _header_menu := $HeaderMenu
@onready var _exit_popup := $ExitPopup
@onready var _background := $Background
@onready var _audio_stream_player = $AudioStreamPlayer


# We want to show all pages, if none are whitelisted
var whitelisted_page_names = []


var _game_ui: Node
var _current_page: Control
var _previous_page: Control
var _current_subpage: Control
var _current_subpage_param: Variant
var _history: Array[Dictionary] = []
var _is_player_in_server: bool = false


func _enter_tree() -> void:
	PriorityInput.register_actions([&"open_main_menu"], ready, tree_exiting)


func _register_state_in_history():
	var data = {
		"page": _current_page.name,
		"subpage": _current_subpage.name if _current_subpage else "",
		"subpage_param": _current_subpage_param
	}
	if _history.size() > 0 and data == _history.back():
		return # previous page is the same, do not add it to history
	_history.append(data)
	if _history.size() > HISTORY_MAX_SIZE:
		_history.pop_front()


func history_go_back():
	if _history.size() < 2:
		return
	_history.pop_back()
	var previous: Dictionary = _history.pop_back()
	var previous_page: StringName = StringName(previous.get("page", ""))
	if previous_page == StringName("") or get_page_from_name(previous_page) == null:
		return
	if _current_page == null or _current_page.name != previous_page:
		change_page(previous_page)
		if _history.size() > 0 and _history.back().get("page", "") == previous_page:
			_history.pop_back()
	var previous_subpage: StringName = StringName(previous.get("subpage", ""))
	if previous_subpage != StringName("") and _current_page.get_node_or_null("Pages/%s" % str(previous_subpage)) != null:
		change_subpage(previous_subpage, previous.get("subpage_param"))


func cleanup_history() -> void:
	_history.clear()


func _ready() -> void:
	_setup_pages_and_subpages()
	_show_default_page()
	show_default_subpage(false)
	_register_state_in_history()
	$PauseButtons.hide()
	Zone.client.connected.connect(_on_zone_connected)
	Zone.client.disconnected.connect(_on_zone_disconnected)
	Analytics.track_event_client(AnalyticsEvent.TYPE.MAIN_MENU_UI_READY)


func setup(game_ui: Node) -> void:
	_game_ui = game_ui
	_exit_popup.setup(game_ui)
	cleanup_history()
	_register_state_in_history()

@onready var _is_main_menu_visible = ProjectSettings.get_setting("feature_flags/enable_main_menu", true)

func _process(delta):
	if visible and not _is_main_menu_visible:
		hide()

func _input(input_event: InputEvent) -> void:
	if not input_event.is_action_pressed(&"open_main_menu"):
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if not _game_ui.can_toggle_main_menu():
		return
	toggle_main_menu_open()


func toggle_main_menu_open(show_space_settings: bool = false) -> void:
	if _is_player_in_server:
		_game_ui.cinematic_mode.disable_cinematic_mode()
		if visible:
			hide()
			_audio_stream_player.stream = BACK_SFX
			_audio_stream_player.play()
			return
		if show_space_settings:
			change_page(&"Discover")
			change_subpage(&"ViewSpace", Zone.space)
			change_subpage(&"EditSpace", Zone.space)
		elif GameUI.instance.should_display_space_listings:
			change_page(&"Home")
			change_subpage(&"HomeSpaceSelect")
		show()
	else:
		if _exit_popup.visible:
			_exit_popup.fade_out()
			return
		_exit_popup.fade_in()


# Sets up the menu scenes pages and subpages
func _setup_pages_and_subpages() -> void:
	var page_names: Array[StringName] = []
	for page in _pages.get_children():
		page.hide()
		var subpages = page.get_node_or_null("Pages")
		if subpages:
			for subpage in subpages.get_children():
				subpage.hide()
		page_names.append(page.name)
	if not GameUI.instance.should_display_space_listings:
		whitelisted_page_names = ["Avatar", "Settings"]
	_header_menu.populate_page_buttons(page_names, whitelisted_page_names)


# Setups up the default pages
func _show_default_page() -> void:
	if GameUI.instance.should_display_space_listings:
		_current_page = get_page_from_name("Home")
	else:
		_current_page = get_page_from_name("Avatar")
	_current_page.show()
	var total_pages: int = $Pages.get_child_count()
	var last_page = $Pages.get_child(total_pages - 1)
	_keep_page_as_selected(last_page.name)


# Setups the default subpage
func show_default_subpage(register_history: bool = true) -> void:
	var subpages := _current_page.get_node_or_null("Pages")
	if subpages:
		if _current_subpage != null:
			_current_subpage.hide()
		if subpages.get_child_count() == 0:
			_current_subpage = null
			return
		var default_subpage = subpages.get_child(0)
		_current_subpage = default_subpage
		default_subpage.show()
		if register_history:
			_register_state_in_history()


# Sets the current page. Used to change pages
func change_page(page_name: StringName) -> void:
	var new_current_page := get_page_from_name(page_name)
	if not is_instance_valid(new_current_page):
		print("Page not found: %s" % str(page_name))
		return
	if is_instance_valid(_current_page) and _current_page.name == page_name:
		return
	if is_instance_valid(_current_page):
		_current_page.hide()
	_previous_page = _current_page
	_current_page = new_current_page
	_reset_subpages(_current_page)
	_check_update_background_image()
	_current_page.show()
	print("Page changed to %s" % str(_current_page.name))
	_keep_page_as_selected(_previous_page.name)
	_register_state_in_history()
	# TODO decouple this analytics call by instead connecting to the page_changed signal
	Analytics.track_event_client(AnalyticsEvent.TYPE.MAIN_MENU_PAGE_CHANGE, {"page": _current_page.name})
	page_changed.emit(_current_page.name)
	_audio_stream_player.stream = TAB_SELECT_SFX
	_audio_stream_player.play()


# Updates the BG if there's metadata for it
func _check_update_background_image() -> void:
	var bg_texture = _current_page.get_meta(&"bg_texture", null)
	if bg_texture != null:
		_background.texture = bg_texture


func get_page_from_name(page_name) -> Control:
	return $Pages.get_node_or_null(String(page_name)) as Control


# Set the first subpage as current if there are subpages
func _reset_subpages(page: Control) -> void:
	var subpages = page.get_node_or_null("Pages")
	if subpages:
		var first_page = subpages.get_child(0)
		change_subpage(first_page.name)


# Keeps the focus on the main page button to match the visuals
func _keep_page_as_selected(previous_page_name: StringName) -> void:
	if not is_instance_valid(_current_page):
		return
	var current_page_button: Button = _header_menu.get_node_or_null(str(_current_page.name))
	var previous_page_button: Button = _header_menu.get_node_or_null(str(previous_page_name))
	if not is_instance_valid(current_page_button):
		return
	var stylebox_focus = current_page_button.get_theme_stylebox("focus")
	var stylebox_normal = current_page_button.get_theme_stylebox("normal")
	if is_instance_valid(previous_page_button):
		previous_page_button.add_theme_stylebox_override("normal", stylebox_normal)
	current_page_button.add_theme_stylebox_override("normal", stylebox_focus)


# Triggers on main menu button pressed
func _on_main_menu_page_button_pressed(page_name: StringName) -> void:
	change_page(page_name)


# Sets the current page's subpage, subpages must be child controls inside of a control named Pages
func change_subpage(page_name: StringName, param: Variant = null) -> void:
	if not is_instance_valid(_current_subpage):
		_current_subpage = _current_page.get_node("Pages/%s" % str(page_name))
		_current_subpage.show()
		return
	if _current_subpage.name == page_name && param == null:
		return
	_current_subpage.hide()
	var new_current_subpage = _current_page.get_node_or_null("Pages/%s" % str(page_name))
	if not is_instance_valid(new_current_subpage):
		print("Subpage %s not found" % str(page_name))
		return
	_current_subpage = new_current_subpage
	_current_subpage_param = param
	if param and _current_subpage.has_method("populate"):
		_current_subpage.populate(param)
	_current_subpage.show()
	_register_state_in_history()
	subpage_changed.emit(_current_subpage.name)
	print("Subpage changed to %s" % str(_current_subpage.name))
	Analytics.track_event_client(AnalyticsEvent.TYPE.MAIN_MENU_SUBPAGE_CHANGE, {"subpage": _current_page.name})


# Triggers when you click the logo. Changes the page back to the default page
func _on_logo_gui_input(event) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var default_page = _pages.get_child(0)
			change_page(default_page.name)


func _on_minimize_window_pressed() -> void:
	Analytics.track_event_client(AnalyticsEvent.TYPE.MAIN_MENU_WINDOW_MINIMIZE_PRESSED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func _on_close_window_pressed() -> void:
	Analytics.track_event_client(AnalyticsEvent.TYPE.MAIN_MENU_WINDOW_CLOSE_PRESSED)
	_exit_popup.fade_in()


func _on_help_button_pressed() -> void:
	GameUI.instance.user_tutorial.show_tutorial_type(UserTutorial.Tutorial_Type.HOME)


func _on_back_button_pressed() -> void:
	if _history.size() > 1:
		history_go_back()
	else:
		show_default_subpage(false)


func _on_esc_button_pressed():
	hide()


func _on_respawn_player_pressed():
	PlayerData.get_local_player().respawn_player()
	hide()


func _on_exit_server_pressed():
	Zone.client.quit_to_main_menu()


func _on_zone_connected() -> void:
	_is_player_in_server = true
	_background.modulate.a = 0.9
	$PauseButtons.show()


func _on_zone_disconnected() -> void:
	_is_player_in_server = false
	_background.modulate.a = 1.0
	$PauseButtons.hide()
