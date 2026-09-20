# idel game

An expandable 2D idle game with fourth-wall-breaking/meta mechanics
inspired by the idea of "There Is No Game", but NOT a horror game.

This is **Stage 2: Data-Driven Generators**.

## Godot version

Godot 4.7 (engine features: `4.7`, `Forward Plus`).

## Current stage

**Stage 2 - Data-Driven Generators.** The project implements Bits, manual
generation, five generator definitions, generic generator counts and pricing,
delta-based production, and a dynamic Processes panel built from reusable
GeneratorRow components. Stage 0 foundation systems remain in place; upgrades,
achievements, prestige, offline progress, and fourth-wall events are not
implemented.

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
- **SaveManager** (`autoload/save_manager.gd`): save versioning, backup
  support, and migration hooks. No actual save data yet.
- **ContentDB** (`autoload/content_db.gd`): validates, indexes, and orders
  data-driven generator definitions.
- **StoryManager** (`autoload/story_manager.gd`): generic story flags
  and current chapter. Emits EventBus events on changes.
- **MetaDirector** (`autoload/meta_director.gd`): schedules and runs
  MetaEvents. Does NOT contain individual event logic.
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

**STAGE 3 - PERSISTENCE AND PROGRESSION**

The next stage may add:

- Save/load of runtime generator state.
- Additional progression systems such as upgrades or achievements.

All of it must follow the architecture rules in `docs/ARCHITECTURE.md`.
