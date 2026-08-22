# Elowen Cottage Assembly

## Overview

Elowen's cottage is a data-driven construction prototype in Godot. It combines:

- `CottageBuildService`, which decides which grid cells are filled and which piece is selected.
- `CottageConstructionSite`, which turns the service state into 3D nodes.
- `cottage_pieces.json`, which maps piece IDs to GLB assets, roles, scales, and roof tint colors.

The prototype grows one cottage over real elapsed time. The foundation appears immediately; additional body pieces resolve at 15-minute intervals; the final piece in each build run is a roof.

The feature is intentionally not wired into `SaveService` yet. Serialization helpers exist, but persistence integration is still future work. See [catman3-handoff.md](catman3-handoff.md) for the project-level status.

## Entry Point: The Construction Site

The default configuration identifies the resident and the initial build size:

```gdscript
@export var site_id: StringName = &"elowen"
@export var build_steps: int = 3
@export var resident_display_name: String = "Elowen"
```

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L24-L27)

When the scene enters the tree, it creates a visual stack and interaction anchor. It then obtains the autoloaded service, creates the site if necessary, resolves any elapsed construction time, and renders the current grid:

```gdscript
var service := get_node("/root/CottageBuildService")
if not service.has_site(site_id):
    service.start_build(site_id, build_steps, randi())
service.check_build(site_id)
_rebuild_visuals()
```

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L78-L89)

The scene itself is a small `Node3D` with the construction-site script attached:

Source: [scenes/buildings/cottage_construction_site.tscn](scenes/buildings/cottage_construction_site.tscn)

## Build State

`CottageBuildService` stores one dictionary per `site_id`. Its important fields are:

- `grid`: `Vector2i(tier, slot)` to piece ID. Tier `0` is the foundation.
- `resolved_order`: the order in which non-foundation pieces were placed.
- `timer`: the current `AwayTimer`.
- `timer_base_count`: progress count when the current timer began.
- `build_steps`: number of random additions in the current run.
- `rng`: deterministic random-number generator for the site.

A new site gets a random seed, a foundation footprint, and a timer:

```gdscript
func start_build(site_id: StringName, initial_build_steps: int, rng_seed: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = rng_seed
    var grid := _roll_foundation_footprint(rng)
    var timer := AwayTimer.new()
    timer.start(STEP_INTERVAL_SECONDS * maxf(0.0, float(initial_build_steps)))

    _sites[site_id] = {
        "grid": grid,
        "resolved_order": [],
        "timer": timer,
        "timer_base_count": 0,
        "build_steps": initial_build_steps,
        "rng": rng,
    }
```

Source: [core/cottage_build_service.gd](core/cottage_build_service.gd#L109-L130)

## Foundation Assembly

The foundation is laid immediately and does not count toward `build_steps`. The service chooses:

1. A footprint size from one to four pieces.
2. A contiguous layout from the permitted 2x2 slot patterns.
3. One foundation style, randomly selected from foundation 2 or foundation 3, reused for every occupied slot.

This replaced the earlier behavior where each occupied slot could independently choose a foundation style. The restriction is enforced in `_foundation_pool()`, which only admits `elowen_foundation_2` and `elowen_foundation_3`; `_roll_foundation_footprint()` then selects one definition before filling the chosen slots.

```gdscript
func _roll_foundation_footprint(rng: RandomNumberGenerator) -> Dictionary:
    var grid := {}
    var foundations := _foundation_pool()
    if foundations.is_empty():
        return grid

    var chosen_foundation: Dictionary = foundations[rng.randi() % foundations.size()]
    var slot_count: int = 1 + rng.randi() % 4
    var slot_options: Array = FOUNDATION_SLOT_SETS_BY_COUNT[slot_count]
    var chosen_slots: Array = slot_options[rng.randi() % slot_options.size()]

    for slot: Variant in chosen_slots:
        grid[Vector2i(0, int(slot))] = str(chosen_foundation.get("id", ""))

    return grid
```

Source: [core/cottage_build_service.gd](core/cottage_build_service.gd#L132-L147)

Slot coordinates are shared by the resolver and renderer:

```text
0 = back-left       1 = back-right
2 = front-left      3 = front-right
```

## Timed Body and Roof Resolution

`check_build()` converts elapsed real time into the number of additions that are currently due. It repeatedly selects an eligible grid cell until the target progress is reached.

- Every non-final addition uses the body-piece pool.
- The final addition uses the roof pool.
- A roof is prevented from landing directly on an unbuilt tier-1 foundation-supported cell.
- The resolver emits `site_changed` when the grid changes.

Relevant implementation: [core/cottage_build_service.gd](core/cottage_build_service.gd#L164-L220)

Eligibility is calculated by `_eligible_cells()`:

- A cell is eligible when the same slot in the tier below is occupied.
- From tier 2 onward, an empty cell may also be cantilevered from an already-filled adjacent slot at the same tier.
- Tier 1 cannot cantilever.
- Search is limited to one tier above the highest occupied tier.

Source: [core/cottage_build_service.gd](core/cottage_build_service.gd#L222-L250)

This produces ordinary vertical stacking first, then allows upper tiers to widen sideways once a supported piece exists at that tier.

## Piece Data Contract

Piece definitions are loaded from [data/cottage_pieces.json](data/cottage_pieces.json). Each entry has an ID, display name, role, and model path. Body pieces may define a uniform `scale`; roof variants may define a `tint_color`.

Example foundation:

```json
{
    "id": "elowen_foundation_2",
    "display_name": "Foundation 2",
    "role": "foundation",
    "model_path": "res://cottage/models/elowen/foundation_2.glb"
}
```

Example body piece:

```json
{
  "id": "elowen_stack_cube_blue",
  "display_name": "Stack Cube (Blue)",
  "role": "body",
  "model_path": "res://cottage/models/elowen/stack_cube_blue.glb",
  "scale": 0.45
}
```

Example roof variant:

```json
{
  "id": "elowen_roof_pyramid_mint",
  "display_name": "Pyramid Roof (Mint)",
  "role": "roof",
  "model_path": "res://cottage/models/elowen/roof_pyramid.glb",
  "tint_color": "bfe8cf"
}
```

The service separates body and roof entries by role. The foundation pool is deliberately restricted to `elowen_foundation_2` and `elowen_foundation_3`, and the selected foundation definition is reused across the whole footprint.

## 3D Rendering and Stacking

`_rebuild_visuals()` clears the previous visual children, groups the service grid by tier, and renders tiers from bottom to top. Each slot maps to a fixed X/Z offset, while Y is calculated from the measured geometry.

```gdscript
var tier_y := 0.0
for tier: Variant in tiers:
    var tier_height := 0.0
    for cell: Vector2i in cells_by_tier[tier]:
        var piece: Dictionary = service.piece_definition(str(grid[cell]))
        var piece_node := _build_piece_node(piece)
        var aabb := _local_aabb(piece_node)
        var offset: Vector3 = FOUNDATION_SLOT_OFFSETS[cell.y]

        piece_node.position = Vector3(
            offset.x,
            tier_y - aabb.position.y,
            offset.z
        )
        _stack_root.add_child(piece_node)
        tier_height = maxf(tier_height, aabb.size.y)
    tier_y += tier_height
```

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L113-L151)

The important detail is that the code does not assume every GLB has the same origin or height. `_local_aabb()` measures the instantiated model recursively, and the piece is shifted so its measured bottom rests at the current tier height. The next tier begins at the tallest piece's measured top.

## Model Loading and Fallbacks

The renderer loads a `PackedScene` from each piece's `model_path`, instantiates it, applies optional tinting, and returns it. If the path is missing or fails to load, it creates a colored placeholder mesh instead.

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L153-L169)

Roof tinting uses a per-instance shader material. This avoids mutating shared imported materials, so two cottages or two pieces can use different roof colors safely.

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L171-L204)

## Upgrades

`add_build_step()` supports later cottage growth:

1. If the last resolved piece is a roof, remove it.
2. Increase `build_steps` by one.
3. Restart the timer for the remaining additions.
4. Resolve the new final piece as a roof when the expanded run completes.

The foundation grid is never changed by an upgrade.

Source: [core/cottage_build_service.gd](core/cottage_build_service.gd#L151-L162)

## Debug Fast-Forward

For playtesting, `debug_fast_forward` can be enabled on the construction site. Every ten real seconds it rewinds the site's timer by one 15-minute interval, calls `check_build()`, rebuilds the visuals, and displays a progress toast.

This is local to the cottage site and does not modify the shared service interval. It must remain disabled before shipping.

Source: [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L29-L36) and [scripts/buildings/cottage_construction_site.gd](scripts/buildings/cottage_construction_site.gd#L92-L111)

## Validation

The standalone smoke test covers:

- One-to-four-piece contiguous foundations.
- Foundation 2 or foundation 3 selection.
- Matching foundation style across every occupied slot.
- Support and cantilever eligibility.
- Roof placement only on the final step.
- The regression case where a roof could land directly on a foundation.
- Removing and rebuilding a roof after an upgrade.
- Real GLB instantiation and AABB-based tier placement.

Source: [scripts/tests/cottage_build_smoke_test.gd](scripts/tests/cottage_build_smoke_test.gd)

## Limitations and Follow-up Work

- The service is not connected to `SaveService`; saved games will not yet restore cottage progress through the normal save flow.
- Only Elowen has production cottage models. Other residents' homes still use placeholder geometry.
- The algorithm is a custom vertical support resolver, not the terrain WFC generator. It models support relationships rather than 2D tile adjacency.
- The site accesses `CottageBuildService._sites` directly for debug fast-forwarding. That is acceptable for a prototype but should become a service API before production use.
- The construction site rebuilds every visible piece whenever progress changes. This is simple and reliable for a small cottage, but incremental updates may be preferable if cottages become larger or numerous.
