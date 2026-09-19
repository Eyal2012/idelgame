extends Node

## Stage 1 validation script.
## Programmatically tests the basic idle loop math without UI interaction.
## Prints VALIDATION_RESULT:OK and quits.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	var result = validate()
	print("VALIDATION_RESULT:", result)
	get_tree().quit()


func validate() -> String:
	var errors := []
	var game = _get_game()
	if game == null:
		return "ERRORS: Game autoload not found"

	# --- A. Starting state ---
	if abs(game.get_currency() - 0.0) > 0.0001:
		errors.append("A: starting bits should be 0, got %s" % game.get_currency())
	if game.get_worker_count() != 0:
		errors.append("A: starting worker count should be 0, got %s" % game.get_worker_count())
	if abs(game.get_production_per_second() - 0.0) > 0.0001:
		errors.append("A: starting production should be 0, got %s" % game.get_production_per_second())

	# --- B. Clicking GENERATE once ---
	var before = game.get_currency()
	game.generate_manual()
	if abs(game.get_currency() - (before + 1.0)) > 0.0001:
		errors.append("B: one click should add 1 Bit, got %s" % game.get_currency())

	# --- C. Clicking 10 times ---
	for _i in range(10):
		game.generate_manual()
	if abs(game.get_currency() - 11.0) > 0.0001:
		errors.append("C: 11 clicks should give 11 Bits, got %s" % game.get_currency())

	# --- D. Buying first Worker ---
	var cost_before = game.get_worker_cost()
	if abs(cost_before - 10.0) > 0.0001:
		errors.append("D: first worker cost should be 10, got %s" % cost_before)

	var buy_ok = game.buy_worker()
	if not buy_ok:
		errors.append("D: first worker purchase should succeed")
	if game.get_worker_count() != 1:
		errors.append("D: worker count should be 1, got %s" % game.get_worker_count())
	if abs(game.get_currency() - 1.0) > 0.0001:
		errors.append("D: bits should be 1 after buying a 10-Bit worker from 11, got %s" % game.get_currency())
	if abs(game.get_production_per_second() - 1.0) > 0.0001:
		errors.append("D: production should be 1/sec with 1 worker, got %s" % game.get_production_per_second())

	# --- E. Next Worker price (1.15 scaling) ---
	var expected_second_cost = 10.0 * pow(1.15, 1)
	var actual_second_cost = game.get_worker_cost()
	if abs(actual_second_cost - expected_second_cost) > 0.01:
		errors.append("E: second worker cost should be ~%s, got %s" % [expected_second_cost, actual_second_cost])

	# --- F. Insufficient funds ---
	var bits_before_fail = game.get_currency()
	var fail_ok = game.buy_worker()
	if fail_ok:
		errors.append("F: purchase with insufficient funds should fail")
	if abs(game.get_currency() - bits_before_fail) > 0.0001:
		errors.append("F: currency should not change on failed purchase, was %s now %s" % [bits_before_fail, game.get_currency()])
	if game.get_worker_count() != 1:
		errors.append("F: worker count should still be 1 after failed purchase, got %s" % game.get_worker_count())

	# --- G. Production uses delta (frame-rate independence) ---
	var prod = game.get_production_per_second()
	if abs(prod - 1.0) > 0.0001:
		errors.append("G: production should be 1/sec, got %s" % prod)
	# Manually tick production with a fake delta.
	for _i in range(500):
		game.update_production(0.01)
	# 500 * 0.01 = 5.0 seconds of production at 1/sec = +5 Bits.
	var expected_after_prod = 1.0 + 5.0
	if abs(game.get_currency() - expected_after_prod) > 0.01:
		errors.append("G: after 5s of production bits should be ~%s, got %s" % [expected_after_prod, game.get_currency()])

	# --- H. can_afford guard ---
	if not game.can_afford(0.0):
		errors.append("H: can_afford(0) should be true")
	if game.can_afford(999999.0):
		errors.append("H: can_afford(999999) should be false with low bits")

	# --- I. spend_currency ---
	if not game.spend_currency(2.0):
		errors.append("I: spend_currency(2) should succeed with enough bits")
	if abs(game.get_currency() - (expected_after_prod - 2.0)) > 0.01:
		errors.append("I: spend_currency did not subtract correctly")
	if game.spend_currency(999999.0):
		errors.append("I: spend_currency(999999) should fail with insufficient bits")

	if errors.is_empty():
		return "OK"
	return "ERRORS: " + ", ".join(errors)


func _get_game() -> Node:
	var root = get_tree().root
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		var n = child.name
		if n.begins_with("*"):
			n = n.substr(1)
		if n == "game":
			return child
	return null