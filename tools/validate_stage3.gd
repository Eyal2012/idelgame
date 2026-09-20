extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const PRIMARY := "user://stage3_validator_save.json"
const BACKUP := "user://stage3_validator_backup.json"
const TEMP := "user://stage3_validator.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var saves := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"save_manager")
	if game == null or saves == null:
		errors.append("Required autoload unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		_validate(errors, game, saves)
		saves.reset_save()
		saves.restore_default_paths()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate(errors: PackedStringArray, game: Node, saves: Node) -> void:
	# A fresh state, then B-I basic generic persistence and schema.
	if saves.load_game() or game.get_currency() != 0.0:
		errors.append("A: missing save did not produce fresh state")
	game.apply_save_data({"bits": 321.0, "generator_counts": {"worker": 3, "terminal": 2}})
	if not saves.save():
		errors.append("B: isolated save failed")
	var raw := _read(PRIMARY)
	if int(raw.get("save_version", 0)) != saves.SAVE_VERSION:
		errors.append("G: save version missing or wrong")
	if int(raw.get("saved_at_unix", 0)) <= 0:
		errors.append("H: timestamp missing or invalid")
	game.reset_save_data()
	saves.load_game()
	if abs(game.get_currency() - 321.0) > 0.1:
		errors.append("C: Bits did not load")
	if game.get_generator_count(&"worker") != 3:
		errors.append("D: Worker count did not load")
	if game.get_generator_count(&"terminal") != 2:
		errors.append("E/F: generator counts did not restore independently")
	if game.get_total_production_per_second() <= 0.0 or game.get_generator_cost(&"worker") <= 0.0:
		errors.append("I: gameplay APIs failed after load")
	# J/K offline formula uses live Game production, never a duplicate formula.
	_write(PRIMARY, _data(0.0, {"worker": 1}, _now() - 5))
	saves.load_game()
	if abs(saves.last_offline_earnings - 5.0) > 1.1:
		errors.append("J: Worker offline reward was not approximately 5")
	_write(PRIMARY, _data(0.0, {"worker": 1, "terminal": 1}, _now() - 5))
	saves.load_game()
	if abs(saves.last_offline_earnings - 45.0) > 9.1:
		errors.append("K: mixed offline reward was not approximately 45")
	_write(PRIMARY, _data(0.0, {"worker": 1}, _now() - saves.MAX_OFFLINE_SECONDS - 99))
	saves.load_game()
	if saves.last_offline_seconds != saves.MAX_OFFLINE_SECONDS:
		errors.append("L: offline cap failed")
	_write(PRIMARY, _data(0.0, {"worker": 1}, _now() + 60))
	saves.load_game()
	if saves.last_offline_seconds != 0 or saves.last_offline_earnings != 0.0:
		errors.append("M: negative elapsed time was rewarded")
	# N/O recovery and P-S sanitation.
	_write(BACKUP, _data(77.0, {"worker": 2}, _now()))
	_write_text(PRIMARY, "not json")
	saves.load_game()
	if abs(game.get_currency() - 77.0) > 0.1:
		errors.append("N: valid backup did not recover")
	_write_text(BACKUP, "also broken")
	saves.load_game()
	if game.get_currency() != 0.0:
		errors.append("O: double corruption did not safely reset")
	_write(PRIMARY, _data(-4.0, {"worker": -2, "unknown": 99}, _now()))
	saves.load_game()
	if game.get_generator_count(&"terminal") != 0:
		errors.append("P: missing generator did not default to zero")
	if game.get_generator_count(&"unknown") != 0:
		errors.append("Q: unknown generator was retained")
	if game.get_generator_count(&"worker") != 0:
		errors.append("R: negative generator count was not sanitized")
	if game.get_currency() != 0.0:
		errors.append("S: invalid currency was not sanitized")
	# T: after the reward is saved, immediate reload must not award that interval again.
	_write(PRIMARY, _data(0.0, {"worker": 1}, _now() - 5))
	saves.load_game()
	var first_reward: float = saves.last_offline_earnings
	saves.save()
	saves.load_game()
	if first_reward < 4.0 or saves.last_offline_earnings > 1.1:
		errors.append("T: offline reward duplicated on second load")


func _data(bits: float, counts: Dictionary, timestamp: int) -> Dictionary:
	return {"save_version": 1, "saved_at_unix": timestamp, "game": {"bits": bits, "generator_counts": counts}}


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _write(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data))


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}
