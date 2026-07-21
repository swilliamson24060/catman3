# Catman-do — Implementation Plan (Godot 4.7)

This plan adapts the GDD to the existing `catmando` Godot project (currently a 3D CharacterBody3D prototype with an isometric-style fixed camera and the inventory system already built). It targets Godot only — the GDD lists Unity/Godot as options, but since the project is already a Godot 4.7 project, everything below assumes Godot, GDScript, and `Resource`/JSON-based data rather than Unity ScriptableObjects.

The guiding principle from the GDD — **no hardcoded stats, everything data-driven and event-driven** — is preserved throughout: every system below reads from JSON/Resource files and communicates via signals, never by one script reaching into another's internals.

## 0. Foundational Architecture (build first, everything else depends on it)

**Goal:** the "engine" the rest of the game plugs into.

- `res://data/` — core JSON: `buildings.json`, `cats.json`, `animal_types.json` (species definitions — mice at launch, cows and others added later without new code), `items.json`, `resonance_patterns.json`, `Unlocked_Content.json`.
- `res://expansions/` — same schema, scanned at boot (`DirAccess.open("res://expansions/").get_files()`), merged into the core registries. This directly implements GDD section 6 (modular expansion scanning) from day one so mods/DLC never require touching core code. Loading is two-pass: gather every fragment from every expansion file first, merge them all into the registries, and only *then* validate cross-references (a job role's `output` item id, a building's `produces.consumes` id, etc.) — this lets one expansion file introduce both a new animal and the new resource it produces without caring what order files happen to load in.
- Item and animal-type ids are namespaced by mod (`core:milk`, `expansion_undersea:kelp`) to prevent collisions when multiple mods add similarly-named resources; core content lives under the `core:` namespace.
- `DataRegistry` (autoload): loads and parses all JSON at startup into typed dictionaries keyed by `id`. Exposes `get_building(id)`, `get_pattern(id)`, etc. This is the single source of truth — no script should ever hardcode a stat.
- `EventBus` (autoload): a signals-only autoload (`building_constructed`, `mouse_hired`, `pattern_discovered`, `achievement_unlocked`, `weather_changed`, ...). Every system talks through this instead of direct references, matching the GDD's "event-driven state machines."
- `GridService` (autoload): maps between logical grid coordinates (Vector2i) and 3D world transforms. This is what lets 2D billboard sprites and 3D meshes share the same transform space per the GDD's 2.5D fallback requirement — visuals are just "whatever node is attached at this grid cell's transform."
- Save/load: a single `SaveData` resource (`discovered_patterns`, `unlocked_content`, `founder_cat_id`, building/mouse state) serialized with `ResourceSaver`/JSON.

**Deliverable:** empty grid, no visuals yet, but data loads, logs registry contents, and an empty save file round-trips.

## 1. Grid, Blueprints & Fog of War

- Extend `GridService` with a tile-state array (empty / fogged / blueprint / built) and an `AStarGrid2D` for logical pathfinding (mice move on the same grid you build on — no separate navmesh needed for a grid-locked city builder).
- `BlueprintPlacer`: reads `buildings.json` for footprint size/cost, previews placement, validates against fog/occupied cells, emits `EventBus.building_placed_as_blueprint`.
- Fog of war: simple per-tile `revealed: bool`, revealed by proximity to the player cat (reuse the existing `player.gd` CharacterBody3D and its position each `_physics_process`).
- Resource nodes (Wood, Twigs, Yarn): scattered on ungrouped tiles from `items.json`, harvested on player contact — this feeds the existing `Inventory` autoload from the previous session, which already models stacks/icons/tooltips. **The inventory system already built is the player's carried-resources UI** — no new inventory needed, just new `InventoryItem` resources for Wood/Twigs/Yarn/Cheese.
- One schema change from the original inventory build: `InventoryItem` gets a generic `properties: Dictionary` field alongside its fixed `id`/`display_name`/`icon`/`max_stack`/`description`. Mechanic-specific data (Cheese's `variety`/`age` for spoilage, a future Wool's `sheared_from` link, anything else a mod invents) lives in `properties` instead of requiring a new export var on the core script every time a mechanic needs one more attribute per item.

**Deliverable:** cat walks around, reveals fog, picks up raw resources into the existing inventory, places a blueprint on a valid tile.

## 2. Founder Cat Selection

- `cats.json` defines the three founders with `primary_pro`/`primary_con` as structured modifiers (same `{target, stat, modifier_type, value}` shape as resonance bonuses, for consistency — reuse the same "apply_global_bonuses" function for both founder traits and pattern bonuses).
- A pre-game `CanvasLayer` select screen (Barnaby / Whisper / Turbo), each backed by a `.tres`/JSON entry with portrait, description, and the modifier list. Selecting one calls the same `apply_global_bonuses()` used later by Architectural Resonance — one code path, two triggers.
- Store `founder_cat_id` in `SaveData` immediately so runs are reproducible and moddable (a 4th founder cat is just a new JSON entry).

**Deliverable:** selection screen → modifiers visibly affect construction speed / harvest rate / recruitment rate in the HUD.

## 3. Livestock Framework: Recruitment & Workforce (Mice First, Built to Take Cows Later)

Rather than a mice-only `MiceManager`, build a single species-agnostic `AnimalManager` from the start. This is the one architectural change from the original draft, made specifically so cows (or any future animal — chickens, bees, whatever) are a data addition, not a new subsystem.

- `animal_types.json` defines each recruitable species as data: `id`, `display_name`, `housing_building_type`, `movement_speed`, `job_roles` (each with `duration`/`output`, matching the shape buildings already use), `upkeep` (what it costs to keep one happy — cheese variety for mice, feed/water for cows), and an `attracts` list for side effects (see below).
- `AnimalManager` (autoload): one pool of animal instances regardless of species, each a small `Resource` holding `species_id`, `role`, `morale`, and a generic `inventory` array (covers both GDD's Mouse Guilds tool slots and anything a cow might carry/wear later).
- Recruitment UI generalizes from "Cheese Board" to a **Recruitment Board**: reads `animal_types.json` to show whichever species have an available housing building on the map, and spends whatever `upkeep`/cost that species' entry specifies (Cheese for mice, feed for cows) — all through the existing `Inventory`/`TownStorage` item system, no new currency logic.
- Animal behavior state machine (`Idle → MovingToJob → Working → Idle`) is the same for every species, driven by `AStarGrid2D` from step 1; only the `duration`/`output` numbers it reads from `animal_types.json`/`buildings.json` differ per species and per job role.
- Delegation UI: assign idle animals to jobs, or use **Laser Pointer Prioritization** (raycast click → `EventBus.priority_target_set(grid_pos)` → idle animals of any species re-path toward it).

**Cows, concretely, once this framework exists:** a `building_barn` housing entry, a `cow` row in `animal_types.json` with a `produce_milk` job role, `Milk` added to `items.json`. Milk feeds two places: a happiness modifier on cats (same `{target: "founder_cat", stat: "happiness", modifier_type: "additive", value: ...}` shape used everywhere else) consumed directly, and a `building_creamery` that converts Milk → Cheese (closing the loop back into mice's existing upkeep cost). The `attracts` field on the cow's `animal_types.json` entry (e.g. `attracts: "stray_cat_visit_chance"`) is read by the Stray Cat Visitors event controller (step 6.9) to raise spawn odds — no code change there either, just a new event-weight input it already reads generically.

**Deliverable:** recruit a mouse, assign it to a resource node, watch it path there, gather, and return — proving the generic animal loop works before cows are ever added.

## 4. Automated Construction & Production

- Construction: assigned mice walk to a blueprint tile, a progress timer runs (modified by founder cat / resonance bonuses read live from `DataRegistry`), building flips from blueprint → built and emits `EventBus.building_constructed(building, save_data)` — **this is the exact hook point for the Architectural Resonance detector**, so wire that in now rather than bolting it on later.
- Production: built buildings with a `produces` field in `buildings.json` run a timer per game tick, converting inputs → outputs into a town-level storage (separate from the player's personal `Inventory` — town storage is a new lightweight autoload, `TownStorage`, sharing the same `InventoryItem` resource type so icons/stacking logic aren't duplicated).

**Deliverable:** full loop closes — explore, blueprint, recruit, mice build it, building produces goods automatically.

## 5. Architectural Resonance (implement exactly per GDD's given schema)

- Port `resonance_patterns.json` and the pseudocode in GDD section 5 almost verbatim:
  - `check_grid_offsets_match(position, required_offsets)` checks the anchor's offsets across all 4 cardinal rotations (rotate offset vectors by 0/90/180/270° before matching).
  - `discovered_patterns` lives in `SaveData`, checked/appended exactly as specified, enforcing the one-time-only rule.
  - `apply_global_bonuses(pattern.bonuses)` is the same function used for founder cat traits (step 2) — `{target, stat, modifier_type, value}` is a generic enough shape to cover both.
- `trigger_discovery_ui` — a toast/banner using the same lightweight `CanvasLayer` overlay pattern as the inventory panel.

**Deliverable:** building three Mouse Huts around a Catnip Garden in the documented triangle fires the one-time bonus and shows the discovery banner; re-triggering the same pattern does nothing.

## 6. Remaining 11 Mechanics — Priority Order

Grouped by implementation cost, cheapest/highest-impact first:

1. **Grooming & Dust Bunnies** — trivial random spawner + click-to-collect, good early "juice."
2. **Whisker-Radar Hot/Cold** — a distance calculation driving a UI shader/animation; no new systems needed.
3. **Cardboard Tier & Rain Events** — add `waterproof: bool` and `tier` to `buildings.json`, a global weather timer in a new `WeatherService` autoload, damage tick on non-waterproof buildings during rain.
4. **Thermal Warmth Grid** — heat-map values per tile (reuses `GridService`'s tile array), sunbeam node emits heat in a radius, mice/cat napping on hot tiles get a temporary buff via the same modifier structure as everything else.
5. **Catnip Drift Dynamics** — extends `WeatherService` with a wind vector; propagate scent intensity from Catnip Gardens downwind each tick, modifying work speed / guard-mouse alertness.
6. **Cheese-Standard Salary** — item-aging timer on cheese stacks in `TownStorage`, morale penalty on mismatch/underpayment feeding into the animal state machine's `Idle→Strike` transition (species-generic, so a future cow "won't work without fresh feed" penalty reuses the exact same path).
7. **Mouse Guilds & Tiny Tools** — the generic `inventory` array on each animal instance (small reuse of `InventoryItem`/slot concepts, just 1-3 slots, no drag-and-drop needed) plus a job-XP counter, applicable to any species.
8. **Cat-Nap Fast-Forward** — global `Engine.time_scale = 5.0` toggle, plus a pastel post-processing shader and "ghost" prediction overlay (run the mouse pathfinding sim one step ahead and render translucent duplicates).
9. **Stray Cat Visitors** — random event controller spawning at map-edge tiles with a simple dialogue/trade UI (reuse the founder-cat-select screen's UI pattern for portraits + choice buttons).
10. **Gravity "Cat-Stack" Scaffolds** — vertical construction state with a wind-driven balance mini-game (a single oscillating slider bar); scope this last since it needs the most bespoke interaction code and has the weakest dependency on other systems.

## 7. Achievement & Unlock Engine

- `Unlocked_Content.json` registry mirrors `discovered_patterns`: an `AchievementService` autoload listens on `EventBus` for qualifying events (first building of a type, N mice recruited, first resonance pattern, etc.), writes to the registry, and emits `achievement_unlocked` which the building-menu UI checks to reveal new options — exactly the "dynamically enabling new building options" requirement, no server calls involved.

## 8. Modular Expansions

- Already scaffolded in step 0. Validate with the two example expansions from the GDD (`Expansion_Undersea.json`, `Expansion_SpaceMice.json`) as smoke tests once the core loop (steps 0–5) is solid — this proves new building/item types can be added without touching engine code. A good smoke test specifically for resource extensibility: have one of the two example expansions introduce a brand new animal *and* a brand new resource type it produces in the same file, confirming the two-pass load/merge handles same-file cross-references correctly.

## 9. Polish Pass

- Save/load robustness, performance pass on mouse pathfinding at scale (pool `AStarGrid2D` queries, cap active pathing mice per frame), audio, and the 2D-sprite-fallback path for any building/mouse assets that don't have 3D meshes ready (billboard `Sprite3D` swapped in at the same `GridService` transform, per the GDD's zero-code-change requirement).

## Suggested Build Order Summary

| Milestone | Depends on | Unlocks |
|---|---|---|
| 0. Data/Event/Grid core | — | everything |
| 1. Grid, blueprints, fog, resources | 0 | exploration loop |
| 2. Founder cat select | 0 | run-level modifiers |
| 3. Animal framework + mice recruitment | 1 | delegation loop, ready for future species |
| 4. Auto construction/production | 3 | full core loop closes |
| 5. Architectural Resonance | 4 | signature mechanic live |
| 6. Remaining 11 mechanics | 4–5 (varies) | full mechanics manual |
| 7. Achievements | 4 | progression/unlocks |
| 8. Expansion loader validation | 0, 6 | modding proven |
| 9. Polish | all | ship |

Steps 0–5 constitute a playable, demoable core loop and should be treated as the MVP milestone; steps 6–9 can be parallelized or reordered based on which of the 12 mechanics you want to showcase first.

## Extensibility Note: Adding New Animal Types (e.g. Cows)

This is why step 3 was changed from a mice-only manager to a generic `AnimalManager`. Adding cows later is purely additive — no existing script needs to change:

1. Add a `cow` entry to `animal_types.json`: housing = `building_barn`, a `produce_milk` job role with its duration/output, and upkeep (feed/water) cost.
2. Add `Milk` to `items.json` as a normal `InventoryItem`-compatible entry — it stacks, has an icon, and flows through `TownStorage` like every other good.
3. Add `building_barn` and `building_creamery` to `buildings.json`. The creamery's `produces` field reads `{consumes: ["Milk"], outputs: ["Cheese"]}` — the same production-timer code from step 4 handles it, since it's already generic over inputs/outputs.
4. Add a happiness bonus entry using the existing modifier shape: `{target: "founder_cat", stat: "happiness", modifier_type: "additive", value: X}`, applied when Milk is consumed.
5. Add an `attracts` weight to the cow's `animal_types.json` entry that the Stray Cat Visitors controller (already reading event weights generically) picks up to raise stray-cat spawn odds near barns.
6. Recruitment Board UI automatically lists cows once a barn exists on the map — no UI code change, since it already reads `animal_types.json` for whichever species have housing available.

No new manager class, no new state machine, no new UI screen — the entire addition is JSON plus two building entries, which is exactly the "vibe-coding"-friendly extensibility the GDD asks for.

## Extensibility Note: Adding New Resource Types

Following on from the cows example — Milk itself is a new resource type, so this is really the same capability viewed from the item side. A modder adding, say, Wool from a future Sheep works the same way:

1. Add `wool` to the expansion's own `items.json` fragment (namespaced as `expansion_x:wool` to avoid colliding with anyone else's `wool`), with whatever `properties` the mechanic needs (e.g. `{"warmth": 3}` if it feeds the Thermal Warmth Grid mechanic).
2. Reference `expansion_x:wool` from a `job_role.output` on the new animal, and/or from a building's `produces.consumes`/`outputs` — both already treat item ids as opaque strings, so no engine code cares that the id is new.
3. Icon and any other assets ship inside the expansion's own folder and load via a normal `res://expansions/expansion_x/...` path — `load()` doesn't care whether a texture came from core or a mod.
4. The two-pass registry load (gather all fragments, merge, then validate) means the new item, the new animal that produces it, and any building that consumes it can all be defined in the same expansion file, in any order, without a "missing item id" validation error.

The one thing this *doesn't* give you for free is UI text/iconography choices (a modder still has to draw an icon and write a description) — but no core script needs to change to add a resource, which is the actual extensibility bar the GDD sets.
