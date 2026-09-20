extends Node
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const PRIMARY := "user://stage46_save.json"
const BACKUP := "user://stage46_backup.json"
const NORMAL_UI_SCENE := preload("res://ui/main/NormalUI.tscn")

func _ready() -> void:
	await get_tree().process_frame
	var errors: PackedStringArray=[]
	var game:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var db:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var saves:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"save_manager")
	if game==null or db==null or saves==null: errors.append("autoload missing")
	else:
		saves.set_test_paths(PRIMARY,BACKUP); saves.reset_save()
		_validate_manual_power(errors, game, saves)
		if not game.owned_upgrades.is_empty(): errors.append("A fresh owns upgrades")
		if game.buy_upgrade(&"worker_threading"): errors.append("B locked bought")
		game.apply_save_data({"bits":10000.0,"generator_counts":{"worker":5,"terminal":5}})
		var worker_before:float=game.get_generator_production(&"worker")
		if not game.buy_upgrade(&"worker_threading"): errors.append("C unlocked failed")
		if abs(game.get_generator_production(&"worker")-worker_before*2.0)>0.01: errors.append("F worker multiplier")
		var terminal_before:float=game.get_generator_production(&"terminal")
		if abs(terminal_before - 6.0*(pow(1.04,5)-1.0)/0.04)>0.01: errors.append("G target leak")
		if not game.buy_upgrade(&"terminal_pipeline"): errors.append("terminal upgrade failed")
		if not game.buy_upgrade(&"vector_scheduler"): errors.append("global upgrade failed")
		if abs(game.get_global_production_multiplier()-1.25)>0.001: errors.append("H global")
		game.apply_save_data({"bits":1000.0,"generator_counts":{"worker":3},"owned_upgrades":["input_cache"]})
		if abs(game.get_manual_generation_amount() - pow(1.08, 3)) > 0.001: errors.append("I manual")
		if game.buy_upgrade(&"invalid") or db.get_upgrade_validation_errors().size()>0: errors.append("M/N invalid content")
		game.apply_save_data({"bits":10000.0,"generator_counts":{"worker":5},"owned_upgrades":["worker_threading"]})
		if not saves.save(): errors.append("K save")
		game.reset_save_data(); saves.load_game()
		if not game.is_upgrade_owned(&"worker_threading"): errors.append("K restore")
		var v2={"save_version":2,"saved_at_unix":int(Time.get_unix_time_from_system()),"game":{"bits":77.0,"generator_counts":{"worker":2}},"story":{"flags":{"operator_discovered":true}}}
		var f=FileAccess.open(PRIMARY,FileAccess.WRITE);f.store_string(JSON.stringify(v2));f.close();saves.load_game()
		if game.get_currency()!=77.0 or game.get_generator_count(&"worker")!=2 or not game.owned_upgrades.is_empty(): errors.append("L v2 migration")
		await _validate_ui(errors, game)
		saves.reset_save();saves.restore_default_paths()
	print("VALIDATION_RESULT:","OK" if errors.is_empty() else "ERRORS: "+", ".join(errors));get_tree().quit()

func _validate_manual_power(errors: PackedStringArray, game: Node, saves: Node) -> void:
	const GROWTH := 1.08
	# A: Workers alone must not modify manual power.
	game.apply_save_data({"bits": 0.0, "generator_counts": {"worker": 10}})
	if not is_equal_approx(game.get_manual_generation_amount(), 1.0): errors.append("manual A no-upgrade worker leak")
	# B-F: formula uses ownership count, including the zero-worker base case.
	for count in [0, 1, 5, 10, 25]:
		game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": count}, "owned_upgrades": ["input_cache"]})
		var expected := pow(GROWTH, count)
		if abs(game.get_manual_generation_amount() - expected) > 0.0001: errors.append("manual %d workers" % count)
	# G: a normal purchase refreshes the calculation without reopening any UI.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10}, "owned_upgrades": ["input_cache"]})
	if game.buy_generator(&"worker") != true or abs(game.get_manual_generation_amount() - pow(GROWTH, 11)) > 0.0001: errors.append("manual G next worker refresh")
	# H: both ownership and count survive the normal save/load route.
	var before_save: float = game.get_manual_generation_amount()
	if not saves.save(): errors.append("manual H save")
	game.reset_save_data(); saves.load_game()
	if abs(game.get_manual_generation_amount() - before_save) > 0.0001: errors.append("manual H restore")
	# I-J: production modifiers and non-Worker counts cannot affect this effect.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10}, "owned_upgrades": ["input_cache", "worker_threading"]})
	if abs(game.get_manual_generation_amount() - pow(GROWTH, 10)) > 0.0001: errors.append("manual I production double-count")
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10, "terminal": 99, "server": 99, "factory": 99, "data_center": 99}, "owned_upgrades": ["input_cache"]})
	if abs(game.get_manual_generation_amount() - pow(GROWTH, 10)) > 0.0001: errors.append("manual J other generator leak")
	# K-L: exact bulk and max APIs refresh once their final ownership count is committed.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 3}, "owned_upgrades": ["input_cache"]})
	if game.buy_generators(&"worker", 10) != 10 or abs(game.get_manual_generation_amount() - pow(GROWTH, 13)) > 0.0001: errors.append("manual K buy ten")
	var maximum: int = game.get_max_affordable_generator_count(&"worker")
	if maximum < 1 or game.buy_generators(&"worker", maximum) != maximum or abs(game.get_manual_generation_amount() - pow(GROWTH, 13 + maximum)) > 0.0001: errors.append("manual L max")
	game.reset_save_data()

func _validate_ui(errors: PackedStringArray, game: Node) -> void:
	game.apply_save_data({"bits":1000000.0,"generator_counts":{"worker":3}})
	var host:=Control.new();host.size=Vector2(1280,720);add_child(host)
	var ui:=NORMAL_UI_SCENE.instantiate() as Control;host.add_child(ui)
	await get_tree().process_frame
	var manual_power:=ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/ManualPowerLabel") as Label
	var core_status:=ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreStatusLabel") as Label
	var worker_link:=ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/WorkerLinkLabel") as Label
	if manual_power==null or not manual_power.text.contains("1 BIT / CLICK"): errors.append("Q manual base readout")
	else:
		var before_install:float=game.get_currency()
		ui.upgrade_store._select(&"input_cache");ui.upgrade_store._install_selected()
		if not game.is_upgrade_owned(&"input_cache") or abs(game.get_currency()-(before_install-60.0))>0.001: errors.append("Q manual install")
		elif not manual_power.text.contains("1.26 BITS / CLICK") or worker_link==null or not worker_link.visible or not worker_link.text.contains("1.26"): errors.append("Q manual installed readout")
		elif game.buy_generators(&"worker",7)!=7 or not manual_power.text.contains("2.16 BITS / CLICK"): errors.append("Q manual buy ten refresh")
		elif not game.buy_generator(&"worker") or not manual_power.text.contains("2.33 BITS / CLICK"): errors.append("Q manual immediate refresh")
	var button:=ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/UpgradesNavLabel") as Button
	if button==null: errors.append("P upgrade navigation missing")
	else:
		button.emit_signal("pressed");await get_tree().process_frame
		if ui.upgrade_store==null or not ui.upgrade_store.visible: errors.append("P store did not open")
		elif ui.upgrade_store._grid==null or ui.upgrade_store._grid.get_child_count()<1: errors.append("P available grid missing")
	host.queue_free()
