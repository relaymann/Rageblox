extends Node
## Unified RageBlox platform policy/state layer.
## Keeps platform UX, accessibility, performance and input behavior consistent
## without replacing the existing creator/gameplay systems.

signal quality_changed(preset: StringName)
signal accessibility_changed
signal navigation_changed(enabled: bool)

const QUALITY_PRESETS := {
	&"LOW": {"resolution": 0.65, "view_distance": 0.55, "effects": false},
	&"MEDIUM": {"resolution": 0.80, "view_distance": 0.70, "effects": true},
	&"HIGH": {"resolution": 1.00, "view_distance": 0.85, "effects": true},
	&"ULTRA": {"resolution": 1.00, "view_distance": 1.00, "effects": true},
}

const CONFIG_PATH := "user://rageblox_platform.cfg"
var quality_preset: StringName = &"HIGH"
var reduced_motion := false
var high_contrast := false
var controller_navigation := true
var ui_scale := 1.0

func _ready() -> void:
	_load()
	_apply_quality(quality_preset)
	get_tree().set_auto_accept_quit(true)

func set_quality(preset: StringName) -> void:
	if not QUALITY_PRESETS.has(preset):
		preset = &"HIGH"
	quality_preset = preset
	_apply_quality(preset)
	_save()
	quality_changed.emit(preset)

func _apply_quality(preset: StringName) -> void:
	var cfg: Dictionary = QUALITY_PRESETS[preset]
	if not is_instance_valid(GameplaySettings):
		return
	match preset:
		&"LOW":
			GameplaySettings.render_quality = GameplaySettings.RenderQuality.LOW
		&"MEDIUM":
			GameplaySettings.render_quality = GameplaySettings.RenderQuality.MEDIUM
		&"HIGH":
			GameplaySettings.render_quality = GameplaySettings.RenderQuality.HIGH
		&"ULTRA":
			GameplaySettings.render_quality = GameplaySettings.RenderQuality.ULTRA
	GameplaySettings.resolution_scale = float(cfg.resolution)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_save()
	accessibility_changed.emit()

func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	_save()
	accessibility_changed.emit()

func set_controller_navigation(enabled: bool) -> void:
	controller_navigation = enabled
	_save()
	navigation_changed.emit(enabled)

func set_ui_scale(scale: float) -> void:
	ui_scale = clampf(scale, 0.5, 2.0)
	_save()
	accessibility_changed.emit()

func should_animate() -> bool:
	return not reduced_motion

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("platform", "quality", String(quality_preset))
	cfg.set_value("accessibility", "reduced_motion", reduced_motion)
	cfg.set_value("accessibility", "high_contrast", high_contrast)
	cfg.set_value("accessibility", "controller_navigation", controller_navigation)
	cfg.set_value("accessibility", "ui_scale", ui_scale)
	cfg.save(CONFIG_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	quality_preset = StringName(str(cfg.get_value("platform", "quality", "HIGH")))
	reduced_motion = bool(cfg.get_value("accessibility", "reduced_motion", false))
	high_contrast = bool(cfg.get_value("accessibility", "high_contrast", false))
	controller_navigation = bool(cfg.get_value("accessibility", "controller_navigation", true))
	ui_scale = float(cfg.get_value("accessibility", "ui_scale", 1.0))
