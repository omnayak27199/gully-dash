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


func _ready() -> void:
	reset_player()


func _process(delta: float) -> void:
	if not _controls_enabled:
		return

	var lane_error: float = _target_x - position.x
	position.x = move_toward(position.x, _target_x, lane_change_speed * delta)

	var desired_angle: float = 0.0
	if absf(lane_error) > 1.0:
		desired_angle = deg_to_rad(signf(lane_error) * max_steering_angle_degrees)

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


func _draw() -> void:
	_draw_shadow()
	_draw_wheels()
	_draw_auto_body()


func _draw_shadow() -> void:
	var points := PackedVector2Array()
	const POINT_COUNT: int = 20
	for index in range(POINT_COUNT):
		var angle: float = TAU * float(index) / float(POINT_COUNT)
		points.append(Vector2(cos(angle) * 28.0, 8.0 + sin(angle) * 43.0))
	draw_colored_polygon(points, Color(0.02, 0.03, 0.025, 0.30))


func _draw_wheels() -> void:
	# A three-wheeler silhouette: one front wheel and two rear wheels.
	draw_rect(Rect2(-5.5, -40.0, 11.0, 22.0), Color("#111518"))
	draw_rect(Rect2(-27.0, 12.0, 9.0, 22.0), Color("#111518"))
	draw_rect(Rect2(18.0, 12.0, 9.0, 22.0), Color("#111518"))
	draw_rect(Rect2(-3.0, -36.0, 6.0, 13.0), Color("#626a6d"))
	draw_rect(Rect2(-25.0, 16.0, 5.0, 14.0), Color("#626a6d"))
	draw_rect(Rect2(20.0, 16.0, 5.0, 14.0), Color("#626a6d"))


func _draw_auto_body() -> void:
	# Outer body and yellow side panels.
	var body_outline := PackedVector2Array([
		Vector2(-15.0, -37.0),
		Vector2(15.0, -37.0),
		Vector2(24.0, -14.0),
		Vector2(24.0, 25.0),
		Vector2(17.0, 35.0),
		Vector2(-17.0, 35.0),
		Vector2(-24.0, 25.0),
		Vector2(-24.0, -14.0)
	])
	draw_colored_polygon(body_outline, Color("#292b26"))

	var body_fill := PackedVector2Array([
		Vector2(-12.0, -34.0),
		Vector2(12.0, -34.0),
		Vector2(20.0, -13.0),
		Vector2(20.0, 23.0),
		Vector2(14.0, 31.0),
		Vector2(-14.0, 31.0),
		Vector2(-20.0, 23.0),
		Vector2(-20.0, -13.0)
	])
	draw_colored_polygon(body_fill, Color("#f0b92f"))

	# Front windshield faces the top of the screen, toward incoming traffic.
	var windshield := PackedVector2Array([
		Vector2(-14.0, -28.0),
		Vector2(14.0, -28.0),
		Vector2(18.0, -14.0),
		Vector2(-18.0, -14.0)
	])
	draw_colored_polygon(windshield, Color("#83d2e5"))
	draw_line(Vector2(-14.0, -27.0), Vector2(14.0, -27.0), Color("#d4f5fa"), 2.0)

	# Green passenger canopy and a small rear bench.
	draw_rect(Rect2(-18.0, -9.0, 36.0, 27.0), Color("#176d49"))
	draw_rect(Rect2(-14.0, -5.0, 28.0, 19.0), Color("#238957"))
	draw_rect(Rect2(-12.0, 8.0, 24.0, 5.0), Color("#8c4731"))
	draw_rect(Rect2(-17.0, 17.0, 34.0, 5.0), Color("#f7d35d"))

	# Headlights, indicators and rear lamps.
	draw_rect(Rect2(-17.0, -32.0, 7.0, 5.0), Color("#fff4b4"))
	draw_rect(Rect2(10.0, -32.0, 7.0, 5.0), Color("#fff4b4"))
	draw_rect(Rect2(-21.0, -15.0, 3.0, 9.0), Color("#db6d43"))
	draw_rect(Rect2(18.0, -15.0, 3.0, 9.0), Color("#db6d43"))
	draw_rect(Rect2(-15.0, 27.0, 6.0, 4.0), Color("#d64a3e"))
	draw_rect(Rect2(9.0, 27.0, 6.0, 4.0), Color("#d64a3e"))
