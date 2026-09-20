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
