extends StaticBody3D
class_name RageBloxShowcaseInteractable

signal player_interact(player: Node)

@export var door_path: NodePath
var _open := false
var _cooldown_until := 0

func _ready() -> void:
	player_interact.connect(_on_player_interact)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.0, 1.6)
	shape.shape = box
	shape.position.y = 0.25
	add_child(shape)

func hover_panel(_position: Vector3) -> void:
	pass

func click_panel() -> void:
	if Time.get_ticks_msec() < _cooldown_until:
		return
	_cooldown_until = Time.get_ticks_msec() + 500
	if Zone.is_host():
		_toggle_for_player(null)
		_sync_state.rpc(_open)
	else:
		_request_toggle.rpc_id(Zone.SERVER_PEER_ID)

func _on_player_interact(player: Node) -> void:
	if Zone.is_host():
		_toggle_for_player(player)
		_sync_state.rpc(_open)

func _toggle_for_player(player: Node) -> void:
	if player != null and is_instance_valid(player):
		if player.global_position.distance_to(global_position) > 5.0:
			return
	_open = not _open
	_apply_state()

@rpc("any_peer", "reliable")
func _request_toggle() -> void:
	if not Zone.is_host():
		return
	var peer_id := get_multiplayer().get_remote_sender_id()
	var player = Zone.find_player_by_peer(peer_id)
	if not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) > 5.0:
		return
	_toggle_for_player(player)
	_sync_state.rpc(_open)

@rpc("authority", "call_remote", "reliable")
func _sync_state(open: bool) -> void:
	_open = open
	_apply_state()

func _apply_state() -> void:
	var door = get_node_or_null(door_path)
	if not is_instance_valid(door):
		return
	var target := door as Node3D
	if _open:
		target.position.y = -3.0
		target.visible = false
	else:
		target.position.y = 2.5
		target.visible = true
