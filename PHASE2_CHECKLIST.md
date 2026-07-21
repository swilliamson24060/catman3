# Phase 2 Implementation Checklist

## Milestone 1 — Architecture and Economy Foundation

- [x] Inspect existing Phase 1 systems and record baseline diagnostics.
- [x] Add catnip to the existing GameState economy.
- [x] Add a lightweight shared simulation clock with debug acceleration.
- [x] Add per-mouse hunger and fatigue data.
- [x] Process recruited mouse cheese needs every simulation cycle.
- [x] Connect feeding and hunger outcomes to contentment.
- [x] Add behavioral contentment bands.
- [x] Show cheese, catnip, and recruited mouse count in the HUD.
- [x] Add development-only mouse-needs inspection.
- [x] Validate and regression-test the complete Phase 1 loop.

## Milestone 2 — Generic Building Placement and Construction Sites

- [x] Add data-driven BuildingDefinition resources.
- [x] Add a keyboard-accessible build menu and placement preview.
- [x] Validate slope, overlap, and controlled-territory placement.
- [x] Add generic construction sites with reserved worker slots.
- [x] Add in-world construction progress and completed-building replacement.
- [x] Add bribe deposits, exact refunds, cancellation, and duplication protection.
- [x] Add a non-producing Test Structure for system validation.

## Milestone 3 — Voluntary Mouse Labor

- [x] Add weighted, personality-sensitive worksite evaluation.
- [x] Add work navigation, slot reservation, and limited repathing.
- [x] Add frame-rate-independent work contribution.
- [x] Add fatigue, breaks, severe-needs refusal, and abandonment.
- [x] Make cheese bribes affect willingness and reward participants.
- [x] Add completion celebration and safe return to following.
- [x] Add development-only work-score labels.
- [x] Validate accounting, completion, and state recovery with an automated smoke test.

## Milestone 4 — Automated Production and Settlement Economy

- [x] Add data-driven production fields to completed buildings.
- [x] Drive production from the shared simulation clock.
- [x] Add a buildable Catnip Garden as the first producing structure.
- [x] Deposit completed production into the existing GameState economy.
- [x] Surface production in player feedback and the HUD.
- [x] Add production inputs and atomic input-to-output conversion.
- [x] Add production pause reasons and in-world status inspection.
- [x] Persist completed buildings and partial production progress.
- [x] Validate multiple producers, debug acceleration, and state recovery with an automated smoke test.
- [x] Support arbitrary data-defined settlement resource ids without new economy code.
- [x] Reject invalid outputs before consuming recipe inputs.
- [x] Validate economy and completed-building persistence through the actual save coordinator.

## Milestone 5 — Architectural Resonance

- [x] Add stable resonance-grid coordinates to Phase 2 building placement.
- [x] Add a buildable Mouse Hut for the first documented pattern.
- [x] Detect Phase 2 patterns across all four cardinal rotations.
- [x] Enforce one-time discovery through SaveData.
- [x] Apply the Herbal Triad production bonus live to Catnip Gardens.
- [x] Add a dedicated discovery banner and pattern details.
- [x] Reapply discovered bonuses when loading a save.
- [x] Apply the Herbal Triad movement bonus live to all mouse navigation states.
- [x] Validate rotation, one-time rewards, persistence, and live production changes with an automated smoke test.

## Milestone 6 — Mechanics Integration

- [x] Mount resource nodes and Whisker-Radar in the active Phase 2 world.
- [x] Mount Grooming/Dust Bunny rewards near Phase 2 construction sites.
- [x] Apply rain durability and waterproofing to Phase 2 buildings.
- [x] Connect the founder cat to fog reveal and thermal warmth buffs.
- [x] Register Phase 2 Catnip Gardens with wind-driven scent drift.
- [x] Apply Catnip Drift bonuses and drowsiness to voluntary mouse labor.
- [x] Keep cheese salary/strike and tiny-tool systems active through shared managers.
- [x] Mount Cat-Nap Dream Mode and its pastel overlay.
- [x] Mount data-weighted Stray Cat Visitors in the active world.
- [x] Add the wind-driven Cat-Stack scaffold balance challenge.
- [x] Validate the integrated mechanics with an automated Milestone 6 smoke test.

## Milestone 7 — Achievements and Unlocks

- [x] Listen to active Phase 2 building, recruitment, and resonance events.
- [x] Keep achievement conditions and rewards data-driven.
- [x] Persist achievement counters and unlocked content across saves.
- [x] Add a locked Cheese Vault progression reward.
- [x] Gate build placement through achievement unlock ids.
- [x] Surface achievement and content-unlock feedback in the HUD.
- [x] Validate one-time rewards, counter persistence, and build gating with an automated smoke test.

## Milestone 8 — Modular Expansions

- [x] Discover expansion JSON fragments deterministically at startup.
- [x] Merge every expansion before validating cross-references.
- [x] Canonicalize expansion runtime ids with filename-derived namespaces.
- [x] Resolve bare references locally first, then fall back to core content.
- [x] Validate building recipes, animal jobs, housing, upkeep, achievements, and resonance references.
- [x] Load the Undersea animal and its new Kelp resource from the same expansion file.
- [x] Load Space Mice founder, item, and cross-namespace achievement content without core-code changes.
- [x] Validate expansion lookup, inventory creation, housing, recruitment, and namespace isolation with an automated smoke test.
