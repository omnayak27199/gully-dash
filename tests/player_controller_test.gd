extends SceneTree
## Lightweight, dependency-free smoke tests for PlayerController.
## Run after editor import: godot --headless --path . --script res://tests/player_controller_test.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene := load("res://scenes/player_auto.tscn") as PackedScene
	_check(packed_scene != null, "player scene loads")
	if packed_scene == null:
		quit(1)
		return

	var player := packed_scene.instantiate() as PlayerController
	_check(player != null, "player scene has PlayerController")
	if player == null:
		quit(1)
		return

	root.add_child(player)
	await process_frame

	_check(player.current_lane == 1, "player starts in center lane")
	_check(player.position.is_equal_approx(Vector2(270.0, 790.0)), "player starts at expected position")

	var lane_events: Array[Vector2i] = []
	player.lane_changed.connect(func(previous_lane: int, current_lane: int) -> void:
		lane_events.append(Vector2i(previous_lane, current_lane))
	)

	_check(player.change_lane(-1), "left lane request succeeds from center")
	_check(player.current_lane == 0, "left lane request selects lane zero")
	_check(not player.change_lane(-1), "left edge blocks an extra lane change")
	_check(player.change_lane(1), "right lane request moves from left lane")
	_check(player.change_lane(1), "second right lane request reaches right edge")
	_check(not player.change_lane(1), "right edge blocks an extra lane change")
	_check(lane_events.size() == 3, "lane change signal only fires on successful changes")

	player.set_controls_enabled(false)
	_check(not player.change_lane(-1), "disabled controls reject lane requests")
	_check(player.current_lane == 2, "disabled controls preserve the current lane")

	player.reset_player()
	_check(player.current_lane == 1, "reset returns player to center lane")
	_check(player.position.is_equal_approx(Vector2(270.0, 790.0)), "reset restores player position")
	_check(is_zero_approx(player.rotation), "reset clears steering rotation")
	_check(player.visible, "reset shows player again")
	_check(player.get_hitbox_rect().size.is_equal_approx(Vector2(42.0, 62.0)), "hitbox dimensions match the tuned collider")

	if failures == 0:
		print("PLAYER_CONTROLLER_TESTS: PASS")
		quit(0)
	else:
		push_error("PLAYER_CONTROLLER_TESTS: %d failure(s)" % failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
