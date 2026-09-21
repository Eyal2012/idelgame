# Architecture

This document defines the architectural rules for the project.
Follow them when adding new mechanics, systems, or content.

## 1. Do not hard-code content that can reasonably be represented as data.

Currencies, generators, upgrades, achievements, and Meta Events should
eventually be defined as Resources/data definitions (see
`resources/`), not inline in code. This keeps content data-driven and
easy to add without touching core systems.

## 2. Generators, upgrades, achievements and Meta Events should use reusable Resources/data definitions.

Each piece of content lives in its own resource folder under
`res://resources/`. Use stable `StringName` ids for every content entry;
never rely on visible display names as identifiers.

## 3. Independent systems communicate through EventBus where appropriate.

Do not reach deeply into another singleton (e.g. `Game.currencies`).
Emit and listen to typed signals on `EventBus` instead. This keeps
systems decoupled and testable.

## 4. Avoid tightly coupling unrelated UI panels.

UI panels should only interact with their own state and with the
systems they represent. They must NOT reach into unrelated UI nodes.
Use EventBus for cross-panel communication.

## 5. Every Meta Event MUST clean up everything it changes.

`MetaEvent.cleanup()` is always called after `complete()` or `cancel()`.
It must undo any modifications the event made to Game state, UI, or
other systems. MetaDirector does not know what an event does internally.

## 6. Persistent state must go through SaveManager.

Do not persist game state directly to disk from other systems.
All save/load operations go through `SaveManager`. SaveManager owns
the save schema, versioning, and migration logic.

## 7. New save fields need backwards-compatible defaults.

When adding a field to the save format, always provide a default value
in the migration code so old saves load cleanly.

## 8. Old saves must not silently break.

`SaveManager.migrate_save()` is the single place where old save versions
are converted. Bump `SAVE_VERSION` only when the schema changes, and
write a migration path for every previous version.

## 9. Story progression belongs in StoryManager/story flags.

Use `StoryManager` for all story state: flags and current chapter.
Do not store story progression in UI nodes or scattered across systems.

## 10. Important gameplay state must never exist only inside UI nodes.

UI displays and interacts with state; it does NOT own core progression
state. All gameplay state lives in `Game` (and friends). UI observes
this state, typically via EventBus signals.

## 11. UI displays/interacts with state; UI should not own core progression state.

UI nodes are thin. They call into systems and reflect changes. They do
not make authoritative changes to progression state.

## 12. Significant systems should expose ways to test/debug them.

Each major system should provide a simple public API that tests or a
debug overlay can call. Avoid private state that cannot be inspected.

## 13. Prefer reusable components over one-off solutions.

If you find yourself copying similar logic into multiple places, extract
a reusable base class, helper, or Resource type.

## 14. Do not rewrite working architecture just to add one feature.

When adding a feature, extend the existing architecture rather than
replacing it. Refactor only when the current structure actively blocks
the new feature.

## 15. Avoid giant manager scripts. Split systems when responsibilities become different.

A script should have one clear responsibility. If a script grows beyond
~200 lines or covers multiple unrelated concerns, split it.

## 16. Use stable IDs/StringName identifiers instead of relying on visible display names.

Identifiers are stable and localized independently of display text.
Always use ids for logic; use display names only for presentation.

## 17. Fourth-wall effects must not permanently corrupt normal UI state.

Meta events run in a separate overlay (`MetaOverlay`) and must restore
any normal UI they modify during `cleanup()`. Normal UI must remain
functional after a meta event ends.

## 18. Never perform dangerous operating-system/file actions for a fake fourth-wall effect.

Fake OS interactions (fake dialogs, fake file prompts, fake crashes)
should be simulated entirely inside the game. They must never touch the
real operating system or real files.

## 19. Generators are data-driven definitions.

`GeneratorDefinition` resources in `res://resources/generators/` own each
generator's stable id, display data, pricing, production, and sort order.
`ContentDB` validates and orders those definitions. `Game` stores only counts
keyed by generator id and exposes generic purchase/production APIs.

Adding a generator must normally require only a new `GeneratorDefinition`
resource. Do not add generator-specific variables, purchase methods, or UI
cards to `Game.gd` or `NormalUI.gd`.

## 20. Processes UI is dynamic.

`NormalUI` creates one reusable `GeneratorRow` for every definition returned
by `ContentDB`. A row presents state and sends purchase requests to `Game`; it
does not own progression state or calculate pricing.

## 21. Save format and ownership

`SaveManager` owns versioned JSON persistence in `user://save.json`. Version 1
contains `save_version`, `saved_at_unix`, and `game`, whose generic
`generator_counts` dictionary is keyed by stable generator ids. `Game` exposes
`get_save_data()` and `apply_save_data()`; SaveManager never reaches into its
internal variables. Missing, unknown, negative, malformed, and non-finite
values are safely normalized.

## 22. Save safety, recovery, and migration

Saving validates `user://save.tmp` before changing the primary. The previously
valid primary is retained as `user://save_backup.json`; loading tries primary,
then backup, then a fresh state without deleting corrupt files. The current
version is 1. Future schema changes add one explicit sequential migration per
version transition in `migrate_save()`.

## 23. Autosave and offline production

SaveManager autosaves every 12 seconds and attempts a final save on application
exit. Startup loading applies offline Bits exactly once per load from Game's
generic production calculation, capped at 86,400 seconds (24 hours). Validators
inject `user://stage3_validator_*` paths, keeping real player saves untouched.

## 24. SHIFT layer architecture

`ShiftManager` observes only Godot's physical Shift-key state and maintains a
reusable registration of a normal `Control`, its hidden SHIFT-layer `Control`,
and a base offset. It records the original position once, applies a small offset
while active, and restores that exact position on release; no puzzle state lives
in UI nodes. `MetaOverlay` hosts hidden material, while `StoryManager` owns
whether SHIFT is available and whether it has been discovered.

## 25. First anomaly and safe observation

`MetaDirector` evaluates the one-time Terminal-plus-Bits progression condition
outside UI and sequences dry diagnostic System Log messages through EventBus.
Temporary UI effects are requested through EventBus and must tween back to their
captured base values. `BehaviorObserver` observes only ordinary in-game Godot
mouse/window/focus/viewport events. It does not inspect files, record input
outside the game, or manipulate the operating system.

## 26. Story persistence and v1 -> v2 migration

Save version 2 adds a `story` block. The explicit v1 -> v2 migration preserves
all game currency and generator counts and adds false defaults for
`first_anomaly_started`, `shift_state_unlocked`, and `operator_discovered`.
All meta effects remain within the game window. Future progression may build
toward the signed 32-bit maximum `2,147,483,647`; that overflow event is not
implemented in Stage 4.

## 27. Process economy and bulk purchasing

`GeneratorDefinition` owns base cost, cost growth, base production, and
production growth. `Game` is the sole owner of next-cost, exact bulk-cost,
affordability, and geometric total-production math. UI must call
`get_generator_bulk_cost`, `get_max_affordable_generator_count`, and
`buy_generators`; it must not duplicate economic formulas. BUY 10 is always the
sum of ten rounded sequential prices. MAX uses bracketing/binary search and
exact sums, never a guessed multiplier or unbounded purchase loop.

## 28. Economy presentation and future modifiers

`NumberFormatter` is the shared number presentation utility. Generator rows
show ownership, next marginal output, total output, and exact BUY 1/BUY 10
costs. `Game.get_generator_production_multiplier()` is a deliberate neutral
extension point for future upgrades; Stage 4.5 adds no hidden multipliers or
upgrade gameplay. Balance simulation lives under `tools/` and never affects
saves or runtime gameplay.

## 29. Upgrade modules

`UpgradeDefinition` resources own stable ids, costs, effects, unlock rules, and
prerequisites. `ContentDB` indexes them deterministically. `Game` alone owns
generic upgrade ownership and applies modifiers in this order: base geometric
generator production, target-generator multipliers, then global multipliers.
UI presents definitions only. Save v3 adds generic `owned_upgrades`; migration
v2 -> v3 defaults it to an empty array while retaining all existing state.

## 30. MemoryPuzzle authority and physical interaction

`MemoryPuzzle` owns the Stage 5 accounting event: percentage escrow,
active/completed state, stable legacy `bit_0` through `bit_4` ids, slot mapping,
hints, intro/completion sequencing, deterministic five-block value allocation,
and save normalization. UI must never mutate `restored`, `slots`, or Bits
directly. Click-to-place and drag/drop both reach the same
`place_bit(bit_id, slot_id)` method. A slot mapping is authoritative over UI
state and must remain one Memory Block to one slot.

`MemoryPuzzleOverlay` is a responsive, non-modal presentation shell. It may
animate detached Memory Blocks back to safe positions, draw diagnostic traces, and show
socket states, but it does not own progression. While SHIFT is active it exposes
four primary Memory Bus addresses; it exposes the fifth reserved address only at
four restored Memory Blocks. Normal UI layout is never translated for this diagnostic
state, and invisible puzzle controls must not intercept normal gameplay input.

SaveManager persists the puzzle through its v4 `memory_puzzle` block. No schema
change is needed for scaled blocks: their values are deterministically derived
from stored escrow by `MemoryPuzzle`. Load-time sanitization discards unknown or
duplicate ids, preserves a valid stored active escrow (including older five-Bit
saves), resolves all-five mappings as completed without a new reward, and
prevents completed state from retaining escrow. Mid-puzzle hints persist enough
timing state to avoid immediate replay spam.

## 31. Chapter 1 endpoint (documentation only)

The signed 32-bit maximum, `2,147,483,647 Bits`, is the planned Chapter 1
endpoint. A future INTEGER OVERFLOW event may transition BIT//SHIFT from its
fake idle interface into an original top-down internal world with exploration,
environmental storytelling, RPG/puzzle systems, dodge/combat encounters, and a
final boss. This is future design direction only; it does not authorize an
overflow implementation, Stage 6 systems, or post-overflow gameplay.

## 32. Developer tooling is a debug-only client

`DevPanel` is instantiated by `Main` only when `OS.is_debug_build()` is true.
It listens for `TAB` in `_input`, suppresses echoed/repeated presses, and marks
the key handled before focused `LineEdit` controls can insert/traverse it.
Release builds have no DevPanel node and its system debug APIs reject calls.
The panel may observe systems and invoke explicit debug APIs, but no gameplay
system may require it to exist.

`Game.debug_set_bits`, generic generator/upgrade debug setters,
`StoryManager.debug_*`, `MemoryPuzzle.debug_*`, and `SaveManager.debug_*` are
the narrow mutation surface. They preserve normal production, ownership,
escrow, save, and EventBus update routes rather than duplicating that logic in
UI. SaveManager's development autosave toggle is non-persistent and defaults
to normal autosave behavior. Debug launches may opt in to a compatible isolated
save target with `-- --dev-save`; otherwise developer cheats affect the active
player save and the panel must state that clearly.

## 33. Data-driven debug checkpoints

`DebugCheckpointDefinition` resources in `resources/debug_checkpoints/` contain
an id, display/stage metadata, generic Game state, Story flags, and Memory
state/progress. `DebugCheckpointCatalog` scans and sorts the directory; the UI
does not contain checkpoint-id conditionals. To add a future stage, add a
validated resource with all prerequisite state needed for a coherent checkpoint.
Checkpoint application resets an active puzzle safely, applies Game and Story
through their debug APIs, then builds Memory Puzzle progress through its normal
escrow and completion authority. Future checkpoints must not introduce Stage 6
or later gameplay merely to support a test jump.
