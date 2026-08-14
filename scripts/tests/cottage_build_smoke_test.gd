extends SceneTree
## Regression guard for the CottageBuildService prototype's grid/support
## model:
## 1) A random 1-4 piece foundation FOOTPRINT (up to a 2x2 grid, contiguous,
##    independently-styled) is laid down all at once at start_build(), at
##    tier 0.
## 2) Every tier above it fills in one piece per real-world 15 minutes,
##    gated by a support rule: a cell needs a piece directly below it
##    (ordinary stacking), OR -- only from the SECOND stackable tier (tier
##    2) upward -- an adjacent cell in the tier directly below it (a
##    cantilever). Tier 1 can never cantilever, so with a single foundation
##    piece it's capped at exactly one stackable; tier 2 gets both the
##    mandatory piece directly above it and an optional cantilevered
##    neighbor, matching the reported design exactly.
## 3) Only the LAST piece of the currently-unlocked run is ever a roof, and
##    granting a site an additional build step later (add_build_step())
##    removes any roof already placed and resumes construction, without
##    ever touching the foundation footprint.
## Covers the service directly and the CottageConstructionSite visual
## driver, including AABB-based placement of the real Elowen GLB pieces.

const SITE := &"test_cottage"
const STEP_INTERVAL_SECONDS := 60.0 * 15.0
const CONSTRUCTION_SITE := preload("res://scenes/buildings/cottage_construction_site.tscn")
const CONTIGUOUS_SLOT_SETS := {
	1: [[0], [1], [2], [3]],
	2: [[0, 1], [0, 2], [1, 3], [2, 3]],
	3: [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]],
	4: [[0, 1, 2, 3]],
}

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var service: Node = root.get_node("CottageBuildService")
	service.new_game()

	# --- Foundation footprint: 1-4 pieces, contiguous, independently styled,
	# placed immediately (no build-step delay). Sample many seeds since the
	# count/layout/style are all randomized. ---
	for seed_value in range(30):
		service.start_build(SITE, 3, seed_value)
		var slots: Dictionary = service.foundation_slots(SITE)
		_check(slots.size() >= 1 and slots.size() <= 4, "the foundation footprint must have between 1 and 4 pieces: got %d (seed %d)" % [slots.size(), seed_value])
		var occupied: Array = slots.keys()
		occupied.sort()
		var valid_layout := false
		for option: Array in CONTIGUOUS_SLOT_SETS.get(occupied.size(), []):
			if option == occupied:
				valid_layout = true
				break
		_check(valid_layout, "the occupied foundation slots must form one of the known contiguous layouts: got %s (seed %d)" % [occupied, seed_value])
		for slot: Variant in slots.keys():
			var piece: Dictionary = service.piece_definition(str(slots[slot]))
			_check(str(piece.get("role", "")) == "foundation", "every occupied foundation slot must hold a real foundation piece (seed %d)" % seed_value)
	_check(int(service.piece_count(SITE)) == 0, "the foundation footprint must not count toward piece_count/build-step progress")
	_check(not bool(service.is_complete(SITE)), "a fresh 3-build-step site must not be complete before any build steps resolve")

	# --- Exact reported scenario: 1 foundation piece -> tier 1 capped at
	# exactly one stackable (no cantilever that low), tier 2 gets the
	# mandatory piece directly above it, and only THEN may cantilever to a
	# neighbor. Force a single-foundation site directly to make this
	# deterministic rather than searching for a matching random seed. ---
	service.start_build(SITE, 6, 1)
	var site_state: Dictionary = service._sites[SITE]
	site_state["grid"] = {Vector2i(0, 0): "elowen_foundation_1"}   # force: single foundation at slot 0
	var timer: AwayTimer = site_state["timer"]

	timer.started_at = Time.get_unix_time_from_system() - STEP_INTERVAL_SECONDS
	service.check_build(SITE)
	var grid1: Dictionary = service.grid_pieces(SITE)
	_check(grid1.has(Vector2i(1, 0)), "with 1 foundation at slot 0, the first stackable must land directly above it, at tier 1 slot 0")
	_check(grid1.size() == 2, "tier 1 must contain exactly one piece when there's only one foundation piece (no cantilever this low): got %d total cells" % grid1.size())

	# A second elapsed interval: tier 1 has nowhere else to grow (capped),
	# so the only eligible cell must be tier 2 slot 0 (support), NOT any
	# other tier-1 slot (no support) and NOT a tier-2 cantilever slot yet
	# (nothing at tier 2 to cantilever from until slot 0 there is filled).
	timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 2.0)
	service.check_build(SITE)
	var grid2: Dictionary = service.grid_pieces(SITE)
	_check(grid2.has(Vector2i(2, 0)), "the second stackable must be the mandatory piece directly above the first, at tier 2 slot 0")
	_check(not grid2.has(Vector2i(1, 1)) and not grid2.has(Vector2i(1, 2)) and not grid2.has(Vector2i(1, 3)), "tier 1 must never gain a second piece when there's only one foundation piece -- there is no support or cantilever available for it")

	# A third interval: NOW tier 2 slot 0 is filled, so an adjacent tier-2
	# slot becomes cantilever-eligible (riding out from tier 1 slot 0, which
	# is adjacent-below it) -- this is the "may cantilever" step. Force the
	# rng's next pick toward the cantilever candidate isn't necessary; we
	# just confirm the eligible-cell set is exactly what the rule predicts.
	var eligible_before_third: Array = service._eligible_cells(grid2)
	var eligible_set := {}
	for cell: Vector2i in eligible_before_third:
		eligible_set[cell] = true
	_check(eligible_set.has(Vector2i(3, 0)), "tier 3 slot 0 must be eligible (support from tier 2 slot 0)")
	_check(eligible_set.has(Vector2i(2, 1)) and eligible_set.has(Vector2i(2, 2)), "tier 2's slots adjacent to slot 0 must be cantilever-eligible once tier 2 slot 0 is filled")
	_check(not eligible_set.has(Vector2i(2, 3)), "tier 2 slot 3 is NOT adjacent to slot 0, so it must not be eligible yet")
	_check(not eligible_set.has(Vector2i(1, 1)), "tier 1 must still have no eligible cells beyond its single supported slot")

	# --- Multi-foundation case: with more than one foundation piece, only
	# ONE of them needs a stackable before tier 2 can open up anywhere. ---
	service.start_build(SITE, 6, 2)
	var multi_state: Dictionary = service._sites[SITE]
	multi_state["grid"] = {Vector2i(0, 0): "elowen_foundation_1", Vector2i(0, 2): "elowen_foundation_2"}   # two foundations, slots 0 and 2 (adjacent)
	var multi_timer: AwayTimer = multi_state["timer"]
	var eligible0: Array = service._eligible_cells(multi_state["grid"])
	var eligible0_set := {}
	for cell: Vector2i in eligible0:
		eligible0_set[cell] = true
	_check(eligible0_set.has(Vector2i(1, 0)) and eligible0_set.has(Vector2i(1, 2)), "both foundation-supported tier-1 slots must be eligible from the start")
	multi_timer.started_at = Time.get_unix_time_from_system() - STEP_INTERVAL_SECONDS
	service.check_build(SITE)
	var multi_grid1: Dictionary = service.grid_pieces(SITE)
	var tier1_count := 0
	for cell: Vector2i in multi_grid1.keys():
		if cell.x == 1: tier1_count += 1
	_check(tier1_count == 1, "only one stackable should land after a single elapsed interval, even though two foundation-supported slots were eligible: got %d" % tier1_count)

	# --- Regression: a roof must never land directly on a foundation piece
	# with no stackable in between. This is exactly the bug that was
	# reported live -- with 2+ foundations and a short build, the FINAL step
	# could previously still pick an unbuilt tier-1 slot (a second
	# foundation that never got its own stackable) for the roof pool,
	# putting a roof straight on bare foundation. build_steps=2 is the
	# tightest case that can trigger it: one body step, then the very next
	# step is both "final" and still has an open tier-1 candidate. Sweep
	# many seeds since which cell gets the body/roof is randomized. ---
	for seed_value in range(40):
		service.start_build(SITE, 2, 100 + seed_value)
		var bug_state: Dictionary = service._sites[SITE]
		bug_state["grid"] = {Vector2i(0, 0): "elowen_foundation_1", Vector2i(0, 2): "elowen_foundation_2"}
		var bug_timer: AwayTimer = bug_state["timer"]
		bug_timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 10.0)
		service.check_build(SITE)
		_check(bool(service.is_complete(SITE)), "sanity: a 2-build-step site should complete after a large backdate (seed %d)" % seed_value)
		var bug_grid: Dictionary = service.grid_pieces(SITE)
		for cell: Vector2i in bug_grid.keys():
			if cell.x == 1:
				var piece: Dictionary = service.piece_definition(str(bug_grid[cell]))
				_check(str(piece.get("role", "")) != "roof", "a roof must never be placed directly on a foundation piece (tier 1) with no stackable between them: found one at %s (seed %d)" % [cell, seed_value])

	# --- Only the LAST piece of the run is ever a roof, wherever the
	# support rule lands it. ---
	service.start_build(SITE, 3, 42)
	var roof_state: Dictionary = service._sites[SITE]
	var roof_timer: AwayTimer = roof_state["timer"]
	roof_timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 2.0)
	service.check_build(SITE)
	for cell: Vector2i in service.grid_pieces(SITE).keys():
		if cell.x >= 1:
			var piece: Dictionary = service.piece_definition(str(service.grid_pieces(SITE)[cell]))
			_check(str(piece.get("role", "")) != "roof", "no roof may appear before the run's final piece: found one at %s with 2 of 3 build steps placed" % cell)
	roof_timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 10.0)
	service.check_build(SITE)
	_check(bool(service.is_complete(SITE)), "a site with all build steps placed must report complete")
	var roof_grid: Dictionary = service.grid_pieces(SITE)
	var roof_cells := 0
	for cell: Vector2i in roof_grid.keys():
		if cell.x >= 1:
			var piece: Dictionary = service.piece_definition(str(roof_grid[cell]))
			if str(piece.get("role", "")) == "roof": roof_cells += 1
	_check(roof_cells == 1, "a completed run must have exactly one roof piece: found %d" % roof_cells)

	# --- Upgrade: adding a build step removes the existing roof and resumes
	# construction; the foundation footprint must never change. ---
	var foundation_before_upgrade: Dictionary = service.foundation_slots(SITE)
	service.add_build_step(SITE)
	_check(int(service.build_steps(SITE)) == 4, "add_build_step must increase the build-step count")
	_check(service.foundation_slots(SITE) == foundation_before_upgrade, "an upgrade must never change the already-placed foundation footprint")
	_check(not bool(service.is_complete(SITE)), "a site mid-upgrade must not report complete")
	var post_pop_grid: Dictionary = service.grid_pieces(SITE)
	var post_pop_roofs := 0
	for cell: Vector2i in post_pop_grid.keys():
		if cell.x >= 1:
			var piece: Dictionary = service.piece_definition(str(post_pop_grid[cell]))
			if str(piece.get("role", "")) == "roof": post_pop_roofs += 1
	_check(post_pop_roofs == 0, "popping the roof on upgrade must leave no roof in the grid until the new run finishes")

	var upgrade_timer: AwayTimer = service._sites[SITE]["timer"]
	upgrade_timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 10.0)
	service.check_build(SITE)
	_check(bool(service.is_complete(SITE)), "the upgraded run must complete once its final cell resolves")
	var final_grid: Dictionary = service.grid_pieces(SITE)
	var final_roofs := 0
	for cell: Vector2i in final_grid.keys():
		if cell.x >= 1:
			var piece: Dictionary = service.piece_definition(str(final_grid[cell]))
			if str(piece.get("role", "")) == "roof": final_roofs += 1
	_check(final_roofs == 1, "the upgraded run must end with exactly one roof again")

	# --- progress_summary() must never be silent, and must reflect completion. ---
	service.start_build(SITE, 3, 7)
	_check(service.progress_summary(SITE).contains("left"), "an in-progress site's summary should mention remaining pieces")
	var complete_timer: AwayTimer = (service._sites[SITE]["timer"] as AwayTimer)
	complete_timer.started_at = Time.get_unix_time_from_system() - (STEP_INTERVAL_SECONDS * 10.0)
	service.check_build(SITE)
	_check(service.progress_summary(SITE).contains("finished"), "a complete site's summary should say so")

	# --- Visual driver: instantiating the scene builds a grid from the real
	# GLB pieces, and pieces at higher tiers sit strictly above lower ones,
	# using each piece's own measured AABB. ---
	service.new_game()
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var site_scene: CottageConstructionSite = CONSTRUCTION_SITE.instantiate() as CottageConstructionSite
	site_scene.site_id = SITE
	site_scene.build_steps = 3
	root.add_child(site_scene)
	await process_frame
	_check(site_scene.get_node("Stack").get_child_count() >= 1, "the construction site should render at least the foundation footprint on ready")

	# Force a known grid (2 foundation pieces side by side, one body piece
	# above one of them) and rebuild visuals directly, bypassing the
	# real-time gate.
	var forced_state: Dictionary = service._sites[SITE]
	forced_state["grid"] = {
		Vector2i(0, 0): "elowen_foundation_1",
		Vector2i(0, 1): "elowen_foundation_2",
		Vector2i(1, 0): "elowen_stack_1",
	}
	site_scene._rebuild_visuals()
	var stack_node: Node3D = site_scene.get_node("Stack")
	_check(stack_node.get_child_count() == 3, "the visual grid should have one node per filled cell")
	var foundation_a: Node3D = stack_node.get_node("elowen_foundation_1")
	var foundation_b: Node3D = stack_node.get_node("elowen_foundation_2")
	_check(foundation_a.position.x != foundation_b.position.x, "two different foundation slots must be placed side by side (different X), not stacked on each other")
	var body_node: Node3D = stack_node.get_node("elowen_stack_1")
	_check(body_node.position.y > foundation_a.position.y, "a tier-1 piece must sit above the foundation tier, using the foundation's own measured height")

	site_scene.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("COTTAGE_BUILD_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
