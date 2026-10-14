extends Node
## Verifies persistence across manager instances and corrupt-primary recovery.

var failures: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var baseline_runs: int = SaveManager.lifetime_runs
	SaveManager.record_run(987654, 2, 123, 1)
	SaveManager.record_run(10, 1, 2, 0)

	var expected_best: int = SaveManager.best_score
	var expected_coins: int = SaveManager.bank_coins
	var expected_runs: int = SaveManager.lifetime_runs
	_check(expected_runs >= baseline_runs + 2, "completed runs increment lifetime count")

	var manager_script := load("res://scripts/save_manager.gd") as Script
	var reloaded: Variant = manager_script.new()
	get_tree().root.add_child(reloaded)
	await get_tree().process_frame
	_check(reloaded.best_score == expected_best, "best score survives manager reload")
	_check(reloaded.bank_coins == expected_coins, "coin wallet survives manager reload")
	_check(reloaded.lifetime_runs == expected_runs, "run count survives manager reload")
	reloaded.queue_free()
	await get_tree().process_frame

	# Two successful writes create a backup. Corrupt only the primary; another
	# manager must recover from the previous known-good file.
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "primary save file can be opened for recovery test")
	if file != null:
		file.store_string("not a valid ConfigFile\n[broken")
		file.close()

	var recovery_manager: Variant = manager_script.new()
	get_tree().root.add_child(recovery_manager)
	await get_tree().process_frame
	_check(recovery_manager.best_score == expected_best, "corrupt primary recovers best score from backup")
	_check(recovery_manager.bank_coins >= 0, "recovered wallet is non-negative")
	recovery_manager.queue_free()
	await get_tree().process_frame
	SaveManager._save_data()

	if failures == 0:
		print("SAVE_MANAGER_TESTS: PASS")
		_finish()
	else:
		push_error("SAVE_MANAGER_TESTS: %d failure(s)" % failures)
		_finish(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
