extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

const EXPECTED_IDS := [&"worker", &"terminal", &"server", &"factory", &"data_center"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var content_db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if content_db == null or game == null:
		errors.append("Required Stage 2 autoload is unavailable")
	else:
		_validate_content(errors, content_db)
		_validate_gameplay(errors, game)
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_content(errors: PackedStringArray, content_db: Node) -> void:
	var definitions: Array = content_db.get_generators()
	if definitions.size() != EXPECTED_IDS.size():
		errors.append("Expected %d generators, got %d" % [EXPECTED_IDS.size(), definitions.size()])
	for index in range(EXPECTED_IDS.size()):
		var generator_id: StringName = EXPECTED_IDS[index]
		if not content_db.has_generator(generator_id):
			errors.append("Missing generator: %s" % generator_id)
			continue
		if index < definitions.size() and definitions[index].id != generator_id:
			errors.append("Generator order is not deterministic at index %d" % index)
	if not content_db.get_generator_validation_errors().is_empty():
		errors.append("Valid generator content reported errors: " + ", ".join(content_db.get_generator_validation_errors()))

	var worker := content_db.get_generator(&"worker") as GeneratorDefinition
	if worker == null or worker.base_cost != 10.0 or worker.base_production != 1.0 or abs(worker.cost_scaling - 1.15) > 0.0001:
		errors.append("Worker definition does not match Stage 2 data")
	var terminal := content_db.get_generator(&"terminal") as GeneratorDefinition
	if terminal == null or terminal.base_cost != 60.0 or terminal.base_production != 6.0 or abs(terminal.production_growth - 1.04) > 0.0001:
		errors.append("Terminal definition does not match current balanced data")
	if terminal == null or terminal.unlock_after_generator_id != &"worker" or terminal.unlock_after_generator_count != 1:
		errors.append("Terminal unlock data does not match Stage 2.5 progression")

	var invalid := GeneratorDefinition.new()
	invalid.id = &"invalid"
	invalid.display_name = "INVALID"
	invalid.base_cost = -1.0
	invalid.base_production = -1.0
	invalid.cost_scaling = 0.5
	if content_db.validate_generator_definition(invalid).is_empty():
		errors.append("Invalid generator definition was accepted")
	var invalid_prerequisite := GeneratorDefinition.new()
	invalid_prerequisite.id = &"invalid_prerequisite"
	invalid_prerequisite.display_name = "INVALID PREREQUISITE"
	invalid_prerequisite.unlock_after_generator_id = &"does_not_exist"
	invalid_prerequisite.unlock_after_generator_count = 1
	if content_db.validate_generator_unlock_reference(invalid_prerequisite).is_empty():
		errors.append("Invalid prerequisite id was accepted without a useful error")


func _validate_gameplay(errors: PackedStringArray, game: Node) -> void:
	game.set_state({"bits": 0.0, "generator_counts": {}})
	for generator_id in EXPECTED_IDS:
		if game.get_generator_count(generator_id) != 0:
			errors.append("Starting count for %s is not zero" % generator_id)
	if not game.is_generator_unlocked(&"worker"):
		errors.append("Worker should be unlocked at start")
	for locked_id in [&"terminal", &"server", &"factory", &"data_center"]:
		if game.is_generator_unlocked(locked_id):
			errors.append("%s should be locked at start" % locked_id)

	game.debug_add_currency(10.0)
	if not game.buy_generator(&"worker") or game.get_generator_count(&"worker") != 1:
		errors.append("Generic Worker purchase failed")
	if not game.is_generator_unlocked(&"terminal") or game.is_generator_unlocked(&"server"):
		errors.append("Worker purchase did not unlock only Terminal")
	if abs(game.get_generator_cost(&"worker") - 12.0) > 0.0001:
		errors.append("Second Worker cost should use ceil(10 * 1.15) = 12")

	game.debug_add_currency(60.0)
	if not game.buy_generator(&"terminal"):
		errors.append("Generic Terminal purchase failed")
	if not game.is_generator_unlocked(&"server"):
		errors.append("Terminal purchase did not unlock Server")
	if game.get_generator_count(&"worker") != 1 or game.get_generator_count(&"terminal") != 1:
		errors.append("Generator counts are not independent")
	if abs(game.get_total_production_per_second() - 7.0) > 0.0001:
		errors.append("Worker plus Terminal production should be 7/sec")
	var before: float = game.get_currency()
	game.update_production(5.0)
	if abs((game.get_currency() - before) - 35.0) > 0.01:
		errors.append("Five seconds at 7/sec should produce 35 Bits")

	game.debug_add_currency(600.0)
	if not game.buy_generator(&"server") or not game.is_generator_unlocked(&"factory"):
		errors.append("Server purchase did not unlock Factory")
	game.debug_add_currency(7200.0)
	if not game.buy_generator(&"factory") or not game.is_generator_unlocked(&"data_center"):
		errors.append("Factory purchase did not unlock Data Center")

	var currency_before_invalid: float = game.get_currency()
	if game.buy_generator(&"does_not_exist") or game.get_generator_cost(&"does_not_exist") >= 0.0:
		errors.append("Invalid generator id did not fail safely")
	if not is_equal_approx(game.get_currency(), currency_before_invalid):
		errors.append("Invalid generator purchase changed currency")

	game.set_state({"bits": 0.0, "generator_counts": {}})
	if game.buy_generator(&"terminal"):
		errors.append("Insufficient-funds generator purchase succeeded")
	if game.get_currency() < 0.0:
		errors.append("Currency became negative")
