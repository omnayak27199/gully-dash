extends Node2D
## First playable prototype for Gully Dash: India Rush.
## Placeholder graphics are drawn in code so no external assets are required yet.

const SCREEN_SIZE := Vector2(540.0, 960.0)
const LANE_X: Array[float] = [135.0, 270.0, 405.0]
const PLAYER_Y := 790.0
const PLAYER_WIDTH := 50.0
const PLAYER_HEIGHT := 78.0

var rng := RandomNumberGenerator.new()
var lane_index := 1
var player_x := 270.0
var road_offset := 0.0
var score := 0.0
var coins_collected := 0
var obstacle_timer := 0.0
var coin_timer := 0.0
var last_obstacle_lane := -1
var run_state := "playing"
var touch_start := Vector2(-1.0, -1.0)

var obstacles: Array[Dictionary] = []
var coins: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()
	queue_redraw()


func _process(delta: float) -> void:
	if run_state != "playing":
		queue_redraw()
		return

	var speed: float = 300.0 + minf(score * 0.35, 220.0)
	road_offset = fmod(road_offset + speed * delta, 120.0)
	score += delta * 12.0
	player_x = move_toward(player_x, LANE_X[lane_index], 800.0 * delta)

	obstacle_timer += delta
	var spawn_interval: float = maxf(0.57, 0.98 - score / 1600.0)
	if obstacle_timer >= spawn_interval:
		obstacle_timer = 0.0
		_spawn_obstacle()

	coin_timer += delta
	if coin_timer >= 1.15:
		coin_timer = 0.0
		_spawn_coin()

	var player_rect := Rect2(
		Vector2(player_x - PLAYER_WIDTH * 0.5, PLAYER_Y - PLAYER_HEIGHT * 0.5),
		Vector2(PLAYER_WIDTH, PLAYER_HEIGHT)
	)

	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = obstacles[i]
		var obstacle_y: float = float(obstacle["y"]) + speed * delta
		obstacle["y"] = obstacle_y
		obstacles[i] = obstacle

		var dimensions := _obstacle_size(String(obstacle["kind"]))
		var obstacle_rect := Rect2(
			Vector2(float(obstacle["x"]) - dimensions.x * 0.5, obstacle_y - dimensions.y * 0.5),
			dimensions
		)
		if player_rect.intersects(obstacle_rect):
			run_state = "game_over"
			break
		if obstacle_y > SCREEN_SIZE.y + 100.0:
			obstacles.remove_at(i)

	if run_state == "playing":
		for i in range(coins.size() - 1, -1, -1):
			var coin: Dictionary = coins[i]
			var coin_y: float = float(coin["y"]) + speed * delta
			coin["y"] = coin_y
			coins[i] = coin

			var coin_rect := Rect2(Vector2(float(coin["x"]) - 16.0, coin_y - 16.0), Vector2(32.0, 32.0))
			if player_rect.intersects(coin_rect):
				coins_collected += 1
				score += 25.0
				coins.remove_at(i)
			elif coin_y > SCREEN_SIZE.y + 40.0:
				coins.remove_at(i)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			if touch_start.x >= 0.0:
				var swipe := event.position - touch_start
				if absf(swipe.x) > 40.0:
					if run_state != "playing":
						_restart_game()
					else:
						_change_lane(1 if swipe.x > 0.0 else -1)
				else:
					_handle_tap(event.position)
			touch_start = Vector2(-1.0, -1.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			if run_state == "playing":
				_change_lane(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			if run_state == "playing":
				_change_lane(1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if run_state != "playing":
				_restart_game()
		get_viewport().set_input_as_handled()


func _handle_tap(position: Vector2) -> void:
	if run_state != "playing":
		_restart_game()
	elif position.x < SCREEN_SIZE.x * 0.5:
		_change_lane(-1)
	else:
		_change_lane(1)


func _change_lane(direction: int) -> void:
	lane_index = clampi(lane_index + direction, 0, LANE_X.size() - 1)


func _restart_game() -> void:
	lane_index = 1
	player_x = LANE_X[lane_index]
	road_offset = 0.0
	score = 0.0
	coins_collected = 0
	obstacle_timer = 0.0
	coin_timer = 0.0
	last_obstacle_lane = -1
	obstacles.clear()
	coins.clear()
	run_state = "playing"
	queue_redraw()


func _spawn_obstacle() -> void:
	var lane := rng.randi_range(0, 2)
	if lane == last_obstacle_lane:
		lane = (lane + rng.randi_range(1, 2)) % 3
	last_obstacle_lane = lane

	var kind := "bus" if rng.randf() < 0.17 else "car"
	obstacles.append({
		"lane": lane,
		"x": LANE_X[lane],
		"y": -100.0,
		"kind": kind
	})


func _spawn_coin() -> void:
	var lane := rng.randi_range(0, 2)
	coins.append({
		"x": LANE_X[lane],
		"y": -30.0
	})


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

	_draw_player()
	_draw_hud()

	if run_state != "playing":
		_draw_game_over()


func _draw_road() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("#3b773e"))
	# Simple roadside grass texture.
	for i in range(12):
		var y: float = fmod(float(i) * 100.0 + road_offset * 0.45, SCREEN_SIZE.y)
		draw_circle(Vector2(25.0 + float((i * 17) % 20), y), 4.0, Color("#2d6935"))
		draw_circle(Vector2(510.0 - float((i * 13) % 18), y + 34.0), 4.0, Color("#2d6935"))

	# Road, shoulders and kerbs.
	draw_rect(Rect2(65.0, 0.0, 410.0, SCREEN_SIZE.y), Color("#292d32"))
	draw_rect(Rect2(65.0, 0.0, 12.0, SCREEN_SIZE.y), Color("#b6b6ad"))
	draw_rect(Rect2(463.0, 0.0, 12.0, SCREEN_SIZE.y), Color("#b6b6ad"))
	for y in range(-120, 1000, 60):
		var stripe_y: float = float(y) + road_offset
		var stripe_color := Color("#d54c3f") if int(floor(float(y) / 60.0)) % 2 == 0 else Color("#f3eee1")
		draw_rect(Rect2(65.0, stripe_y, 12.0, 30.0), stripe_color)
		draw_rect(Rect2(463.0, stripe_y, 12.0, 30.0), stripe_color)

	# Three lanes, with dashed separators scrolling toward the player.
	for divider_x in [201.5, 338.5]:
		for y in range(-120, 1020, 120):
			var dash_y: float = float(y) + road_offset
			draw_rect(Rect2(divider_x - 2.0, dash_y, 4.0, 54.0), Color("#d8d8cc"))


func _draw_player() -> void:
	var x := player_x
	var y := PLAYER_Y

	# Wheels and shadow.
	draw_rect(Rect2(x - 31.0, y - 25.0, 8.0, 54.0), Color("#121416"))
	draw_rect(Rect2(x + 23.0, y - 25.0, 8.0, 54.0), Color("#121416"))
	draw_rect(Rect2(x - 26.0, y - 43.0, 52.0, 88.0), Color("#e5a72f"))
	# Front and bonnet.
	draw_rect(Rect2(x - 21.0, y + 15.0, 42.0, 23.0), Color("#f3c54a"))
	# Windshield.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 19.0, y - 25.0),
		Vector2(x + 19.0, y - 25.0),
		Vector2(x + 16.0, y + 8.0),
		Vector2(x - 16.0, y + 8.0)
	]), Color("#77cbe1"))
	draw_line(Vector2(x, y - 24.0), Vector2(x, y + 7.0), Color("#3c7180"), 3.0)
	# Roof stripe and headlamps.
	draw_rect(Rect2(x - 24.0, y - 38.0, 48.0, 8.0), Color("#197d54"))
	draw_rect(Rect2(x - 20.0, y + 30.0, 10.0, 6.0), Color("#fff2af"))
	draw_rect(Rect2(x + 10.0, y + 30.0, 10.0, 6.0), Color("#fff2af"))
	draw_rect(Rect2(x - 9.0, y + 16.0, 18.0, 5.0), Color("#25292c"))


func _draw_vehicle(x: float, y: float, kind: String) -> void:
	var is_bus := kind == "bus"
	var width := 62.0 if is_bus else 48.0
	var height := 100.0 if is_bus else 74.0
	var body_color := Color("#2e8dcc") if is_bus else Color("#d8584b")
	draw_rect(Rect2(x - width * 0.5 - 4.0, y - height * 0.5 + 9.0, 7.0, height - 18.0), Color("#111315"))
	draw_rect(Rect2(x + width * 0.5 - 3.0, y - height * 0.5 + 9.0, 7.0, height - 18.0), Color("#111315"))
	draw_rect(Rect2(x - width * 0.5, y - height * 0.5, width, height), body_color)
	var window_color := Color("#83c8de")
	draw_rect(Rect2(x - width * 0.5 + 7.0, y - height * 0.5 + 9.0, width - 14.0, height * 0.32), window_color)
	draw_rect(Rect2(x - width * 0.5 + 7.0, y + height * 0.06, width - 14.0, height * 0.18), Color("#272d32"))
	draw_rect(Rect2(x - width * 0.5 + 5.0, y + height * 0.5 - 12.0, 9.0, 5.0), Color("#fff1b0"))
	draw_rect(Rect2(x + width * 0.5 - 14.0, y + height * 0.5 - 12.0, 9.0, 5.0), Color("#fff1b0"))


func _draw_coin(x: float, y: float) -> void:
	draw_circle(Vector2(x, y), 17.0, Color("#8d5d17"))
	draw_circle(Vector2(x, y), 13.0, Color("#ffd34d"))
	draw_circle(Vector2(x, y), 8.0, Color("#f9ae28"))
	draw_line(Vector2(x - 4.0, y), Vector2(x + 4.0, y), Color("#8d5d17"), 2.0)


func _draw_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, SCREEN_SIZE.x, 78.0), Color(0.05, 0.07, 0.08, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 29.0), "GULLY DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f5d36b"))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 60.0), "SCORE  %06d" % int(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#ffffff"))
	draw_string(ThemeDB.fallback_font, Vector2(380.0, 49.0), "COINS  %02d" % coins_collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffd34d"))
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 933.0), "TAP LEFT / RIGHT OR SWIPE TO CHANGE LANES", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 15, Color("#ffffff"))


func _draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.02, 0.03, 0.04, 0.76))
	_draw_centered_text("RIDE OVER", 385.0, 42, Color("#ffd34d"))
	_draw_centered_text("Score: %d" % int(score), 442.0, 27, Color("#ffffff"))
	_draw_centered_text("Coins: %d" % coins_collected, 484.0, 23, Color("#ffe19a"))
	draw_rect(Rect2(125.0, 535.0, 290.0, 70.0), Color("#197d54"))
	draw_rect(Rect2(130.0, 540.0, 280.0, 60.0), Color("#239964"))
	_draw_centered_text("TAP TO RIDE AGAIN", 578.0, 21, Color("#ffffff"))
	_draw_centered_text("ENTER / SPACE TO RESTART", 642.0, 16, Color("#e7e7df"))


func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((SCREEN_SIZE.x - text_width) * 0.5, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
