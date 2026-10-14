extends SceneTree
## Integration smoke tests for menu -> run -> pause/resume -> game-over/save.
## Run after an editor import: godot --headless --path . --script res://tests/game_smoke_test.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "main scene loads")
	if packed_scene == null:
		quit(1)
		return

	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_check(game.run_state == &"menu", "game starts at main menu")
	_check(game.player != null, "main scene contains modular player controller")

	game._handle_tap(Vector2(270.0, 395.0))
	_check(game.run_state == &"playing", "start button enters gameplay")
	_check(game.player.visible, "player is visible during a run")
	_check(game.player._controls_enabled, "steering enabled during a run")

	game._handle_back_request()
	_check(game.run_state == &"paused", "back request pauses an active run")
	_check(not game.player._controls_enabled, "pause disables steering")

	game._resume_run()
	_check(game.run_state == &"playing", "resume returns to active gameplay")
	_check(game.player._controls_enabled, "resume enables steering")

	var runs_before: int = SaveManager.lifetime_runs
	game.score = 123.0
	game.distance_m = 50.0
	game.coins_collected = 3
	game._end_run()
	_check(game.run_state == &"game_over", "collision/end-run transition shows game over")
	_check(not game.player.visible, "player is hidden on game over")
	_check(SaveManager.lifetime_runs == runs_before + 1, "game over persists exactly one completed run")

	var runs_after_end: int = SaveManager.lifetime_runs
	game._end_run()
	_check(SaveManager.lifetime_runs == runs_after_end, "repeated end-run call cannot duplicate rewards")

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

	if failures == 0:
		print("GAME_SMOKE_TESTS: PASS")
		quit(0)
	else:
		push_error("GAME_SMOKE_TESTS: %d failure(s)" % failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
