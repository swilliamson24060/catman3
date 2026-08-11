extends RefCounted
class_name ResidentAppearance
## Applies a resident's real 3D model to their agent -- one distinct
## rigged/animated .glb set per resident (data/residents.json's model_dir),
## replacing the old shared-mesh-plus-flat-tint placeholder
## (resident_agent.gd used to instance one shared animal-bunny.glb under
## ModelRoot and recolor every mesh in it via _apply_color()).
##
## Unlike the founder's Meshy exports (founder/cat_appearance.gd), every
## resident is a different creature with the creature's name baked into the
## filename (e.g. "Meshy_AI_Polka_Dot_Otter_Hug_biped_..."), so files are
## found by matching the well-known suffix Meshy gives every export of a
## given kind, not by an exact shared filename.

const FILE_SUFFIXES := {
	"idle": "_Character_output.glb",
	"walk": "_Animation_Walking_withSkin.glb",
	"run": "_Animation_Running_withSkin.glb",
	"casual_walk": "_Animation_Casual_Walk_withSkin.glb",
}

## Measured directly from the imported meshes' AABB: unlike the founder's
## first export batch (which measured ~1/76th of the intended size), these
## come in already at the project's real-world scale -- a human/creature
## height of roughly 1.4-1.65m at scale 1.0, consistent with the founder's
## own corrected scale. Tune this if a future export batch differs.
const MODEL_SCALE := 1.0
## Same Meshy rig convention as the founder exports (confirmed by identical
## clip names -- "Armature|walking_man|baselayer" etc. -- across both
## batches): the rig faces the opposite way from this project's -Z-forward
## convention.
const MODEL_ROTATION_Y_DEGREES := 180.0

static func apply_to_resident(resident: Node, resident_id: String) -> void:
	if resident == null:
		return
	var registry := resident.get_node_or_null("/root/DataRegistry")
	if registry == null:
		return
	var resident_data: Dictionary = registry.get_resident(resident_id) if registry.has_method("get_resident") else {}
	var model_dir: String = str(resident_data.get("model_dir", ""))
	if model_dir.is_empty():
		return
	var model_root := resident.get_node_or_null("ModelRoot")
	if model_root == null:
		return
	for child in model_root.get_children():
		child.queue_free()

	var idle_path := _find_file(model_dir, FILE_SUFFIXES.idle)
	if idle_path.is_empty():
		push_warning("[ResidentAppearance] No base model found for resident '%s' at %s" % [resident_id, model_dir])
		return
	var base_packed: PackedScene = load(idle_path)
	if base_packed == null:
		push_warning("[ResidentAppearance] Could not load base model for resident '%s' at %s" % [resident_id, idle_path])
		return
	var model := base_packed.instantiate() as Node3D
	model.name = "ResidentModel"
	model.rotation_degrees.y = MODEL_ROTATION_Y_DEGREES
	model.scale = Vector3.ONE * MODEL_SCALE
	model_root.add_child(model)

	var anim_player := _find_animation_player(model)
	if anim_player == null:
		return
	var combined := AnimationLibrary.new()
	_copy_first_animation(anim_player, combined, "idle")
	_graft_animation(combined, "walk", _find_file(model_dir, FILE_SUFFIXES.walk))
	_graft_animation(combined, "run", _find_file(model_dir, FILE_SUFFIXES.run))
	var casual_walk_path := _find_file(model_dir, FILE_SUFFIXES.casual_walk)
	if not casual_walk_path.is_empty():
		_graft_animation(combined, "casual_walk", casual_walk_path)
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", combined)
	anim_player.play("idle")
	resident.set_meta("resident_animation_player", anim_player)

static func find_animation_player(resident: Node) -> AnimationPlayer:
	if resident == null:
		return null
	# has_meta() guard, not get_meta(key, null): Object.get_meta()'s default
	# parameter can't tell "caller passed null" from "caller passed nothing"
	# (both collapse to the same internal empty Variant), so calling
	# get_meta(key, null) on a resident with no model applied yet logs a
	# recoverable engine error every frame. See founder/cat_appearance.gd's
	# find_animation_player() for the same fix, found the hard way there.
	if resident.has_meta("resident_animation_player"):
		var meta: Variant = resident.get_meta("resident_animation_player")
		if meta is AnimationPlayer and is_instance_valid(meta):
			return meta
	var model_root := resident.get_node_or_null("ModelRoot")
	return _find_animation_player(model_root) if model_root != null else null

static func _find_file(model_dir: String, suffix: String) -> String:
	var absolute_dir := ProjectSettings.globalize_path(model_dir)
	var dir := DirAccess.open(model_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(suffix):
			dir.list_dir_end()
			return "%s/%s" % [model_dir, file_name]
		file_name = dir.get_next()
	dir.list_dir_end()
	push_warning("[ResidentAppearance] No file ending in '%s' found in %s" % [suffix, absolute_dir])
	return ""

static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

## Each Meshy export carries exactly one animation in its default library --
## lifted out under a clean name rather than kept under Meshy's own clip name.
static func _copy_first_animation(source_player: AnimationPlayer, target_lib: AnimationLibrary, clean_name: String) -> void:
	for lib_name: StringName in source_player.get_animation_library_list():
		var lib := source_player.get_animation_library(lib_name)
		for anim_name: StringName in lib.get_animation_list():
			target_lib.add_animation(clean_name, lib.get_animation(anim_name))
			return

static func _graft_animation(target_lib: AnimationLibrary, clean_name: String, source_path: String) -> void:
	if source_path.is_empty():
		return
	var packed: PackedScene = load(source_path)
	if packed == null:
		return
	var source_scene := packed.instantiate()
	var source_player := _find_animation_player(source_scene)
	if source_player != null:
		_copy_first_animation(source_player, target_lib, clean_name)
	source_scene.queue_free()
