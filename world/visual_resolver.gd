class_name VisualResolver
extends RefCounted
## Shared "what should this thing look like" resolver (Step 9 polish: the
## GDD's 2D-sprite-fallback requirement). Every building/animal visual asks
## the same three questions, cheapest-real-asset-first:
##   1. Does its data entry name a real 3D model (`mesh_scene_path`) that
##      actually exists on disk? Instantiate it.
##   2. Otherwise, does it name a 2D `sprite_path` texture? Build a
##      billboard Sprite3D at the same GridService transform a 3D mesh
##      would have used -- the GDD's "zero-code-change" 2.5D fallback.
##   3. Otherwise, hand back to whatever procedural placeholder the caller
##      already builds (a tinted box, a preloaded stand-in model, etc.)
## No caller needs an if/else chain of its own -- dropping a real model or
## sprite path into a buildings.json/animal_types.json entry is the only
## change ever needed to upgrade a placeholder to real art.

static func resolve(data: Dictionary, fallback: Callable) -> Node3D:
	var mesh_path: String = data.get("mesh_scene_path", "")
	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var scene: PackedScene = load(mesh_path)
		if scene:
			return scene.instantiate()

	var sprite_path: String = data.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite := Sprite3D.new()
		sprite.texture = load(sprite_path)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.01
		sprite.position.y = 0.5
		return sprite

	return fallback.call()
