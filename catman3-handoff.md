# Catman3 — Hand-off Document

This document is written so that another LLM (or a human) can pick up this project cold, with no prior context, and understand what the game is, what's been built, what it looks like, and what's left. If you're that reader: start here, then follow the pointers into the docs listed at the bottom as needed. Don't assume anything not written down here or in those docs — verify against the actual code/scenes before making claims about current behavior.

## 1. What this project is

**Catman3** is a Godot 4.7.1 project. It is a fork/continuation of a sibling project called `catmando` (a sibling directory on this machine, `~/catmando`), and it is itself mid-way through a full **reboot** of an earlier prototype ("Catmando" / "Catman-do"). The reboot is the active, current design — the original prototype still exists in the codebase for regression/compatibility reasons but is not the game being built forward.

There is also a `chart-ladder` repo elsewhere on this machine — that is a **different, unrelated game** (a word/tile game), not part of this project. Don't confuse the two if you see both mentioned in memory or context.

### 1.1 The one-line pitch

A small, combat-free, cozy settlement game: you are the founding cat of a neglected woodland clearing. You explore, listen, and propose community priorities; a small cast of named residents autonomously choose how to help; together you uncover a lost "Seasonal Resonance" pattern-magic system that transforms the village when solved correctly.

It deliberately blends:
- the personal attachment / discovery / seasonal rhythm of a life-sim,
- the readable isometric world / worker autonomy / visible growth of a classic RTS,
- a bespoke mystery mechanic (Seasonal Resonance) where the village discovers ancient spatial "machines" that activate only when the right pattern + components + natural condition (weather/time) line up.

**No combat, no hard failure states, no starvation/timer pressure.** Design pillars (see `docs/CATMANDO_REBOOT_PROJECT_PLAN.md` §2.3 for the authoritative version):
1. A small place with deep consequences — one dense clearing, one woodland route; every addition should change behavior or appearance, not just pad content.
2. Residents are people, not production units — names, homes, routines, aspirations, relationships.
3. Peaceful strategy is readable — plan from an isometric view, propose priorities, watch autonomous work unfold; no micromanagement.
4. Discovery creates surprise — knowledge is found through exploration/rumor/observation, not a visible tech tree.
5. Rewards are visible before numerical — new flowers, gatherings, crafts, sounds matter more than % bonuses.
6. Nature is a collaborator — the Resonance system works *with* weather/light/water/season, not against them.

### 1.2 Core gameplay loop

1. Begin a day, talk to residents.
2. Choose a community priority or personal activity.
3. Explore the clearing / woodland for resources, rumors, relics, machine parts.
4. Bring discoveries back for investigation.
5. Place/contribute to a project, path, garden, building, or Resonance component.
6. Residents voluntarily contribute based on personality/skill/needs/friendship/schedule (not commanded).
7. See a visible result — changed routine, finished project, new craft, social gathering, Resonance reaction.
8. End the day with a short journal summary; unfinished work safely continues tomorrow.

### 1.3 The proof-of-concept content ("The First Bloom")

The shippable vertical slice (already built, see §2 below) is centered on one complete story arc: restore the village's abandoned community garden, discover three components (a rain lens, a carved copper gear, dormant heirloom seeds) via exploration, place them on three ruin-clue plinths in a triangle around the garden's old tree, and trigger activation on the next rain→sunrise transition. This produces a permanent visible change (new flower colors, a garden-gathering social activity, an Almanac record) — not a numeric bonus. Full spec: `CATMANDO_REBOOT_PROJECT_PLAN.md` §3 and §6.

## 2. Mechanics actually built (status: all "Complete" below have working, tested code)

The project is organized into **milestones**, each tracked with a dated "Status" paragraph in `docs/CATMANDO_REBOOT_PROJECT_PLAN.md`. As of this writing:

| Milestone | What it is | Status |
|---|---|---|
| 0 | Reboot seam: legacy prototype preserved at `scenes/world/main.tscn`, new dev entry point is `scenes/world/village_clearing.tscn` behind `feature/reboot_mode` | Complete |
| 1 | Handcrafted clearing (55×55m, grown from 45×45m for a buffer ring), camera, founder movement/interaction, woodland route, ruin | Complete |
| 2 | Calendar (Morning/Afternoon/Evening/Night), weather forecast/rain/wind, day-end journal | Complete |
| 3 | Three named residents (Mara the gardener, Pip the tinkerer/builder, Elowen the historian) with scored autonomous routines | Complete |
| 4 | Relationships (symmetric bond, remembered moments), four social places | Complete |
| 5 | Community garden restoration project (5 phases, resident + founder contribution) | Complete |
| 6 | Woodland exploration, rumors, discovery pipeline (found → investigated → interpreted), Almanac | Complete |
| 7 | Seasonal Resonance solver (tolerant world-space geometry, 5 feedback tiers), The First Bloom pattern | Complete |
| 8 | Communal irrigation machine + first craft family (natural dyes) | Complete |
| 9 | First Bloom celebration event (resident contributions, player choice, closing sequence) | Complete |
| 10 | HUD, Village Journal, accessibility (remappable input, text scale, high contrast, hint ladder) | Complete |
| 11–14 | Terrain/wall-clock foundation, Wave Function Collapse generator, home "growth plot" (plant a seed, resolves over real elapsed time), resident solo expeditions to generated areas | Complete |
| 15 | Founder selection (pick one of 3–4 founder cats, each biases resident activity choices), deeper resident conversation system, Meshy-AI 3D models for founder + residents | Complete |
| 16 | Cohesive art/audio/game-feel pass — **in progress**, see §4 below | Partial |
| 17 | Validation, cleanup, release slice | Not started |

Full narrative detail (what was actually built, what deviated from the original spec and why) for every milestone above is in `CATMANDO_REBOOT_PROJECT_PLAN.md` — read that doc's "Status" paragraphs before touching any of these systems, they explain real gotchas.

### 2.1 A system *not* in the milestone plan: Elowen's cottage (WFC construction prototype)

Separately from the numbered milestones, there is a **Wave-Function-Collapse-driven cottage-building prototype** for one resident (Elowen), added in commits `990dd11`→`b135ca5`. It's a real, tested 3D-grid piece-placement system (`core/cottage_build_service.gd` + `scripts/buildings/cottage_construction_site.gd`) that grows a cottage over real elapsed time using foundation/stackable/roof pieces with a support/cantilever rule, using a real 12-piece pastel-granite asset set (`cottage/models/elowen/`, `data/cottage_pieces.json`). **It is deliberately not wired into `SaveService`** — it's described in its own commits as "a pre-art mechanic test, not a shipped feature." Mara and Pip's homes are still flat placeholder blocks. Treat this as an experimental branch of work, not part of the milestone-tracked plan, unless/until someone decides to formalize it.

### 2.2 Data-driven convention

Almost everything (residents, rumors, discoveries, projects, resonance patterns/components, crafts, cottage pieces, terrain tiles, founder cats, buildings, achievements, audio cues, village events) is defined in JSON under `data/*.json` and loaded by the `DataRegistry` autoload — not hardcoded. New content (a new resident, a new discovery, a new Resonance pattern) should almost always be a data change plus small service glue, not new bespoke systems. There's also an expansion-loading mechanism (see `Expansion_*.json` references in the plan) proven with one real example (`kelp_bed` terrain tile in `Expansion_Undersea.json`).

## 3. Technical architecture

- **Engine:** Godot 4.7.1, GDScript, `CharacterBody3D`-based, `1 Godot unit = 1 meter`.
- **Active dev scene:** `res://scenes/world/village_clearing.tscn` (this is `run/main_scene` in `project.godot`). The legacy prototype (pre-reboot) still boots from `res://scenes/world/main.tscn` for regression purposes only — do not build new gameplay there.
- **Autoloads** (see `project.godot`'s `[autoload]` section for the authoritative list): `EventBus`, `DataRegistry`, `GridService`, `SaveService`, `StatsService`, `Inventory`, `TownStorage`, `WeatherService`, `AnimalManager` (legacy), `ResonanceService` (legacy exact-grid), `AchievementService`, `AudioService`, `AppearanceService`, `GameState`, `SimulationClock`, `SettlementManager`, `ScaffoldService`, `CalendarService`, `RelationshipService`, `CommunityProjectService`, `RumorService`, `DiscoveryService`, `InvestigationService`, `ResidentManager`, `SeasonalResonanceService` (reboot tolerant-geometry solver), `CommunityMachineService`, `CelebrationService`, `UserExperienceService`, `GrowthPlotService`, `ExpeditionService`, `AlmanacNotificationService`, `CottageBuildService`.
- **Save system:** `core/save_service.gd` + `core/save_data.gd`, versioned (schema v4+), persists day/period, residents, relationships, projects, discoveries, placed objects, Resonance attempts, ecology, story state, founder choice, growth plot, expeditions. Local save file lives at `user://` (on this machine: `~/Library/Application Support/Godot/app_userdata/Catmando/catmando_save.json`) — **a stale dev-test save (`founder_milestone9`) exists there from earlier development** and will auto-load in headless mode and offer a resume-or-new-game choice in a live GUI run. If you see unexpected pre-installed machines/buildings during live testing, check whether it's this stale save before assuming it's a bug (this exact thing happened during the nature-asset session — a fully-installed workshop irrigation machine part rendering in a dusty-rose color was mistaken for a texture bug before being traced to this).
- **Key directories:**
  - `core/` — the bulk of autoload services (43 files).
  - `data/` — JSON content definitions.
  - `scenes/` — `.tscn` scenes: `world/` (clearing, woodland, ruin), `residents/`, `projects/`, `resonance/`, `buildings/`, `ui/`, `player/`, `discoveries/`, `social/`, `machines/`, `events/`, `picnic/`.
  - `scripts/` — supporting `.gd` for the above (`scripts/world/`, `scripts/residents/`, `scripts/buildings/`, `scripts/construction/`, `scripts/tests/`, `scripts/ui/`, `scripts/social/`, `scripts/mice/`, `scripts/player/`, `scripts/discoveries/`, `scripts/resonance/`).
  - `founder/` — founder selection UI + `CatAppearance` model/coat system.
  - `residents/` — `ResidentAppearance` model system + per-resident `models/<id>/` Meshy AI exports.
  - `cottage/models/elowen/` — the cottage-piece GLB set.
  - `environment/` — ground textures (`textures/`) and, as of the nature-asset work, MegaKit 3D models (`models/nature/`).
  - `tools/` — one-off dev scripts (portrait generation etc.); **treat this directory as scratch** — the convention this session followed was to create temporary diagnostic/capture scripts here and delete them immediately after use, never leaving `project.godot`'s `run/main_scene` pointed at a temp scene between turns (see §5.3 for why this matters).

### 3.1 Testing convention

- `scripts/tests/*.gd` are standalone scripts (`extends SceneTree`), each runnable directly: `godot --headless --script res://scripts/tests/some_test.gd --path <project>`. There is **no test runner** — iterate over the directory yourself in a shell loop.
- Exclude `*_visual_capture.gd` files from headless batch runs — they need a live renderer (Godot's headless mode uses a dummy renderer).
- As of this writing there are 43 non-visual-capture test files, all passing.
- Known **false positives** when grepping test output for "error"/"fail": the string `failure_rate` (a legitimate stat name) matches `fail`, and `milestone11_terrain_foundation_smoke_test.gd` intentionally triggers a `Parse JSON failed` error as part of testing broken-fixture handling. Neither is a real failure.
- After adding/editing any `.gd`/`.tscn`/asset file that a headless test run needs to see, **run a project rescan first**: `godot --headless --editor --path <project> --quit`. A fresh script/scene/asset isn't reliably picked up by a `--script` run otherwise (this bit us repeatedly — new `class_name` scripts, new imported textures/models, and edited `.import` files all needed this).
- Live visual verification (screenshots) requires the actual editor/game process, not headless. The working technique this session used: write a throwaway capture scene under `tools/` that instantiates the real gameplay scene, waits a couple of frames, positions a temp `Camera3D`, calls `get_viewport().get_texture().get_image().save_png(...)`, then `get_tree().quit()`; temporarily point `project.godot`'s `run/main_scene` at it; run via the Godot MCP tool (`run_project`/`get_debug_output` — there is no direct screenshot MCP tool); read the saved PNG; **immediately revert `run/main_scene` and delete the temp files** before doing anything else, even before the next turn. Leaving that swap in place broke the actual game boot at least once this session when a background disconnect interrupted the sequence.
- The stray top-level files `WFC sprites/`, `cobblestone_bases.png`(+`.import`+`.kra`), `transparent sprite sheet.png`(+`.import`+`.kra`) are untracked, unexplained, and **not part of this project's committed work** — leave them alone, don't stage them in commits, and don't delete them without asking (ownership/purpose unclear).

## 4. Look and feel / graphics — current state

**Target direction** (from `docs/environment_art_brief.md` and `CATMANDO_REBOOT_PROJECT_PLAN.md` §8.1): a warm, toy-like woodland diorama — chunky silhouettes, restrained detail, painted surfaces, soft shadows, expressive character animation, orthographic isometric camera (38° pitch, four 90° snap angles).

**What's actually in the game right now (mixed placeholder + real art):**

- **Founder cat & residents:** real rigged/animated Meshy-AI-generated `.glb` models (Milestone 15), replacing the old shared flat-tinted placeholder. Founder portraits in the selection UI are **stale** — they still show the old placeholder look and haven't been regenerated to match the new 3D models (tracked as an open TODO, see §5).
- **Elowen's cottage:** real GLB pieces (12-variant pastel granite stack set + three replacement roof shapes: Northwest Lodge, Minaret, and Pyramid). Each roof shape has data-driven pastel peach, baby blue, and mint variants that share geometry and apply a per-instance material tint. Mara and Pip's homes are still flat colored placeholder boxes.
- **Trees (village clearing + woodland route):** as of the most recent work, real 3D models from the **Stylized Nature MegaKit** (Quaternius, CC0 license — see `WFC sprites/Stylized Nature MegaKit/License_Standard.txt`, no attribution legally required), replacing the old procedural cylinder+sphere placeholder trees. Species are weighted-random per placement (common/pine trees common; twisted/dead trees deliberately rare, since the twisted-tree foliage texture is a saturated autumn red that reads as a jarring accent against the game's otherwise soft palette at full frequency).
- **Ground:** one continuous world-space procedural material (`environment/shaders/clearing_ground.gdshader`) now replaces the visible raised rectangular zone plates. It paints broad low-frequency grass variation, a softly irregular winding woodland path, and blended village/garden/workshop wear without tiling an image. A visual-only forest-floor apron extends to 76×76m behind the treeline, while the original 55×55m collision floor and invisible boundary walls still constrain characters; the south woodland gate is the only walk-through opening. The MegaKit has no terrain texture; its prop atlases remain used only by their intended models.
- **Ground *coverage*** comes from real 3D vegetation: a zone-aware `MultiMeshInstance3D`-based grass/clover carpet (~8,000 GPU-instanced, shortened tufts, one draw call per species). A grass-specific shader normalizes the kit atlas's orange/yellow variants into a cohesive green range while retaining silhouette/alpha variation. MegaKit ferns, flowers, mushrooms, rocks, and rare bushes are weighted and clustered along both sides of the path as well as the woodland buffer. All dressing is implemented in `scripts/world/nature_props.gd` and wired into the clearing/route; it remains skipped in headless tests.
- **UI:** functional HUD/journal/almanac exist (Milestone 10) with a warm-toned bordered-panel look; final icon/glyph/portrait art per `docs/ui_art_brief.md` has not been commissioned.
- **Everything else** (Resonance plinths/VFX, machine states, celebration props, discovery relics) is still placeholder-quality per each system's own art brief (see §6 list) — functionally complete, visually unfinished.

**Net picture:** terrain/vegetation just had its real-art pass (Milestone 16 step 2 "replace terrain and large landmarks" + step 5 "replace vegetation/flowers" are the only steps started); residents/buildings/UI/audio (steps 3, 4, 6, 7) have not.

## 5. What's left to do

Roughly in the order it'll naturally come up:

1. **Regenerate founder portraits** to match the new 3D founder models (tracked, not started — the selection-screen portraits are still the old look).
2. **Finish Milestone 16** (cohesive art/audio/game-feel pass): residents, buildings (Mara/Pip cottages still boxes), project-phase variants, props/components, UI/icons, interaction audio (footsteps, work sounds, ambience, placement feedback), then profile triangle/material/texture/draw-call budgets. See `CATMANDO_REBOOT_PROJECT_PLAN.md` Milestone 16 for the full step list and its in-progress status note.
3. **Decide the ground's fate:** current flat-color-plus-vegetation-carpet approach works and passes review, but if a textured ground is still wanted, it needs genuinely tileable source art (hand-authored or a licensed pack made for terrain), not a repurposed prop atlas.
4. **Decide Elowen's cottage system's fate:** it's a real, tested feature sitting outside the milestone plan and outside the save system. Someone needs to decide whether to formalize it (wire into `SaveService`, extend to Mara/Pip) or leave it as a permanent prototype.
5. **Milestone 17** (validation/cleanup/release slice): full regression pass, remove now-safe deprecated autoloads (see `docs/deprecated_systems.md` for exact removal criteria per system — don't remove anything until its criterion is actually met), save-migration/corruption-recovery validation, cross-platform export builds, performance baseline, content-authoring guide.
6. **Content expansion** is explicitly gated until Milestone 17 passes (`CATMANDO_REBOOT_PROJECT_PLAN.md` §9) — don't add new regions/residents/patterns before then.

## 6. Other Markdown documents in this repo

| File | Covers |
|---|---|
| `docs/CATMANDO_REBOOT_PROJECT_PLAN.md` | **The authoritative design + implementation plan.** Product definition, core loop, design pillars, the vertical-slice scope and its First Bloom pattern spec, what to keep/adapt/remove from the old prototype, target architecture, resident/relationship/project/discovery/Resonance data schemas and lifecycles, per-milestone implementation steps *and* dated "Status" completion write-ups (the real build log — read this for what actually happened, not just what was planned), the art asset plan and batch list, content-expansion rules for after the slice ships, and working instructions/definition-of-done for whoever (human or LLM) implements a milestone. This is the single most important doc in the repo. |
| `docs/environment_art_brief.md` | Visual Direction Asset Batch A: locked clearing/camera dimensions, the six ground-zone footprints, requested concept-art deliverables. **Now includes a 2026-08-16 update marking the ground-texture request superseded** — see §4 above for why. |
| `docs/character_art_brief.md` | Character Asset Batch B: founder + three residents' scale, origin, animation-socket, and delivery contract for commissioned character art. |
| `docs/village_kit_art_brief.md` | Village Kit Asset Batch C: cottages, workshop, garden-phase variants, paths/fences/signs/social-prop contract. |
| `docs/exploration_art_brief.md` | Exploration Asset Batch D: woodland vegetation, ruin modules, relic/component/investigation-prop contract. |
| `docs/resonance_art_brief.md` | Seasonal Resonance Asset Batch E: plinth/component sockets, five-tier feedback VFX language, activation sequence contract. |
| `docs/machine_craft_art_brief.md` | Machine/Craft Asset Batch F: irrigation machine state variants, craft-output contract. |
| `docs/celebration_art_brief.md` | Celebration Asset Batch G: First Bloom event staging, contribution slots, decoration-choice contract. |
| `docs/ui_art_brief.md` | UI Asset Batch H: HUD/Almanac/board/journal/map style guide and icon/accessibility-variant contract. |
| `docs/deprecated_systems.md` | Table of legacy-prototype systems kept only for regression compatibility (salaries, generic recruitment, right-click orders, catnip drift, Dust Bunny rewards, Whisker Radar, cat-stack scaffolding, dream-mode prediction, Cheese Vault, old expansions, the 70×70 uniform field, exact-offset Resonance, military iconography) — each with its specific removal criterion. Check this before deleting anything that looks unused. |
| `docs/implementation_plan.md` | An **earlier, largely superseded** Godot implementation plan for the pre-reboot "Catman-do" prototype (Phase 1/2 economy/inventory system). Historical context only — the reboot plan above is what's active now. |
| `AGENTS.md` | Funplay MCP-for-Godot integration notes (local MCP endpoint, project skill file location) — tooling setup, not game design. |
| `DEVELOPMENT_CHECKLIST.md` | A short, mostly-legacy checklist (contentment factors, unhappy-mouse behavior, HUD music toggle) from the pre-reboot prototype. Mostly stale. |
| `PHASE2_CHECKLIST.md` | Legacy "Phase 2" implementation checklist (economy foundation, per-mouse cheese, simulation clock) from before the reboot. Historical context only. |
| `docs/Catman-do_Game_Design_Document.pdf` | The original game design document (PDF, not Markdown) that `implementation_plan.md` was adapted from. Predates the reboot; useful only for original-vision archaeology. |
| `hand-off.md` (this file) | You are here. |

---

*Last updated 2026-08-16, after the Stylized Nature MegaKit tree/ground-decoration work (see `CATMANDO_REBOOT_PROJECT_PLAN.md` Milestone 16 status and git commits `2d1ff8a`/`51e8e56`). If you're picking this project up and make non-trivial changes, update this file's relevant section(s) rather than leaving it to drift.*
