extends Node2D
## Main game coordinator. Player movement/rendering lives in PlayerController;
## persistent progression/settings/audio live in their own autoload modules.

const VIEW_SIZE := Vector2(540.0, 960.0)
const ROAD_LEFT := 65.0
const ROAD_WIDTH := 410.0
const LANE_CENTERS: Array[float] = [135.0, 270.0, 405.0]
const PLAYER_Y := 790.0
const ROAD_MARKING_PERIOD := 120.0

const MENU_PLAY := Rect2(115.0, 360.0, 310.0, 74.0)
const MENU_GARAGE := Rect2(115.0, 453.0, 310.0, 58.0)
const MENU_MISSIONS := Rect2(115.0, 527.0, 310.0, 58.0)
const MENU_SETTINGS := Rect2(115.0, 601.0, 310.0, 58.0)
const PAUSE_HITBOX := Rect2(465.0, 7.0, 65.0, 65.0)
const PAUSE_RESUME := Rect2(120.0, 380.0, 300.0, 64.0)
const PAUSE_HOME := Rect2(120.0, 462.0, 300.0, 58.0)
const PAUSE_SETTINGS := Rect2(120.0, 538.0, 300.0, 58.0)
const GAME_OVER_RETRY := Rect2(125.0, 535.0, 290.0, 68.0)
const GAME_OVER_HOME := Rect2(135.0, 624.0, 270.0, 54.0)
const GARAGE_CLASSIC := Rect2(70.0, 330.0, 400.0, 100.0)
const GARAGE_BLUE := Rect2(70.0, 448.0, 400.0, 100.0)
const GARAGE_PINK := Rect2(70.0, 566.0, 400.0, 100.0)
const CONTENT_BACK := Rect2(135.0, 770.0, 270.0, 58.0)
const EXIT_STAY := Rect2(120.0, 470.0, 300.0, 62.0)
const EXIT_QUIT := Rect2(120.0, 550.0, 300.0, 62.0)
const SETTINGS_SOUND := Rect2(90.0, 350.0, 360.0, 62.0)
const SETTINGS_HAPTICS := Rect2(90.0, 440.0, 360.0, 62.0)
const SETTINGS_MOTION := Rect2(90.0, 530.0, 360.0, 62.0)
const COLOR_GRASS := Color("#3b773e")
const COLOR_ROAD := Color("#292d32")
const COLOR_KERB_RED := Color("#d54c3f")
const COLOR_KERB_WHITE := Color("#f3eee1")
const COLOR_LANE_MARKING := Color("#d8d8cc")
const COLOR_INK := Color("#f8f4e9")
const COLOR_MUTED := Color("#b4c0b5")
const COLOR_PANEL := Color("#172421")
const COLOR_GREEN := Color("#218755")
const COLOR_GOLD := Color("#f5c94f")

@onready var player: PlayerController = $Player

var rng := RandomNumberGenerator.new()
var road_offset: float = 0.0
var score: float = 0.0
var distance_m: float = 0.0
var coins_collected: int = 0
var powerups_used: int = 0
var obstacle_timer: float = 0.0
var collectible_timer: float = 0.0
var last_obstacle_lane: int = -1
var run_state: StringName = &"menu"
var settings_return_state: StringName = &"menu"
var touch_start := Vector2(-1.0, -1.0)
var shield_active: bool = false
var multiplier_time: float = 0.0
var status_message: String = ""
var status_time: float = 0.0
var completed_missions_this_run: Array[String] = []

var obstacles: Array[Dictionary] = []
var collectibles: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()
	player.position.y = PLAYER_Y
	player.apply_skin(SaveManager.selected_skin)
	player.set_controls_enabled(false)
	player.visible = true
	AudioFeedback.play_event(&"start")
	queue_redraw()


func _process(delta: float) -> void:
	if status_time > 0.0:
		status_time = maxf(0.0, status_time - delta)

	if run_state != &"playing":
		queue_redraw()
		return

	var speed: float = _current_world_speed()
	var motion_scale: float = 0.35 if SettingsManager.reduced_motion else 1.0
	road_offset = fmod(road_offset + speed * delta * motion_scale, ROAD_MARKING_PERIOD)
	distance_m += speed * delta / 100.0
	var score_multiplier: float = 2.0 if multiplier_time > 0.0 else 1.0
	score += delta * 12.0 * score_multiplier

	if multiplier_time > 0.0:
		multiplier_time = maxf(0.0, multiplier_time - delta)

	if shield_active:
		# Flash gently so protection is legible without relying on colour alone.
		pass

	_update_spawn_timers(delta)
	_update_obstacles(delta, speed)

	if run_state == &"playing":
		_update_collectibles(delta, speed)

	queue_redraw()


func _current_world_speed() -> float:
	return 300.0 + minf(score * 0.35, 220.0)


func _update_spawn_timers(delta: float) -> void:
	obstacle_timer += delta
	var obstacle_interval: float = maxf(0.57, 0.98 - score / 1600.0)
	if obstacle_timer >= obstacle_interval:
		obstacle_timer = fmod(obstacle_timer, obstacle_interval)
		_spawn_obstacle()

	collectible_timer += delta
	if collectible_timer >= 0.86:
		collectible_timer = fmod(collectible_timer, 0.86)
		_spawn_collectible()


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
			if shield_active:
				shield_active = false
				obstacles.remove_at(index)
				AudioFeedback.play_event(&"powerup")
				SettingsManager.vibrate(55)
				_show_status("SHIELD SAVED YOU!")
				continue
			_end_run()
			return

		if obstacle_y > VIEW_SIZE.y + size.y:
			obstacles.remove_at(index)


func _update_collectibles(delta: float, speed: float) -> void:
	var player_rect: Rect2 = player.get_hitbox_rect()
	for index in range(collectibles.size() - 1, -1, -1):
		var item: Dictionary = collectibles[index]
		var item_y: float = float(item["y"]) + speed * delta
		item["y"] = item_y
		collectibles[index] = item

		var pickup_rect := Rect2(
			Vector2(float(item["x"]) - 18.0, item_y - 18.0),
			Vector2(36.0, 36.0)
		)
		if player_rect.intersects(pickup_rect):
			_collect_item(StringName(item["kind"]))
			collectibles.remove_at(index)
		elif item_y > VIEW_SIZE.y + 44.0:
			collectibles.remove_at(index)


func _collect_item(kind: StringName) -> void:
	match kind:
		&"coin":
			var coin_value: int = 2 if multiplier_time > 0.0 else 1
			coins_collected += coin_value
			score += 25.0 * float(coin_value)
			AudioFeedback.play_event(&"coin")
			SettingsManager.vibrate(18)
			_show_status("+%d CHAI COIN%s" % [coin_value, "" if coin_value == 1 else "S"])
		&"passenger":
			# Passenger pickups are intentionally uncommon and share the lane
			# of a recently spawned obstacle, making the reward a risk/reward choice.
			multiplier_time = maxf(multiplier_time, 7.0)
			score += 45.0
			powerups_used += 1
			AudioFeedback.play_event(&"passenger")
			SettingsManager.vibrate(28)
			_show_status("PASSENGER RUSH  •  2X SCORE!")
		&"shield":
			shield_active = true
			powerups_used += 1
			AudioFeedback.play_event(&"powerup")
			SettingsManager.vibrate(45)
			_show_status("SHIELD READY")
		&"multiplier":
			multiplier_time = maxf(multiplier_time, 9.0)
			powerups_used += 1
			AudioFeedback.play_event(&"powerup")
			SettingsManager.vibrate(35)
			_show_status("COIN RUSH  •  2X REWARDS!")


func _show_status(message: String) -> void:
	status_message = message
	status_time = 1.8


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
		if event.keycode == KEY_ESCAPE:
			_handle_back_request()
		elif run_state == &"playing":
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				player.change_lane(-1)
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				player.change_lane(1)
			elif event.keycode == KEY_P:
				_pause_run()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			match run_state:
				&"menu":
					_start_run()
				&"paused":
					_resume_run()
				&"game_over":
					_start_run()
				&"settings":
					_return_from_settings()
				&"garage", &"missions":
					_show_menu()
				&"exit_confirm":
					_show_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()


func _handle_back_request() -> void:
	match run_state:
		&"playing":
			_pause_run()
		&"paused":
			_show_menu()
		&"settings":
			_return_from_settings()
		&"garage", &"missions":
			_show_menu()
		&"exit_confirm":
			_show_menu()
		&"game_over":
			_show_menu()
		&"menu":
			run_state = &"exit_confirm"
			player.visible = false
	queue_redraw()


func _handle_touch_release(position: Vector2) -> void:
	if touch_start.x < 0.0:
		return

	var gesture: Vector2 = position - touch_start
	var horizontal_swipe: bool = absf(gesture.x) >= 36.0 and absf(gesture.x) > absf(gesture.y) * 1.2
	if run_state == &"playing" and horizontal_swipe:
		player.change_lane(1 if gesture.x > 0.0 else -1)
	elif gesture.length() < 24.0:
		_handle_tap(position)


func _handle_tap(position: Vector2) -> void:
	match run_state:
		&"menu":
			if MENU_PLAY.has_point(position):
				_start_run()
			elif MENU_GARAGE.has_point(position):
				run_state = &"garage"
				player.visible = false
				player.set_controls_enabled(false)
			elif MENU_MISSIONS.has_point(position):
				run_state = &"missions"
				player.visible = false
				player.set_controls_enabled(false)
			elif MENU_SETTINGS.has_point(position):
				settings_return_state = &"menu"
				run_state = &"settings"
				player.visible = false
				player.set_controls_enabled(false)

		&"playing":
			if PAUSE_HITBOX.has_point(position):
				_pause_run()
			else:
				player.change_lane(-1 if position.x < VIEW_SIZE.x * 0.5 else 1)

		&"paused":
			if PAUSE_RESUME.has_point(position):
				_resume_run()
			elif PAUSE_HOME.has_point(position):
				_show_menu()
			elif PAUSE_SETTINGS.has_point(position):
				settings_return_state = &"paused"
				run_state = &"settings"
				player.visible = false

		&"game_over":
			if GAME_OVER_RETRY.has_point(position):
				_start_run()
			elif GAME_OVER_HOME.has_point(position):
				_show_menu()

		&"garage":
			if GARAGE_CLASSIC.has_point(position):
				_select_skin(&"classic")
			elif GARAGE_BLUE.has_point(position):
				_select_skin(&"blue")
			elif GARAGE_PINK.has_point(position):
				_select_skin(&"pink")
			elif CONTENT_BACK.has_point(position):
				_show_menu()

		&"missions":
			if CONTENT_BACK.has_point(position):
				_show_menu()

		&"settings":
			if SETTINGS_SOUND.has_point(position):
				SettingsManager.toggle_sound()
				if SettingsManager.sound_enabled:
					AudioFeedback.play_event(&"coin")
			elif SETTINGS_HAPTICS.has_point(position):
				SettingsManager.toggle_haptics()
			elif SETTINGS_MOTION.has_point(position):
				SettingsManager.toggle_reduced_motion()
			elif CONTENT_BACK.has_point(position):
				_return_from_settings()

		&"exit_confirm":
			if EXIT_STAY.has_point(position):
				_show_menu()
			elif EXIT_QUIT.has_point(position):
				get_tree().quit()

	queue_redraw()


func _start_run() -> void:
	run_state = &"playing"
	road_offset = 0.0
	score = 0.0
	distance_m = 0.0
	coins_collected = 0
	powerups_used = 0
	obstacle_timer = 0.0
	collectible_timer = 0.0
	last_obstacle_lane = -1
	shield_active = false
	multiplier_time = 0.0
	completed_missions_this_run.clear()
	obstacles.clear()
	collectibles.clear()
	player.reset_player()
	player.position.y = PLAYER_Y
	player.apply_skin(SaveManager.selected_skin)
	player.set_controls_enabled(true)
	player.visible = true
	AudioFeedback.play_event(&"start")
	queue_redraw()


func _pause_run() -> void:
	if run_state != &"playing":
		return
	run_state = &"paused"
	player.set_controls_enabled(false)
	SettingsManager.vibrate(20)
	queue_redraw()


func _resume_run() -> void:
	if run_state != &"paused":
		return
	run_state = &"playing"
	player.set_controls_enabled(true)
	queue_redraw()


func _return_from_settings() -> void:
	run_state = settings_return_state
	player.visible = run_state == &"menu" or run_state == &"paused"
	player.set_controls_enabled(run_state == &"playing")
	queue_redraw()


func _show_menu() -> void:
	run_state = &"menu"
	player.set_controls_enabled(false)
	player.reset_player()
	player.apply_skin(SaveManager.selected_skin)
	player.position.y = PLAYER_Y
	player.visible = true
	queue_redraw()


func _select_skin(skin_id: StringName) -> void:
	if SaveManager.buy_or_select_skin(skin_id):
		player.apply_skin(SaveManager.selected_skin)
		_show_status("RIDE STYLE SELECTED")
		AudioFeedback.play_event(&"coin")
	else:
		_show_status("NEED %d CHAI COINS" % SaveManager.skin_price(skin_id))


func _end_run() -> void:
	if run_state != &"playing":
		return
	run_state = &"game_over"
	player.set_controls_enabled(false)
	player.visible = false
	completed_missions_this_run = SaveManager.record_run(
		int(score),
		coins_collected,
		int(distance_m),
		powerups_used
	)
	AudioFeedback.play_event(&"crash")
	SettingsManager.vibrate(65)


func _spawn_obstacle() -> void:
	var lane: int = rng.randi_range(0, LANE_CENTERS.size() - 1)
	if lane == last_obstacle_lane:
		lane = (lane + rng.randi_range(1, LANE_CENTERS.size() - 1)) % LANE_CENTERS.size()
	last_obstacle_lane = lane

	var kind: StringName = &"bus" if rng.randf() < 0.17 else &"car"
	obstacles.append({
		"lane": lane,
		"x": LANE_CENTERS[lane],
		"y": -105.0,
		"kind": kind
	})


func _spawn_collectible() -> void:
	var roll: float = rng.randf()
	var kind: StringName
	if roll < 0.64:
		kind = &"coin"
	elif roll < 0.76:
		kind = &"passenger"
	elif roll < 0.88:
		kind = &"shield"
	else:
		kind = &"multiplier"

	var lane: int = rng.randi_range(0, LANE_CENTERS.size() - 1)
	var spawn_y: float = -35.0

	# Put some passenger pickups ahead of traffic in the same lane, creating
	# a readable opportunity with a genuine risk if the player stays too long.
	if kind == &"passenger" and not obstacles.is_empty() and rng.randf() < 0.7:
		var near_obstacle: Dictionary = obstacles[rng.randi_range(0, obstacles.size() - 1)]
		lane = int(near_obstacle["lane"])
		spawn_y = float(near_obstacle["y"]) + 65.0

	collectibles.append({"x": LANE_CENTERS[lane], "y": spawn_y, "kind": kind})


func _obstacle_size(kind: String) -> Vector2:
	if kind == "bus":
		return Vector2(62.0, 100.0)
	return Vector2(48.0, 74.0)


func _draw() -> void:
	_draw_road()

	for item in collectibles:
		_draw_collectible(float(item["x"]), float(item["y"]), StringName(item["kind"]))

	for obstacle in obstacles:
		_draw_vehicle(float(obstacle["x"]), float(obstacle["y"]), String(obstacle["kind"]))

	if run_state == &"playing" or run_state == &"paused":
		_draw_game_hud()

	match run_state:
		&"menu":
			_draw_menu()
		&"paused":
			_draw_pause_screen()
		&"game_over":
			_draw_game_over()
		&"garage":
			_draw_garage()
		&"missions":
			_draw_missions()
		&"settings":
			_draw_settings()
		&"exit_confirm":
			_draw_exit_confirm()

	if status_time > 0.0 and not status_message.is_empty() and run_state != &"game_over":
		_draw_status_message()


func _draw_road() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_GRASS)

	# Procedural roadside blocks keep the prototype self-contained and asset-free.
	for index in range(9):
		var y: float = fmod(float(index) * 125.0 + road_offset * 0.35, VIEW_SIZE.y)
		var left_x: float = 10.0 + float((index * 19) % 32)
		var right_x: float = 486.0 + float((index * 13) % 22)
		draw_rect(Rect2(left_x, y, 22.0, 58.0), Color("#667a5d"))
		draw_rect(Rect2(left_x - 4.0, y - 6.0, 30.0, 12.0), Color("#d4bd85"))
		draw_rect(Rect2(right_x, fmod(y + 38.0, VIEW_SIZE.y), 30.0, 50.0), Color("#7e7053"))
		draw_rect(Rect2(right_x - 4.0, fmod(y + 32.0, VIEW_SIZE.y), 38.0, 12.0), Color("#c66c4b"))

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
			draw_rect(Rect2(divider_x - 2.0, float(y) + road_offset, 4.0, 54.0), COLOR_LANE_MARKING)


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


func _draw_collectible(x: float, y: float, kind: StringName) -> void:
	match kind:
		&"coin":
			draw_circle(Vector2(x, y), 18.0, Color("#8d5d17"))
			draw_circle(Vector2(x, y), 14.0, COLOR_GOLD)
			draw_circle(Vector2(x, y), 8.0, Color("#f9ae28"))
			draw_string(ThemeDB.fallback_font, Vector2(x - 4.0, y + 5.0), "₹", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8d5d17"))
		&"passenger":
			draw_circle(Vector2(x, y), 21.0, Color("#ffe09c"))
			draw_circle(Vector2(x, y), 16.0, Color("#d9783e"))
			draw_circle(Vector2(x, y - 6.0), 5.0, Color("#fff2d9"))
			draw_rect(Rect2(x - 8.0, y, 16.0, 10.0), Color("#fff2d9"))
		&"shield":
			draw_circle(Vector2(x, y), 21.0, Color("#9ce9f3"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - 14.0), Vector2(x + 12.0, y - 8.0),
				Vector2(x + 9.0, y + 7.0), Vector2(x, y + 14.0),
				Vector2(x - 9.0, y + 7.0), Vector2(x - 12.0, y - 8.0)
			]), Color("#2483a5"))
			draw_line(Vector2(x - 5.0, y), Vector2(x - 1.0, y + 4.0), Color.WHITE, 2.0)
			draw_line(Vector2(x - 1.0, y + 4.0), Vector2(x + 6.0, y - 5.0), Color.WHITE, 2.0)
		&"multiplier":
			draw_circle(Vector2(x, y), 21.0, Color("#e5b6ff"))
			draw_circle(Vector2(x, y), 15.0, Color("#8751c4"))
			_draw_centered_text_at("2X", Vector2(x, y + 5.0), 14, Color.WHITE)


func _draw_game_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 92.0), Color(0.05, 0.07, 0.08, 0.9))
	_draw_text("GULLY DASH", Vector2(18.0, 25.0), 16, COLOR_GOLD)
	_draw_text("%06d" % int(score), Vector2(18.0, 58.0), 27, COLOR_INK)
	_draw_text("%dm" % int(distance_m), Vector2(205.0, 55.0), 18, COLOR_MUTED)
	_draw_text("₹ %d" % coins_collected, Vector2(365.0, 31.0), 17, COLOR_GOLD)
	_draw_button(PAUSE_HITBOX, "Ⅱ", true, 18)
	if shield_active:
		_draw_text("SHIELD", Vector2(20.0, 119.0), 14, Color("#9ce9f3"))
	if multiplier_time > 0.0:
		_draw_text("2X  %.0fs" % multiplier_time, Vector2(20.0, 145.0), 14, Color("#e5b6ff"))
	_draw_text("SWIPE OR TAP TO STEER", Vector2(0.0, 931.0), 14, COLOR_INK, VIEW_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_menu() -> void:
	_draw_backdrop()
	_draw_centered_text("GULLY", Vector2(270.0, 158.0), 52, COLOR_GOLD)
	_draw_centered_text("DASH", Vector2(270.0, 217.0), 52, COLOR_INK)
	_draw_centered_text("INDIA RUSH", Vector2(270.0, 254.0), 17, Color("#9fe0b1"))
	_draw_centered_text("DODGE TRAFFIC. PICK UP PASSENGERS. KEEP RIDING.", Vector2(270.0, 299.0), 11, COLOR_MUTED)
	_draw_button(MENU_PLAY, "START RIDE", true, 24)
	_draw_button(MENU_GARAGE, "AUTO GARAGE", false, 18)
	_draw_button(MENU_MISSIONS, "CHALLENGES", false, 18)
	_draw_button(MENU_SETTINGS, "SETTINGS", false, 18)
	_draw_text("BEST  %06d" % SaveManager.best_score, Vector2(32.0, 858.0), 18, COLOR_INK)
	_draw_text("CHAI COINS  %d" % SaveManager.bank_coins, Vector2(32.0, 890.0), 17, COLOR_GOLD)


func _draw_pause_screen() -> void:
	_draw_backdrop()
	_draw_centered_text("RIDE PAUSED", Vector2(270.0, 300.0), 34, COLOR_GOLD)
	_draw_centered_text("Your run is safe. Take a breath.", Vector2(270.0, 337.0), 16, COLOR_MUTED)
	_draw_button(PAUSE_RESUME, "RESUME RIDE", true, 22)
	_draw_button(PAUSE_HOME, "MAIN MENU", false, 18)
	_draw_button(PAUSE_SETTINGS, "SETTINGS", false, 18)


func _draw_game_over() -> void:
	_draw_backdrop()
	_draw_centered_text("RIDE OVER", Vector2(270.0, 355.0), 38, COLOR_GOLD)
	_draw_centered_text("SCORE  %06d" % int(score), Vector2(270.0, 411.0), 25, COLOR_INK)
	_draw_centered_text("DISTANCE  %d m" % int(distance_m), Vector2(270.0, 447.0), 18, COLOR_MUTED)
	_draw_centered_text("COLLECTED  ₹ %d" % coins_collected, Vector2(270.0, 480.0), 18, COLOR_GOLD)
	_draw_centered_text("BEST  %06d" % SaveManager.best_score, Vector2(270.0, 510.0), 16, COLOR_INK)
	if not completed_missions_this_run.is_empty():
		_draw_centered_text("CHALLENGE REWARD EARNED!", Vector2(270.0, 529.0), 13, Color("#9fe0b1"))
	_draw_button(GAME_OVER_RETRY, "RIDE AGAIN", true, 22)
	_draw_button(GAME_OVER_HOME, "MAIN MENU", false, 18)


func _draw_garage() -> void:
	_draw_backdrop()
	_draw_centered_text("AUTO GARAGE", Vector2(270.0, 145.0), 32, COLOR_GOLD)
	_draw_centered_text("CHAI COINS  ₹ %d" % SaveManager.bank_coins, Vector2(270.0, 192.0), 17, COLOR_INK)
	_draw_skin_card(GARAGE_CLASSIC, &"classic", "CLASSIC AUTO", 0, Color("#f0b92f"), Color("#176d49"))
	_draw_skin_card(GARAGE_BLUE, &"blue", "BLUE METRO", 100, Color("#4a9ddb"), Color("#18385f"))
	_draw_skin_card(GARAGE_PINK, &"pink", "PINK PARADE", 200, Color("#f27cad"), Color("#7d285d"))
	_draw_button(CONTENT_BACK, "BACK", false, 18)


func _draw_skin_card(rect: Rect2, skin_id: StringName, title: String, price: int, body: Color, canopy: Color) -> void:
	var selected: bool = SaveManager.selected_skin == skin_id
	var unlocked: bool = SaveManager.is_skin_unlocked(skin_id)
	_draw_button(rect, "", selected, 10)
	draw_circle(Vector2(rect.position.x + 50.0, rect.position.y + 50.0), 26.0, canopy)
	draw_rect(Rect2(rect.position.x + 33.0, rect.position.y + 40.0, 34.0, 20.0), body)
	_draw_text(title, Vector2(rect.position.x + 94.0, rect.position.y + 39.0), 17, COLOR_INK)
	var suffix: String = "SELECTED" if selected else ("UNLOCKED • TAP TO SELECT" if unlocked else "UNLOCK • %d COINS" % price)
	_draw_text(suffix, Vector2(rect.position.x + 94.0, rect.position.y + 68.0), 13, COLOR_GOLD if unlocked else COLOR_MUTED)


func _draw_missions() -> void:
	_draw_backdrop()
	_draw_centered_text("CHALLENGES", Vector2(270.0, 150.0), 32, COLOR_GOLD)
	_draw_centered_text("Rewards arrive automatically when a run completes.", Vector2(270.0, 194.0), 13, COLOR_MUTED)
	var mission_ids: Array[String] = ["collect_25", "distance_1000", "play_5"]
	var mission_titles: Array[String] = ["CHAI COIN COLLECTOR", "ROAD WARRIOR", "FIVE RIDES"]
	var mission_y: Array[float] = [260.0, 382.0, 504.0]
	for index in range(mission_ids.size()):
		var progress: Dictionary = SaveManager.get_mission_progress(mission_ids[index])
		var rect := Rect2(58.0, mission_y[index], 424.0, 98.0)
		_draw_button(rect, "", bool(progress["completed"]), 8)
		_draw_text(mission_titles[index], Vector2(78.0, mission_y[index] + 31.0), 16, COLOR_INK)
		_draw_text("%d / %d" % [int(progress["progress"]), int(progress["goal"])], Vector2(78.0, mission_y[index] + 61.0), 15, COLOR_MUTED)
		_draw_text("+%d COINS" % int(progress["reward"]), Vector2(342.0, mission_y[index] + 50.0), 14, COLOR_GOLD)
		if bool(progress["completed"]):
			_draw_text("DONE", Vector2(414.0, mission_y[index] + 78.0), 11, Color("#9fe0b1"))
	_draw_button(CONTENT_BACK, "BACK", false, 18)


func _draw_settings() -> void:
	_draw_backdrop()
	_draw_centered_text("SETTINGS", Vector2(270.0, 175.0), 34, COLOR_GOLD)
	_draw_button(SETTINGS_SOUND, "SOUND  •  %s" % _on_off(SettingsManager.sound_enabled), SettingsManager.sound_enabled, 17)
	_draw_button(SETTINGS_HAPTICS, "VIBRATION  •  %s" % _on_off(SettingsManager.haptics_enabled), SettingsManager.haptics_enabled, 17)
	_draw_button(SETTINGS_MOTION, "REDUCED MOTION  •  %s" % _on_off(SettingsManager.reduced_motion), SettingsManager.reduced_motion, 17)
	_draw_centered_text("Preferences are saved on this device.", Vector2(270.0, 640.0), 14, COLOR_MUTED)
	_draw_button(CONTENT_BACK, "BACK", false, 18)


func _draw_exit_confirm() -> void:
	_draw_backdrop()
	_draw_centered_text("END THIS RIDE?", Vector2(270.0, 370.0), 34, COLOR_GOLD)
	_draw_centered_text("Your saved coins and records will stay on this device.", Vector2(270.0, 410.0), 13, COLOR_MUTED)
	_draw_button(EXIT_STAY, "KEEP PLAYING", true, 20)
	_draw_button(EXIT_QUIT, "EXIT GAME", false, 20)


func _on_off(enabled: bool) -> String:
	return "ON" if enabled else "OFF"


func _draw_status_message() -> void:
	var alpha: float = clampf(status_time / 0.25, 0.0, 1.0)
	var baseline: float = 235.0 if run_state in [&"garage", &"missions", &"settings"] else 202.0
	var rect := Rect2(55.0, baseline - 34.0, 430.0, 52.0)
	draw_rect(rect, Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, alpha * 0.94))
	_draw_centered_text(status_message, Vector2(270.0, baseline), 15, Color(1.0, 1.0, 1.0, alpha))


func _draw_backdrop() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.02, 0.045, 0.04, 0.72))
	draw_rect(Rect2(18.0, 28.0, VIEW_SIZE.x - 36.0, VIEW_SIZE.y - 56.0), Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.90))
	draw_rect(Rect2(18.0, 28.0, VIEW_SIZE.x - 36.0, VIEW_SIZE.y - 56.0), Color("#52745c"), false, 2.0)


func _draw_button(rect: Rect2, label: String, primary: bool, font_size: int) -> void:
	var fill: Color = COLOR_GREEN if primary else Color("#23352f")
	var border: Color = Color("#8fd6a5") if primary else Color("#526e60")
	draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.24))
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2.0)
	if not label.is_empty():
		_draw_centered_text(label, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + float(font_size) * 0.34), font_size, COLOR_INK)


func _draw_text(text: String, baseline: Vector2, font_size: int, color: Color, width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, baseline, text, alignment, width, font_size, color)


func _draw_centered_text(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2(baseline.x - text_width * 0.5, baseline.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_text_at(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, text_size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
