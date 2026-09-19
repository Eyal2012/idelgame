extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Exercises the real NormalUI button connections, event-driven label refresh,
## affordability state, and Game's live _process passive-production loop.

const NORMAL_UI_SCENE := preload("res://ui/main/NormalUI.tscn")
const BITS_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel")
const OWNED_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/OwnedRow/WorkerOwnedLabel")
const GENERATE_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton")
const BUY_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/BuyWorkerButton")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		print("VALIDATION_RESULT:ERRORS: game autoload is unavailable")
		get_tree().quit()
		return

	game.set_state({"bits": 0.0, "worker_count": 0})
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var ui := NORMAL_UI_SCENE.instantiate() as Control
	host.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var bits_label := ui.get_node_or_null(BITS_PATH) as Label
	var owned_label := ui.get_node_or_null(OWNED_PATH) as Label
	var generate_button := ui.get_node_or_null(GENERATE_PATH) as Button
	var buy_button := ui.get_node_or_null(BUY_PATH) as Button
	if bits_label == null or owned_label == null or generate_button == null or buy_button == null:
		errors.append("NormalUI interaction controls are missing")
	else:
		await _run_interaction_checks(errors, game, bits_label, owned_label, generate_button, buy_button)

	host.queue_free()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _run_interaction_checks(errors: PackedStringArray, game: Node, bits_label: Label, owned_label: Label, generate_button: Button, buy_button: Button) -> void:
	if generate_button.disabled:
		errors.append("Generate button starts disabled")
	if not buy_button.disabled:
		errors.append("Buy button starts enabled without 10 Bits")

	generate_button.emit_signal("pressed")
	if not is_equal_approx(game.get_currency(), 1.0) or bits_label.text != "1 BITS":
		errors.append("Generate button did not update Game and BitsLabel to 1")

	for _press in range(9):
		generate_button.emit_signal("pressed")
	if not is_equal_approx(game.get_currency(), 10.0) or bits_label.text != "10 BITS":
		errors.append("Ten generate presses did not produce 10 Bits")
	if buy_button.disabled:
		errors.append("Buy button did not enable at 10 Bits")

	buy_button.emit_signal("pressed")
	if not is_equal_approx(game.get_currency(), 0.0) or game.get_worker_count() != 1:
		errors.append("First Worker purchase did not spend 10 Bits and grant one Worker")
	if owned_label.text != "1":
		errors.append("Owned label did not refresh after first Worker purchase")
	if not buy_button.disabled:
		errors.append("Buy button did not disable after the first Worker purchase")

	var production_start: float = game.get_currency()
	await get_tree().create_timer(5.0).timeout
	var produced: float = game.get_currency() - production_start
	if produced < 4.5 or produced > 5.5:
		errors.append("Live passive production over five seconds was %.3f, expected about 5" % produced)
	if not bits_label.text.ends_with(" BITS"):
		errors.append("BitsLabel did not remain connected during passive production")

	for _press in range(7):
		generate_button.emit_signal("pressed")
	if buy_button.disabled:
		errors.append("Buy button did not enable for the second Worker after earning enough Bits")
	else:
		buy_button.emit_signal("pressed")
		if game.get_worker_count() != 2 or owned_label.text != "2":
			errors.append("Second Worker purchase did not update Game and Owned label")
