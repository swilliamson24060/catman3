extends RefCounted
class_name CatAppearance
## Applies a founder's real 3D model to the player cat -- one distinct
## rigged/animated .glb per founder (data/cats.json's model_dir), not a
## shared model recolored per founder the way the old Kenney placeholder was.
##
## Each model_dir holds three Meshy AI exports that share one 24-bone
## skeleton (confirmed by inspecting the actual imports): a base
## "Character_output" (rest pose) plus "Animation_Walking_withSkin" and
## "Animation_Running_withSkin" -- each of those two is a full second copy of
## the skinned mesh with just one baked-in animation, Meshy's normal export
## shape for a multi-animation character. Godot imports each .glb as its own
## scene, so rather than have three skinned meshes on screen at once, this
## uses Character_output as the one visible model and grafts the other two
## files' single animation each onto its AnimationPlayer, under clean names
## ("idle"/"walk"/"run") so gameplay code never needs to know Meshy's actual
## clip names (e.g. "Armature|walking_man|baselayer").

const MODEL_FILES := {
	"idle": "Meshy_AI_Vestcat_biped_Character_output.glb",
	"walk": "Meshy_AI_Vestcat_biped_Animation_Walking_withSkin.glb",
	"run": "Meshy_AI_Vestcat_biped_Animation_Running_withSkin.glb",
}

## Tune this single shared constant if the models ever need rescaling again;
## nothing else here needs to change.
const MODEL_SCALE := 1.0
## Meshy's rig faces the opposite way from this project's -Z-forward
## convention -- the same fix the old Kenney asset needed.
const MODEL_ROTATION_Y_DEGREES := 180.0

static func apply_to_player(player: Node, founder_id: String, _coat: Dictionary) -> void:
	if player == null:
		return
	var founder_data: Dictionary = player.get_node("/root/DataRegistry").get_founder_cat(founder_id)
	var model_dir: String = str(founder_data.get("model_dir", ""))
	if model_dir.is_empty():
		push_warning("[CatAppearance] No model_dir for founder '%s' -- leaving the current visual as-is." % founder_id)
		return

	var visual_root := player.get_node_or_null("VisualRoot")
	if visual_root == null:
		return
	for child in visual_root.get_children():
		child.queue_free()

	var base_packed: PackedScene = load("%s/%s" % [model_dir, MODEL_FILES.idle])
	if base_packed == null:
		push_warning("[CatAppearance] Could not load base model for founder '%s' at %s" % [founder_id, model_dir])
		return
	var model := base_packed.instantiate() as Node3D
	model.name = "CatModel"
	model.rotation_degrees.y = MODEL_ROTATION_Y_DEGREES
	model.scale = Vector3.ONE * MODEL_SCALE
	visual_root.add_child(model)

	var anim_player := _find_animation_player(model)
	if anim_player == null:
		return
	var combined := AnimationLibrary.new()
	_copy_first_animation(anim_player, combined, "idle")
	_graft_animation(combined, "walk", "%s/%s" % [model_dir, MODEL_FILES.walk])
	_graft_animation(combined, "run", "%s/%s" % [model_dir, MODEL_FILES.run])
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", combined)
	anim_player.play("idle")
	player.set_meta("cat_animation_player", anim_player)

static func find_animation_player(player: Node) -> AnimationPlayer:
	if player == null:
		return null
	# has_meta() guard is required, not stylistic: Object.get_meta()'s default
	# parameter can't distinguish "caller passed null" from "caller passed
	# nothing" (both collapse to the same internal empty Variant), so calling
	# get_meta(key, null) on a player with no model applied yet -- the normal
	# state before founder selection -- logs a recoverable engine error on
	# every single physics frame.
	if player.has_meta("cat_animation_player"):
		var meta: Variant = player.get_meta("cat_animation_player")
		if meta is AnimationPlayer and is_instance_valid(meta):
			return meta
	var visual_root := player.get_node_or_null("VisualRoot")
	return _find_animation_player(visual_root) if visual_root != null else null

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
	var packed: PackedScene = load(source_path)
	if packed == null:
		return
	var source_scene := packed.instantiate()
	var source_player := _find_animation_player(source_scene)
	if source_player != null:
		_copy_first_animation(source_player, target_lib, clean_name)
	source_scene.queue_free()
