class_name VillageClearingBootstrap
extends Node3D

const LEGACY_SCENE_PATH := "res://scenes/world/main.tscn"
const INTERACTION_ANCHOR := preload("res://scenes/world/interaction_anchor.tscn")
const FOUNDER_SELECT_UI := preload("res://founder/founder_select_ui.tscn")
const BOOT_RESUME_UI := preload("res://founder/boot_resume_ui.tscn")
## CLEARING_GRASS_TEXTURE covers the open, unbuilt ground (clearing base,
## woodland gate path, exploration stage). GRASSY_CENTER_TEXTURE covers
## buildable areas other than the garden (village center, home edge,
## workshop edge). GARDEN_PLOT_TEXTURE is the abandoned garden's own tile.
const CLEARING_GRASS_TEXTURE := preload("res://environment/textures/clearing_grass/clearing_grass.png")
const GRASSY_CENTER_TEXTURE := preload("res://environment/textures/grassy_center/grassy_center.png")
const GARDEN_PLOT_TEXTURE := preload("res://environment/textures/garden_plot/garden_plot.png")
## How many meters of ground one texture tile should cover. The first guess
## (5.0) stretched each tile across too much ground, blowing up whatever
## pattern is in the source image into an oversized, repetitive "wallpaper"
## look -- lower means more, smaller repeats across the same ground span.
const GROUND_TEXTURE_TILE_METERS := 1.5

const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.6
const CLEARING_HALF_EXTENT := 27.5
const GATE_HALF_WIDTH := 4.0   # opening in the south wall for the woodland path

## The walkable clearing extends to CLEARING_HALF_EXTENT, but nothing should
## ever be built within BUILD_MARGIN of the tree line -- keeps structures
## from crowding right up against the boundary so they stay easy to see
## against open ground. The founder can still walk through this ring; it
## only constrains where a *building* may go. Chosen so BUILDABLE_HALF_EXTENT
## lands exactly on the clearing's old (pre-buffer) footprint -- every
## existing hand-placed structure already fits inside it with no repositioning.
const BUILD_MARGIN := 5.0
const BUILDABLE_HALF_EXTENT := CLEARING_HALF_EXTENT - BUILD_MARGIN

## The exploration stage is a separate island of ground, reached only by
## teleport (see ExpeditionService.visit_area()), placed past the clearing's
## north treeline. Derived from CLEARING_HALF_EXTENT rather than a fixed
## Vector3 so resizing the clearing can't silently push the two into
## overlapping again -- which is exactly what happened here: the stage was
## originally placed with just enough room against a 22.5 half-extent, and
## enlarging the clearing to 27.5 for the build buffer ate that margin,
## leaving the stage's ground/walls/treeline overlapping the clearing's.
const EXPLORATION_STAGE_HALF_EXTENT := 7.0  # half of ExplorationStageGround's 14x14 footprint
const EXPLORATION_STAGE_CLEARANCE := 6.0    # gap kept between the clearing's north treeline and the stage's south wall
const EXPLORATION_STAGE_ORIGIN := Vector3(0.0, 0.0, CLEARING_HALF_EXTENT + EXPLORATION_STAGE_CLEARANCE + EXPLORATION_STAGE_HALF_EXTENT)

## True if `position` is far enough from the tree line to build on. No
## dynamic building-placement system exists in the reboot yet -- this is the
## hook for when one does, so the constraint is established in code now
## rather than left to be reverse-engineered later.
static func is_within_buildable_area(position: Vector3) -> bool:
	return absf(position.x) <= BUILDABLE_HALF_EXTENT and absf(position.z) <= BUILDABLE_HALF_EXTENT

const DESTINATIONS := {
	&"village_center": Vector3(0.0, 0.0, 0.0),
	&"home_edge": Vector3(-17.0, 0.0, -6.0),
	&"workshop_edge": Vector3(14.0, 0.0, -1.5),
	&"abandoned_garden": Vector3(-7.0, 0.0, 11.5),
	&"woodland_gate": Vector3(0.0, 0.0, -19.0),
	&"ruin_overlook": Vector3(0.0, 0.0, -47.0),
}

const ZONE_COLORS := {
	&"clearing": Color(0.29, 0.48, 0.25),
	&"village": Color(0.56, 0.49, 0.35),
	&"homes": Color(0.38, 0.57, 0.31),
	&"workshop": Color(0.57, 0.43, 0.25),
	&"garden": Color(0.38, 0.32, 0.2),
	&"path": Color(0.48, 0.4, 0.29),
}

func _ready() -> void:
	if not bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		push_warning("[Reboot] village_clearing.tscn was opened while reboot mode is disabled.")
	_build_clearing()
	_spawn_authored_anchors()
	_spawn_community_board()
	_spawn_investigation_table()
	_spawn_growth_plot_anchor()
	_spawn_expedition_post()
	_spawn_world_boundaries()
	_spawn_exploration_stage()
	get_node("/root/ResidentManager").bind_world(self)
	get_node("/root/ExpeditionService").bind_world($ExplorationStage)
	_maybe_show_founder_select()
	print("[Reboot] Milestone 1 clearing booted. Legacy prototype remains at %s" % LEGACY_SCENE_PATH)

## No save -> the founder-select modal (already data-driven and reused
## as-is from the legacy scenes, see founder/founder_select_ui.gd) picks a
## founder, applies its coat/modifiers, and unpauses. Save exists -> the
## resume-or-new-game modal (founder/boot_resume_ui.gd) asks first, rather
## than silently auto-loading -- a returning player had no way to start
## fresh before except deleting the save file by hand.
##
## Headless is the shape of every existing smoke test that instantiates this
## scene (none of them expect an interactive choice, and several rely on
## get_tree().create_timer()/_process() running unpaused right after
## instantiation) -- showing a modal there would pause the whole tree out
## from under tests that were never written to expect it. There's no
## interactive player to make a choice in that context anyway, so headless
## keeps the old silent behavior: auto-load if a save exists, otherwise skip
## straight into a fresh, unpaused boot. Both modals stay fully testable by
## instantiating them directly, independent of this boot gate.
func _maybe_show_founder_select() -> void:
	var save_service := get_node("/root/SaveService")
	var has_save := FileAccess.file_exists(ProjectSettings.globalize_path(save_service.SAVE_PATH))
	if has_save and DisplayServer.get_name() == "headless":
		save_service.load_game()
		_apply_founder_appearance(save_service.current.founder_cat_id)
	elif has_save:
		add_child(BOOT_RESUME_UI.instantiate())
	elif DisplayServer.get_name() != "headless":
		add_child(FOUNDER_SELECT_UI.instantiate())

func _apply_founder_appearance(founder_id: String) -> void:
	if founder_id.is_empty():
		return
	var founder_data: Dictionary = get_node("/root/DataRegistry").get_founder_cat(founder_id)
	if founder_data.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player_cat")
	CatAppearance.apply_to_player(player, founder_id, founder_data.get("coat", {}))

func _exit_tree() -> void:
	var manager := get_node_or_null("/root/ResidentManager")
	if manager != null:
		manager.unbind_world(self)
	var expedition_service := get_node_or_null("/root/ExpeditionService")
	if expedition_service != null:
		expedition_service.unbind_world($ExplorationStage)

func get_authored_destinations() -> Dictionary:
	return DESTINATIONS.duplicate()

func _build_clearing() -> void:
	var clearing_span := CLEARING_HALF_EXTENT * 2.0
	_create_ground("ClearingBase", Vector3(clearing_span, 0.25, clearing_span), Vector3(0.0, -0.125, 0.0), ZONE_COLORS.clearing, true, CLEARING_GRASS_TEXTURE, clearing_span / GROUND_TEXTURE_TILE_METERS)
	_create_ground("VillageCenter", Vector3(13.0, 0.12, 11.0), Vector3(0.0, 0.03, 0.0), ZONE_COLORS.village, false, GRASSY_CENTER_TEXTURE, 13.0 / GROUND_TEXTURE_TILE_METERS)
	_create_ground("HomeEdge", Vector3(12.0, 0.1, 16.0), Vector3(-15.5, 0.025, -5.5), ZONE_COLORS.homes, false, GRASSY_CENTER_TEXTURE, 16.0 / GROUND_TEXTURE_TILE_METERS)
	_create_ground("WorkshopEdge", Vector3(11.0, 0.14, 13.0), Vector3(15.5, 0.045, -4.0), ZONE_COLORS.workshop, false, GRASSY_CENTER_TEXTURE, 13.0 / GROUND_TEXTURE_TILE_METERS)
	_create_ground("AbandonedGarden", Vector3(15.0, 0.08, 11.0), Vector3(-7.0, 0.015, 15.0), ZONE_COLORS.garden, false, GARDEN_PLOT_TEXTURE, 15.0 / GROUND_TEXTURE_TILE_METERS)
	_create_ground("WoodlandGatePath", Vector3(6.0, 0.06, 13.0), Vector3(0.0, 0.01, -17.0), ZONE_COLORS.path, false, CLEARING_GRASS_TEXTURE, 13.0 / GROUND_TEXTURE_TILE_METERS)

	_create_block("HomeMaraPlaceholder", Vector3(4.2, 3.2, 4.2), Vector3(-17.0, 1.6, -10.0), Color(0.78, 0.51, 0.45))
	_create_block("HomePipPlaceholder", Vector3(4.2, 3.7, 4.2), Vector3(-12.0, 1.85, -4.5), Color(0.45, 0.64, 0.78))
	_create_block("HomeElowenPlaceholder", Vector3(4.2, 3.4, 4.2), Vector3(14.0, 1.7, 8.0), Color(0.6, 0.45, 0.76))
	_create_block("WorkshopPlaceholder", Vector3(6.0, 4.2, 5.0), Vector3(15.0, 2.1, -5.5), Color(0.88, 0.5, 0.2))

	_create_tree("OldGardenTree", Vector3(-7.0, 0.0, 19.0), 1.35)
	_create_tree("CenterTree", Vector3(4.5, 0.0, 4.5), 1.0)
	for tree_data: Array in [
		[Vector3(-21.0, 0.0, -18.0), 1.15], [Vector3(-18.0, 0.0, 19.5), 1.0],
		[Vector3(20.5, 0.0, 17.0), 1.2], [Vector3(20.0, 0.0, -17.0), 1.0],
		[Vector3(-7.0, 0.0, -20.5), 0.95], [Vector3(7.0, 0.0, -20.5), 1.05],
	]:
		_create_tree("BoundaryTree", tree_data[0], tree_data[1])
	_create_block("GatePostLeft", Vector3(0.7, 3.2, 0.7), Vector3(-3.2, 1.6, -21.0), Color(0.28, 0.16, 0.08))
	_create_block("GatePostRight", Vector3(0.7, 3.2, 0.7), Vector3(3.2, 1.6, -21.0), Color(0.28, 0.16, 0.08))

## Invisible collision walls around the clearing's own footprint (the
## legacy prototype had exactly this -- see docs/deprecated_systems.md's
## "70x70 uniform prototype field" entry -- but it never got ported to the
## reboot). Left open at the south gate (between the two GatePost markers
## above) so the woodland route stays reachable on foot; every other new
## destination (the exploration stage) is teleport-only -- see
## ExpeditionService.visit_area()/leave_visited_area() -- so it doesn't need
## a matching gap here. No visible mesh: the treeline below is what makes
## the boundary read as "the forest continues" rather than a floating wall.
func _spawn_world_boundaries() -> void:
	var half := CLEARING_HALF_EXTENT
	var wall_y := WALL_HEIGHT / 2.0
	_create_boundary_wall("BoundaryNorth", Vector3(half * 2.0, WALL_HEIGHT, WALL_THICKNESS), Vector3(0.0, wall_y, half))
	_create_boundary_wall("BoundaryEast", Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0), Vector3(half, wall_y, 0.0))
	_create_boundary_wall("BoundaryWest", Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0), Vector3(-half, wall_y, 0.0))
	var south_segment_width := half - GATE_HALF_WIDTH
	var south_segment_center_x := (half + GATE_HALF_WIDTH) / 2.0
	_create_boundary_wall("BoundarySouthWest", Vector3(south_segment_width, WALL_HEIGHT, WALL_THICKNESS), Vector3(-south_segment_center_x, wall_y, -half))
	_create_boundary_wall("BoundarySouthEast", Vector3(south_segment_width, WALL_HEIGHT, WALL_THICKNESS), Vector3(south_segment_center_x, wall_y, -half))

	_spawn_treeline(Vector3(-half, 0.0, half), Vector3(half, 0.0, half), Vector3(0.0, 0.0, 2.0))
	_spawn_treeline(Vector3(half, 0.0, -half), Vector3(half, 0.0, half), Vector3(2.0, 0.0, 0.0))
	_spawn_treeline(Vector3(-half, 0.0, -half), Vector3(-half, 0.0, half), Vector3(-2.0, 0.0, 0.0))
	_spawn_treeline(Vector3(-half, 0.0, -half), Vector3(-GATE_HALF_WIDTH, 0.0, -half), Vector3(0.0, 0.0, -2.0))
	_spawn_treeline(Vector3(GATE_HALF_WIDTH, 0.0, -half), Vector3(half, 0.0, -half), Vector3(0.0, 0.0, -2.0))

func _spawn_authored_anchors() -> void:
	var prompts := {
		&"village_center": "Look around the village center",
		&"home_edge": "Inspect the future homes",
		&"workshop_edge": "Inspect the workshop plot",
		&"abandoned_garden": "Inspect the abandoned garden",
		&"woodland_gate": "Listen at the woodland gate",
		&"ruin_overlook": "Study the ancient ruin",
	}
	var intro_titles := {
		&"village_center": "Village Center",
		&"home_edge": "Future Homes",
		&"workshop_edge": "Workshop Plot",
		&"abandoned_garden": "Abandoned Garden",
		&"woodland_gate": "Woodland Gate",
		&"ruin_overlook": "Ancient Ruin",
	}
	var intro_bodies := {
		&"village_center": "The heart of the settlement, where paths from every district meet. As the village grows, this is where its story will be told.",
		&"home_edge": "Room for cottages once the village can support them. Resting here ends the day and carries you into tomorrow -- weather, resident schedules, and any growing plot all move forward.",
		&"workshop_edge": "Marked out for a future workshop. Nothing to build yet, but residents already dream about what could go here.",
		&"abandoned_garden": "Overgrown and untended, but not forgotten. Look closer at its edges -- the stone marker nearby has its own story.",
		&"woodland_gate": "The threshold between the village and the woods beyond. Listening here surfaces rumors about what residents have noticed nearby -- each one a hint toward something worth finding.",
		&"ruin_overlook": "Weathered stones with a deliberate shape. Studying them is the first step toward understanding what they once meant -- and what they might do again.",
	}
	for anchor_id: StringName in DESTINATIONS:
		var anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
		anchor.name = String(anchor_id).to_pascal_case() + "Anchor"
		anchor.anchor_id = anchor_id
		anchor.prompt = prompts[anchor_id]
		anchor.intro_title = intro_titles[anchor_id]
		anchor.intro_body = intro_bodies[anchor_id]
		anchor.position = DESTINATIONS[anchor_id] + Vector3.UP * 0.05
		anchor.activated.connect(_on_anchor_activated)
		$AuthoredInteractionAnchors.add_child(anchor)

func _on_anchor_activated(anchor_id: StringName) -> void:
	if anchor_id == &"home_edge":
		get_node("/root/CalendarService").end_day()
	elif anchor_id == &"community_board":
		get_node("/root/ResidentManager").request_board()
	elif anchor_id == &"investigation_table":
		get_node("/root/InvestigationService").request_table()
	elif anchor_id == &"garden_plaque":
		get_node("/root/DiscoveryService").find(&"discovery_old_plaque")
		get_node("/root/RumorService").acquire(&"rumor_plaque")
		# The inscription is worn smooth -- the founder can't read it alone.
		# Elowen (resident_specialty "history", registered as a reading
		# opportunity in _spawn_investigation_table below) has to visit it
		# herself before its content is known; see ResidentManager's
		# register_reading_opportunity/_find_reading_opportunity_for. Once
		# she's reported back, DiscoveryService's state is "interpreted" and
		# revisiting the plaque just shows what's already known.
		var discovery := get_node("/root/DiscoveryService")
		var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
		if shell == null: return
		if discovery.state(&"discovery_old_plaque") == &"interpreted":
			var inscription: String = discovery.definition(&"discovery_old_plaque").get("interpretation", "")
			if not inscription.is_empty():
				shell.show_dialog(discovery.display_name(&"discovery_old_plaque"), "\"%s\"" % inscription)
		else:
			shell.show_dialog("Weathered Stone", "The inscription is worn smooth by weather and time -- unreadable at a glance. Someone who knows local history might be able to make sense of it.")
	elif anchor_id == &"woodland_gate":
		get_node("/root/RumorService").acquire(&"rumor_heirloom_seeds")
		get_node("/root/DiscoveryService").reveal_rumor(&"component_heirloom_seeds")
		get_node("/root/RumorService").acquire(&"rumor_rain_lens")
		get_node("/root/DiscoveryService").reveal_rumor(&"component_rain_lens")
	elif anchor_id == &"ruin_overlook":
		get_node("/root/RumorService").acquire(&"rumor_triangle")
		get_node("/root/DiscoveryService").reveal_rumor(&"clue_ruin_triangle")
	elif anchor_id == &"growth_plot":
		var growth := get_node("/root/GrowthPlotService")
		growth.check_growth()
		if not growth.is_growing():
			growth.plant_seed(randi())
	elif anchor_id == &"expedition_post":
		get_node("/root/ExpeditionService").request_post()

func _spawn_community_board() -> void:
	_create_block("CommunityBoardPlaceholder", Vector3(2.2, 1.8, 0.25), Vector3(5.5, 0.9, -0.5), Color(0.82, 0.65, 0.28), false)
	var anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	anchor.name = "CommunityBoardAnchor"
	anchor.anchor_id = &"community_board"
	anchor.prompt = "Open the Community Board"
	anchor.intro_title = "Community Board"
	anchor.intro_body = "Set a shared priority for the village. Residents choose for themselves how and when to help, but the board shapes what they lean toward."
	anchor.position = Vector3(5.5, 0.0, 0.5)
	anchor.activated.connect(_on_anchor_activated)
	$CommunityBoard.add_child(anchor)

func _spawn_investigation_table() -> void:
	_create_block("InvestigationTablePlaceholder", Vector3(2.4, 0.8, 1.2), Vector3(12.8, 0.4, -1.0), Color(0.26, 0.62, 0.68), false)
	var table_anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	table_anchor.anchor_id = &"investigation_table"
	table_anchor.prompt = "Use the workshop investigation table"
	table_anchor.intro_title = "Investigation Table"
	table_anchor.intro_body = "Bring unidentified finds here to learn what they are. A resident adds context based on their specialty, but anyone can investigate -- no one is ever blocked."
	table_anchor.position = Vector3(12.8, 0.0, -0.2)
	table_anchor.activated.connect(_on_anchor_activated)
	$AuthoredInteractionAnchors.add_child(table_anchor)
	# Kept clear of OldGardenTree's crown (position (-7, 19), scaled radius
	# ~1.8m) -- it used to sit ~2m from the trunk, close enough to be hidden
	# behind the foliage from most camera angles.
	_create_block("GardenPlaqueMarker", Vector3(0.9, 0.6, 0.35), Vector3(-10.5, 0.3, 17.5), Color(0.56, 0.54, 0.5), false)
	# No intro_title here, unlike the other anchors: _on_anchor_activated's
	# garden_plaque branch already gives a full, accurate, state-dependent
	# explanation on every single interaction (faded / Elowen's report / the
	# inscription) -- a separate one-time intro would just repeat the first
	# of those back to back.
	var plaque_anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	plaque_anchor.anchor_id = &"garden_plaque"
	plaque_anchor.prompt = "Inspect the stone edge by the old tree"
	plaque_anchor.position = Vector3(-10.5, 0.0, 17.5)
	plaque_anchor.activated.connect(_on_anchor_activated)
	$AuthoredInteractionAnchors.add_child(plaque_anchor)
	var plaque_specialty := StringName(str(get_node("/root/DiscoveryService").definition(&"discovery_old_plaque").get("resident_specialty", "")))
	get_node("/root/ResidentManager").register_reading_opportunity(&"discovery_old_plaque", plaque_specialty, plaque_anchor.position)

func _spawn_growth_plot_anchor() -> void:
	_create_block("GrowthPlotMarker", Vector3(1.0, 0.3, 1.0), Vector3(9.0, 0.15, 10.5), Color(0.55, 0.4, 0.2), false)
	var anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	anchor.name = "GrowthPlotAnchor"
	anchor.anchor_id = &"growth_plot"
	anchor.prompt = "Tend the growth plot"
	anchor.intro_title = "Growth Plot"
	anchor.intro_body = "Plant a seed here and it grows on its own, even while you're away -- checking back reveals how much time has passed and what has taken root. No rushing it; the village grows at its own pace."
	anchor.position = Vector3(9.0, 0.0, 10.5)
	anchor.activated.connect(_on_anchor_activated)
	$AuthoredInteractionAnchors.add_child(anchor)

## Kept at least ~2x RebootFounderCat.interaction_radius (2.4m) away from
## every other anchor, growth_plot included -- any closer and the nearest-
## anchor proximity check in _update_interaction_anchor() can't reliably
## tell them apart, which milestone1_clearing_smoke_test.gd's per-anchor
## proximity sweep catches.
func _spawn_expedition_post() -> void:
	_create_block("ExpeditionPostMarker", Vector3(0.8, 1.6, 0.8), Vector3(11.0, 0.8, 16.0), Color(0.42, 0.34, 0.22))
	var anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	anchor.name = "ExpeditionPostAnchor"
	anchor.anchor_id = &"expedition_post"
	anchor.prompt = "Plan an expedition"
	anchor.intro_title = "Expedition Post"
	anchor.intro_body = "Send one resident out on a solo expedition to a new, unexplored area. They'll be away for a while, and you can visit what they find or bring them home whenever you're ready."
	anchor.position = Vector3(11.0, 0.0, 16.0)
	anchor.activated.connect(_on_anchor_activated)
	$AuthoredInteractionAnchors.add_child(anchor)

## An always-present, initially-empty container. ExpeditionService adds the
## single currently-visited ExplorationArea into it on visit and frees it on
## leaving -- built in code rather than authored into the .tscn since it
## starts empty and only ever holds one transient child at a time.
##
## EXPLORATION_STAGE_ORIGIN is derived from CLEARING_HALF_EXTENT (see above)
## so it always sits clear of the clearing's own ground and treeline, and
## outside WoodlandRoute/AncientRuin's own path geometry too -- there's
## nothing else out there, so this needs its own real ground with collision,
## not just the visual zone-tint _create_ground normally adds on top of an
## existing floor.
func _spawn_exploration_stage() -> void:
	var exploration_span := EXPLORATION_STAGE_HALF_EXTENT * 2.0
	_create_ground("ExplorationStageGround", Vector3(exploration_span, 0.25, exploration_span), EXPLORATION_STAGE_ORIGIN + Vector3(0.0, -0.125, 0.0), ZONE_COLORS.clearing, true, CLEARING_GRASS_TEXTURE, exploration_span / GROUND_TEXTURE_TILE_METERS)

	# Fully enclosed, no gate needed: the founder only ever arrives here via
	# ExpeditionService.visit_area()'s teleport (a "travel montage" beat, not
	# a walk), matching how departure/return already work for the resident.
	var half := EXPLORATION_STAGE_HALF_EXTENT
	var wall_y := WALL_HEIGHT / 2.0
	var origin := EXPLORATION_STAGE_ORIGIN
	_create_boundary_wall("ExplorationBoundaryNorth", Vector3(half * 2.0, WALL_HEIGHT, WALL_THICKNESS), origin + Vector3(0.0, wall_y, half))
	_create_boundary_wall("ExplorationBoundarySouth", Vector3(half * 2.0, WALL_HEIGHT, WALL_THICKNESS), origin + Vector3(0.0, wall_y, -half))
	_create_boundary_wall("ExplorationBoundaryEast", Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0), origin + Vector3(half, wall_y, 0.0))
	_create_boundary_wall("ExplorationBoundaryWest", Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0), origin + Vector3(-half, wall_y, 0.0))
	_spawn_treeline(origin + Vector3(-half, 0.0, half), origin + Vector3(half, 0.0, half), Vector3(0.0, 0.0, 2.0))
	_spawn_treeline(origin + Vector3(-half, 0.0, -half), origin + Vector3(half, 0.0, -half), Vector3(0.0, 0.0, -2.0))
	_spawn_treeline(origin + Vector3(half, 0.0, -half), origin + Vector3(half, 0.0, half), Vector3(2.0, 0.0, 0.0))
	_spawn_treeline(origin + Vector3(-half, 0.0, -half), origin + Vector3(-half, 0.0, half), Vector3(-2.0, 0.0, 0.0))

	var stage := Node3D.new()
	stage.name = "ExplorationStage"
	stage.position = EXPLORATION_STAGE_ORIGIN
	add_child(stage)

func _create_ground(node_name: String, size: Vector3, position: Vector3, color: Color, collision: bool = false, texture: Texture2D = null, tile_repeats: float = 1.0) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _textured_material(texture, tile_repeats) if texture != null else _material(color)
	body.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	$TerrainZones.add_child(body)

func _create_block(node_name: String, size: Vector3, position: Vector3, color: Color, collision: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 5 if collision else 0
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	$PlaceholderProps.add_child(body)

func _create_tree(node_name: String, position: Vector3, scale_factor: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 5
	body.set_meta("development_placeholder", true)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28 * scale_factor
	trunk_mesh.bottom_radius = 0.42 * scale_factor
	trunk_mesh.height = 3.0 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5 * scale_factor
	trunk.material_override = _material(Color(0.3, 0.17, 0.08))
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.35 * scale_factor
	crown_mesh.height = 2.5 * scale_factor
	crown.mesh = crown_mesh
	crown.position.y = 3.4 * scale_factor
	crown.material_override = _material(Color(0.17, 0.43, 0.2))
	body.add_child(crown)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45 * scale_factor
	shape.height = 3.0 * scale_factor
	collision.shape = shape
	collision.position.y = 1.5 * scale_factor
	body.add_child(collision)
	$PlaceholderProps.add_child(body)

## No visible mesh -- collision only. Tagged "world_boundary" so
## reboot_founder_cat.gd can tell "I bumped a world edge" apart from bumping
## a tree or a building, and show a specific notice for it.
func _create_boundary_wall(node_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.add_to_group("world_boundary")
	body.set_meta("development_placeholder", true)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	$PlaceholderProps.add_child(body)

## Trees spaced along a straight line, offset outward by `outward_offset` so
## they sit just past a boundary wall rather than on top of it -- purely
## decorative dressing that makes "you can't go further" read as a forest
## edge instead of an invisible wall in a field.
func _spawn_treeline(from: Vector3, to: Vector3, outward_offset: Vector3, spacing: float = 4.5) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var count := maxi(1, int(length / spacing))
	for i in range(count + 1):
		var t := float(i) / float(count)
		var pos := from.lerp(to, t) + outward_offset
		_create_tree("BoundaryTreeline_%d_%d_%d" % [int(from.x), int(from.z), i], pos, randf_range(0.85, 1.25))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

## uv1_scale repeats the texture tile_repeats times across the BoxMesh's
## default 0-1 UV range per face; the GPU sampler wraps by default, so this
## alone is enough to tile rather than stretch one image across the ground.
func _textured_material(texture: Texture2D, tile_repeats: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_scale = Vector3(tile_repeats, tile_repeats, 1.0)
	material.roughness = 0.95
	return material
