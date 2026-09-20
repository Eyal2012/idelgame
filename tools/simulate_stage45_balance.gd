extends SceneTree

## Development-only deterministic economy sketch. It never touches Game/save data.
const IDS := [&"worker", &"terminal", &"server", &"factory", &"data_center"]
const MANUAL_INCOME_PER_SECOND := 0.5
## Calibration only: this does not alter gameplay or prescribe a player CPS.
const MANUAL_GROWTH_CANDIDATES := [1.06, 1.07, 1.08, 1.09, 1.10]
const MANUAL_WORKER_COUNTS := [0, 1, 5, 10, 25, 50]


func _init() -> void:
	var definitions: Dictionary = {}
	for generator_id in IDS:
		definitions[generator_id] = load("res://resources/generators/%s.tres" % generator_id) as GeneratorDefinition
	var counts := {}
	for generator_id in IDS:
		counts[generator_id] = 0
	var bits := 0.0
	var time := 0.0
	var milestones := {}
	var last_purchase_time := 0.0
	var longest_gap := 0.0
	while time < 3600.0 and not milestones.has(&"data_center"):
		var bought := _buy_best_affordable(bits, counts, definitions)
		if not bought.is_empty():
			var definition: GeneratorDefinition = definitions[bought]
			var cost := _next_cost(definition, counts[bought] - 1)
			bits -= cost
			if not milestones.has(bought):
				milestones[bought] = time
			longest_gap = maxf(longest_gap, time - last_purchase_time)
			last_purchase_time = time
		else:
			var production := _total_production(counts, definitions)
			bits += (production + (MANUAL_INCOME_PER_SECOND if counts[&"terminal"] == 0 else 0.0)) * 0.25
			time += 0.25
	print("BALANCE_SIMULATION")
	for generator_id in IDS:
		print("first_%s=%.1fs" % [generator_id, float(milestones.get(generator_id, -1.0))])
	print("longest_no_purchase_gap=%.1fs" % longest_gap)
	print("end_time=%.1fs bits=%s" % [time, bits])
	print("MANUAL_POWER_CANDIDATES // BITS_PER_CLICK")
	for growth in MANUAL_GROWTH_CANDIDATES:
		var values: PackedStringArray = []
		for count in MANUAL_WORKER_COUNTS:
			values.append("%d=%.2f" % [count, pow(growth, count)])
		print("growth=%.2f %s" % [growth, ", ".join(values)])
	quit()


func _buy_best_affordable(bits: float, counts: Dictionary, definitions: Dictionary) -> StringName:
	var best_id: StringName = &""
	var best_payback := INF
	for generator_id in IDS:
		var definition: GeneratorDefinition = definitions[generator_id]
		if not _is_unlocked(definition, counts):
			continue
		var cost := _next_cost(definition, counts[generator_id])
		if cost > bits:
			continue
		var next_output := definition.base_production * pow(definition.production_growth, counts[generator_id])
		var payback := cost / next_output
		if payback < best_payback:
			best_payback = payback
			best_id = generator_id
	if not best_id.is_empty():
		counts[best_id] += 1
	return best_id


func _is_unlocked(definition: GeneratorDefinition, counts: Dictionary) -> bool:
	return definition.unlock_after_generator_id.is_empty() or counts[definition.unlock_after_generator_id] >= definition.unlock_after_generator_count


func _next_cost(definition: GeneratorDefinition, owned: int) -> float:
	return ceil(definition.base_cost * pow(definition.cost_scaling, owned))


func _total_production(counts: Dictionary, definitions: Dictionary) -> float:
	var total := 0.0
	for generator_id in IDS:
		var definition: GeneratorDefinition = definitions[generator_id]
		var count: int = counts[generator_id]
		if count > 0:
			total += definition.base_production * (pow(definition.production_growth, count) - 1.0) / (definition.production_growth - 1.0)
	return total
