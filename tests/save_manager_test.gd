extends SceneTree
## Verifies persisted state reloads and corrupt primary files recover from backup.
## This test writes only to the isolated Godot user:// save area of the test runner.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var baseline_runs: int = SaveManager.lifetime_runs
	SaveManager.record_run(987654, 2, 123, 1)
	SaveManager.record_run(10, 1, 2, 0)

	var expected_best: int = SaveManager.best_score
	var expected_coins: int = SaveManager.bank_coins
	var expected_runs: int = SaveManager.lifetime_runs
	_check(expected_runs >= baseline_runs + 2, "completed runs increment lifetime count")

	var script := load("res://scripts/save_manager.gd") as Script
	var reloaded := script.new()
	root.add_child(reloaded)
	await process_frame
	_check(reloaded.best_score == expected_best, "best score survives creating a fresh save manager")
	_check(reloaded.bank_coins == expected_coins, "coin wallet survives reload")
	_check(reloaded.lifetime_runs == expected_runs, "run count survives reload")
	reloaded.queue_free()
	await process_frame

	# Two successful writes create a known-good backup. Corrupt only the primary
	# file, then construct a fresh manager and verify it reads the backup.
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "primary save file can be opened for recovery test")
	if file != null:
		file.store_string("not a valid ConfigFile\n[broken")
		file.close()

	var recovery_manager := script.new()
	root.add_child(recovery_manager)
	await process_frame
	_check(recovery_manager.best_score == expected_best, "corrupt primary recovers the best score from backup")
	_check(recovery_manager.bank_coins >= 0, "recovered wallet remains non-negative")
	recovery_manager.queue_free()

	# Restore a valid primary for any subsequent tests running in this process.
	SaveManager._save_data()

	if failures == 0:
		print("SAVE_MANAGER_TESTS: PASS")
		quit(0)
	else:
		push_error("SAVE_MANAGER_TESTS: %d failure(s)" % failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
