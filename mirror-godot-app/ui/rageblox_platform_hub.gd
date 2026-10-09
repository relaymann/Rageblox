extends Control

const ACCENT := Color(0.78, 0.09, 0.12, 1)
const PANEL := Color(0.055, 0.06, 0.07, 0.96)
const MUTED := Color(0.62, 0.64, 0.68, 1)

var _content: VBoxContainer
var _search: LineEdit
var _active := &"home"
var _tabs: Dictionary = {}
var _refreshing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	RageBloxBetaPlatform.experience_changed.connect(_refresh)
	RageBloxBetaPlatform.social_changed.connect(_refresh)
	RageBloxBetaPlatform.avatar_changed.connect(_refresh)
	_refresh()
	call_deferred("_load_backend_experiences")

func _load_backend_experiences() -> void:
	if not is_instance_valid(Net) or not Net.is_fully_logged_in():
		return
	var params := SpaceClient.SpaceListRequestParameters.new()
	params.per_page = 36
	var promise: Promise = Net.space_client.get_published_spaces(params)
	var published = await promise.wait_till_fulfilled()
	if promise.is_error() or not published is Array:
		return
	RageBloxBetaPlatform.cache_experiences(published)
	for item in published:
		if item is Dictionary:
			var id := StringName(str(item.get("_id", "")))
			if id != StringName():
				RageBloxServices.cache_experience(id, item)
	_refresh()

func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 32)
	root.add_theme_constant_override("margin_right", 32)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)
	var outer := VBoxContainer.new()
	root.add_child(outer)
	var title := Label.new()
	title.text = "RageBlox"
	title.add_theme_font_size_override("font_size", 30)
	outer.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Reignited platform hub"
	subtitle.add_theme_color_override("font_color", MUTED)
	outer.add_child(subtitle)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	for tab in ["Home", "Discover", "Social", "Avatar", "Studio"]:
		var button := Button.new()
		button.text = tab
		button.custom_minimum_size = Vector2(112, 38)
		button.pressed.connect(_select_tab.bind(tab.to_lower()))
		tabs.add_child(button)
		_tabs[tab.to_lower()] = button
	var search_row := HBoxContainer.new()
	_search = LineEdit.new()
	_search.placeholder_text = "Search experiences, creators, users, assets, avatars, collections…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value): _refresh())
	search_row.add_child(_search)
	outer.add_child(search_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func _select_tab(tab: String) -> void:
	_active = StringName(tab)
	_refresh()

func _refresh() -> void:
	if _refreshing or not is_instance_valid(_content):
		return
	_refreshing = true
	for child in _content.get_children():
		child.queue_free()
	await get_tree().process_frame
	match _active:
		&"home":
			_build_home()
		&"discover":
			_build_discover()
		&"social":
			_build_social()
		&"avatar":
			_build_avatar()
		&"studio":
			_build_studio()
	_refreshing = false

func _section(title_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	section.add_child(title)
	_content.add_child(section)
	return section

func _card(title_text: String, detail: String, action_text: String = "", callback: Callable = Callable()) -> PanelContainer:
	var panel := PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	labels.add_child(title)
	var body := Label.new()
	body.text = detail
	body.add_theme_color_override("font_color", MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(body)
	row.add_child(labels)
	if not action_text.is_empty():
		var button := Button.new()
		button.text = action_text
		button.pressed.connect(callback)
		row.add_child(button)
	return panel

func _experience_card(item: Dictionary) -> PanelContainer:
	var id := StringName(str(item.get("id", item.get("_id", ""))))
	var title := str(item.get("name", item.get("title", "Untitled Experience")))
	var creator := str(item.get("creator", item.get("creatorName", "Unknown creator")))
	var players := int(item.get("playerCount", 0))
	var genre := str(item.get("genre", item.get("category", "Experience")))
	var panel := _card(title, "%s • %s • %d playing" % [creator, genre, players], "View", func():
		_open_experience(item)
	)
	var favorite := Button.new()
	favorite.text = "★" if RageBloxServices.favorite_experiences.has(id) else "☆"
	favorite.pressed.connect(func():
		var next := not RageBloxServices.favorite_experiences.has(id)
		RageBloxServices.set_favorite(id, next)
		_refresh()
	)
	panel.get_child(0).add_child(favorite)
	return panel

func _open_experience(item: Dictionary) -> void:
	var id := str(item.get("_id", item.get("id", "")))
	if id.is_empty() or not GameUI.instance or not GameUI.instance.main_menu_ui:
		return
	RageBloxServices.mark_experience_played(StringName(id))
	RageBloxBetaPlatform.record_event(&"experience_view", {"id": id})
	if id == "rageblox-showcase":
		RageBloxServices.set_presence(StringName(id), 0)
		GameUI.instance.loading_ui.show()
		GameUI.instance.main_menu_ui.hide()
		Zone.client.start_local_showcase()
		return
	GameUI.instance.main_menu_ui.change_page(&"Discover")
	GameUI.instance.main_menu_ui.change_subpage(&"ViewSpace", item)
	GameUI.instance.main_menu_ui.show()

func _build_home() -> void:
	var continue_items := RageBloxBetaPlatform.get_experiences(&"recent")
	var favorites := RageBloxBetaPlatform.get_experiences(&"favorites")
	var section := _section("Home")
	section.add_child(_card("Continue Playing", "Resume your most recent experiences.", "Browse", func(): _select_tab("discover")))
	section.add_child(_card("Friends & Party", "%d friends • %d party members" % [RageBloxServices.friends.size(), RageBloxBetaPlatform.party.size()], "Open", func(): _select_tab("social")))
	if continue_items.is_empty():
		section.add_child(_card("No recent experiences yet", "Play an experience and it will appear here."))
	else:
		for item in continue_items.slice(0, 6):
			section.add_child(_experience_card(item))
	if not favorites.is_empty():
		var fav := _section("Favorites")
		for item in favorites.slice(0, 6):
			fav.add_child(_experience_card(item))

func _build_discover() -> void:
	var q := _search.text if is_instance_valid(_search) else ""
	for bucket in [StringName("featured"), StringName("trending"), StringName("rising"), StringName("new")]:
		var items := RageBloxBetaPlatform.get_experiences(bucket, "", q)
		var section := _section(bucket.capitalize())
		if items.is_empty():
			section.add_child(_card("Nothing available yet", "This section is waiting for real experience metadata."))
		else:
			for item in items.slice(0, 12):
				section.add_child(_experience_card(item))
	var categories := _section("Categories / Genres")
	var seen: Dictionary = {}
	for item in RageBloxBetaPlatform.experience_catalog:
		var category := str(item.get("genre", item.get("category", "")))
		if category.is_empty() or seen.has(category):
			continue
		seen[category] = true
		var b := Button.new()
		b.text = category
		b.pressed.connect(func(): _search.text = category)
		categories.add_child(b)
	if not q.is_empty():
		var search_results := _section("Search Results")
		var all := RageBloxBetaPlatform.get_experiences(&"all", "", q)
		if all.is_empty():
			search_results.add_child(_card("No results", "Try another search."))
		else:
			for item in all.slice(0, 20):
				search_results.add_child(_experience_card(item))

func _build_social() -> void:
	var section := _section("Friends")
	if RageBloxServices.friends.is_empty():
		section.add_child(_card("No friends saved", "Friend presence will appear here when available."))
	else:
		for id in RageBloxServices.friends:
			var friend: Dictionary = RageBloxServices.friends[id]
			var status := "Online" if bool(friend.get("online", false)) else "Offline"
			section.add_child(_card(str(friend.get("display_name", id)), status, "Join" if status == "Online" else "", func(): _join_friend(id)))
	var requests := _section("Friend Requests")
	if RageBloxBetaPlatform.friend_requests.is_empty():
		requests.add_child(_card("No pending requests", ""))
	else:
		for request in RageBloxBetaPlatform.friend_requests:
			requests.add_child(_card(str(request.get("display_name", request.get("id", ""))), "Friend request", "Accept", func(): RageBloxBetaPlatform.accept_friend_request(StringName(str(request.get("id", ""))))))
	var party := _section("Party")
	party.add_child(_card("Party", "%d members" % RageBloxBetaPlatform.party.size(), "Create" if RageBloxBetaPlatform.party.is_empty() else "Leave", func():
		if RageBloxBetaPlatform.party.is_empty(): RageBloxBetaPlatform.create_party()
		else: RageBloxBetaPlatform.leave_party()
	))
	party.add_child(_card("Block / Mute", "%d blocked • %d muted" % [RageBloxBetaPlatform.blocked_users.size(), RageBloxBetaPlatform.muted_users.size()]))

func _join_friend(user_id: StringName) -> void:
	var friend: Dictionary = RageBloxServices.friends.get(user_id, {})
	var experience_id := StringName(str(friend.get("experience_id", "")))
	if experience_id != StringName():
		Zone.client.start_join_play_space_by_space_id(str(experience_id))

func _build_avatar() -> void:
	var section := _section("Avatar")
	section.add_child(_card("Body", "Height %.2f • Width %.2f" % [float(RageBloxBetaPlatform.avatar_config.body.get("height", 1.0)), float(RageBloxBetaPlatform.avatar_config.body.get("width", 1.0))]))
	var body := HBoxContainer.new()
	var height := HSlider.new()
	height.min_value = 0.8
	height.max_value = 1.2
	height.step = 0.05
	height.value = float(RageBloxBetaPlatform.avatar_config.body.get("height", 1.0))
	height.value_changed.connect(func(v): RageBloxBetaPlatform.set_avatar_value("body", "height", v); _refresh())
	var width := HSlider.new()
	width.min_value = 0.8
	width.max_value = 1.2
	width.step = 0.05
	width.value = float(RageBloxBetaPlatform.avatar_config.body.get("width", 1.0))
	width.value_changed.connect(func(v): RageBloxBetaPlatform.set_avatar_value("body", "width", v); _refresh())
	body.add_child(height)
	body.add_child(width)
	section.add_child(body)
	var accessories := _section("Accessories & Clothing")
	for category in ["hats", "hair", "face", "back", "shoulder", "waist", "shirt", "pants"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = category.capitalize()
		label.custom_minimum_size.x = 120
		row.add_child(label)
		var edit := LineEdit.new()
		edit.placeholder_text = "Asset ID / URL"
		edit.text = str(RageBloxBetaPlatform.avatar_config.accessories.get(category, RageBloxBetaPlatform.avatar_config.clothing.get(category, "")))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_submitted.connect(func(value):
			if category in ["shirt", "pants"]:
				RageBloxBetaPlatform.set_avatar_value("clothing", category, value)
			else:
				var current: Dictionary = RageBloxBetaPlatform.avatar_config.accessories
				current[category] = value
				RageBloxBetaPlatform.save_avatar_config(RageBloxBetaPlatform.avatar_config)
		)
		row.add_child(edit)
		section.add_child(row)
	var animations := _section("Animations & Emotes")
	for name in ["Idle", "Walk", "Run", "Jump", "Fall", "Land", "Death"]:
		var b := Button.new()
		b.text = name
		b.pressed.connect(RageBloxBetaPlatform.set_animation.bind(name))
		animations.add_child(b)
	for name in ["Wave", "Point", "Cheer", "Laugh", "Dance"]:
		var b := Button.new()
		b.text = name
		b.pressed.connect(RageBloxBetaPlatform.set_emote.bind(name))
		animations.add_child(b)
	var outfits := _section("Saved Outfits")
	for i in 5:
		var row := HBoxContainer.new()
		var slot := Button.new()
		slot.text = "Outfit %d" % (i + 1)
		slot.pressed.connect(RageBloxBetaPlatform.load_outfit.bind(i))
		row.add_child(slot)
		var save := Button.new()
		save.text = "Save / Overwrite"
		save.pressed.connect(RageBloxBetaPlatform.save_outfit.bind(i, "Outfit %d" % (i + 1)))
		row.add_child(save)
		outfits.add_child(row)

func _build_studio() -> void:
	var section := _section("RageBlox Studio 2.0")
	section.add_child(_card("Explorer", "Hierarchy, search, filtering, selection and multi-selection.", "Open", _open_studio))
	section.add_child(_card("Inspector", "Properties, categories, validation and transform controls.", "Open", _open_studio))
	section.add_child(_card("Asset Browser", "Search, categories, previews, insertion and caching.", "Open", _open_assets))
	section.add_child(_card("Playtest", "Play, stop, ready-check and multi-client architecture.", "Playtest", _playtest))
	section.add_child(_card("Output / Console", "Errors, warnings, logs and filtering are available through the creator runtime.", "Open", _open_studio))
	section.add_child(_card("Autosave / Recovery", "Creator state is retained through the existing project save/version infrastructure.", "Open", _open_studio))
	section.add_child(_card("Object editing", "Move, rotate, scale, snap, duplicate, group, lock and hide state are tracked in the beta Studio session."))
	var search := LineEdit.new()
	search.placeholder_text = "Search the current scene / Explorer…"
	search.text_submitted.connect(func(value):
		RageBloxBetaPlatform.studio_search(value)
		if GameUI.instance and GameUI.instance.creator_ui:
			GameUI.instance.creator_ui.search_node_tree(value)
	)
	section.add_child(search)

func _open_studio() -> void:
	hide()
	if GameUI.instance:
		GameUI.instance.main_menu_ui.hide()
		GameUI.instance.creator_ui.show()

func _open_assets() -> void:
	_open_studio()
	if GameUI.instance:
		GameUI.instance.creator_ui.toggle_asset_browser_visibility()

func _playtest() -> void:
	_open_studio()
	if GameUI.instance:
		GameUI.instance.creator_ui._on_build_toolbar_playtest_requested()
