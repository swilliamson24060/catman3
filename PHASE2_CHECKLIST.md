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
- [ ] Add a dedicated discovery banner and pattern details.
- [ ] Reapply discovered bonuses when loading a save.
- [ ] Validate rotation, one-time rewards, persistence, and live production changes with an automated smoke test.
