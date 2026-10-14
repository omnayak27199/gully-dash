extends Node2D
## Coordinates the run loop, world objects, score, collision and HUD.
## Player steering and player artwork are delegated to PlayerController.

const VIEW_SIZE := Vector2(540.0, 960.0)
const ROAD_LEFT := 65.0
const ROAD_WIDTH := 410.0
const LANE_CENTERS: Array[float] = [135.0, 270.0, 405.0]
const PLAYER_Y := 790.0
const ROAD_MARKING_PERIOD := 120.0
const RESTART_BUTTON := Rect2(125.0, 535.0, 290.0, 70.0)

const COLOR_GRASS := Color("#3b773e")
const COLOR_ROAD := Color("#292d32")
const COLOR_KERB_RED := Color("#d54c3f")
const COLOR_KERB_WHITE := Color("#f3eee1")
const COLOR_LANE_MARKING := Color("#d8d8cc")

@onready var player: PlayerController = $Player

var rng := RandomNumberGenerator.new()
var road_offset: float = 0.0
var score: float = 0.0
var coins_collected: int = 0
var obstacle_timer: float = 0.0
var coin_timer: float = 0.0
var last_obstacle_lane: int = -1
var run_state: StringName = &"playing"
var touch_start := Vector2(-1.0, -1.0)

var obstacles: Array[Dictionary] = []
var coins: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()
	player.position.y = PLAYER_Y
	player.set_controls_enabled(true)
	queue_redraw()


func _process(delta: float) -> void:
	if run_state != &"playing":
		return

	var speed: float = _current_world_speed()
	road_offset = fmod(road_offset + speed * delta, ROAD_MARKING_PERIOD)
	score += delta * 12.0

	_update_spawn_timers(delta)
	_update_obstacles(delta, speed)

	if run_state == &"playing":
		_update_coins(delta, speed)

	queue_redraw()


func _current_world_speed() -> float:
	return 300.0 + minf(score * 0.35, 220.0)


func _update_spawn_timers(delta: float) -> void:
	obstacle_timer += delta
	var obstacle_interval: float = maxf(0.57, 0.98 - score / 1600.0)
	if obstacle_timer >= obstacle_interval:
		obstacle_timer -= obstacle_interval
		_spawn_obstacle()

	coin_timer += delta
	if coin_timer >= 1.15:
		coin_timer -= 1.15
		_spawn_coin()


func _update_obstacles(delta: float, speed: float) -> void:
	var player_rect: Rect2 = player.get_hitbox_rect()

	for index in range(obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = obstacles[index]
		var obstacle_y: float = float(obstacle["y"]) + speed * delta
		obstacle["y"] = obstacle_y
		obstacles[index] = obstacle

		var size: Vector2 = _obstacle_size(String(obstacle["kind"]))
		var obstacle_rect := Rect2(
			Vector2(float(obstacle["x"]) - size.x * 0.5, obstacle_y - size.y * 0.5),
			size
		)

		if player_rect.intersects(obstacle_rect):
			_end_run()
			return

		if obstacle_y > VIEW_SIZE.y + size.y:
			obstacles.remove_at(index)


func _update_coins(delta: float, speed: float) -> void:
	var player_rect: Rect2 = player.get_hitbox_rect()

	for index in range(coins.size() - 1, -1, -1):
		var coin: Dictionary = coins[index]
		var coin_y: float = float(coin["y"]) + speed * delta
		coin["y"] = coin_y
		coins[index] = coin

		var coin_rect := Rect2(
			Vector2(float(coin["x"]) - 16.0, coin_y - 16.0),
			Vector2(32.0, 32.0)
		)

		if player_rect.intersects(coin_rect):
			coins_collected += 1
			score += 25.0
			coins.remove_at(index)
		elif coin_y > VIEW_SIZE.y + 40.0:
			coins.remove_at(index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			_handle_touch_release(event.position)
			touch_start = Vector2(-1.0, -1.0)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo:
		if run_state == &"playing":
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				player.change_lane(-1)
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				player.change_lane(1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_restart_run()
		get_viewport().set_input_as_handled()


func _handle_touch_release(position: Vector2) -> void:
	if touch_start.x < 0.0:
		return

	var gesture: Vector2 = position - touch_start
	var is_horizontal_swipe: bool = absf(gesture.x) >= 40.0 and absf(gesture.x) > absf(gesture.y) * 1.2
	if run_state != &"playing":
		if RESTART_BUTTON.has_point(position):
			_restart_run()
	elif is_horizontal_swipe:
		player.change_lane(1 if gesture.x > 0.0 else -1)
	elif gesture.length() < 22.0:
		_handle_tap(position)


func _handle_tap(position: Vector2) -> void:
	if run_state != &"playing":
		if RESTART_BUTTON.has_point(position):
			_restart_run()
		return

	player.change_lane(-1 if position.x < VIEW_SIZE.x * 0.5 else 1)


func _end_run() -> void:
	run_state = &"game_over"
	player.set_controls_enabled(false)
	player.visible = false


func _restart_run() -> void:
	run_state = &"playing"
	road_offset = 0.0
	score = 0.0
	coins_collected = 0
	obstacle_timer = 0.0
	coin_timer = 0.0
	last_obstacle_lane = -1
	obstacles.clear()
	coins.clear()
	player.reset_player()
	player.position.y = PLAYER_Y
	queue_redraw()


func _spawn_obstacle() -> void:
	var lane: int = rng.randi_range(0, LANE_CENTERS.size() - 1)
	if lane == last_obstacle_lane:
		lane = (lane + rng.randi_range(1, LANE_CENTERS.size() - 1)) % LANE_CENTERS.size()
	last_obstacle_lane = lane

	var kind: StringName = &"bus" if rng.randf() < 0.17 else &"car"
	obstacles.append({
		"lane": lane,
		"x": LANE_CENTERS[lane],
		"y": -100.0,
		"kind": kind
	})


func _spawn_coin() -> void:
	var lane: int = rng.randi_range(0, LANE_CENTERS.size() - 1)
	coins.append({"x": LANE_CENTERS[lane], "y": -30.0})


func _obstacle_size(kind: String) -> Vector2:
	if kind == "bus":
		return Vector2(62.0, 100.0)
	return Vector2(48.0, 74.0)


func _draw() -> void:
	_draw_road()

	for coin in coins:
		_draw_coin(float(coin["x"]), float(coin["y"]))

	for obstacle in obstacles:
		_draw_vehicle(float(obstacle["x"]), float(obstacle["y"]), String(obstacle["kind"]))

	_draw_hud()
	if run_state == &"game_over":
		_draw_game_over()


func _draw_road() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_GRASS)

	for index in range(12):
		var y: float = fmod(float(index) * 100.0 + road_offset * 0.45, VIEW_SIZE.y)
		draw_circle(Vector2(25.0 + float((index * 17) % 20), y), 4.0, Color("#2d6935"))
		draw_circle(Vector2(510.0 - float((index * 13) % 18), y + 34.0), 4.0, Color("#2d6935"))

	draw_rect(Rect2(ROAD_LEFT, 0.0, ROAD_WIDTH, VIEW_SIZE.y), COLOR_ROAD)
	draw_rect(Rect2(ROAD_LEFT, 0.0, 12.0, VIEW_SIZE.y), Color("#b6b6ad"))
	draw_rect(Rect2(ROAD_LEFT + ROAD_WIDTH - 12.0, 0.0, 12.0, VIEW_SIZE.y), Color("#b6b6ad"))

	for y in range(-120, 1000, 60):
		var stripe_y: float = float(y) + road_offset
		var stripe_color: Color = COLOR_KERB_RED if int(floor(float(y) / 60.0)) % 2 == 0 else COLOR_KERB_WHITE
		draw_rect(Rect2(ROAD_LEFT, stripe_y, 12.0, 30.0), stripe_color)
		draw_rect(Rect2(ROAD_LEFT + ROAD_WIDTH - 12.0, stripe_y, 12.0, 30.0), stripe_color)

	for divider_x in [201.5, 338.5]:
		for y in range(-120, 1020, 120):
			draw_rect(
				Rect2(divider_x - 2.0, float(y) + road_offset, 4.0, 54.0),
				COLOR_LANE_MARKING
			)


func _draw_vehicle(x: float, y: float, kind: String) -> void:
	var is_bus: bool = kind == "bus"
	var width: float = 62.0 if is_bus else 48.0
	var height: float = 100.0 if is_bus else 74.0
	var body_color: Color = Color("#2e8dcc") if is_bus else Color("#d8584b")

	draw_rect(Rect2(x - width * 0.5 - 4.0, y - height * 0.5 + 9.0, 7.0, height - 18.0), Color("#111315"))
	draw_rect(Rect2(x + width * 0.5 - 3.0, y - height * 0.5 + 9.0, 7.0, height - 18.0), Color("#111315"))
	draw_rect(Rect2(x - width * 0.5, y - height * 0.5, width, height), body_color)
	draw_rect(Rect2(x - width * 0.5 + 7.0, y - height * 0.5 + 9.0, width - 14.0, height * 0.32), Color("#83c8de"))
	draw_rect(Rect2(x - width * 0.5 + 7.0, y + height * 0.06, width - 14.0, height * 0.18), Color("#272d32"))
	draw_rect(Rect2(x - width * 0.5 + 5.0, y + height * 0.5 - 12.0, 9.0, 5.0), Color("#fff1b0"))
	draw_rect(Rect2(x + width * 0.5 - 14.0, y + height * 0.5 - 12.0, 9.0, 5.0), Color("#fff1b0"))


func _draw_coin(x: float, y: float) -> void:
	draw_circle(Vector2(x, y), 17.0, Color("#8d5d17"))
	draw_circle(Vector2(x, y), 13.0, Color("#ffd34d"))
	draw_circle(Vector2(x, y), 8.0, Color("#f9ae28"))
	draw_line(Vector2(x - 4.0, y), Vector2(x + 4.0, y), Color("#8d5d17"), 2.0)


func _draw_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 78.0), Color(0.05, 0.07, 0.08, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 29.0), "GULLY DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f5d36b"))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 60.0), "SCORE  %06d" % int(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(380.0, 49.0), "COINS  %02d" % coins_collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffd34d"))
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 933.0), "TAP LEFT / RIGHT OR SWIPE TO CHANGE LANES", HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, 15, Color("#ffffff"))


func _draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.02, 0.03, 0.04, 0.78))
	_draw_centered_text("RIDE OVER", 385.0, 42, Color("#ffd34d"))
	_draw_centered_text("Score: %d" % int(score), 442.0, 27, Color("#ffffff"))
	_draw_centered_text("Coins: %d" % coins_collected, 484.0, 23, Color("#ffe19a"))

	draw_rect(RESTART_BUTTON, Color("#197d54"))
	draw_rect(Rect2(130.0, 540.0, 280.0, 60.0), Color("#239964"))
	_draw_centered_text("TAP TO RIDE AGAIN", 578.0, 21, Color("#ffffff"))
	_draw_centered_text("ENTER / SPACE TO RESTART", 642.0, 16, Color("#e7e7df"))


func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2((VIEW_SIZE.x - text_width) * 0.5, baseline_y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
