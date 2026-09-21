extends Node

## EventBus
##
## Typed signal hub for communication between independent systems.
## Systems should NOT reach deeply into each other; they emit/listen here.
##
## Signal naming convention: <subject>_<verb> (past tense for completed actions).

## Emitted when a currency amount changes.
## Args: currency_id (StringName), old_amount (float), new_amount (float)
signal currency_changed(currency_id: StringName, old_amount: float, new_amount: float)

## Emitted when a generator is purchased.
## Args: generator_id (StringName), new_count (int)
signal generator_bought(generator_id: StringName, new_count: int)

## Emitted once for a completed bulk purchase.
signal generator_bulk_bought(generator_id: StringName, amount: int, new_count: int)

## Emitted when an upgrade is purchased.
## Args: upgrade_id (StringName)
signal upgrade_bought(upgrade_id: StringName)

## Emitted when an achievement is unlocked.
## Args: achievement_id (StringName)
signal achievement_unlocked(achievement_id: StringName)

## Emitted when a prestige cycle begins.
## Args: prestige_id (StringName)
signal prestige_started(prestige_id: StringName)

## Emitted when a prestige cycle completes.
## Args: prestige_id (StringName)
signal prestige_completed(prestige_id: StringName)

## Emitted when a menu opens.
## Args: menu_id (StringName)
signal menu_opened(menu_id: StringName)

## Emitted when a menu closes.
## Args: menu_id (StringName)
signal menu_closed(menu_id: StringName)

## Emitted when a story event starts.
## Args: event_id (StringName)
signal story_event_started(event_id: StringName)

## Emitted when a story event finishes.
## Args: event_id (StringName)
signal story_event_finished(event_id: StringName)

## Emitted when a story flag changes.
## Args: flag_id (StringName), old_value (Variant), new_value (Variant)
signal story_flag_changed(flag_id: StringName, old_value: Variant, new_value: Variant)

## Emitted when a chapter is entered.
## Args: chapter_id (StringName)
signal story_chapter_started(chapter_id: StringName)

## Emitted when a meta (fourth-wall) event starts.
## Args: event_id (StringName)
signal meta_event_started(event_id: StringName)

## Emitted when a meta (fourth-wall) event finishes.
## Args: event_id (StringName)
signal meta_event_finished(event_id: StringName)

## Emitted when a meta event is cancelled.
## Args: event_id (StringName)
signal meta_event_cancelled(event_id: StringName)

## Emitted when a feature is unlocked.
## Args: feature_id (StringName)
signal feature_unlocked(feature_id: StringName)

## Emitted when a feature is locked.
## Args: feature_id (StringName)
signal feature_locked(feature_id: StringName)

## Emitted when save begins.
signal save_started()

## Emitted when save completes successfully.
## Args: success (bool)
signal save_completed(success: bool)

## Emitted when load begins.
signal load_started()

## Emitted when load completes successfully.
## Args: success (bool)
signal load_completed(success: bool)

## Diagnostic text for the single System Log presentation surface.
signal system_log_message(message: String)

## Stage 4 meta/SHIFT presentation events. Gameplay state remains in managers.
signal anomaly_visual_requested()
signal shift_state_changed(active: bool)
signal operator_discovered()
signal memory_puzzle_event(event_id: StringName, bit_index: int, slot_index: int)
signal access_mask_changed(mask: int)
signal scheduler_queue_changed()

## Emitted when the game is reset.
signal game_reset()


func _ready() -> void:
	# Connect internal cross-system bridges here if needed.
	# Keep this minimal to avoid hidden coupling.
	pass
