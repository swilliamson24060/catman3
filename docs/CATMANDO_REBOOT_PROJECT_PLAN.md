# Catmando Reboot Project Plan

## 1. Purpose

This plan converts the current Catmando prototype into a small, expandable, combat-free cozy settlement game combining:

- the personal attachment, collecting, relic discovery, seasonal rhythm, and expressive village life of a life simulation;
- the readable isometric world, exploration, worker activity, settlement planning, and visible growth of a classic single-player real-time strategy game;
- a distinctive mystery system in which the village discovers ancient spatial machines that activate only when the correct pattern, components, and natural conditions meet.

This is an implementation plan for Codex working in Godot 4.7. It is deliberately ordered so that the project becomes playable early, placeholder art can be used safely, and final art is requested only after dimensions, camera, and interaction needs are proven.

The reboot is not a miniature version of the old feature list. It is a change in the game's center of gravity:

> The player explores to recover lost knowledge, then works with a small cast of residents to build a village that behaves differently because of what they discovered.

## 2. Product Definition

### 2.1 Player fantasy

The player is the founding cat of a neglected woodland clearing. They do not command an army or own every resident. They explore, listen, propose community priorities, arrange the village, help with projects, and watch autonomous residents turn shared plans into daily life.

### 2.2 Core loop

1. Begin a day and speak with residents.
2. Choose one community priority or personal activity.
3. Explore the clearing or nearby woodland for resources, rumors, relics, and machine parts.
4. Return discoveries to the village for collaborative investigation.
5. Place a project, path, garden, building, or Resonance component.
6. Residents voluntarily contribute according to personality, skills, needs, friendships, and schedule.
7. Observe a visible result: a changed routine, completed project, new craft, environmental transformation, social gathering, or Resonance reaction.
8. End the day with a short journal summary. Unfinished work safely continues tomorrow.

There is no combat, enemy pressure, hard failure timer, starvation spiral, or irreversible failure caused by experimentation.

### 2.3 Design pillars

1. **A small place with deep consequences.** Start with one dense clearing and one woodland route. Every major addition must change behavior or appearance.
2. **Residents are people, not units.** Residents have names, homes, routines, aspirations, relationships, and useful specialties.
3. **Peaceful strategy is readable.** The player plans from an isometric view, proposes priorities, and watches work unfold without micromanaging every action.
4. **Discovery creates surprise.** Important knowledge is found through exploration, rumors, observation, and low-cost experiments rather than unlocked from a visible technology tree.
5. **Rewards are visible before they are numerical.** New flowers, gatherings, clothes, sounds, visitors, and crafts matter more than percentage bonuses.
6. **Nature is a collaborator.** Seasonal Resonance mechanisms work with weather, light, water, wind, and seasons rather than overpowering them.

### 2.4 What makes Catmando different

The player does not primarily collect furniture and customize a private home. They shape a cooperative settlement simulation. Buildings create jobs and social routines. Discoveries are interpreted by the community. Ancient patterns transform ecology, craft, and village behavior. Residents contribute to and personalize the result.

## 3. First Shippable Scope: The Community Garden Vertical Slice

Do not build a large world first. The first complete version contains:

- one handcrafted village clearing approximately 45 x 45 meters;
- one short woodland exploration route with three small branches;
- the founder cat;
- three named residents: a gardener, a tinkerer/builder, and a curious historian;
- three resident homes, initially represented by plots or simple cottages;
- one workshop;
- one abandoned community garden;
- one ancient Stonehenge-like ruin;
- a day/evening/night cycle and lightweight weather;
- resource gathering sufficient to complete the garden;
- one community priority: restore the garden;
- three linked discoveries: an old plaque, an irrigation component, and the first Resonance clue;
- one machine: the repaired irrigation device;
- one discoverable Seasonal Resonance pattern: **The First Bloom**;
- one social payoff: residents begin gathering in the restored garden;
- one village event: the First Bloom celebration;
- saving and loading at any point outside an active cutscene.

### 3.1 The First Bloom pattern

The ruin provides a strong but incomplete triangular clue. The correct solution is:

- **Pattern:** three small standing-stone plinths in a triangle around the restored garden's old tree;
- **Components:** a rain lens, a carved copper gear, and a packet of dormant heirloom seeds;
- **Condition:** rain followed by the next morning's sunrise;
- **Partial feedback:** stones emit faint motes for correct component types; lines briefly shimmer for correct adjacency; the center tree rustles when all three positions are correct; outside the activation condition the mechanism remains dormant but clearly promising;
- **Activation:** at sunrise, water and light travel through the triangle, new flower colors grow, residents gather, and the Almanac records The First Bloom;
- **Permanent effects:** new flower colors enter the local seed pool, the gardener gains a new aspiration step, garden gatherings become possible, and decorative dyes become a future unlock;
- **No raw production multiplier is shown to the player.** Any supporting numerical modifier remains secondary and is described through resident behavior.

### 3.2 Vertical-slice completion test

The slice is successful when a new player can, without developer explanation:

1. meet the three residents;
2. understand why restoring the garden matters;
3. explore and find all three discoveries;
4. see residents help with investigation and construction;
5. form and test the triangle;
6. understand partial Resonance feedback;
7. witness The First Bloom activate under the correct weather/time transition;
8. see village routines and visuals permanently change;
9. save, reload, and retain the changed village.

Target first-play duration: 45-75 minutes. Target repeatable daily play after the story slice: 10-20 minutes per session.

## 4. Conversion of the Current Project

The existing codebase contains useful infrastructure, but old content and prototype mechanics must not dictate the new design.

### 4.1 Keep and adapt

| Current system | Action | New responsibility |
|---|---|---|
| `core/data_registry.gd` | Keep and extend | Load residents, rumors, discoveries, projects, seasons, Resonance patterns, components, crafts, and world regions. |
| `core/event_bus.gd` | Keep and extend | Carry day, relationship, investigation, project, exploration, and Resonance events without direct system coupling. |
| `core/save_service.gd` and `core/save_data.gd` | Keep and migrate | Versioned save for days, residents, relationships, projects, discoveries, placed objects, Resonance attempts, ecology, and story state. |
| `core/grid_service.gd` | Keep for logical placement | Support project footprints and tolerant Resonance geometry; do not force free player movement onto a visible tile grid. |
| `autoload/simulation_clock.gd` | Replace internals | Become the calendar/day-period authority with Morning, Afternoon, Evening, and Night. Retain debug speed controls. |
| `core/weather_service.gd` | Keep and extend | Deterministic daily forecast, transitions, rainfall history, wind, and Resonance activation windows. |
| `autoload/settlement_manager.gd` | Keep and refactor | Own placed homes, projects, landmarks, paths, social places, machine slots, and world persistence. |
| `core/building_manager.gd` and construction scenes | Adapt | Construct community projects with phases and resident contributions. Remove the assumption that construction is a resource converter. |
| `core/animal_manager.gd` and current mouse behavior | Replace public experience; reuse pathing ideas | Become `ResidentManager` plus resident agents with routines, voluntary task choice, conversations, relationships, and aspirations. |
| `core/resonance_service.gd` | Substantially rewrite | Evaluate pattern + components + condition, return graded feedback, track experiments, and perform visible world transformations. |
| `core/town_storage.gd` and inventory | Simplify and keep | Hold a small set of meaningful materials and discoveries. Automatically stack ordinary materials. |
| fog and resource-node code | Adapt | Reveal a small handcrafted map and support authored discovery sites rather than uniform resource scattering. |
| existing save and smoke-test approach | Keep | Add headless tests for each new service and playable flow tests for every milestone. |
| `world/visual_resolver.gd` | Keep | Continue supporting placeholder meshes and later final models through the same scene/data references. |
| audio service | Keep | Use procedural placeholders until authored SFX are delivered. |

### 4.2 Disable, remove, or defer from the playable build

Do not delete old code immediately. First remove it from the active scene/autoload flow, mark it deprecated, and delete it only after the vertical slice passes regression tests.

- Cheese salary, strikes caused by salary, and recurring upkeep.
- Generic animal recruitment and housing capacity.
- Direct right-click worker orders and laser-pointer prioritization.
- Catnip drift work-speed modifiers.
- Dust Bunny rewards as an economy mechanic.
- Whisker Radar as a universal hot/cold detector.
- Cat-stack scaffolding balance challenge.
- Dream-mode production prediction.
- Cheese Vault progression.
- Undersea and Space Mice expansion content.
- Achievement-driven building unlocks.
- A large uniform 70 x 70 prototype field.
- Repeated huts used solely to create a numerical Resonance bonus.
- Any sword, potion, conflict, defense, or military iconography.

These systems may be reconsidered later only if they serve the new pillars. Keep expansion loading technically functional, but do not spend production time authoring expansions before the core game works.

### 4.3 Rename concepts during implementation

- `AnimalManager` -> `ResidentManager`
- recruited animal -> resident
- job -> activity or contribution
- construction site -> community project when the work is communal
- Architectural Resonance -> Seasonal Resonance
- achievement -> Almanac discovery or community milestone
- production bonus -> new capability, ecological effect, or routine change
- priority target -> community priority

Use compatibility adapters while saves and tests are migrated. Do not perform a risky repository-wide rename in one step.

## 5. Target Godot Architecture

### 5.1 New directories

```text
res://
  data/
    residents.json
    relationships.json
    projects.json
    discoveries.json
    rumors.json
    resonance_patterns.json
    resonance_components.json
    crafts.json
    seasons.json
    world_regions.json
  core/
    calendar_service.gd
    resident_manager.gd
    relationship_service.gd
    routine_service.gd
    community_project_service.gd
    discovery_service.gd
    rumor_service.gd
    investigation_service.gd
    resonance_service.gd
    ecology_service.gd
    almanac_service.gd
  resources/
    residents/resident_definition.gd
    projects/project_definition.gd
    discoveries/discovery_definition.gd
    resonance/resonance_pattern_definition.gd
    resonance/resonance_component_definition.gd
  scenes/
    world/village_clearing.tscn
    world/woodland_route.tscn
    world/ancient_ruin.tscn
    residents/resident_agent.tscn
    projects/community_project.tscn
    resonance/resonance_plinth.tscn
    resonance/resonance_feedback.tscn
    ui/almanac.tscn
    ui/day_summary.tscn
    ui/community_board.tscn
    ui/investigation_table.tscn
  art/
    placeholders/
    final/
```

Existing folders can remain while migration is in progress. New code should use the target structure.

### 5.2 Resident data

Each resident definition needs:

```json
{
  "id": "resident_mara",
  "display_name": "Mara",
  "species": "mouse",
  "specialty": "gardening",
  "personality_tags": ["patient", "observant"],
  "likes": ["flowers", "rain", "shared_meals"],
  "dislikes": ["noise_at_night"],
  "home_id": "home_mara",
  "base_routine_id": "routine_mara_spring",
  "aspiration_id": "aspiration_restore_garden",
  "discovery_skills": ["botany", "soil"],
  "relationship_seeds": {"resident_pip": 10}
}
```

The vertical slice has exactly three residents. Do not generate interchangeable residents.

### 5.3 Resident agent states

Use a small hierarchical state machine:

- `FollowingRoutine`
  - travel
  - perform activity
- `ConsideringContribution`
- `ContributingToProject`
- `Investigating`
- `Socializing`
- `TalkingToPlayer`
- `ReactingToEvent`
- `GoingHome`
- `Sleeping`

Activity selection should score a short candidate list using schedule, specialty, relationship to participants, aspiration relevance, distance, weather preference, and current comfort. Do not simulate dozens of hidden needs. For the vertical slice, use only energy, mood, and social openness.

### 5.4 Relationships

Store directional familiarity and symmetric bond separately only if dialogue requires it. Otherwise begin with one symmetric integer bond per resident pair and a small set of remembered moments.

Relationships grow through witnessed activities: collaborating, sharing meals, helping an aspiration, exploring together, and participating in successful Resonance. Never reward repetitive dialogue spam.

Thresholds unlock behavior, not just dialogue:

- acquaintance: greet and share rumors;
- friend: voluntarily visit or work together;
- close friend: perform paired exploration and exchange gifts;
- community bond: propose joint projects or rituals.

### 5.5 Community projects

A project has:

- authored location or player-selected valid zone;
- 2-4 phases;
- material needs;
- contribution activities suited to resident specialties;
- visible construction states;
- optional decisions;
- completion consequences for routines, ecology, and available activities.

The player may contribute directly but cannot instantly finish a project by holding a button. Residents should visibly carry, inspect, build, plant, paint, and celebrate.

### 5.6 Discovery pipeline

Use one pipeline for plaques, relics, machine components, seeds, and clues:

```text
Hidden/rumored -> location revealed -> found -> unidentified
-> investigation available -> investigated -> interpreted
-> displayed, installed, planted, or used in a project
```

Each discovery can contribute to two or more domains:

- local history;
- a community project;
- a craft capability;
- a Resonance component or clue;
- a resident aspiration;
- an ecological change.

The Village Almanac is the single collection interface. Do not add separate fossil, machine-part, recipe, and pattern encyclopedias.

## 6. Seasonal Resonance Specification

### 6.1 Definition

Seasonal Resonance is a lost technology in which spatial arrangements gather natural forces. A valid activation requires:

1. **Geometry:** relative placement of nodes or landmarks;
2. **Components:** correct item, plant, building, machine, or material roles;
3. **Condition:** weather, time, season, moon state, wind, water, temperature, or a recent environmental transition;
4. **Optional participation:** specified residents or community activities for later patterns.

### 6.2 Discovery principles

- The complete solution is never shown before discovery.
- The first pattern teaches the feedback language generously.
- Later clues omit one or more dimensions.
- Experiments are free to rearrange and never consume unique components.
- Near-correct attempts always produce consistent feedback.
- Once discovered, the Almanac records the exact reconstruction requirements.
- Residents automatically operate a discovered pattern when its condition returns unless the player disables it.
- A pattern produces a visible or behavioral change. Numerical bonuses may support the result but are never the only reward.

### 6.3 Data schema

Replace the current building-offset-only schema with:

```json
{
  "id": "resonance_first_bloom",
  "display_name": "The First Bloom",
  "clue_ids": ["clue_ruin_triangle", "clue_garden_plaque"],
  "geometry": {
    "shape": "triangle",
    "tolerance_meters": 0.65,
    "rotation_invariant": true,
    "scale_range": [3.5, 5.5],
    "center_requirement": {"type": "landmark", "id": "old_garden_tree"},
    "nodes": [
      {"role": "water", "allowed_components": ["component_rain_lens"]},
      {"role": "motion", "allowed_components": ["component_copper_gear"]},
      {"role": "life", "allowed_components": ["component_heirloom_seeds"]}
    ]
  },
  "condition": {
    "weather_history": ["rain"],
    "day_period": "morning",
    "transition": "sunrise"
  },
  "effects": [
    {"type": "unlock_flower_palette", "palette_id": "first_bloom_colors"},
    {"type": "enable_social_activity", "activity_id": "garden_gathering"},
    {"type": "advance_aspiration", "aspiration_id": "aspiration_restore_garden"},
    {"type": "play_world_sequence", "sequence_id": "sequence_first_bloom"}
  ]
}
```

Use world-space geometry with tolerance rather than exact grid offsets. Pattern recognition must allow rotation and modest player imprecision. Keep logical snapping as an optional placement aid.

### 6.4 Evaluation stages

`ResonanceService.evaluate_attempt(pattern_candidate)` returns separate scores:

- geometry score;
- component-role score;
- center/landmark score;
- condition status;
- overall feedback tier.

Feedback tiers:

| Tier | Meaning | Presentation |
|---|---|---|
| 0 Dormant | Fundamentally wrong | No effect beyond ordinary object idle animation. |
| 1 Stirring | At least one relevant element | One component emits a quiet mote or note. |
| 2 Echoing | Geometry or roles substantially correct | Brief lines, coordinated tones, resident comment. |
| 3 Aligned | Build is correct but condition is absent | Stable center pulse and Almanac note that the arrangement is waiting. |
| 4 Activated | All requirements met | Authored transformation sequence and permanent state change. |

The system must not disclose which exact node is wrong after the introductory pattern. Visual and audio feedback should narrow the search without becoming a checklist.

### 6.5 Activation lifecycle

```text
player places/moves component
-> debounce 0.25 seconds
-> evaluate nearby candidate arrangements
-> show feedback tier
-> if aligned, register an activation watcher
-> CalendarService/WeatherService emits condition transition
-> evaluate again
-> lock input around the pattern briefly
-> play activation sequence
-> apply idempotent effects
-> record discovery and world mutation
-> invite resident reactions
-> save immediately after sequence
```

All effects must be idempotent. Loading a save reapplies persistent world state without replaying rewards or the discovery sequence.

### 6.6 Preventing clutter

- Only dedicated plinths, landmarks, gardens, paths, and machine slots participate in Resonance for the first release.
- The vertical slice uses three movable Resonance components and one active pattern.
- A village region can track at most three unresolved pattern rumors.
- Completed patterns become compact landmarks; residents maintain them automatically.
- Ordinary decorative objects do not enter the solver.
- One Almanac screen records all clues, experiments, and confirmed patterns.
- Machine workshops have one active machine slot initially.

## 7. Step-by-Step Godot Implementation Plan

Each milestone ends in a runnable build. Codex must not begin the next milestone until the listed acceptance tests pass.

### Milestone 0 — Preserve the baseline and create the reboot seam

**Status (2026-08-03): Complete.** Baseline legacy smoke tests pass in Godot 4.7.1. The reboot development entry point is active behind `feature/reboot_mode`; the original prototype remains at `res://scenes/world/main.tscn`. Save schema v4 adds an explicit reboot/legacy generation marker and transactionally migrates v1-v3 saves only when legacy mode is selected. Compatibility autoloads now isolate clock, resident/animal, and Resonance naming. Deprecated-system removal gates are recorded in `docs/deprecated_systems.md`.

**Justified deviations:** The legacy scene retains its existing path instead of being duplicated to `scenes/legacy/`, avoiding a large copied resource and preserving current references. Deprecated autoloads remain registered until Milestone 12 as required by the plan; reboot code accesses the three retained systems only through compatibility seams. Seasonal Resonance evaluation itself remains intentionally unimplemented until Milestone 7.

**Goal:** Make the old prototype recoverable while creating a safe entry point for the new game.

Implementation:

1. Run and record all existing smoke tests.
2. Create a versioned save migration boundary; increment the save schema version.
3. Add a `feature/reboot_mode` project setting defaulting to true during development.
4. Create `scenes/world/village_clearing.tscn` and make it the reboot main scene only after it can boot.
5. Introduce compatibility wrappers for the existing clock, resident/animal manager, and resonance service.
6. Add a `docs/deprecated_systems.md` inventory with removal criteria.
7. Keep the old main scene available as `scenes/legacy/main_legacy.tscn` or retain its current path until the new scene boots.

Tests:

- Project starts without parser or autoload errors.
- Old save is either migrated or rejected with a friendly development log; it never silently corrupts.
- Legacy smoke tests remain runnable.

Art required: none. Use existing primitives.

### Milestone 1 — Handcrafted clearing, camera, and interaction feel

**Status (2026-08-03): Complete.** The reboot main scene now contains a locked 45 × 45 meter clearing, six visually distinct authored destinations, a short woodland route with three branches, and a primitive ancient ruin. A reboot-only founder controller provides tuned acceleration, braking, turning, and contextual interaction without depending on legacy economy or placement systems. The camera is orthographic isometric with four 90-degree snap angles; trees and buildings participate in camera-to-player occlusion fading. Authored interaction anchors and localized procedural ambience cover the clearing, woodland, and ruin. Placeholder contracts are recorded under `art/placeholders/`, and Visual Direction Asset Batch A is specified in `docs/environment_art_brief.md`.

**Justified deviations:** The route and ruin are separate reusable scenes but remain instanced into the clearing for a seamless Milestone 1 play space. Reachability is validated by sampling the actual collision world into a test-only AStar graph rather than committing a navigation mesh before resident navigation requirements are known. Procedural tones stand in for ambience; calendar-driven ambience variation remains deferred to Milestone 2.

**Goal:** Establish enjoyable movement and a visually readable small world before adding simulation.

Implementation:

1. Greybox the 45 x 45 meter clearing and one woodland route.
2. Replace the flat field with shaped terrain zones: village center, home edge, workshop edge, abandoned garden, woodland gate, ruin overlook.
3. Use a fixed isometric camera with limited rotation or four snap angles. Do not implement free orbit until occlusion and placement are proven.
4. Tune player acceleration, stopping, turning, interaction radius, and contextual prompts.
5. Add occlusion fading for trees/buildings between camera and player.
6. Add authored interaction anchors instead of relying only on collision proximity.
7. Add basic ambience zones for clearing, woodland, and ruin.

Tests:

- Player can reach every authored location without snagging.
- Camera never hides an interaction for more than one snap rotation.
- World communicates five distinct destinations without UI markers.
- Stable 60 FPS on the development target in the greybox.

Placeholder art:

- color-coded primitive blocks for homes/workshop;
- cylinders and spheres for trees;
- low-poly stones for the ruin;
- flat colors for terrain zones;
- icon billboard for interactable anchors.

Final art gate: request **environment concept art** now, after the camera and world dimensions are locked. Required deliverables are one village-clearing paint-over, one woodland/ruin paint-over, palette sheet, material callouts, and scale reference beside the player.

### Milestone 2 — Calendar, weather, and a safe cozy day

**Goal:** Create the daily rhythm required by routines and Seasonal Resonance.

**Status (2026-08-03): Complete.** `CalendarService` is now the authoritative reboot clock with four configurable periods, home-triggered day completion, modal/sequence pause ownership, debug jumps, resident schedule signals, and persisted day/period progress. `WeatherService` now derives a rolling three-day forecast and deterministic wind from the save seed, persists recent weather, and exposes a one-shot `rain_to_sunrise` transition. The clearing responds with period-specific lighting, sky color, procedural rain, sun/moon discs, ambience mixes, a readable forecast HUD, and a modal end-of-day journal covering discoveries, project work, relationship moments, and tomorrow's weather. `SimulationClock` remains available as a reboot adapter and continues to own legacy-mode behavior.

**Justified deviations:** The existing save schema remains version 4 because Milestone 0 established calendar/weather fields as optional forward-compatible data at that migration boundary; incrementing it would create a second migration boundary without an incompatible schema change. The placeholder sky uses the existing environment's authored color background rather than adding temporary skybox resources. Debug keys F6/F7 provide period stepping and the required weather-transition seam; direct debug APIs still allow any exact period/transition in automated tools. No resident agents or Milestone 3 routine logic were introduced.

Implementation:

1. Replace `SimulationClock` behavior with `CalendarService` while retaining an adapter for old signal users.
2. Add Morning, Afternoon, Evening, and Night periods.
3. Advance periods through configurable duration and allow the player to end the day at home.
4. Pause simulation for modal dialogue and important sequences.
5. Extend weather to produce a three-day deterministic forecast from the save seed.
6. Track recent weather and transitions such as `rain -> sunrise`.
7. Add lighting, sky color, ambience, and resident schedule signals for each period.
8. Add a concise end-of-day summary containing discoveries, project progress, relationship moments, and tomorrow's forecast.
9. Ensure nothing important is permanently missed by ending a day.

Tests:

- Time and forecast persist across save/load.
- Debug controls can jump to any period and weather transition.
- Rain-followed-by-sunrise emits exactly one activation event.
- Dialogue pauses time without desynchronizing weather.

Placeholder art: gradient sky colors, existing light, procedural rain, simple moon/sun discs.

Final art required later: skyboxes or gradient specification, rain particles, wet-surface material treatment, period-specific lighting reference. Do not commission these until the world palette from Milestone 1 is approved.

### Milestone 3 — Three named residents and daily routines

**Goal:** Replace generic recruitable labor with a memorable initial community.

Implementation:

1. Create the resident schema and definitions for Mara the gardener, Pip the tinkerer/builder, and Elowen the curious historian. Names may change during narrative review.
2. Create `resident_agent.tscn` with navigation, state machine, interaction anchor, speech bubble anchor, carried-item socket, and animation interface.
3. Spawn residents from save data rather than recruiting them.
4. Give each resident a morning, afternoon, evening, and night routine.
5. Implement candidate activity scoring with clear debug visualization.
6. Add contextual conversations based on location, weather, project state, and recent discoveries.
7. Add one aspiration per resident and expose its current step through dialogue, not a quest checklist.
8. Replace direct commands with a Community Board where the player proposes one priority.
9. Allow residents to decline or delay a contribution for understandable reasons, then communicate those reasons.

Tests:

- Each resident completes a full day without getting stuck.
- Save/load restores home, routine period, and important activity state safely.
- Residents visibly differ in where they go and what they choose.
- The player can always locate a resident through the Almanac/map without a permanent overhead marker.

Placeholder art:

- reuse cube-pet models with three unmistakable colors;
- simple two-frame or tweened idle/walk/work animations;
- text-only portrait cards;
- colored carry-item cubes.

Final art gate: request **character concepts and production models** after agent scale, sockets, and animation list are locked. Required per resident: turnaround, color palette, expression sheet, home motif, six core animations (idle, walk, talk, carry, work, celebrate), and bust portrait. The founder additionally needs interaction and tool-use poses.

### Milestone 4 — Relationships and social places

**Goal:** Make village arrangement change resident behavior without becoming a hidden-stat decorating puzzle.

Implementation:

1. Add `RelationshipService` with bonds and remembered moments.
2. Define social places as authored or player-created areas: old tree, workshop porch, garden table, and cottage stoop.
3. Add paired and group activity reservations so residents do not overlap.
4. Allow collaboration, meals, conversations, visits, and celebrations to create relationship memories.
5. Add resident compatibility as preferences, not deterministic friend/enemy categories.
6. Surface relationship change through animations, dialogue, visits, and journal entries before showing numbers.
7. Add the future-facing effect API that Resonance can use to enable a new social activity.

Tests:

- Two residents can plan, travel to, perform, and exit a shared activity.
- Repeated identical interactions have diminishing or no bond reward.
- A newly enabled social activity enters routine selection without reloading.

Placeholder art: benches, table, mugs, and work props made from primitives; icon bubbles for activity type.

Final art required: none yet. Social-prop dimensions are still being learned.

### Milestone 5 — Community garden project

**Goal:** Prove peaceful strategy and cooperative settlement growth.

Implementation:

1. Add the Community Board and propose `project_restore_garden`.
2. Implement project phases: clear debris, repair beds, restore irrigation, plant, celebrate.
3. Give each phase visible state changes and contribution slots.
4. Let the player gather or carry materials and perform short direct contributions.
5. Let residents choose contributions based on specialty, aspiration, relationship, schedule, and priority.
6. Add resident comments and short coordination moments at phase transitions.
7. Complete the garden only after both player and resident participation have been demonstrated; do not require arbitrary grind totals.
8. On completion, add garden routines but keep rare flower colors locked behind The First Bloom.

Tests:

- Project can be completed without debug commands.
- No material can be double-spent or lost on save/load.
- Residents visibly perform at least three different contribution animations.
- Project phase visuals restore correctly from every phase.

Placeholder art: five versions of the same garden scene assembled from boxes, decals, and color changes.

Final art gate: request **modular environment kit, cottages, workshop, and garden states** after footprints and interaction sockets are locked. Require clean silhouettes at the chosen camera distance, modular damage/restoration variants, collision proxies, and LOD guidance. Garden needs abandoned, cleared, repaired, planted, and First Bloom variants.

### Milestone 6 — Authored exploration, rumors, and discoveries

**Goal:** Connect village life to a small but surprising exploration route.

Implementation:

1. Build the woodland route with three branches and controlled sightlines.
2. Add rumor acquisition from residents, environmental observations, and project phase changes.
3. Add the unified discovery state machine.
4. Place the old plaque, rain lens, copper gear, dormant seeds, and triangular ruin clue.
5. Make at least one discovery found by a resident and converted into a player rumor.
6. Allow a suitable resident to accompany or meet the player for one investigation beat.
7. Add investigation at the workshop table; resident specialty changes interpretation dialogue but never blocks progression.
8. Add Almanac pages for rumors, unidentified finds, interpreted finds, and confirmed patterns.
9. Use authored landmarks and resident language before map markers. Add a marker only after the player asks for help or revisits a rumor.

Tests:

- Every discovery can be found in any order.
- Progress cannot deadlock if the player ends the day, travels alone, or stores a component.
- An unidentified item never reveals its final purpose in inventory text.
- Investigation results persist and update all dependent conversations.

Placeholder art: unique colored/outlined primitive for each discovery, stone slabs with decal symbols, parchment-style text panels.

Final art gate: request **relics, machine components, ruin set, discovery VFX, and Almanac illustrations** after clue readability is playtested. Each unique component requires a world model, inventory icon, investigation close-up, inactive VFX anchor, and activated material variant.

### Milestone 7 — Seasonal Resonance prototype

**Goal:** Implement fair spatial experimentation and The First Bloom.

Implementation:

1. Replace the current exact-offset Resonance matcher with tolerant world-space geometry evaluators.
2. Implement triangle evaluation first: side-length tolerance, center containment, rotation independence, scale bounds, unique node assignments, and landmark requirement.
3. Add three plinths with component slots and safe component retrieval.
4. Implement component-role scoring without revealing hidden roles in the UI.
5. Implement the five feedback tiers with placeholder color, particle, and tones.
6. Register an activation watcher only for an Aligned arrangement.
7. Connect to the rain-followed-by-sunrise condition.
8. Implement idempotent effect handlers: unlock flower palette, enable garden gathering, advance aspiration, play sequence, update Almanac.
9. Add resident reactions based on whether they witnessed the attempt or activation.
10. Save immediately after activation completes.

Automated tests:

- correct triangle at several rotations and valid scales;
- incorrect, nearly correct, and mirrored role assignments;
- valid pattern outside its condition;
- activation on exactly one correct transition;
- no duplicate effect or reward after save/load;
- unique components are always recoverable;
- no evaluation storm while dragging a component.

Playable tests:

- Players understand that the ruin suggests a triangle.
- At least 80% of test players interpret Tier 2 and Tier 3 as progress rather than failure.
- Test players can solve the introductory pattern without external explanation.

Placeholder art: stone plinth cylinders, three strongly shaped components, colored motes, line meshes, synthesized three-note audio, rapid flower material swap.

Final art required after the feedback test: tier-specific Resonance VFX, component glow materials, spatial audio motif, activation sequence animation, new flower models/textures, and resident celebration animations.

### Milestone 8 — Craft capability and communal machine

**Goal:** Demonstrate that discovered machinery creates new possibilities rather than a percentage factory.

Implementation:

1. Add one workshop machine slot.
2. Turn the recovered irrigation assembly into a community machine installed during the garden project.
3. Allow components to have investigation, project, and Resonance uses without duplicating the item.
4. After The First Bloom, unlock one new craft family such as natural dyes from the new flowers.
5. Have Pip operate or maintain the device as part of a routine.
6. Add visible input, work, and output stages; do not use passive invisible timers.
7. Restrict the slice to one machine and one new craft family.

Tests:

- Machine state persists.
- Unlock happens only once but crafts remain available.
- Resident routine reacts to installed/active/broken states.
- The player understands what became possible without reading a stat table.

Placeholder art: modular box machine with moving gear and water particles; recolored cloth swatches.

Final art gate: request **irrigation machine and first craft set** after animation sockets and state list are locked. Require incomplete, installed-idle, operating, Resonant, and maintenance states.

### Milestone 9 — First Bloom celebration and complete narrative slice

**Goal:** Pay off the full loop with an authored communal moment.

Implementation:

1. Trigger celebration preparation after activation.
2. Give each resident a small, visible contribution.
3. Add one player choice affecting decoration or activity, not success/failure.
4. Stage the gathering using the new garden social activity.
5. Add a short closing conversation that seeds rumors of distant patterns.
6. Roll into repeatable days rather than ending the save.
7. Add credits/demo-complete acknowledgement only in demo builds.

Tests:

- Celebration works regardless of activation day or resident positions.
- Save/load before preparation, during preparation, and after completion is safe.
- No resident remains trapped in event state.

Placeholder art: bunting strips, light orbs, food blocks, text portraits.

Final art required: festival props, food set, bunting, evening lighting treatment, group celebration animation, and one short music arrangement layered over the village theme.

### Milestone 10 — UI, accessibility, and onboarding

**Goal:** Make the slice understandable without removing mystery.

Implementation:

1. Replace the prototype HUD with time/forecast, contextual interaction, current community priority, and compact carried-material display.
2. Keep numeric economy panels out of the default HUD.
3. Add Community Board, Almanac, investigation table, day summary, settings, save/load, and optional map.
4. Teach interaction, project contribution, rumors, investigation, component placement, and Resonance feedback through play.
5. Never tutorialize the exact First Bloom answer.
6. Add remappable input, hold/toggle options, text size, contrast options, camera shake control, subtitle controls, color-independent Resonance feedback, and reduced-flash mode.
7. Add a hint ladder: resident nudge -> Almanac clue synthesis -> optional explicit geometry help. It must be player-requested after the initial clue.

Tests:

- Entire slice is keyboard/controller playable.
- Resonance tiers remain distinguishable in grayscale and with audio muted.
- UI scales cleanly from 1280 x 720 upward.
- No critical information exists only in transient dialogue.

Placeholder art: theme boxes, text labels, monochrome icons.

Final art gate: request **UI style guide and production assets** only after all screens and information hierarchy survive usability testing. Require nine-slice panels, buttons/states, cursor, input glyph strategy, icons, Almanac frames, portraits, and typography specification with licensing.

### Milestone 11 — Cohesive art, audio, and game feel pass

**Goal:** Replace placeholders without destabilizing gameplay.

Implementation order:

1. Lock camera, scale, palette, texel density, shader approach, and import rules in an art bible.
2. Replace terrain and large landmarks first.
3. Replace residents and animation clips.
4. Replace buildings and project phase variants.
5. Replace props, components, vegetation, and flowers.
6. Replace UI and icons.
7. Add interaction animation, squash/stretch where appropriate, footsteps, placement feedback, work sounds, ambience, and mix states.
8. Profile after each asset family; enforce triangle, material, texture, and draw-call budgets.
9. Delete a placeholder only after all references resolve to final or approved fallback assets.

Acceptance:

- No visible placeholder appears in the release slice.
- Silhouettes and interactables remain legible at gameplay zoom.
- Wet, sunrise, evening, and Resonance states remain within the palette.
- Audio communicates feedback tiers without becoming intrusive.
- Performance target remains stable.

### Milestone 12 — Validation, cleanup, and release slice

**Goal:** Ship a stable small game that can expand cleanly.

Implementation:

1. Run all automated and playable-flow tests.
2. Remove deprecated autoloads from `project.godot` after confirming no live references.
3. Move unused old content to a clearly marked archive or delete it in a separately reviewed change.
4. Validate save migration, corruption recovery, and version rejection.
5. Add telemetry hooks only if privacy and product requirements exist; do not block release on telemetry.
6. Export Windows, macOS, and Linux development builds as required.
7. Record baseline performance and memory for the vertical slice.
8. Produce a content-authoring guide for adding residents, regions, discoveries, projects, crafts, and patterns.

Release criteria:

- no parser errors, red editor errors, broken resource paths, or missing input actions;
- no progression deadlocks across the complete slice;
- no unique discovery can be lost;
- save/load passes at every story boundary;
- complete slice passes with mouse/keyboard and controller;
- credits and third-party asset licenses are correct;
- art and audio sources are documented.

## 8. Art Asset Plan

### 8.1 Art direction recommendation

Use a warm, toy-like woodland diorama with chunky silhouettes, restrained detail, painted surfaces, soft shadows, seasonal color shifts, and expressive resident animation. The camera must make characters and interactable objects readable without outlines everywhere.

Do not combine untouched assets from multiple packs in the final build. Asset packs may be used for greyboxing, but final assets need a shared palette, proportion language, material response, and level of detail.

### 8.2 Placeholder rules

- Store generated placeholders under `res://art/placeholders/`.
- Use loud but harmonious category colors: resident, project, discovery, Resonance, social prop.
- Give every placeholder the same origin, scale, collision, sockets, and scene interface expected from final art.
- Never encode gameplay into a mesh name or material color; gameplay reads data and node contracts.
- Each final asset replaces a placeholder through a scene or data reference, not code changes.
- Add a development-only placeholder watermark or metadata flag so none ships accidentally.

### 8.3 Required asset batches

| Batch | Requested after | Assets |
|---|---|---|
| A. Visual direction | Milestone 1 camera/world lock | Clearing and ruin concepts, palette, material sheet, scale guide, season variants. |
| B. Characters | Milestone 3 agent contract lock | Founder + three residents, portraits, expressions, animation set, carried-item sockets. |
| C. Village kit | Milestone 5 footprint lock | Three cottages, workshop, garden phases, paths, fences, signs, social props. |
| D. Exploration | Milestone 6 clue test | Woodland vegetation, ruin modules, plaque, rain lens, gear, seeds, investigation props, icons. |
| E. Resonance | Milestone 7 feedback test | Plinths, activated materials, VFX tiers, flower palettes, activation animation, audio motif. |
| F. Machine/crafts | Milestone 8 state lock | Irrigation machine states, moving parts, water effects, dye/cloth craft outputs. |
| G. Celebration | Milestone 9 staging lock | Bunting, tables, food, lanterns, celebration clips, music layer. |
| H. UI | Milestone 10 usability lock | HUD, Almanac, board, journal, map, icons, glyphs, portraits, accessibility variants. |

### 8.4 Technical delivery requirements for 3D art

Before commissioning, Codex or the developer must provide artists with:

- Godot units: 1 unit = 1 meter;
- agreed character height and doorway scale;
- camera angle and minimum/maximum zoom screenshots;
- forward axis, origins, pivots, and placement grid conventions;
- named sockets for carry, interaction, VFX, and component installation;
- material/shader limits;
- maximum texture sizes and texel density;
- collision ownership (artist mesh or separate developer proxy);
- animation naming, loop rules, root-motion policy, and frame rate;
- required state variants;
- GLB export settings and a test-import scene.

Every delivered batch must first be imported into an isolated asset-validation scene. Verify scale, pivot, materials, animation names, bounding boxes, and performance before replacing placeholders.

## 9. Content Expansion After the Vertical Slice

Only begin expansion after Milestone 12 passes.

### Expansion order

1. Add one new woodland region and one new resident.
2. Add one new community project tied to that resident's aspiration.
3. Add two rumors and 3-5 discoveries.
4. Add one Seasonal Resonance pattern using one familiar and one new condition.
5. Add one machine or craft family unlocked by that pattern.
6. Add one ecological or social transformation.
7. Playtest the complete chain before adding another region.

### Pattern difficulty progression

- Pattern 1: geometry strongly hinted; components and condition mostly clear.
- Pattern 2: geometry clear; one component role uncertain.
- Pattern 3: condition clear; geometry must be inferred from two clues.
- Pattern 4: uses paths or a larger landmark.
- Pattern 5: requires a resident social ritual in addition to natural conditions.

Never increase difficulty by requiring pixel-perfect placement, rare random weather without forecasting, consumed unique items, or enormous search spaces.

## 10. Codex Working Instructions

For every implementation milestone, Codex should follow this procedure:

1. Read `AGENTS.md` and `res://.funplay/skills/funplay-godot-project.md` completely.
2. Start the Godot editor with the Funplay MCP addon enabled.
3. Read `godot://project/context` or call `get_project_info` before broad edits.
4. Inspect the current scene, script errors, recent logs, git status, and files named in the milestone.
5. State the milestone, assumptions, files to change, and acceptance tests before editing.
6. Preserve unrelated user changes and do not perform destructive cleanup without explicit authorization.
7. Implement the smallest playable end-to-end path first; keep data-driven definitions separate from presentation.
8. Use signals for cross-system communication and typed GDScript for new production code.
9. Keep placeholder art behind stable scene interfaces.
10. Add or update automated tests in the same change as the behavior.
11. Validate changed scripts, run relevant smoke tests, run the game, and inspect the result visually.
12. Save every mutated scene through Godot and confirm there are no new script errors.
13. Update this plan's milestone status and record intentional deviations.
14. Stop at the milestone acceptance gate. Do not opportunistically implement later content.

### Required test layers

- **Unit/service tests:** data validation, calendar transitions, scoring, geometry, save migrations, idempotent effects.
- **Scene smoke tests:** scene instantiation, node contracts, signals, navigation, component sockets.
- **Flow tests:** new game through garden restoration and First Bloom.
- **Visual checks:** screenshots at morning, rain, sunset, ruin view, partial Resonance, activation, and celebration.
- **Manual feel checks:** movement, interaction, resident readability, feedback comprehension, and clutter.

### Definition of done for any feature

A feature is not done until:

- it works in the active playable scene;
- its state saves and loads correctly;
- failure and cancellation paths are safe;
- the player receives understandable visual/audio feedback;
- placeholder and final-art contracts are documented;
- relevant automated tests pass;
- the Godot error log is clean.

## 11. Immediate Next Actions

Execute these in order:

1. Approve this reboot plan and freeze additions to the old mechanic list.
2. Complete Milestone 0 and capture the current prototype baseline.
3. Greybox the handcrafted clearing and ruin in Milestone 1.
4. Playtest movement, camera, and spatial readability before implementing new simulation.
5. Lock the clearing dimensions and request Visual Direction Asset Batch A.
6. Continue through the vertical-slice milestones without adding expansions or extra residents.

The most important production rule is: **finish The First Bloom with placeholders before scaling content or commissioning the majority of final art.** It is the proof that exploration, residents, peaceful planning, ancient patterns, seasonal conditions, machinery, and visible village change form one enjoyable game.
