extends Node

## Main
##
## Root scene for the game.
##
## Structure:
##   Main
##   ├── GameLayer      (core gameplay nodes; not UI)
##   └── UI
##       ├── NormalUI     (normal gameplay UI)
##       ├── MetaOverlay   (fourth-wall effects; must not corrupt NormalUI)
##       ├── DialogueOverlay (story dialogue)
##       └── DebugOverlay   (developer debug UI)
##
## Stage 1: NormalUI holds the basic idle loop UI.

@onready var game_layer: Node = $GameLayer
@onready var ui: Control = $UI
@onready var normal_ui: Control = $UI/NormalUI
@onready var meta_overlay: Control = $UI/MetaOverlay
@onready var dialogue_overlay: Control = $UI/DialogueOverlay
@onready var debug_overlay: Control = $UI/DebugOverlay


func _ready() -> void:
	_ensure_layer(game_layer)
	_ensure_layer(ui)
	_ensure_layer(normal_ui)
	_ensure_layer(meta_overlay)
	_ensure_layer(dialogue_overlay)
	_ensure_layer(debug_overlay)


## Make sure a node is visible and process-enabled.
func _ensure_layer(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	node.process_mode = Node.PROCESS_MODE_ALWAYS