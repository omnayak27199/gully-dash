extends Node
## Integration smoke test for menu -> run -> pause/resume -> game-over/save.

var failures: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Keep integration tests from contaminating a developer's real local save.
	SaveManager.set_storage_paths(
		"user://gully_dash_game_test.cfg",
		"user://gully_dash_game_test.tmp",
		"user://gully_dash_game_test.bak",
		true
	)
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "main scene loads")
	if packed_scene == null:
		_finish()
		return

	var game: Variant = packed_scene.instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(game.run_state == &"menu", "game starts at main menu")
	_check(game.player != null, "main scene contains modular player controller")

	game._handle_tap(Vector2(270.0, 395.0))
	_check(game.run_state == &"playing", "start button enters gameplay")
	_check(game.player.visible, "player is visible during a run")
	_check(game.player._controls_enabled, "steering enabled during a run")

	game.score = 0.0
	game.coins_collected = 0
	game.powerups_used = 0
	game._collect_item(&"coin")
	_check(game.coins_collected == 1, "coin pickup increments run coins")
	_check(is_equal_approx(game.score, 25.0), "coin pickup adds score")
	game.multiplier_time = 5.0
	game._collect_item(&"coin")
	_check(game.coins_collected == 3, "active multiplier doubles coin value")
	_check(is_equal_approx(game.score, 75.0), "active multiplier doubles coin score")
	game._collect_item(&"passenger")
	_check(game.multiplier_time >= 7.0, "passenger starts score multiplier")
	game._collect_item(&"shield")
	_check(game.shield_active, "shield pickup activates one-hit protection")
	game.obstacles.append({"lane": 1, "x": 270.0, "y": 790.0, "kind": "car"})
	game._update_obstacles(0.016, 0.0)
	_check(not game.shield_active, "shield absorbs one colliding vehicle")
	_check(game.run_state == &"playing", "shield prevents immediate game over")
	game._collect_item(&"multiplier")
	_check(game.multiplier_time >= 9.0, "multiplier power-up extends the bonus window")
	_check(game.powerups_used == 3, "passenger and power-ups count as run pickups")

	game._handle_back_request()
	_check(game.run_state == &"paused", "back request pauses active run")
	_check(not game.player._controls_enabled, "pause disables steering")

	game._resume_run()
	_check(game.run_state == &"playing", "resume returns to active gameplay")
	_check(game.player._controls_enabled, "resume enables steering")

	var runs_before: int = SaveManager.lifetime_runs
	game.score = 123.0
	game.distance_m = 50.0
	game.coins_collected = 3
	game._end_run()
	_check(game.run_state == &"game_over", "end-run transition shows game over")
	_check(not game.player.visible, "player is hidden on game over")
	_check(SaveManager.lifetime_runs == runs_before + 1, "game-over persists exactly one completed run")

	var runs_after_end: int = SaveManager.lifetime_runs
	game._end_run()
	_check(SaveManager.lifetime_runs == runs_after_end, "repeated end-run cannot duplicate rewards")

	game._handle_tap(Vector2(250.0, 590.0))
	_check(game.run_state == &"playing", "ride-again button restarts the run")
	_check(game.coins_collected == 0, "new run starts with a clean run-coin counter")

	game._handle_back_request()
	_check(game.run_state == &"paused", "back pauses restarted run")
	game._handle_back_request()
	_check(game.run_state == &"menu", "back from pause returns to main menu")
	game._handle_back_request()
	_check(game.run_state == &"exit_confirm", "back from menu requests exit confirmation")
	game._handle_tap(Vector2(260.0, 500.0))
	_check(game.run_state == &"menu", "stay button cancels exit")

	game.queue_free()
	await get_tree().process_frame
	_remove_test_saves()
	if failures == 0:
		print("GAME_SMOKE_TESTS: PASS")
		_finish()
	else:
		push_error("GAME_SMOKE_TESTS: %d failure(s)" % failures)
		_finish(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _remove_test_saves() -> void:
	for path in [
		"user://gully_dash_game_test.cfg",
		"user://gully_dash_game_test.tmp",
		"user://gully_dash_game_test.bak"
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
