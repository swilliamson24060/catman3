class_name NatureProps
extends RefCounted
## Shared helper for spawning real Stylized Nature MegaKit trees, rocks, and
## small ground decoration (grass/flowers/ferns/mushrooms/clover/bush) --
## used by both village_clearing.gd (treeline, boundary trees, wild-ground
## scatter) and woodland_route.gd (route trees), so the sizing/grounding
## logic only lives in one place.
##
## The kit's raw meshes are inconsistently scaled relative to each other (a
## "short grass" clump measures well over a meter tall unscaled, while a
## "medium rock" is a multi-meter boulder) -- every entry below carries its
## own per-species scale, tuned by measuring each model's actual AABB (see
## tools/dev_measure_nature_assets.gd) against a hand-picked real-world
## target size. Same "measure, don't guess" approach used for Elowen's
## cottage pieces (see cottage_build_service.gd/cottage_construction_site.gd).

const MODEL_DIR := "res://environment/models/nature/"
const GRASS_CARPET_SHADER := preload("res://environment/shaders/grass_carpet.gdshader")

## {prefix, count, scale, weight} -- CommonTree/Pine measure close to a
## natural ~7m tree already (scale 1.0); TwistedTree's raw mesh is a huge
## ~16m ancient-looking tangle and DeadTree a ~9.5m snag, both scaled down to
## sit in the same rough height band as the others so no single species
## dominates the skyline. `weight` is relative selection frequency (not a
## percentage) -- TwistedTree's foliage texture renders a saturated autumn
## red that reads as a jarring accent against this game's soft pastel look
## next to a full-strength share of the treeline, so it (and the starker
## DeadTree) stay rare "occasional gnarled old tree" flavor rather than a
## quarter of every tree in view.
const TREE_SPECIES := [
	{"prefix": "CommonTree_", "count": 5, "scale": 1.0, "weight": 5},
	{"prefix": "Pine_", "count": 5, "scale": 1.0, "weight": 5},
	{"prefix": "TwistedTree_", "count": 5, "scale": 0.42, "weight": 1},
	{"prefix": "DeadTree_", "count": 5, "scale": 0.63, "weight": 1},
]
const TREE_SPECIES_TOTAL_WEIGHT := 12   # sum of TREE_SPECIES weights above

static func _pick_tree_species(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi_range(1, TREE_SPECIES_TOTAL_WEIGHT)
	var cumulative := 0
	for species: Dictionary in TREE_SPECIES:
		cumulative += int(species["weight"])
		if roll <= cumulative:
			return species
	return TREE_SPECIES[0]

const ROCK_MODELS := [
	{"path": "Rock_Medium_1", "scale": 0.8}, {"path": "Rock_Medium_2", "scale": 0.8}, {"path": "Rock_Medium_3", "scale": 0.8},
	{"path": "Pebble_Round_1", "scale": 1.1}, {"path": "Pebble_Round_2", "scale": 1.1}, {"path": "Pebble_Round_3", "scale": 1.1},
	{"path": "Pebble_Round_4", "scale": 1.1}, {"path": "Pebble_Round_5", "scale": 1.1},
	{"path": "Pebble_Square_1", "scale": 1.0}, {"path": "Pebble_Square_2", "scale": 1.0}, {"path": "Pebble_Square_3", "scale": 1.0},
]

## Grass/clover only -- a MultiMeshInstance3D renders one mesh per batch, so
## dense ground-carpet coverage (the thing individual Node3D instances can't
## afford at real "covers the ground" density -- thousands of scene nodes
## would be thousands of physics/transform updates) needs its own species
## list separate from GROUND_DECOR_MODELS' larger, individually-placed props.
const GRASS_CARPET_MODELS := [
	{"path": "Grass_Common_Short", "scale": 0.26}, {"path": "Grass_Common_Tall", "scale": 0.33},
	{"path": "Grass_Wispy_Short", "scale": 0.27}, {"path": "Grass_Wispy_Tall", "scale": 0.33},
	{"path": "Clover_1", "scale": 0.19}, {"path": "Clover_2", "scale": 0.19},
]

const GROUND_DECOR_MODELS := [
	{"path": "Grass_Common_Short", "scale": 0.26, "weight": 6.0}, {"path": "Grass_Common_Tall", "scale": 0.33, "weight": 4.0},
	{"path": "Grass_Wispy_Short", "scale": 0.27, "weight": 6.0}, {"path": "Grass_Wispy_Tall", "scale": 0.33, "weight": 4.0},
	{"path": "Clover_1", "scale": 0.19, "weight": 5.0}, {"path": "Clover_2", "scale": 0.19, "weight": 5.0},
	{"path": "Flower_3_Group", "scale": 0.24, "weight": 1.4}, {"path": "Flower_3_Single", "scale": 0.3, "weight": 0.8},
	{"path": "Flower_4_Group", "scale": 0.24, "weight": 1.4}, {"path": "Flower_4_Single", "scale": 0.3, "weight": 0.8},
	{"path": "Fern_1", "scale": 0.6, "weight": 3.5},
	{"path": "Mushroom_Common", "scale": 0.54, "weight": 1.1}, {"path": "Mushroom_Laetiporus", "scale": 0.45, "weight": 0.8},
	{"path": "Bush_Common", "scale": 0.52, "weight": 0.35}, {"path": "Bush_Common_Flowers", "scale": 0.48, "weight": 0.18},
]

## A real tree, real collision (StaticBody3D + trunk-sized CollisionShape3D so
## the crown doesn't block movement, matching the old placeholder's
## trunk-only cylinder), grounded at local y=0, wrapped for `parent.add_child`.
## Falls back to the old procedural box/sphere tree if the kit model fails to
## load (shouldn't happen once imported, but mirrors CottageConstructionSite's
## no-silent-empty-node convention).
static func spawn_tree(node_name: String, position: Vector3, extra_scale: float, rng: RandomNumberGenerator) -> StaticBody3D:
	var species: Dictionary = _pick_tree_species(rng)
	var variant := rng.randi_range(1, int(species["count"]))
	var path := "%s%s%d.gltf" % [MODEL_DIR, species["prefix"], variant]
	var uniform_scale: float = float(species["scale"]) * extra_scale
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 5
	body.set_meta("development_placeholder", true)
	var result := _grounded_instance(path, uniform_scale)
	if result.is_empty():
		return _placeholder_tree(body, extra_scale)
	body.add_child(result["node"])
	var aabb: AABB = result["aabb"]
	var trunk_radius := maxf(aabb.size.x, aabb.size.z) * 0.12
	var trunk_height := aabb.size.y * 0.55
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(trunk_radius, 0.2)
	shape.height = maxf(trunk_height, 1.0)
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body.add_child(collision)
	return body

## A rock or pebble, visual only (no collision -- small enough underfoot that
## blocking movement on every pebble would be more annoying than the
## placeholder-free ground it's dressing).
static func spawn_rock(node_name: String, position: Vector3, extra_scale: float, rng: RandomNumberGenerator) -> Node3D:
	var entry: Dictionary = ROCK_MODELS[rng.randi_range(0, ROCK_MODELS.size() - 1)]
	var path := MODEL_DIR + str(entry["path"]) + ".gltf"
	var result := _grounded_instance(path, float(entry["scale"]) * extra_scale)
	if result.is_empty():
		return null
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.position = position
	wrapper.rotation.y = rng.randf_range(0.0, TAU)
	wrapper.add_child(result["node"])
	return wrapper

## Grass/flower/fern/mushroom/clover/bush -- purely decorative dressing, no
## collision, matching _spawn_treeline's established "the founder walks
## through it" convention for anything this small.
static func spawn_ground_decor(node_name: String, position: Vector3, extra_scale: float, rng: RandomNumberGenerator) -> Node3D:
	var entry := _pick_ground_decor(rng)
	var path := MODEL_DIR + str(entry["path"]) + ".gltf"
	var result := _grounded_instance(path, float(entry["scale"]) * extra_scale)
	if result.is_empty():
		return null
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.position = position
	wrapper.rotation.y = rng.randf_range(0.0, TAU)
	wrapper.add_child(result["node"])
	return wrapper

static func _pick_ground_decor(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for candidate: Dictionary in GROUND_DECOR_MODELS:
		total += float(candidate.weight)
	var roll := rng.randf_range(0.0, total)
	for candidate: Dictionary in GROUND_DECOR_MODELS:
		roll -= float(candidate.weight)
		if roll <= 0.0:
			return candidate
	return GROUND_DECOR_MODELS[0]

## Real ground-carpet coverage: one MultiMeshInstance3D per GRASS_CARPET_MODELS
## species, `points` distributed randomly across them. MultiMesh renders every
## instance of a mesh in a single draw call, so this is the only way to get
## true "the ground is covered in grass" density (thousands of tufts) without
## thousands of individual scene nodes -- each of `spawn_ground_decor`'s
## wrapper Node3D + StaticBody-free instance is fine for a few hundred ferns/
## mushrooms/bushes, but not for grass at real coverage density.
## No AABB grounding (unlike spawn_tree/spawn_rock/spawn_ground_decor) --
## every grass/clover model measures close enough to its own y=0 already
## (a few cm of variance, invisible under blades this size) that the AABB
## measurement pass this function would otherwise need per-species isn't
## worth paying for tens of thousands of instances.
static func build_grass_carpet(points: Array, rng: RandomNumberGenerator) -> Node3D:
	var carpet := Node3D.new()
	carpet.name = "GrassCarpet"
	var buckets: Array = []
	buckets.resize(GRASS_CARPET_MODELS.size())
	for i in buckets.size():
		buckets[i] = []
	for point: Variant in points:
		buckets[rng.randi_range(0, GRASS_CARPET_MODELS.size() - 1)].append(point)
	for i in GRASS_CARPET_MODELS.size():
		var entry: Dictionary = GRASS_CARPET_MODELS[i]
		var bucket: Array = buckets[i]
		if bucket.is_empty():
			continue
		var mesh := _extract_mesh(MODEL_DIR + str(entry["path"]) + ".gltf")
		if mesh == null:
			continue
		var base_scale: float = float(entry["scale"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = bucket.size()
		for j in bucket.size():
			var pos: Vector3 = bucket[j]
			var instance_scale := base_scale * rng.randf_range(0.88, 1.32)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * instance_scale)
			mm.set_instance_transform(j, Transform3D(basis, pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(entry["path"])
		mmi.multimesh = mm
		var source_material := mesh.surface_get_material(0) as StandardMaterial3D
		if source_material != null and source_material.albedo_texture != null:
			var carpet_material := ShaderMaterial.new()
			carpet_material.shader = GRASS_CARPET_SHADER
			carpet_material.set_shader_parameter("grass_atlas", source_material.albedo_texture)
			mmi.material_override = carpet_material
		carpet.add_child(mmi)
	return carpet

## Loads `path`, instantiates it, and returns the first descendant mesh found
## -- used to hand a real MegaKit mesh resource to a MultiMesh, since
## MultiMeshInstance3D needs the Mesh resource itself, not a scene to
## instantiate per point.
static func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	var mesh := _find_mesh_in(instance)
	instance.free()
	return mesh

static func _find_mesh_in(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _find_mesh_in(child)
		if found != null:
			return found
	return null

## Loads `path`, applies `uniform_scale`, and shifts the instance up so its
## OWN measured bottom sits at local y=0 -- the delivered kit models aren't
## reliably centered/grounded at their own origin either, same issue
## CottageConstructionSite's _rebuild_visuals works around.
static func _grounded_instance(path: String, uniform_scale: float) -> Dictionary:
	if not ResourceLoader.exists(path, "PackedScene"):
		return {}
	var packed: PackedScene = load(path)
	if packed == null:
		return {}
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return {}
	instance.scale = Vector3.ONE * uniform_scale
	var aabb := _local_aabb(instance)
	instance.position.y -= aabb.position.y
	return {"node": instance, "aabb": aabb}

static func _local_aabb(node: Node) -> AABB:
	return _accumulate_aabb(node, Transform3D.IDENTITY)

static func _accumulate_aabb(node: Node, parent_xform: Transform3D) -> AABB:
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

## Fallback matching the pre-kit procedural tree, used only if a model
## somehow fails to load post-import.
static func _placeholder_tree(body: StaticBody3D, scale_factor: float) -> StaticBody3D:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28 * scale_factor
	trunk_mesh.bottom_radius = 0.42 * scale_factor
	trunk_mesh.height = 3.0 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5 * scale_factor
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.3, 0.17, 0.08)
	trunk_material.roughness = 0.95
	trunk.material_override = trunk_material
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.35 * scale_factor
	crown_mesh.height = 2.5 * scale_factor
	crown.mesh = crown_mesh
	crown.position.y = 3.4 * scale_factor
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color(0.17, 0.43, 0.2)
	crown_material.roughness = 0.95
	crown.material_override = crown_material
	body.add_child(crown)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45 * scale_factor
	shape.height = 3.0 * scale_factor
	collision.shape = shape
	collision.position.y = 1.5 * scale_factor
	body.add_child(collision)
	return body
