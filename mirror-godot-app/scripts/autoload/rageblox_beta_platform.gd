class_name RageBloxBetaPlatform
extends Node

## Cohesive beta platform state layer for RageBlox.
## This complements RageBloxServices rather than replacing it.

signal social_changed
signal party_changed
signal avatar_changed
signal experience_changed
signal chat_message_received(message: Dictionary)
signal platform_notification(title: String, body: String)
signal connection_state_changed(state: StringName)

const CONFIG_PATH := "user://rageblox_beta_platform.cfg"
const MAX_RECENT := 50
const MAX_MESSAGES := 100

var profiles: Dictionary = {}
var friend_requests: Array[Dictionary] = []
var blocked_users: Array[StringName] = []
var muted_users: Array[StringName] = []
var party: Array[StringName] = []
var party_leader: StringName = StringName()
var current_players: Array[Dictionary] = []
var chat_messages: Array[Dictionary] = []
var connection_state: StringName = &"connected"
var avatar_config: Dictionary = {
	"body": {"height": 1.0, "width": 1.0},
	"colors": {
		"head": Color(0.85, 0.67, 0.48, 1),
		"torso": Color(0.25, 0.35, 0.55, 1),
		"left_arm": Color(0.85, 0.67, 0.48, 1),
		"right_arm": Color(0.85, 0.67, 0.48, 1),
		"left_leg": Color(0.12, 0.14, 0.18, 1),
		"right_leg": Color(0.12, 0.14, 0.18, 1)
	},
	"accessories": {},
	"clothing": {"shirt": "", "pants": ""},
	"animation": "Idle",
	"emote": ""
}
var avatar_outfits: Array[Dictionary] = [{}, {}, {}, {}, {}]
var experience_catalog: Array[Dictionary] = []
var analytics: Array[Dictionary] = []
var studio_session: Dictionary = {
	"locked": {},
	"hidden": {},
	"groups": {},
	"last_search": ""
}

func _ready() -> void:
	_load()
	var showcase := {"id": &"rageblox-showcase", "_id": "rageblox-showcase", "name": "RageBlox Showcase", "title": "RageBlox Showcase", "creatorName": "RageBlox", "creator": "RageBlox", "genre": "Showcase", "category": "Showcase", "description": "The built-in beta showcase for testing movement, camera, interaction, avatar, HUD, respawn and networking.", "playerCount": 1, "featured": true, "new": true, "local": true}
	cache_experiences([showcase])
	_refresh_players()
	set_process(true)
	if Zone.client:
		if not Zone.client.connected.is_connected(_on_zone_connected):
			Zone.client.connected.connect(_on_zone_connected)
		if not Zone.client.disconnected.is_connected(_on_zone_disconnected):
			Zone.client.disconnected.connect(_on_zone_disconnected)

func _process(_delta: float) -> void:
	if Zone.is_client() and Zone.is_space_loaded() and current_players.is_empty():
		_refresh_players()

func _on_zone_connected() -> void:
	set_connection_state(&"connected")
	_refresh_players()

func _on_zone_disconnected() -> void:
	set_connection_state(&"disconnected")
	current_players.clear()
	social_changed.emit()

func _refresh_players() -> void:
	if not is_instance_valid(Zone):
		return
	var next: Array[Dictionary] = []
	for player in Zone.get_all_players():
		if not is_instance_valid(player):
			continue
		var user_id := StringName(str(player.get("user_id") if player.get("user_id") != null else player.name))
		next.append({
			"id": user_id,
			"name": str(player.name),
			"online": true,
			"experience": str(RageBloxServices.current_experience)
		})
	if next != current_players:
		current_players = next
		social_changed.emit()

func get_players() -> Array[Dictionary]:
	_refresh_players()
	if current_players.is_empty():
		return [{"id": &"local", "name": "You", "online": true, "experience": str(RageBloxServices.current_experience)}]
	return current_players.duplicate(true)

func add_friend_request(user_id: StringName, display_name: String) -> void:
	if blocked_users.has(user_id):
		return
	for request in friend_requests:
		if request.get("id") == user_id:
			return
	friend_requests.append({"id": user_id, "display_name": display_name})
	social_changed.emit()
	_save()

func accept_friend_request(user_id: StringName) -> void:
	var display_name := str(user_id)
	for request in friend_requests:
		if request.get("id") == user_id:
			display_name = str(request.get("display_name", display_name))
			break
	friend_requests = friend_requests.filter(func(item): return item.get("id") != user_id)
	RageBloxServices.add_friend(user_id, display_name, true)
	social_changed.emit()
	_save()

func decline_friend_request(user_id: StringName) -> void:
	friend_requests = friend_requests.filter(func(item): return item.get("id") != user_id)
	social_changed.emit()
	_save()

func block_user(user_id: StringName) -> void:
	if not blocked_users.has(user_id):
		blocked_users.append(user_id)
	mute_user(user_id)
	RageBloxServices.remove_friend(user_id)
	social_changed.emit()
	_save()

func unblock_user(user_id: StringName) -> void:
	blocked_users.erase(user_id)
	social_changed.emit()
	_save()

func mute_user(user_id: StringName) -> void:
	if not muted_users.has(user_id):
		muted_users.append(user_id)
	social_changed.emit()
	_save()

func unmute_user(user_id: StringName) -> void:
	muted_users.erase(user_id)
	social_changed.emit()
	_save()

func create_party() -> void:
	party.clear()
	party.append(&"local")
	party_leader = &"local"
	RageBloxServices.set_party(party)
	party_changed.emit()
	_save()

func invite_to_party(user_id: StringName) -> void:
	if blocked_users.has(user_id) or party.has(user_id):
		return
	party.append(user_id)
	if party_leader == StringName():
		party_leader = &"local"
	RageBloxServices.set_party(party)
	party_changed.emit()
	_save()

func leave_party() -> void:
	party.clear()
	party_leader = StringName()
	RageBloxServices.set_party(party)
	party_changed.emit()
	_save()

func get_party() -> Array[StringName]:
	return party.duplicate()

func send_chat(display_name: String, body: String) -> void:
	var clean := body.strip_edges()
	if clean.is_empty():
		return
	if not bool(RageBloxServices.safety_settings.get("chat_enabled", true)):
		return
	var message := {
		"sender": display_name,
		"body": clean.left(300),
		"time": Time.get_unix_time_from_system()
	}
	chat_messages.push_back(message)
	if chat_messages.size() > MAX_MESSAGES:
		chat_messages.pop_front()
	chat_message_received.emit(message)
	_save()

func get_chat_messages() -> Array[Dictionary]:
	return chat_messages.duplicate(true)

func set_connection_state(state: StringName) -> void:
	connection_state = state
	connection_state_changed.emit(state)

func save_avatar_config(config: Dictionary) -> void:
	avatar_config = config.duplicate(true)
	avatar_changed.emit()
	_save()

func set_avatar_value(section: String, key: String, value: Variant) -> void:
	if not avatar_config.has(section) or not avatar_config[section] is Dictionary:
		avatar_config[section] = {}
	avatar_config[section][key] = value
	else:
		avatar_config[section][key] = value
	avatar_changed.emit()
	_save()

func save_outfit(slot: int, name: String = "") -> bool:
	if slot < 0 or slot >= avatar_outfits.size():
		return false
	var outfit := avatar_config.duplicate(true)
	outfit["name"] = name if not name.is_empty() else "Outfit %d" % (slot + 1)
	avatar_outfits[slot] = outfit
	RageBloxServices.save_avatar_outfit(slot, outfit)
	avatar_changed.emit()
	_save()
	return true

func load_outfit(slot: int) -> bool:
	if slot < 0 or slot >= avatar_outfits.size() or avatar_outfits[slot].is_empty():
		return false
	avatar_config = avatar_outfits[slot].duplicate(true)
	avatar_changed.emit()
	_save()
	return true

func set_animation(name: String) -> void:
	avatar_config["animation"] = name
	avatar_changed.emit()
	_save()

func set_emote(name: String) -> void:
	avatar_config["emote"] = name
	avatar_changed.emit()
	_save()

func cache_experiences(items: Array) -> void:
	for item in items:
		if item is Dictionary:
			var id := StringName(str(item.get("_id", item.get("id", ""))))
			if id != StringName():
				var copy := item.duplicate(true)
				copy["id"] = id
				var found := false
				for i in experience_catalog.size():
					if experience_catalog[i].get("id") == id:
						experience_catalog[i] = copy
						found = true
						break
				if not found:
					experience_catalog.append(copy)
	while experience_catalog.size() > 200:
		experience_catalog.pop_front()
	experience_changed.emit()
	_save()

func get_experiences(section: StringName, category: String = "", query: String = "") -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var q := query.strip_edges().to_lower()
	for item in experience_catalog:
		var title := str(item.get("name", item.get("title", "")))
		var creator := str(item.get("creator", item.get("creatorName", "")))
		var genre := str(item.get("genre", item.get("category", "")))
		if not q.is_empty() and not (title.to_lower().contains(q) or creator.to_lower().contains(q) or genre.to_lower().contains(q)):
			continue
		if not category.is_empty() and genre.to_lower() != category.to_lower():
			continue
		var include := match section:
			&"featured": bool(item.get("featured", false))
			&"rising": bool(item.get("rising", false))
			&"new": bool(item.get("new", false))
			&"trending": int(item.get("playerCount", 0)) > 0
			&"recent": RageBloxServices.recent_experiences.has(StringName(str(item.get("id", ""))))
			&"favorites": RageBloxServices.favorite_experiences.has(StringName(str(item.get("id", ""))))
			_: true
		if include:
			filtered.append(item.duplicate(true))
	if section == &"trending":
		filtered.sort_custom(func(a, b): return int(a.get("playerCount", 0)) > int(b.get("playerCount", 0)))
	elif section == &"recent":
		filtered.sort_custom(func(a, b):
			return RageBloxServices.recent_experiences.find(StringName(str(a.get("id", "")))) < RageBloxServices.recent_experiences.find(StringName(str(b.get("id", ""))))
		)
	return filtered

func record_event(name: StringName, data: Dictionary = {}) -> void:
	analytics.append({"name": name, "data": data.duplicate(true), "time": Time.get_unix_time_from_system()})
	if analytics.size() > 500:
		analytics.pop_front()

func studio_lock(id: StringName, locked: bool) -> void:
	if locked:
		studio_session.locked[id] = true
	else:
		studio_session.locked.erase(id)

func studio_hide(id: StringName, hidden: bool) -> void:
	if hidden:
		studio_session.hidden[id] = true
	else:
		studio_session.hidden.erase(id)

func studio_group(ids: Array[StringName], group_name: String) -> void:
	if group_name.is_empty() or ids.is_empty():
		return
	studio_session.groups[group_name] = ids.duplicate()

func studio_search(text: String) -> void:
	studio_session.last_search = text

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("social", "friend_requests", friend_requests)
	cfg.set_value("social", "blocked", blocked_users)
	cfg.set_value("social", "muted", muted_users)
	cfg.set_value("social", "party", party)
	cfg.set_value("social", "party_leader", party_leader)
	cfg.set_value("chat", "messages", chat_messages)
	cfg.set_value("avatar", "config", avatar_config)
	cfg.set_value("avatar", "outfits", avatar_outfits)
	cfg.set_value("discovery", "catalog", experience_catalog)
	cfg.set_value("analytics", "events", analytics)
	cfg.set_value("studio", "session", studio_session)
	cfg.save(CONFIG_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var requests = cfg.get_value("social", "friend_requests", [])
	var blocked = cfg.get_value("social", "blocked", [])
	var muted = cfg.get_value("social", "muted", [])
	var stored_party = cfg.get_value("social", "party", [])
	var messages = cfg.get_value("chat", "messages", [])
	var stored_avatar = cfg.get_value("avatar", "config", {})
	var stored_outfits = cfg.get_value("avatar", "outfits", [])
	var catalog = cfg.get_value("discovery", "catalog", [])
	var stored_analytics = cfg.get_value("analytics", "events", [])
	var stored_studio = cfg.get_value("studio", "session", {})

	friend_requests = requests if requests is Array else []
	blocked_users.clear()
	if blocked is Array:
		for value in blocked:
			if value is String or value is StringName:
				blocked_users.append(StringName(str(value)))
	muted_users.clear()
	if muted is Array:
		for value in muted:
			if value is String or value is StringName:
				muted_users.append(StringName(str(value)))
	party.clear()
	if stored_party is Array:
		for value in stored_party:
			if value is String or value is StringName:
				party.append(StringName(str(value)))
	party_leader = StringName(str(cfg.get_value("social", "party_leader", "")))
	chat_messages = messages if messages is Array else []
	if stored_avatar is Dictionary:
		avatar_config = stored_avatar.duplicate(true)
	avatar_outfits = [{}, {}, {}, {}, {}]
	if stored_outfits is Array:
		for i in range(min(avatar_outfits.size(), stored_outfits.size())):
			if stored_outfits[i] is Dictionary:
				avatar_outfits[i] = stored_outfits[i].duplicate(true)
	experience_catalog = []
	if catalog is Array:
		for item in catalog:
			if item is Dictionary:
				experience_catalog.append(item.duplicate(true))
	analytics = stored_analytics if stored_analytics is Array else []
	studio_session = stored_studio.duplicate(true) if stored_studio is Dictionary else studio_session
