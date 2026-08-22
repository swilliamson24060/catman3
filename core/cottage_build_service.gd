extends Node
## Autoload "CottageBuildService". Prototype for WFC-driven cottage
## construction on a small 3D grid: up to 2 slots across, 2 deep, and as many
## tiers tall as build_steps allows.
##
## Tier 0 (the foundation) is a random 1-4 piece footprint (up to a 2x2
## grid, using one randomly chosen foundation style for every occupied slot),
## placed all at once at start_build(). Every tier above it is resolved one piece per
## real-world 15 minutes, gated by a support rule:
##   - a cell (tier, slot) can be filled once the cell directly BELOW it
##     (tier-1, same slot) is filled -- ordinary vertical stacking, OR
##   - from the SECOND stackable tier upward only (tier >= 2), a cell can
##     also be filled once an ADJACENT slot at the SAME tier is already
##     filled -- a cantilever, riding out sideways from a piece that's
##     already there rather than needing its own direct support. This means
##     the cantilever option only opens up AFTER the mandatory
##     directly-supported piece at that tier has landed, never in the same
##     step as it. Tier 1 can never cantilever (there's nothing built yet to
##     ride out from), so with a single foundation piece tier 1 is always
##     capped at exactly one stackable, and the earliest a footprint can
##     widen beyond the foundation is tier 2.
## Only the LAST piece of the currently-unlocked run is ever a roof --
## wherever the support rule happens to place that final piece.
##
## "build_steps" is how many random additions happen above the foundation
## (matching the design vocabulary: "3 build steps on day one"). A site is
## complete once build_steps pieces have been placed, and the last of those
## is always a roof.
##
## Upgrades (add_build_step()): when a site is granted an additional build
## step later (the week/month progression), any roof already sitting at the
## end of the build is popped back off -- the cottage is "under construction
## again" -- a new timer starts for the newly available step(s), and the run
## resolves as before. The vacated cell's support/cantilever eligibility is
## unchanged, so the same cell is usually (but not necessarily, if more than
## one cell was eligible) where the next piece lands; the roof itself may
## come back as the same piece id or a different one -- the pick is
## independent. The foundation footprint is fixed once placed -- upgrades
## never change it.
##
## Deliberately NOT wired into SaveService yet -- this is a pre-art mechanic
## test, not a shipped feature. serialize_state()/restore_state() exist so
## wiring it in later is a small change, not a redesign.
##
## This is a bespoke small resolver, not a reuse of the growth plot's
## WfcGenerator (built for terrain's 2D north/south/east/west tile
## adjacency) -- a cottage's shape is a different kind of problem (vertical
## tiers with a support rule), not a flat grid, so it gets its own algorithm
## rather than bending that one into a shape it wasn't designed for.

signal site_changed(site_id: StringName)

const PIECES_PATH := "res://data/cottage_pieces.json"
const STEP_INTERVAL_SECONDS := 60.0 * 15.0   # one piece every 15 real-world minutes

## Footprint slots (also used for every tier above the foundation):
##   0 = back-left   1 = back-right
##   2 = front-left  3 = front-right
const ALL_SLOTS := [0, 1, 2, 3]
const SLOT_ADJACENCY := {0: [1, 2], 1: [0, 3], 2: [0, 3], 3: [1, 2]}
## For a given occupied-slot count, only CONTIGUOUS layouts are offered (no
## single foundation piece floating diagonally disconnected from the rest of
## the footprint) -- one option is picked at random per count.
const FOUNDATION_SLOT_SETS_BY_COUNT := {
	1: [[0], [1], [2], [3]],
	2: [[0, 1], [0, 2], [1, 3], [2, 3]],
	3: [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]],
	4: [[0, 1, 2, 3]],
}

var _pieces: Array[Dictionary] = []
## site_id (StringName) -> {
##   "grid": Dictionary[Vector2i, String]  -- (tier, slot) -> piece id. Tier 0 is the
##                                             foundation, set once at start_build(); tier
##                                             >= 1 fills in over time via check_build().
##   "resolved_order": Array[Vector2i]     -- (tier, slot) cells filled above the foundation,
##                                             in the order check_build() filled them
##   "timer": AwayTimer                    -- real-time clock for the CURRENT run of unresolved cells
##   "timer_base_count": int               -- resolved_order.size() at the moment "timer" was (re)started
##   "build_steps": int                    -- random additions above the foundation, at the current unlock tier
##   "rng": RandomNumberGenerator
## }
var _sites: Dictionary = {}

func _ready() -> void:
	_load_pieces()

func new_game() -> void:
	_sites.clear()

func _load_pieces() -> void:
	var file := FileAccess.open(PIECES_PATH, FileAccess.READ)
	if file == null:
		push_error("[CottageBuildService] Missing cottage_pieces.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	_pieces.clear()
	for entry: Variant in parsed.get("cottage_pieces", []):
		if entry is Dictionary:
			_pieces.append(entry as Dictionary)

## Starts a new site: lays down a random 1-4 piece foundation footprint
## immediately (all occupied slots use the same randomly chosen foundation 2
## or foundation 3 style) and starts the real-time clock for `build_steps`
## random additions above it. Calling this again for an existing site_id
## restarts it from scratch.
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
	site_changed.emit(site_id)

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

## Occupied foundation slot index -> piece id (tier 0 only). Fixed for the
## site's whole lifetime once start_build() runs; upgrades never touch it.
func foundation_slots(site_id: StringName) -> Dictionary:
	var result := {}
	if not _sites.has(site_id):
		return result
	var grid: Dictionary = _sites[site_id]["grid"]
	for cell: Vector2i in grid.keys():
		if cell.x == 0:
			result[cell.y] = grid[cell]
	return result

## Full grid, every filled cell (foundation and everything built above it):
## (tier, slot) -> piece id.
func grid_pieces(site_id: StringName) -> Dictionary:
	if not _sites.has(site_id):
		return {}
	return _sites[site_id]["grid"]

## Grants one more build step to an existing, already-complete-or-in-progress
## site (the week/month progression). If the site's most recently resolved
## cell holds a roof, it's removed first -- construction resumes there (or
## wherever else is eligible), and a fresh roof only reappears once the new,
## larger run finishes.
func add_build_step(site_id: StringName) -> void:
	if not _sites.has(site_id):
		return
	var site: Dictionary = _sites[site_id]
	var resolved: Array = site["resolved_order"]
	var grid: Dictionary = site["grid"]
	if not resolved.is_empty():
		var last_cell: Vector2i = resolved[resolved.size() - 1]
		var last_piece := piece_definition(str(grid.get(last_cell, "")))
		if str(last_piece.get("role", "")) == "roof":
			grid.erase(last_cell)
			resolved.remove_at(resolved.size() - 1)
	site["build_steps"] = int(site["build_steps"]) + 1
	var timer := AwayTimer.new()
	var remaining: int = build_steps(site_id) - resolved.size()
	timer.start(STEP_INTERVAL_SECONDS * maxf(0.0, float(remaining)))
	site["timer"] = timer
	site["timer_base_count"] = resolved.size()
	site_changed.emit(site_id)

func has_site(site_id: StringName) -> bool:
	return _sites.has(site_id)

## Resolves whatever real-world time has accrued since the site's current
## timer started into newly-filled grid cells. Safe to call often
## (revisiting the site) -- a no-op once the current run is complete or
## nothing new is due yet. Every cell resolves to a body piece EXCEPT the
## final cell of the current run, which always resolves to a roof.
func check_build(site_id: StringName) -> void:
	if not _sites.has(site_id):
		return
	var site: Dictionary = _sites[site_id]
	var timer: AwayTimer = site["timer"]
	var base_count: int = site["timer_base_count"]
	var total_target: int = build_steps(site_id)
	var elapsed_steps: int = int(timer.credited_seconds() / STEP_INTERVAL_SECONDS)
	var target_count: int = mini(base_count + elapsed_steps, total_target)
	var resolved: Array = site["resolved_order"]
	var grid: Dictionary = site["grid"]
	var rng: RandomNumberGenerator = site["rng"]
	var changed := false
	while resolved.size() < target_count:
		var candidates := _eligible_cells(grid)
		if candidates.is_empty():
			break
		var is_final_slot: bool = resolved.size() == total_target - 1
		if is_final_slot:
			# A roof must never be the first piece of its own column --
			# tier 1 cells are always support-eligible directly off a
			# foundation, so if the final step's random candidate pool still
			# included one (e.g. a second foundation slot that never got its
			# own stackable yet), a roof could land straight on bare
			# foundation with nothing between them. Exclude tier-1 cells
			# from ROOF placement specifically; body placement is unaffected.
			var roof_candidates: Array[Vector2i] = []
			for candidate: Vector2i in candidates:
				if candidate.x >= 2:
					roof_candidates.append(candidate)
			if not roof_candidates.is_empty():
				candidates = roof_candidates
		var cell: Vector2i = candidates[rng.randi() % candidates.size()]
		var pool := _roof_pool() if is_final_slot else _body_pool()
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		grid[cell] = str(pick.get("id", ""))
		resolved.append(cell)
		changed = true
	if changed:
		site_changed.emit(site_id)

## Every currently-empty cell that could legally be filled next: supported
## directly from below, or (tier >= 2 only) cantilevered from an ALREADY-
## FILLED neighbor at the SAME tier -- so the mandatory piece directly above
## must land first, and only then does cantilevering off of it become
## possible; it never opens up in the same step as the support-eligible
## cell it rides out from. Search is bounded to one tier above the highest
## currently-filled tier -- nothing higher could possibly be eligible yet.
func _eligible_cells(grid: Dictionary) -> Array[Vector2i]:
	var max_tier := 0
	for cell: Vector2i in grid.keys():
		max_tier = maxi(max_tier, cell.x)
	var eligible: Array[Vector2i] = []
	for tier in range(1, max_tier + 2):
		for slot: int in ALL_SLOTS:
			var cell := Vector2i(tier, slot)
			if grid.has(cell):
				continue
			var supported: bool = grid.has(Vector2i(tier - 1, slot))
			var cantilevered := false
			if not supported and tier >= 2:
				for neighbor_slot: int in SLOT_ADJACENCY[slot]:
					if grid.has(Vector2i(tier, neighbor_slot)):
						cantilevered = true
						break
			if supported or cantilevered:
				eligible.append(cell)
	return eligible

func is_complete(site_id: StringName) -> bool:
	if not _sites.has(site_id):
		return false
	var resolved: Array = _sites[site_id]["resolved_order"]
	return resolved.size() >= build_steps(site_id)

func piece_count(site_id: StringName) -> int:
	if not _sites.has(site_id):
		return 0
	var resolved: Array = _sites[site_id]["resolved_order"]
	return resolved.size()

func build_steps(site_id: StringName) -> int:
	if not _sites.has(site_id):
		return 0
	return int(_sites[site_id]["build_steps"])

func piece_definition(piece_id: String) -> Dictionary:
	for piece: Dictionary in _pieces:
		if str(piece.get("id", "")) == piece_id:
			return piece
	return {}

## Human-readable progress for a site's InteractionAnchor to report on every
## visit -- the "never fire silently" pattern established for every other
## anchor in this game (see village_clearing.gd's growth_plot/abandoned_garden
## handling).
func progress_summary(site_id: StringName) -> String:
	if not _sites.has(site_id):
		return "Nothing has been started here yet."
	if is_complete(site_id):
		return "The cottage is finished, roof and all."
	var remaining := build_steps(site_id) - piece_count(site_id)
	var minutes_to_next := _seconds_until_next_step(site_id) / 60.0
	return "Still under construction (%d piece%s left) -- the next piece is due in about %d minutes." % [remaining, "" if remaining == 1 else "s", int(ceil(minutes_to_next))]

func _seconds_until_next_step(site_id: StringName) -> float:
	var site: Dictionary = _sites[site_id]
	var timer: AwayTimer = site["timer"]
	var base_count: int = site["timer_base_count"]
	var steps_into_this_run: int = piece_count(site_id) - base_count
	var next_step_seconds := float(steps_into_this_run + 1) * STEP_INTERVAL_SECONDS
	return clampf(next_step_seconds - timer.credited_seconds(), 0.0, STEP_INTERVAL_SECONDS)

func _foundation_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for piece: Dictionary in _pieces:
		if str(piece.get("id", "")) in ["elowen_foundation_2", "elowen_foundation_3"]:
			pool.append(piece)
	return pool

func _body_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for piece: Dictionary in _pieces:
		if str(piece.get("role", "")) == "body":
			pool.append(piece)
	return pool

func _roof_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for piece: Dictionary in _pieces:
		if str(piece.get("role", "")) == "roof":
			pool.append(piece)
	return pool

## Vector2i isn't a valid JSON dictionary key -- encode as "tier,slot",
## matching TileFogPlot's own convention for flattening Godot vector types.
func _encode_cell(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _decode_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func serialize_state() -> Dictionary:
	var out := {}
	for site_id: Variant in _sites.keys():
		var site: Dictionary = _sites[site_id]
		var timer: AwayTimer = site["timer"]
		var rng: RandomNumberGenerator = site["rng"]
		var grid_out := {}
		for cell: Vector2i in (site["grid"] as Dictionary).keys():
			grid_out[_encode_cell(cell)] = str(site["grid"][cell])
		var resolved_out: Array[String] = []
		for cell: Vector2i in (site["resolved_order"] as Array):
			resolved_out.append(_encode_cell(cell))
		out[String(site_id)] = {
			"grid": grid_out,
			"resolved_order": resolved_out,
			"timer": timer.serialize(),
			"timer_base_count": int(site["timer_base_count"]),
			"build_steps": int(site["build_steps"]),
			"rng_seed": int(rng.seed),
		}
	return out

func restore_state(data: Dictionary) -> void:
	_sites.clear()
	for site_key: String in data:
		var entry: Dictionary = data[site_key]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(entry.get("rng_seed", 0))
		var grid := {}
		var grid_in: Dictionary = entry.get("grid", {})
		for cell_key: String in grid_in:
			grid[_decode_cell(cell_key)] = str(grid_in[cell_key])
		var resolved: Array[Vector2i] = []
		for cell_key: Variant in entry.get("resolved_order", []):
			resolved.append(_decode_cell(str(cell_key)))
		_sites[StringName(site_key)] = {
			"grid": grid,
			"resolved_order": resolved,
			"timer": AwayTimer.from_data(entry.get("timer", {})),
			"timer_base_count": int(entry.get("timer_base_count", resolved.size())),
			"build_steps": int(entry.get("build_steps", 0)),
			"rng": rng,
		}
