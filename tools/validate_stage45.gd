extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const NORMAL_UI_SCENE := preload("res://ui/main/NormalUI.tscn")
const IDS := [&"worker", &"terminal", &"server", &"factory", &"data_center"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var content := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	if game == null or content == null:
		errors.append("Required economy autoload unavailable")
	else:
		_validate_definition_math(errors, game, content)
		_validate_bulk_purchases(errors, game)
		await _validate_shop_ui(errors, game)
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_definition_math(errors: PackedStringArray, game: Node, content: Node) -> void:
	for generator_id in IDS:
		var definition := content.get_generator(generator_id) as GeneratorDefinition
		if definition == null or definition.cost_scaling <= 1.0 or definition.production_growth < 1.0 or definition.base_production <= 0.0:
			errors.append("Balance data invalid for %s" % generator_id)
			continue
		for count in [1, 2, 10, 100]:
			game.apply_save_data({"bits": 0.0, "generator_counts": {str(generator_id): count}})
			var expected_total := definition.base_production * (pow(definition.production_growth, count) - 1.0) / (definition.production_growth - 1.0)
			var expected_next := definition.base_production * pow(definition.production_growth, count)
			if abs(game.get_generator_production(generator_id) - expected_total) > 0.001 or abs(game.get_next_generator_production(generator_id) - expected_next) > 0.001:
				errors.append("Geometric production mismatch for %s x%d" % [generator_id, count])
		game.apply_save_data({"bits": 0.0, "generator_counts": {}})
		if game.get_generator_cost(generator_id) != definition.base_cost:
			errors.append("Initial cost mismatch for %s" % generator_id)


func _validate_bulk_purchases(errors: PackedStringArray, game: Node) -> void:
	# A-D: exact cost, count, output, and safe failure.
	game.apply_save_data({"bits": 100000.0, "generator_counts": {}})
	var expected_cost := 0.0
	for index in range(10):
		expected_cost += ceil(10.0 * pow(1.15, index))
	if game.get_generator_bulk_cost(&"worker", 10) != expected_cost:
		errors.append("A: BUY 10 cost is not exact")
	var before: float = game.get_currency()
	if game.buy_generators(&"worker", 10) != 10 or game.get_generator_count(&"worker") != 10 or abs(game.get_currency() - (before - expected_cost)) > 0.001:
		errors.append("A/B: BUY 10 did not match displayed deduction/count")
	var expected_production := (pow(1.04, 10) - 1.0) / 0.04
	if abs(game.get_generator_production(&"worker") - expected_production) > 0.001:
		errors.append("C: geometric bulk production is wrong")
	game.apply_save_data({"bits": 9.0, "generator_counts": {}})
	if game.buy_generators(&"worker", 1) != 0 or game.get_currency() != 9.0:
		errors.append("D: unaffordable buy was unsafe")
	game.apply_save_data({"bits": 10.0, "generator_counts": {}})
	if game.buy_generators(&"worker", 1) != 1 or game.get_currency() != 0.0:
		errors.append("E: exact-funds purchase failed")
	# F-H: MAX equals a sequential equivalent and cannot go negative.
	game.apply_save_data({"bits": 10000.0, "generator_counts": {}})
	var max_count: int = game.get_max_affordable_generator_count(&"worker")
	var max_cost: float = game.get_generator_bulk_cost(&"worker", max_count)
	if game.buy_generators(&"worker", max_count) != max_count or game.get_currency() < 0.0:
		errors.append("F/G: MAX was unsafe or inaccurate")
	game.apply_save_data({"bits": max_cost, "generator_counts": {}})
	for _index in range(max_count):
		if not game.buy_generator(&"worker"):
			errors.append("H: sequential comparison failed")
			break
	if game.get_generator_count(&"worker") != max_count or abs(game.get_currency()) > 0.001:
		errors.append("H: bulk differs from sequential purchases")
	# I: a huge finite balance must return promptly and safely.
	game.apply_save_data({"bits": 1.0e100, "generator_counts": {}})
	var started := Time.get_ticks_msec()
	var huge_count: int = game.get_max_affordable_generator_count(&"worker")
	if huge_count < 1 or Time.get_ticks_msec() - started > 1000:
		errors.append("I: MAX performance regressed")


func _validate_shop_ui(errors: PackedStringArray, game: Node) -> void:
	game.apply_save_data({"bits": 100000.0, "generator_counts": {"worker": 1}})
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var ui := NORMAL_UI_SCENE.instantiate() as Control
	host.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	var row := ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/worker") as Control
	if row == null or row.custom_minimum_size.y > 110.0:
		errors.append("Shop row is missing or not compact")
	else:
		var buy_10 := row.get_node_or_null("Margin/VBox/PurchaseRow/Buy10Button") as Button
		var max_button := row.get_node_or_null("Margin/VBox/PurchaseRow/MaxButton") as Button
		var cost := row.get_node_or_null("Margin/VBox/PurchaseRow/CostValueLabel") as Label
		if buy_10 == null or max_button == null or cost == null or not cost.text.contains("10:"):
			errors.append("Shop bulk controls or exact cost presentation are missing")
		else:
			var before_count: int = game.get_generator_count(&"worker")
			buy_10.emit_signal("pressed")
			if game.get_generator_count(&"worker") != before_count + 10:
				errors.append("Shop BUY 10 did not execute one exact bulk purchase")
	host.queue_free()
