class_name ExplorationArea
extends Node3D
## The transient visual content for the currently-visited exploration area.
## Built entirely in code (no separate .tscn) -- ExpeditionService
## instantiates one of these into the ExplorationStage node when the player
## visits, and frees it when they leave. Same placeholder-first convention
## as the rest of the project: real art slots in later via each terrain
## tile's scene_path with zero changes here.

const INTERACTION_ANCHOR := preload("res://scenes/world/interaction_anchor.tscn")

var tiles_root: Node3D
var return_anchor: InteractionAnchor

func _ready() -> void:
	tiles_root = Node3D.new()
	tiles_root.name = "Tiles"
	add_child(tiles_root)

	return_anchor = INTERACTION_ANCHOR.instantiate() as InteractionAnchor
	return_anchor.name = "ReturnAnchor"
	return_anchor.anchor_id = &"return_to_village"
	return_anchor.prompt = "Return to the village"
	return_anchor.position = Vector3(-1.0, 0.0, -1.0)
	return_anchor.activated.connect(_on_return_activated)
	add_child(return_anchor)

func _on_return_activated(_anchor_id: StringName) -> void:
	get_node("/root/ExpeditionService").leave_visited_area()

## Rebuilds the visible tiles from `area`'s currently-revealed cells. Called
## once on visit and again whenever generation or founder-proximity reveals
## more of the plot -- cheap enough to just rebuild wholesale each time
## given exploration areas are small (see ExpeditionService.AREA_WIDTH/HEIGHT).
func apply_area_state(area: TileFogPlot) -> void:
	for child in tiles_root.get_children():
		child.queue_free()
	for cell in area.all_cells():
		if not area.is_revealed(cell):
			continue
		var tile_def: Dictionary = get_node("/root/DataRegistry").get_terrain_tile(area.get_tile_id(cell))
		var scene_path := str(tile_def.get("scene_path", ""))
		var visual: Node3D = load(scene_path).instantiate() if (scene_path != "" and ResourceLoader.exists(scene_path)) else _placeholder_tile()
		visual.position = area.grid_to_world(cell)   # area.origin is Vector3.ZERO for exploration areas -- this node's own transform supplies the world offset
		tiles_root.add_child(visual)

func _placeholder_tile() -> Node3D:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.08, 0.9)
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.55, 0.35)
	material.roughness = 0.95
	body.material_override = material
	return body
