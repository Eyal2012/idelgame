# idel game

An expandable 2D idle game with fourth-wall-breaking/meta mechanics
inspired by the idea of "There Is No Game", but NOT a horror game.

This is **Stage 8: Range Saturation**.

## Godot version

Godot 4.7 (engine features: `4.7`, `Forward Plus`).

## Current stage

**Stage 8 - Range Saturation — COMPLETE.** Normal progression now has a stable
signed-32-bit endpoint at **2,147,483,647 Bits**. The Integer Range Manager
clamps all output at that limit, presents the capacity and final halted state,
and persists it in saves. Compute Override I–III appear only during Stage 8.
SHIFT exposes the diagnostic Integer Register; it does not move the normal UI.
The next planned event is **INTEGER OVERFLOW**. Actual overflow, interface
breakdown, and a canonical top-down transition are not implemented.

**Stage 7 - Scheduler Desync.** After Stage 6 completion and a normal-play delay,
Terminal Node is temporarily starved by a 25% scheduler inefficiency. SHIFT
exposes an execution queue that the OPERATOR repairs with deterministic controls.

**Stage 6 - Access Mask.** Stage 5.2's scaled Memory Blocks remain intact. After
Stage 5 completion and a normal-play breathing period, a security audit starts
with the fictional READ-only operator mask `0001`. New module installations are
then denied without spending Bits until SHIFT exposes the compact Access Register
and the player shifts the active bit left to `0010` (WRITE). INTEGER
OVERFLOW, and the later top-down internal world remain documentation-only.

**Stage 5.2 - Scaled Memory Blocks.** After discovering OPERATOR, owning two
modules, and bringing a Server online, a five-percent accounting mismatch can
occur. Five detached physical Memory Blocks represent the temporarily
unaddressable Bits; each can be selected/clicked into sockets or dragged onto
them while normal production and every normal control continue to work.
The normal UI remains stationary during SHIFT; the diagnostic layer exposes a
Memory Bus, four primary addresses, and a fifth reserved address near System Log
only after four Memory Blocks are restored. Stage 8 and later mechanics are not started.

## Developer panel (debug builds only)

Press `TAB` to toggle the compact **BIT//SHIFT // DEV PANEL** in a Godot debug
build. The panel consumes TAB before text controls or normal focus traversal can
use it, ignores key-repeat toggles, and its floating panel blocks clicks only
where it physically overlaps the game. Release builds do not instantiate this
UI, and the debug mutation APIs reject release calls.

It offers live economy, data-driven Process and upgrade controls, current-state
readouts, Story/SHIFT/OPERATOR tools, authoritative Memory Puzzle controls,
save controls, autosave testing, and UI refresh commands. It intentionally does
not pause production by default. Normal launches modify the current player save.
For isolated testing, launch a debug build with `-- --dev-save`; this selects
the compatible `user://dev_save.json` target rather than the player save.
`RESET SAVE` requires a second confirmation click.

Checkpoints are `DebugCheckpointDefinition` resources in
`res://resources/debug_checkpoints/`. The panel discovers that directory at
runtime, so future content registers a checkpoint by adding a resource with
generic Game state, Story flags, and Memory Puzzle state—never another
stage-specific branch in the panel. Current entries cover Fresh, Stage 4's
anomaly/SHIFT/OPERATOR states, and Stage 5 from ready through completion.
`Game`, `StoryManager`, `MemoryPuzzle`, and `SaveManager` expose debug-only
methods for those actions; normal game systems never depend on the panel.

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

Save version 4 persists `owned_upgrades` as a stable ID array alongside the
MemoryPuzzle block. v2 saves migrate without changing Bits, generator counts,
or Story/OPERATOR flags.

## Memory Bus Recovery

`MemoryPuzzle` is the sole authority for the percentage escrow, stable `bit_0`
through `bit_4` identities, slot mapping, completion, and sanitization. A new
failure escrows `min(floor(current Bits), max(10, floor(current Bits * 0.05)))`
once, then splits that exact integer across five Memory Blocks with quotient and
remainder allocation. Completion refunds the stored escrow once. A v4 save made
mid-puzzle retains its stored escrow verbatim, so older `escrow: 5` saves remain
five-Bit puzzles rather than being reinterpreted. Malformed display-cache data is
ignored; slots and stored escrow remain authoritative.

`MemoryPuzzleOverlay` is presentation and input only. It provides compact cyan /
violet `MB-01` through `MB-05` controls with their authoritative stored value,
click-selection with socket-click fallback, and drag / drop. Both paths call the
same `MemoryPuzzle.place_bit()` authority. Invalid drops tween back to a
responsive safe position; releasing SHIFT during a drag only hides the socket
targets, so the eventual release returns safely. The overlay is deliberately
non-modal: it has no full-window input blocker.

During SHIFT, restrained traces connect the Core-side diagnostic origin to the
four Memory Bus slots. At four of five, `ADDRESS 04 // RESERVED` appears above
the System Log with a faint diagnostic trace. Hints begin only in this state at
30/60/90 seconds and persist their level/timer through save/load. Completion
cleans up all Bit/socket controls and sequences the memory-restored / OPERATOR
write messages without affecting normal economy systems.

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

Save version 4 adds the optional `memory_puzzle` block. v3 saves migrate to an
inactive, zero-escrow puzzle; v4 loads also safely accept absent newer timing
fields. Existing generator counts and all story/OPERATOR flags load unchanged.

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

Focused developer-panel validation:

```
godot --headless --path . --scene res://tools/ValidateDevPanel.tscn
```

## Roadmap

Stage 5: Memory Accounting Failure. Stage 6: Access Mask. Stage 7: Scheduler
Desync. **Stage 8: Range Saturation — COMPLETE.**

Canonical ending: **2,147,483,647** → **INTEGER RANGE LIMIT REACHED**.
Next: **INTEGER OVERFLOW** → **BIT//SHIFT BREAKDOWN** → **INTERNAL WORLD** →
**TOP-DOWN CHAPTER**. `dev/topdown/TopDownPrototype.tscn` remains
development-only and is not reachable through canonical progression.

## Long-term Chapter 1 endpoint (documentation only)

Normal progression now settles at `2,147,483,647 Bits`, the signed 32-bit
integer limit. A later INTEGER OVERFLOW event may break down BIT//SHIFT's
interface and transition into an original top-down internal world. No actual
overflow, cutscene, canonical TopDownPrototype entry, Chapter 2, combat, or
boss content is implemented in Stage 8.

All of it must follow the architecture rules in `docs/ARCHITECTURE.md`.
