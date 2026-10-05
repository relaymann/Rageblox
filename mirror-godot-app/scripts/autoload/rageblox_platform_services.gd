class_name RageBloxPlatformServices
extends Node

signal service_state_changed(service: StringName)
signal notification_received(notification: Dictionary)
signal party_changed(members: Array)
signal avatar_outfit_changed(slot: int)
signal economy_changed(balance: int)
signal experience_presence_changed(experience_id: StringName, players: int)

const SERVICE_NAMES := [
	&"discovery", &"social", &"avatar", &"economy", &"matchmaking",
	&"analytics", &"safety", &"assets", &"streaming", &"creator",
	&"luau", &"cross_platform", &"labs", &"launcher"
]

var services_enabled: Dictionary = {}
var discovery_cache: Dictionary = {}
var recent_experiences: Array[StringName] = []
var favorite_experiences: Array[StringName] = []
var friends: Dictionary = {}
var party_members: Array[StringName] = []
var notifications: Array[Dictionary] = []
var avatar_outfits: Array[Dictionary] = [{}, {}, {}, {}, {}]
var economy_balance: int = 0
var matchmaking_state := &"idle"
var matchmaking_region := &"auto"
var current_experience: StringName = StringName()
var asset_cache_manifest: Dictionary = {}
var streaming_enabled := true
var labs_flags: Dictionary = {}
var safety_settings := {
	"chat_enabled": true,
	"voice_enabled": false,
	"allow_friend_requests": true,
	"allow_party_invites": true,
}
var analytics_session_id := ""
var platform_capabilities := {
	"keyboard_mouse": true,
	"controller": true,
	"touch": false,
	"vr": false,
	"cross_play": true,
}

func _ready() -> void:
	for service in SERVICE_NAMES:
		services_enabled[service] = true
	analytics_session_id = "%s-%s" % [Time.get_unix_time_from_system(), randi()]
	_load_local_state()

func is_service_available(service: StringName) -> bool:
	return bool(services_enabled.get(service, false))

func set_service_enabled(service: StringName, enabled: bool) -> void:
	if service not in SERVICE_NAMES:
		return
	services_enabled[service] = enabled
	service_state_changed.emit(service)

func cache_experience(experience_id: StringName, metadata: Dictionary) -> void:
	discovery_cache[experience_id] = metadata.duplicate(true)

func mark_experience_played(experience_id: StringName) -> void:
	recent_experiences.erase(experience_id)
	recent_experiences.push_front(experience_id)
	if recent_experiences.size() > 50:
		recent_experiences.resize(50)
	_save_local_state()

func set_favorite(experience_id: StringName, favorite: bool) -> void:
	favorite_experiences.erase(experience_id)
	if favorite:
		favorite_experiences.push_front(experience_id)
	_save_local_state()

func add_friend(user_id: StringName, display_name: String, online := false) -> void:
	friends[user_id] = {"display_name": display_name, "online": online}
	_save_local_state()

func remove_friend(user_id: StringName) -> void:
	friends.erase(user_id)
	_save_local_state()

func set_party(members: Array[StringName]) -> void:
	party_members = members.duplicate()
	party_changed.emit(party_members)

func add_notification(kind: StringName, title: String, body: String, payload := {}) -> void:
	var notification := {"kind": kind, "title": title, "body": body, "payload": payload, "time": Time.get_unix_time_from_system(), "read": false}
	notifications.push_front(notification)
	if notifications.size() > 100:
		notifications.resize(100)
	notification_received.emit(notification)

func save_avatar_outfit(slot: int, outfit: Dictionary) -> bool:
	if slot < 0 or slot >= avatar_outfits.size():
		return false
	avatar_outfits[slot] = outfit.duplicate(true)
	_save_local_state()
	avatar_outfit_changed.emit(slot)
	return true

func set_matchmaking(region: StringName, state: StringName) -> void:
	matchmaking_region = region
	matchmaking_state = state
	service_state_changed.emit(&"matchmaking")

func set_presence(experience_id: StringName, players: int) -> void:
	current_experience = experience_id
	experience_presence_changed.emit(experience_id, players)

func register_asset(asset_id: StringName, version: String, size_bytes: int) -> void:
	asset_cache_manifest[asset_id] = {"version": version, "size": size_bytes, "last_used": Time.get_unix_time_from_system()}
	if asset_cache_manifest.size() > 10000:
		_evict_old_assets(1000)

func _evict_old_assets(count: int) -> void:
	var entries := asset_cache_manifest.keys()
	entries.sort_custom(func(a, b): return int(asset_cache_manifest[a].get("last_used", 0)) < int(asset_cache_manifest[b].get("last_used", 0)))
	for i in range(min(count, entries.size())):
		asset_cache_manifest.erase(entries[i])

func set_lab_flag(flag: StringName, enabled: bool) -> void:
	labs_flags[flag] = enabled
	_save_local_state()

func set_safety_setting(key: String, value: bool) -> void:
	if not safety_settings.has(key):
		return
	safety_settings[key] = value
	_save_local_state()

func set_platform_capability(capability: String, enabled: bool) -> void:
	if platform_capabilities.has(capability):
		platform_capabilities[capability] = enabled

func _save_local_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("platform", "recent_experiences", recent_experiences)
	cfg.set_value("platform", "favorite_experiences", favorite_experiences)
	cfg.set_value("platform", "friends", friends)
	cfg.set_value("platform", "avatar_outfits", avatar_outfits)
	cfg.set_value("platform", "labs_flags", labs_flags)
	cfg.set_value("safety", "settings", safety_settings)
	cfg.save("user://rageblox_platform_services.cfg")

func _load_local_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://rageblox_platform_services.cfg") != OK:
		return
	recent_experiences = cfg.get_value("platform", "recent_experiences", recent_experiences)
	favorite_experiences = cfg.get_value("platform", "favorite_experiences", favorite_experiences)
	friends = cfg.get_value("platform", "friends", friends)
	avatar_outfits = cfg.get_value("platform", "avatar_outfits", avatar_outfits)
	labs_flags = cfg.get_value("platform", "labs_flags", labs_flags)
	safety_settings = cfg.get_value("safety", "settings", safety_settings)
