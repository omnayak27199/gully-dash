class_name PlayerController
extends Node2D
## Owns player lane selection, movement smoothing, hitbox and placeholder art.
## Lane positions are expressed in the Game scene's 540x960 viewport coordinates.

signal lane_changed(previous_lane: int, current_lane: int)

const LANE_CENTERS: Array[float] = [135.0, 270.0, 405.0]
const SPAWN_Y: float = 790.0
## Slightly forgiving hitbox: narrower than the visible vehicle to improve feel.
const HITBOX_SIZE := Vector2(42.0, 62.0)

@export_range(200.0, 1600.0, 25.0) var lane_change_speed: float = 900.0
@export_range(0.0, 12.0, 0.5) var max_steering_angle_degrees: float = 6.0
@export_range(1.0, 24.0, 0.5) var steering_settle_speed: float = 14.0

var current_lane: int = 1
var _target_x: float = LANE_CENTERS[1]
var _controls_enabled: bool = true
var reduced_motion_enabled: bool = false
var _skin_id: StringName = &"classic"
var _skin_texture: Texture2D
var _visual: Sprite2D


func _ready() -> void:
	reset_player()
	_setup_visual()


func _setup_visual() -> void:
	_visual = Sprite2D.new()
	_visual.name = "AutoSprite"
	_visual.position = Vector2.ZERO
	_visual.scale = Vector2(0.42, 0.42)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_visual)
	if _skin_texture == null:
		apply_skin(_skin_id)
	else:
		_visual.texture = _skin_texture


func _process(delta: float) -> void:
	if not _controls_enabled:
		return

	var lane_error: float = _target_x - position.x
	position.x = move_toward(position.x, _target_x, lane_change_speed * delta)

	var desired_angle: float = 0.0
	var steering_limit: float = max_steering_angle_degrees
	if reduced_motion_enabled:
		steering_limit = 0.0
	if absf(lane_error) > 1.0:
		desired_angle = deg_to_rad(signf(lane_error) * steering_limit)

	rotation = lerp_angle(
		rotation,
		desired_angle,
		clampf(delta * steering_settle_speed, 0.0, 1.0)
	)


## Requests a relative lane change. Returns false when blocked at an edge or disabled.
func change_lane(direction: int) -> bool:
	if not _controls_enabled:
		return false
	if direction != -1 and direction != 1:
		return false

	var next_lane: int = clampi(current_lane + direction, 0, LANE_CENTERS.size() - 1)
	if next_lane == current_lane:
		return false

	var previous_lane: int = current_lane
	current_lane = next_lane
	_target_x = LANE_CENTERS[current_lane]
	lane_changed.emit(previous_lane, current_lane)
	return true


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled


## Injected from the game coordinator to keep this controller reusable/testable.
func set_reduced_motion_enabled(enabled: bool) -> void:
	reduced_motion_enabled = enabled


## Apply the selected local cosmetic skin. Unknown IDs safely fall back to classic.
func apply_skin(skin_id: StringName) -> void:
	var asset_path: String
	match skin_id:
		&"blue":
			_skin_id = &"blue"
			asset_path = "res://assets/sprites/auto_blue.svg"
		&"pink":
			_skin_id = &"pink"
			asset_path = "res://assets/sprites/auto_pink.svg"
		_:
			_skin_id = &"classic"
			asset_path = "res://assets/sprites/auto_classic.svg"

	_skin_texture = load(asset_path) as Texture2D
	if _skin_texture == null:
		push_error("Could not load auto skin asset: " + asset_path)
	elif is_instance_valid(_visual):
		_visual.texture = _skin_texture


## Reset all movement state between runs so no steering momentum carries over.
func reset_player() -> void:
	current_lane = 1
	position = Vector2(LANE_CENTERS[current_lane], SPAWN_Y)
	_target_x = position.x
	rotation = 0.0
	_controls_enabled = true
	visible = true
	queue_redraw()


## Returns a rectangle in the shared Game/Player parent coordinate space.
func get_hitbox_rect() -> Rect2:
	return Rect2(position - HITBOX_SIZE * 0.5, HITBOX_SIZE)


