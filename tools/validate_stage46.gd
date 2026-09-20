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
		game.apply_save_data({"bits":1000.0,"generator_counts":{},"owned_upgrades":["input_cache"]})
		if game.get_manual_generation_amount()!=2.0: errors.append("I manual")
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

func _validate_ui(errors: PackedStringArray, game: Node) -> void:
	game.apply_save_data({"bits":1000.0,"generator_counts":{"worker":5}})
	var host:=Control.new();host.size=Vector2(1280,720);add_child(host)
	var ui:=NORMAL_UI_SCENE.instantiate() as Control;host.add_child(ui)
	await get_tree().process_frame
	var button:=ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/UpgradesNavLabel") as Button
	if button==null: errors.append("P upgrade navigation missing")
	else:
		button.emit_signal("pressed");await get_tree().process_frame
		if ui.upgrade_store==null or not ui.upgrade_store.visible: errors.append("P store did not open")
		elif ui.upgrade_store._grid==null or ui.upgrade_store._grid.get_child_count()<1: errors.append("P available grid missing")
	host.queue_free()
