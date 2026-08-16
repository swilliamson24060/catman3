class_name CottageConstructionSite
extends Node3D
## Visual driver for one CottageBuildService site -- turns its state into
## real geometry and player-facing feedback (see core/cottage_build_service.gd
## for the actual build logic).
##
## A small 3D grid, up to 2x2 slots per tier: tier 0 is the foundation
## footprint (1-4 pieces, styles independently chosen -- see
## FOUNDATION_SLOT_OFFSETS), and every tier above it fills in over time per
## CottageBuildService's support/cantilever rule. Rendering just walks the
## service's grid tier by tier and places whatever's there at that slot's
## fixed (x, z) position -- the actual shape (does it stay a single column,
## does it widen on an upper floor, etc.) is entirely the service's call.
##
## Pieces are stacked/placed using each instantiated model's OWN measured
## bounding box, not fixed per-role heights: the delivered Elowen GLBs
## (foundation/stack/roof) are each a different real size and are centered
## on their own local origin rather than resting at local Y=0 (common for
## AI-generated exports, and different from docs/village_kit_art_brief.md's
## stated ground-contact convention) -- so a piece is shifted up until its
## OWN measured bottom sits at its target height, then the next piece in the
## column starts where this one's measured top ended. This works regardless
## of how any given piece happens to be centered, and needs no per-asset
## tuning as more pieces (e.g. more stacks, per the "I will add more later"
## plan) arrive.
##
## A piece with no model_path (or one that fails to load) falls back to a
## plain colored placeholder box/prism -- lets other villagers' cottages
## (no art yet) keep using the old dev-placeholder convention (see
## scripts/projects/material_source.gd) while Elowen's uses the real thing.

@export var site_id: StringName = &"elowen"
@export var build_steps: int = 3   # random additions after the foundation
@export var resident_display_name: String = "Elowen"
## TEMPORARY playtesting aid -- when true, forces one build step every
## DEBUG_FAST_FORWARD_INTERVAL real seconds instead of waiting a real
## 15-minute interval per step, so the build can be watched end to end in
## under a minute. Must be false before this ships; it bypasses
## CottageBuildService's real-time gate entirely by rewinding the site's own
## AwayTimer, not by changing the shared STEP_INTERVAL_SECONDS constant, so
## it can't affect any other site.
@export var debug_fast_forward: bool = false

const PLACEHOLDER_FOOTPRINT := 3.4   # meters -- only used for placeholder fallback pieces
const PLACEHOLDER_HEIGHT := {"foundation": 0.4, "roof": 0.9}
const PLACEHOLDER_DEFAULT_HEIGHT := 0.9
const DEBUG_FAST_FORWARD_INTERVAL := 10.0   # real seconds per forced step
const DEBUG_STEP_INTERVAL_SECONDS := 60.0 * 15.0   # must match CottageBuildService.STEP_INTERVAL_SECONDS

## Center-to-center spacing between adjacent foundation grid slots -- close
## to the real Elowen foundation pieces' own measured footprint (~1.9m) plus
## a small gap, not derived from any one piece's exact size since up to 4
## different foundation styles can occupy the grid at once.
const FOUNDATION_GRID_CELL_SIZE := 2.1
## Slot index -> (x, z) offset from the site origin. 0/1 = back row (left/
## right), 2/3 = front row (left/right); matches
## CottageBuildService.FOUNDATION_SLOT_SETS_BY_COUNT's slot numbering.
const FOUNDATION_SLOT_OFFSETS := [
	Vector3(-FOUNDATION_GRID_CELL_SIZE * 0.5, 0.0, -FOUNDATION_GRID_CELL_SIZE * 0.5),
	Vector3(FOUNDATION_GRID_CELL_SIZE * 0.5, 0.0, -FOUNDATION_GRID_CELL_SIZE * 0.5),
	Vector3(-FOUNDATION_GRID_CELL_SIZE * 0.5, 0.0, FOUNDATION_GRID_CELL_SIZE * 0.5),
	Vector3(FOUNDATION_GRID_CELL_SIZE * 0.5, 0.0, FOUNDATION_GRID_CELL_SIZE * 0.5),
]

var _anchor: InteractionAnchor
var _stack_root: Node3D
var _debug_ff_accum := 0.0

func _ready() -> void:
	set_meta("development_placeholder", true)
	_stack_root = Node3D.new()
	_stack_root.name = "Stack"
	add_child(_stack_root)

	_anchor = preload("res://scenes/world/interaction_anchor.tscn").instantiate() as InteractionAnchor
	_anchor.anchor_id = StringName("cottage_site_%s" % site_id)
	_anchor.prompt = "Inspect %s's cottage" % resident_display_name
	_anchor.intro_title = "%s's Cottage" % resident_display_name
	_anchor.intro_body = "A foundation has been laid. Every 15 minutes (real time), a new piece is added -- a roof only ever appears once the current run is actually finished. Check back to watch it take shape."
	_anchor.activated.connect(_on_interact)
	add_child(_anchor)

	var service := get_node("/root/CottageBuildService")
	if not service.has_site(site_id):
		service.start_build(site_id, build_steps, randi())
	service.check_build(site_id)
	_rebuild_visuals()

func _process(delta: float) -> void:
	if not debug_fast_forward:
		return
	var service := get_node("/root/CottageBuildService")
	if not service.has_site(site_id) or bool(service.is_complete(site_id)):
		return
	_debug_ff_accum += delta
	if _debug_ff_accum < DEBUG_FAST_FORWARD_INTERVAL:
		return
	_debug_ff_accum = 0.0
	var timer: AwayTimer = service._sites[site_id]["timer"]
	timer.started_at -= DEBUG_STEP_INTERVAL_SECONDS
	service.check_build(site_id)
	_rebuild_visuals()
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if shell != null:
		shell.show_event_toast(service.progress_summary(site_id))

func _on_interact(_anchor_id: StringName) -> void:
	var service := get_node("/root/CottageBuildService")
	service.check_build(site_id)
	_rebuild_visuals()
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if shell != null:
		shell.show_event_toast(service.progress_summary(site_id))

func _rebuild_visuals() -> void:
	# Immediate free (not queue_free) -- every old child is unconditionally
	# replaced in this same call, so there's no need for deferred-removal
	# safety, and queue_free() here would leave stale and fresh meshes
	# coexisting for a frame (visibly, and in get_child_count() for callers/
	# tests that check right after calling this).
	for child in _stack_root.get_children():
		_stack_root.remove_child(child)
		child.free()
	var service := get_node("/root/CottageBuildService")

	# Group the grid's cells by tier so each tier can be placed at one
	# shared Y (the height the tallest piece in that tier needs), then
	# stack tiers upward in order.
	var grid: Dictionary = service.grid_pieces(site_id)
	var cells_by_tier: Dictionary = {}
	for cell: Vector2i in grid.keys():
		var tier_cells: Array = cells_by_tier.get(cell.x, [])
		tier_cells.append(cell)
		cells_by_tier[cell.x] = tier_cells
	var tiers: Array = cells_by_tier.keys()
	tiers.sort()

	var tier_y := 0.0
	for tier: Variant in tiers:
		var tier_height := 0.0
		for cell: Vector2i in cells_by_tier[tier]:
			var piece: Dictionary = service.piece_definition(str(grid[cell]))
			var piece_node := _build_piece_node(piece)
			var aabb := _local_aabb(piece_node)
			var offset: Vector3 = FOUNDATION_SLOT_OFFSETS[cell.y]
			piece_node.position = Vector3(offset.x, tier_y - aabb.position.y, offset.z)
			_stack_root.add_child(piece_node)
			tier_height = maxf(tier_height, aabb.size.y)
		tier_y += tier_height

func _build_piece_node(piece: Dictionary) -> Node3D:
	var node := _build_piece_node_unscaled(piece)
	# Optional per-piece uniform scale, applied before the caller measures
	# this node's AABB -- lets a piece authored at a mismatched real-world
	# size (e.g. a generic primitive not modeled to this cottage's ~2m grid)
	# fit the footprint without needing new art. Defaults to 1.0 (no-op) for
	# pieces already modeled at the right scale.
	var piece_scale: float = float(piece.get("scale", 1.0))
	if piece_scale != 1.0:
		node.scale = Vector3.ONE * piece_scale
	return node

func _build_piece_node_unscaled(piece: Dictionary) -> Node3D:
	var model_path := str(piece.get("model_path", ""))
	if not model_path.is_empty() and ResourceLoader.exists(model_path, "PackedScene"):
		var packed: PackedScene = load(model_path)
		if packed != null:
			var instance := packed.instantiate() as Node3D
			if instance != null:
				instance.name = str(piece.get("id", "Piece"))
				return instance
	return _build_placeholder_piece(piece)

## Fallback for a piece with no (or a failed) model_path -- a plain colored
## primitive, matching this project's established dev-placeholder look.
func _build_placeholder_piece(piece: Dictionary) -> Node3D:
	var visual := MeshInstance3D.new()
	visual.name = str(piece.get("id", "Piece"))
	var role := str(piece.get("role", ""))
	var height: float = PLACEHOLDER_HEIGHT.get(role, PLACEHOLDER_DEFAULT_HEIGHT)
	if role == "roof":
		var mesh := PrismMesh.new()
		mesh.size = Vector3(PLACEHOLDER_FOOTPRINT, height, PLACEHOLDER_FOOTPRINT)
		visual.mesh = mesh
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(PLACEHOLDER_FOOTPRINT, height, PLACEHOLDER_FOOTPRINT)
		visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(str(piece.get("placeholder_color", "cccccc")))
	material.roughness = 0.85
	visual.material_override = material
	# BoxMesh/PrismMesh are centered on their own origin, same as the real
	# assets -- wrap in a Node3D so _local_aabb() below measures it the same
	# way regardless of which path built the piece.
	var wrapper := Node3D.new()
	wrapper.name = visual.name
	wrapper.add_child(visual)
	return wrapper

## Merged local-space bounding box of every VisualInstance3D under `node`
## (recursive, transform-aware) -- used to stack pieces by their actual
## measured size rather than an assumed fixed height.
func _local_aabb(node: Node) -> AABB:
	return _accumulate_aabb(node, Transform3D.IDENTITY)

func _accumulate_aabb(node: Node, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var result := AABB()
	var has_any := false
	if node is VisualInstance3D:
		result = xform * (node as VisualInstance3D).get_aabb()
		has_any = true
	for child in node.get_children():
		var child_aabb := _accumulate_aabb(child, xform)
		if not has_any:
			result = child_aabb
			has_any = true
		elif child_aabb.size != Vector3.ZERO:
			result = result.merge(child_aabb)
	return result
