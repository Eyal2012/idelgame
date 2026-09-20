# idel game

An expandable 2D idle game with fourth-wall-breaking/meta mechanics
inspired by the idea of "There Is No Game", but NOT a horror game.

This is **Stage 4.6: Data-Driven Upgrade Store**.

## Godot version

Godot 4.7 (engine features: `4.7`, `Forward Plus`).

## Current stage

**Stage 4.5 - Balanced Economy.** BIT//SHIFT begins as a computation-management
idle game, but its longer-term identity is an original puzzle/adventure inside a
fictional system. The normal surface now has geometric per-copy production,
exact BUY 1 / BUY 10 / MAX purchasing, compact shop feedback, and deterministic
data-driven pacing. The one-time SHIFT anomaly and hidden `OPERATOR` process
remain intact; Memory Leak, overflow, prestige, and later puzzle chapters are
not implemented.

## Process economy

All Process costs use `ceil(base_cost * 1.15^owned)`. Each additional owned
copy contributes `base_production * 1.04^(purchase_index - 1)`; total output is
computed with the geometric-series formula rather than per-copy frame loops.
The balanced tier entries are Worker `10 / 1/s`, Terminal `60 / 6/s`, Server
`600 / 30/s`, Factory `7,200 / 180/s`, and Data Center `90,000 / 1,200/s`.

GeneratorRow delegates exact purchase math to Game. BUY 10 sums the next ten
rounded individual prices; MAX uses logarithmic bracketing/binary search over
those exact sums. Shared `NumberFormatter` keeps ordinary values comma-formatted
and abbreviates only at millions (with the future 32-bit target kept explicit).
`tools/simulate_stage45_balance.gd` is a save-free development simulation.

## Upgrade modules

Upgrade resources are loaded and validated by `ContentDB`; `Game` owns generic
upgrade IDs, one-time purchases, and modifier calculation. The store’s compact
AVAILABLE grid exposes installable modules, while INSTALLED retains a dim text
record. Effects stack as base geometric production × generator multipliers ×
global multipliers; manual additions are applied to the base manual click.

Save version 3 persists `owned_upgrades` as a stable ID array. v2 saves migrate
without changing Bits, generator counts, or Story/OPERATOR flags.

## Save data

The primary file is `user://save.json`; the one-generation fallback is
`user://save_backup.json`. Save version 2 is human-readable JSON:

```json
{"save_version": 2, "saved_at_unix": 1234567890,
 "game": {"bits": 1234, "generator_counts": {"worker": 4}},
 "story": {"flags": {"shift_state_unlocked": true}}}
```

Counts use stable generator ids, so a newly added generator resource defaults to
zero without a new save field. Saves first validate `user://save.tmp`; a valid
old primary is rotated to backup before replacement. Load tries primary, then
backup, then starts safely fresh. Future format changes use sequential migration
functions. Offline earnings are `Game`'s current total production per second
multiplied by elapsed time, capped at 24 hours. Save v1 migrates to v2 by adding
safe default story flags. `ValidateStage3` uses only
`user://stage3_validator_*` files and never touches player saves.

Stage 4.5 changes only resource balance/math; no save-format change is needed.
Existing generator counts and all story/OPERATOR flags load unchanged.

## Project structure

```
res://
├── autoload/          # Global singletons (EventBus, Game, SaveManager, ...)
├── core/              # Gameplay system skeletons (currency, generators, ...)
├── meta/              # Fourth-wall-breaking infrastructure
│   ├── base/          # MetaEvent base class
│   ├── events/        # Individual meta event resources (future)
│   └── effects/       # Reusable meta effects (future)
├── story/             # Story infrastructure (chapters, dialogue, conditions)
├── systems/           # Reusable gameplay systems (conditions, rewards, modifiers)
├── ui/                # UI skeletons
│   ├── main/          # Main scene + layer controller
│   ├── components/    # Reusable UI components (future)
│   ├── overlays/      # Overlay nodes (future)
│   └── debug/         # Debug UI (future)
├── resources/         # Data-driven content (future)
├── art/               # Art assets (future)
├── audio/             # Audio assets (future)
├── tools/             # Developer tooling scripts (future)
├── tests/             # Test scripts (future)
└── docs/              # Documentation
```

## Main architectural systems

- **Game** (`autoload/game.gd`): owns runtime Bits and generic generator
  counts. Does NOT own UI state or generator definitions.
- **EventBus** (`autoload/event_bus.gd`): typed signal hub. Independent
  systems communicate through it rather than reaching into each other.
- **SaveManager** (`autoload/save_manager.gd`): versioned JSON persistence,
  validated temporary writes, backup recovery, autosave, offline progress, and
  migration hooks. `reset_save()` is available for development/testing.
- **ContentDB** (`autoload/content_db.gd`): validates, indexes, and orders
  data-driven generator definitions.
- **StoryManager** (`autoload/story_manager.gd`): generic story flags
  and current chapter. It owns `first_anomaly_started`,
  `shift_state_unlocked`, and `operator_discovered`, and emits EventBus events
  on changes.
- **MetaDirector** (`autoload/meta_director.gd`): schedules and runs
  MetaEvents. It evaluates the first anomaly outside the UI and sequences its
  diagnostic messages and temporary presentation request.
- **ShiftManager** (`autoload/shift_manager.gd`): reusable registry of normal
  and hidden UI pairs. It owns physical Shift-key state but no progression.
- **SettingsManager** (`autoload/settings_manager.gd`): user settings
  storage (audio, display, gameplay, accessibility).
- **WindowManager** (`autoload/window_manager.gd`): safe abstraction for
  future window-related mechanics. No real OS interaction yet.
- **FeatureManager** (`autoload/feature_manager.gd`): generic
  `is_unlocked` / `unlock` / `lock` system for features like shop,
  upgrades, prestige, secret_menu, developer_console.
- **DebugLogger** (`autoload/debug_logger.gd`): lightweight category-
  based logger (GAME, SAVE, STORY, META, CONTENT, ...).

## MetaEvent lifecycle

Every fourth-wall event inherits from `MetaEvent`
(`res://meta/base/meta_event.gd`) and follows:

```
can_start() -> start() -> update() -> complete()/cancel() -> cleanup()
```

`MetaDirector` only calls these methods. Events are responsible for
cleaning up everything they change.

## How to open/run the project

Open the project in the Godot editor:

```
godot --path C:\Development\installation-test\idel-game
```

Or run headlessly for validation:

```
godot --headless --path . --editor --quit
```

The main scene is `res://ui/main/Main.tscn`.

## What should be built next

Future systems may use computing concepts such as permissions, scheduling,
buffers, binary state, and UI compilation. The long-term normal progression
goal remains the signed 32-bit maximum `2,147,483,647`, where a later overflow
chapter may occur; it is deliberately not implemented yet.

All of it must follow the architecture rules in `docs/ARCHITECTURE.md`.
