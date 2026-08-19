# AGENTS.md — Archipiélago Maizena

## Purpose

This document is the single source of truth for LLM-assisted work (Cursor, Copilot, ChatGPT, or similar) in this repository.

**Project:** Archipiélago Maizena — 2D top-down exploration game, Web/PWA export.

**Stack:** Godot **4.7**, GL Compatibility, 20 FPS cap, GDScript, Dialogue Manager 3.10.0.

**Team:** Solo-dev — there is no second reviewer, no CI/CD, and no automated test gates. Every "human reviewer" requirement means **me, reviewing my own diffs before accepting them**.

**Deploy:** Netlify publishes from `web_build/` (`netlify.toml`: `publish = "web_build"`). Production updates when `web_build/` is committed and pushed.

This policy applies to:
- Code generated via Cursor (Tab, Cmd+K, Agent/Composer mode)
- Code produced by autonomous coding agents
- Refactors or modifications suggested by LLMs
- GDScript, shaders, `.dialogue`, and `.tres`/`.tscn` structural edits suggested by LLMs

LLM-generated code is **not trusted by default** and must satisfy the validation rules below before it is considered done.

---

# Part I — LLM Quality Policy

# 1. Mandatory Self-Review

1. All LLM-generated code MUST be reviewed by me before being accepted, every time — even small Tab-completions that touch gameplay logic.
2. No diff is auto-accepted. Cursor's "Accept All" on multi-file Agent changes is NOT allowed without reading each file's diff first.
3. I am fully responsible for:
   - Correctness
   - Security
   - Performance
   - Architectural consistency
4. If I cannot explain what the generated code does, it MUST NOT be accepted. Rewrite the prompt or rewrite the code by hand instead.

There is no PR workflow or automatic merge — I am the only gate.

---

# 2. Test Coverage Requirements

There is **no automated test suite** and no coverage thresholds. Chasing 90%/80%/95% coverage on gameplay code produces theater, not safety.

Instead:

- Any non-trivial system (combat, inventory, save/load, dialogue state, anything touching persistent player data) SHOULD have at least a manual test checklist describing what was verified by hand in the editor.
- **Maizena smoke test** (Part II §G) is the acceptance gate for changes touching quest, dialogue, combat, or input.
- LLM-generated code that silently breaks previously-working behavior (a scene that loaded fine now errors, a signal that used to fire no longer does) MUST be rejected and fixed before moving on.

There is no GUT or other test framework in this project.

---

# 3. Cyclomatic Complexity Limits

LLMs frequently generate overly complex functions. Limits apply, adjusted for gameplay/state-machine code which is naturally more branchy than typical backend logic:

- Recommended per function: ≤ 10
- Maximum allowed per function: 15
- \> 15 requires mandatory refactor before accepting the change
- \> 20 is strictly forbidden

Refactor by:
- Splitting large functions
- Extracting helper functions or reusable components (nodes/classes with `class_name`)
- Replacing deeply nested `if/elif` dialogue/state logic with an explicit state machine (`enum` + `match`)
- Avoid premature polymorphism for one-off cases — in GDScript, an extra subclass hierarchy is often worse than a clear `match`

---

# 4. Godot/Cursor-Specific Correctness Requirements

LLM-generated GDScript MUST undergo explicit correctness validation before being accepted:

Review MUST verify:

- No Godot 3.x syntax leaked in (`yield()`, `onready` without `@`, `export(TYPE)` without `@`, string-based `connect()`, `.instance()` instead of `.instantiate()`)
- No invented/hallucinated nodes, methods, or properties — if Cursor wasn't certain an API exists in Godot 4.7, it should have flagged that, not asserted it confidently
- No reference to Autoloads, signals, or groups that don't actually exist in this project (see Part II)
- Proper input validation on anything that touches save data or external files — corrupted or missing JSON must not crash the game on boot (`WorldState`, `MaizenaMeta`, `WorldMetrics`)
- No hardcoded secrets — metrics endpoint URLs and Open-Meteo are public; anything requiring a token belongs outside version control
- No sensitive data (emails, device IDs, anything personally identifying) written into `print()`/log output
- **Web export correctness:** do not assume desktop-only APIs without verifying Web export behavior
- **`JavaScriptBridge`** only where already used (e.g. `scripts/music_manager.gd` for visibility pause) — do not spread without justification

If correctness is unclear, the code MUST be rejected and re-prompted with more context rather than accepted "to see if it works."

---

# 5. Architectural Compliance

LLM-generated code MUST:

- Respect the project's scene/script structure (see **Part II** of this file)
- Not introduce circular dependencies between Autoloads
- Not bypass the data layer — e.g. reaching into another scene's internal nodes via fragile `get_node("../../X")` paths instead of using signals, exported references, or unique names (`%Node`)
- Not introduce unnecessary new Autoloads when a local node or a passed reference would do
- Not duplicate logic that already exists as a component/resource elsewhere in the project

If LLM output conflicts with the existing architecture, it MUST be rewritten — Cursor does not get to silently "improve" structure while doing an unrelated task; structural changes are called out explicitly and done as their own step.

---

# 6. Dependency Policy

LLM-generated code MUST NOT:

- Add Godot Asset Library plugins/addons without explicit justification (what it solves, why hand-rolling it isn't simpler)
- Upgrade the Godot minor/major version, or bump addon versions, on its own initiative
- Introduce unmaintained or abandoned addons
- Propose GitHub Actions, CI pipelines, or pre-commit hooks unless explicitly requested

All new dependencies require my explicit approval before being added to `addons/` or `project.godot`.

The only addon in this project is **Dialogue Manager 3.10.0**. Do not edit `addons/dialogue_manager/` except for approved upgrades.

---

# 7. Code Quality Requirements

Generated code MUST:

- Be readable and maintainable — favor clarity over cleverness
- Use descriptive naming (`snake_case` functions/variables, `PascalCase` classes/nodes, `CONSTANT_CASE` constants)
- Use static typing wherever possible (`var health: int`, `func heal(amount: int) -> void:`)
- Avoid dead code and unused imports/preloads
- Follow project naming conventions (Part II §D): Spanish for `GameState` gameplay API, English for system scripts

Generated code MUST NOT:

- Contain large commented-out code blocks
- Include placeholder `# TODO` logic left inside paths that are supposed to be finished/shippable
- Contain speculative optimizations for problems that don't exist yet (premature object pooling, premature multithreading)
- Leave stray `print()` debug statements in code presented as done

---

# 8. Performance Responsibility

LLM-generated code MUST:

- Avoid instantiating/freeing nodes inside `_process`/`_physics_process` loops — use object pooling for frequently spawned things (projectiles, particles, hit effects)
- Use `_physics_process` for movement/physics, `_process` for non-physics visual/UI logic — not interchangeably
- Avoid N+1-style patterns (e.g. looping over all nodes in a group every frame when a signal-based approach would do)
- Avoid unnecessary heavy lookups in hot paths (`get_node()` with long paths called every frame instead of cached `@onready` references)

This project runs at **20 FPS** with GL Compatibility on Web — profile in the Godot profiler if a slowdown is suspected, not guessed at.

---

# 9. Traceability

For any non-trivial LLM-assisted change (multi-file Agent/Composer edits, anything touching save data or core systems), I SHOULD:

- Note in a commit message that the change was LLM-assisted
- Keep the prompt for non-trivial generations if it required real back-and-forth, in case the same bug pattern shows up again
- Briefly note how it was validated (played through manually, checked X scene in editor, exported web build, etc.)

This is for my own future debugging — skipping it is how "why did I write this" debt builds up.

---

# 10. Local Enforcement (no CI/CD)

There is **no CI/CD pipeline**. Validation is entirely manual:

1. Open the project in Godot and run the affected scene(s) — a script with no syntax errors is not the same as a script that works. Boot from F5 or `loading_screen.tscn`, not an isolated world scene.
2. Check the Godot **Output** and **Debugger** panels for new warnings/errors after any Agent change — multi-file edits can silently break unrelated scenes.
3. Run the **smoke test** (Part II §G) for gameplay changes.
4. For changes that must reach web users: export Web → `./tools/patch_web_build.sh` → test in browser **before** committing `web_build/`.

Do not bypass whatever local checks exist (linter, `gdformat`) just because no one else will see the diff.

---

# 11. Responsibility Model

LLMs are productivity tools.

They are not:
- Autonomous decision-makers on game design or architecture
- Authorities on what Godot APIs currently exist
- Security auditors
- Performance experts

Final responsibility always belongs to me, the human developer — Cursor accelerates typing and exploration, it doesn't own the decisions.

---

# 12. Guiding Principle

Speed without quality increases long-term cost — and on a solo project, there's no one else to catch what slips through.

LLM-generated code is acceptable only when it:
- Improves my actual iteration speed (not just produces more code faster)
- Maintains system integrity (doesn't quietly break what already worked)
- Does not introduce technical debt I won't recognize in three months
- Meets or exceeds what I'd write by hand, given the same time

---

# Part II — Maizena Project Guide

## A. Scene Boot Flow

Runtime boot sequence:

```
scenes/boot/loading_screen.tscn → scenes/boot/main_scene.tscn → bosque_encantado.tscn + player + UI
```

- `run/main_scene` in `project.godot` = `res://scenes/boot/loading_screen.tscn`
- Maps swap via `MainScene.travel_to()` between `bosque_encantado.tscn`, `ciudad_world.tscn`, and `pantano_world.tscn`
- **LLM rule:** Always test from F5 or `loading_screen.tscn`. Do not run a world scene in isolation — it lacks nodes from `main_scene`.

---

## B. Autoload Contract

| Autoload | File | Persists | Responsibility |
|----------|------|----------|----------------|
| `GameState` | `autoload/game_state.gd` | No (session) | Quest flags, inventory, NPC talk counts, minigame launcher |
| `WorldState` | `autoload/world_state.gd` | `user://world_state.json` | World time, decay, accumulation, visit timestamps |
| `MaizenaMeta` | `autoload/maizena_meta.gd` | `user://maizena_meta.json` | Eras, song play log, welcome flag |
| `DialogueController` | `autoload/dialogue_controller.gd` | No | Input lock during dialogue |
| `HongosSpawner` | `autoload/hongos_spawner.gd` | No | Quest mushroom spawn |
| `CordobaWeather` | `autoload/cordoba_weather.gd` | No | Open-Meteo API (no API key) |
| `ViewportLayout` | `autoload/viewport_layout.gd` | No | Responsive UI/camera scaling |
| `WorldMetrics` | `autoload/world_metrics.gd` | `user://metrics_client_id` | Optional anonymous telemetry |
| `DialogueManager` | addon | — | Dialogue Manager runtime |

**LLM rules:**
- Do not move quest flags from `GameState` to persisted autoloads without explicit approval
- Do not create new autoloads for scene-local state
- Dialogue mutations must call **existing** autoload methods (`do GameState.buscar_comida()`), not invented APIs
- Session state (`GameState`) vs persistent state (`WorldState`, `MaizenaMeta`) — keep the boundary

---

## C. World Systems (embedded in `*_world.tscn`)

Each map scene (`new_world`, `ciudad_world`, `pantano_world`) shares this layout:

- Root `NewWorld` with `scripts/systems/world_map.gd` (`camera_limit_*`)
- Child `TimeOfDaySystem` (`scripts/systems/time_day_system.gd` — the only project `class_name`) holding `CanvasModulate` + `WeatherVisualSystem`
- Sibling systems: `ResidueSystem`, `WorldAutonomySystem`, `NpcPresenceSystem`
- TMX instance from `assets/art/maps/web_maizena_rpg/` (YATI import) + `InteractiveObjects/` and map hotspots

**LLM rule:** Edit tile data in Tiled (`.tmx`), reimport via YATI. Do not run the legacy `merge_world_systems.gd` tool for these maps.

---

## D. Coding Conventions

**Naming (mixed, intentional):**
- Gameplay/quest API in **Spanish**: `buscar_comida()`, `completar_comida()`, `quest_hambre_active`
- System scripts in **English**: `get_presence_multiplier()`, `_apply_viewport_layout()`
- New public `GameState` methods → Spanish; new system scripts → English

**Base classes:**
- NPCs/signs extend `scripts/gameplay/interactive_object.gd` (StaticBody2D + dialogue + schedules)
- Exception: `scenes/entities/props/hongos/hongos.gd` (Area2D pickup)
- Minigame: `scripts/gameplay/bollo_fight_minigame.gd` — `enum UiPhase` + signal `finished(victory: bool)`

**Existing groups (do not invent):** `player`, `dialogue`, `time_system`, `world_npc`, `settings_menu`, `welcome_popup`, `music_manager`, `weather_visual_system`

**Responsive UI:** New UI must use `ViewportLayout` (`effective_ui_scale()`, signal `layout_changed`) — see `scripts/ui/song_banner.gd` as reference.

**Input gating:** Respect `DialogueController.input_locked`, `GameState.bollo_training_active`, and pause state from settings/welcome popups.

**Comments:** Spanish for gameplay intent; English acceptable in system headers. Stay consistent within a file.

---

## E. Dialogue (first-class code)

- Dialogue files live next to their entity (`scenes/entities/{npcs|signs|places|props}/{name}/{name}.dialogue`)
- Custom balloon: `scenes/ui/dialogue_balloon/balloon.tscn` + `assets/art/ui/themes/dialogue_theme.tres`
- Quest changes go through `.dialogue` mutations + autoload methods — do not duplicate quest logic in NPC scripts
- Do not edit `addons/dialogue_manager/` except for approved upgrades

Example mutation pattern:

```
do GameState.buscar_comida()
do HongosSpawner.spawn_hongos()
```

---

## F. Folder Layout

```
assets/
  fonts/
  audio/music/
  audio/sfx/
  art/battle|characters|tilesets|props|ui/
  art/maps/web_maizena_rpg/
  docs/briefs/
scenes/
  boot/                  loading_screen, main_scene
  ui/                    settings, welcome, song_banner, minimap, dialogue_balloon/, virtual_joystick
  world/                 bosque_encantado, ciudad_world, pantano_world, world_resources/
  minigames/             bollo_fight_minigame
  gameplay/              player.tscn, music_manager.tscn
  entities/
    npcs/{name}/         .tscn + .dialogue
    signs/cartel_*/      .tscn + .dialogue
    places/              laboratorio, templo_sapos, orbe_electrico
    props/               hongos (+ hongos.gd), bicicleta, piedra_grieta
scripts/
  systems/               time, weather, residue, autonomy, npc_presence, era_system, world_map, map_hotspot
  ui/                    settings, welcome, song_banner, loading_screen, virtual_joystick, minimap, player_settings
  gameplay/              player, interactive_object, bollo_fight, music_manager, main_scene
autoload/                project singletons
tools/                   editor CLI (merge, export, web patch)
web_build/               Netlify deploy artifact (regenerate via export; see §J)
netlify/                 serverless functions (metrics); netlify.toml = COOP/COEP + cache headers
addons/                  dialogue_manager + YATI (Tiled import)
```

---

## G. Manual Validation (no CI)

**Base smoke test** — run after gameplay changes:

1. Start game; confirm player moves with keyboard/tap
2. Talk to `el_viejo`, accept food quest
3. Confirm mushroom spawns at a valid position
4. Pick up mushroom; confirm quest state changes
5. Return to `el_viejo`; complete quest without errors
6. Open/close Settings; confirm volume and input blocking

**Extend as needed** for the area touched: bollo minigame, Noticias popup, music/web visibility pause, weather/residue systems.

Reject any change that breaks scenes or signals that previously worked.

---

## H. Dependencies and Limits

- **Only addon:** Dialogue Manager 3.10.0 — no new plugins without approval
- **External services:** Open-Meteo (`CordobaWeather`), optional metrics via Netlify function (`netlify/functions/`) — no secrets in repo
- **No GUT** — manual testing only
- **No CI/CD** — do not propose GitHub Actions or automated pipelines unless explicitly requested

---

## I. Reference Files for LLM

When implementing a feature, read these first:

| Task | Reference file |
|------|----------------|
| Quest/inventory | `autoload/game_state.gd` |
| Interactive NPC | `scripts/gameplay/interactive_object.gd` |
| Persistence | `autoload/world_state.gd`, `autoload/maizena_meta.gd` |
| Minigame | `scripts/gameplay/bollo_fight_minigame.gd` |
| Player/input | `scripts/gameplay/player.gd` |
| Music | `scripts/gameplay/music_manager.gd` |
| Responsive UI | `autoload/viewport_layout.gd` |
| World time/weather | `scripts/systems/time_day_system.gd`, `scripts/systems/world_map.gd`, `autoload/cordoba_weather.gd` |

---

## J. Netlify Deploy

Production flow:

```
1. Develop and validate in Godot (F5 / loading_screen.tscn)
2. Export Web (preset in export_presets.cfg) → web_build/
3. ./tools/patch_web_build.sh
4. Test web_build/ locally or via Netlify preview
5. Commit + push web_build/  →  Netlify deploys automatically
```

**LLM rules for `web_build/`:**
- Do **not** hand-edit `index.pck`, `.wasm`, `.js`, or other export binaries
- Do **not** commit `web_build/` without running the patch script after export
- Source changes (`.gd`, `.tscn`, `assets/`, entity `.dialogue` files) are **not live** until re-exported and pushed
- COOP/COEP and cache headers live in `netlify.toml` — do not duplicate without reason

**Re-export when:** Any change in `scripts/`, `scenes/`, `autoload/`, or `assets/` must reach web users.

---

## K. LLM Do / Don't Summary

**Do:**
- Read reference files (§I) before implementing
- Use existing groups, signals, and autoload APIs
- Extend `scripts/gameplay/interactive_object.gd` for new NPCs/signs
- Use `ViewportLayout` for new UI
- Run smoke test after gameplay changes
- Re-export web build when shipping to production

**Don't:**
- Invent autoloads, groups, or signals
- Edit `addons/dialogue_manager/` or `web_build/` binaries
- Run a world scene in isolation for testing
- Move session quest state into persisted JSON autoloads
- Propose CI/CD, coverage thresholds, or new addons without approval
- Duplicate quest logic outside `.dialogue` + `GameState`
