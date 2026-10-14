extends Node
## Verifies persistence and corrupt-primary recovery in isolated test files.

var failures: int = 0
const TEST_SAVE := "user://gully_dash_save_test.cfg"
const TEST_TEMP := "user://gully_dash_save_test.tmp"
const TEST_BACKUP := "user://gully_dash_save_test.bak"


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var manager_script := load("res://scripts/save_manager.gd") as Script
	var manager: Variant = manager_script.new()
	manager.set_storage_paths(TEST_SAVE, TEST_TEMP, TEST_BACKUP)
	get_tree().root.add_child(manager)
	await get_tree().process_frame

	_check(manager.lifetime_runs == 0, "test store starts empty")
	manager.record_run(987654, 2, 123, 1)
	manager.record_run(10, 1, 2, 0)

	var expected_best: int = manager.best_score
	var expected_coins: int = manager.bank_coins
	var expected_runs: int = manager.lifetime_runs
	_check(expected_runs == 2, "completed runs increment lifetime count")
	_check(expected_best == 987654, "best score stores the maximum")

	var reloaded: Variant = manager_script.new()
	reloaded.set_storage_paths(TEST_SAVE, TEST_TEMP, TEST_BACKUP)
	get_tree().root.add_child(reloaded)
	await get_tree().process_frame
	_check(reloaded.best_score == expected_best, "best score survives manager reload")
	_check(reloaded.bank_coins == expected_coins, "coin wallet survives reload")
	_check(reloaded.lifetime_runs == expected_runs, "run count survives reload")

	# A second successful write guarantees a previous good file exists. Corrupt
	# only the primary; a new instance should load the preserved backup.
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	_check(file != null, "test save file can be opened for recovery test")
	if file != null:
		file.store_string("not a valid ConfigFile\n[broken")
		file.close()

	var recovery_manager: Variant = manager_script.new()
	recovery_manager.set_storage_paths(TEST_SAVE, TEST_TEMP, TEST_BACKUP)
	get_tree().root.add_child(recovery_manager)
	await get_tree().process_frame
	_check(recovery_manager.best_score == expected_best, "corrupt primary recovers best score from backup")
	_check(recovery_manager.lifetime_runs >= 1, "recovered save contains committed progress")

	manager.queue_free()
	reloaded.queue_free()
	recovery_manager._save_data()
	recovery_manager.queue_free()
	await get_tree().process_frame
	_remove_test_saves()

	if failures == 0:
		print("SAVE_MANAGER_TESTS: PASS")
		_finish()
	else:
		push_error("SAVE_MANAGER_TESTS: %d failure(s)" % failures)
		_finish(1)


func _remove_test_saves() -> void:
	for path in [TEST_SAVE, TEST_TEMP, TEST_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
