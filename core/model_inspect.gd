extends Node
## Temporary: dumps the animal-cat model's node tree so we can find the eye
## mesh/material. Safe to delete after use.

func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_cat")
	if player == null:
		print("[ModelInspect] no player found")
		return
	var cat := player.get_node_or_null("animal-cat2")
	if cat == null:
		print("[ModelInspect] no animal-cat2 found")
		return
	print("--- animal-cat2 tree ---")
	_dump(cat, 0)
	print("--- end tree ---")

func _dump(node: Node, depth: int) -> void:
	var prefix := "  ".repeat(depth)
	var path := str(node.get_path())
	print("%s>>> %s (%s)" % [prefix, node.name, node.get_class()])
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		var surf_count := mesh.get_surface_count() if mesh else 0
		print("%s    full_path=%s surfaces=%d" % [prefix, path, surf_count])
		for i in surf_count:
			var mat: Material = node.get_surface_override_material(i)
			var source := "override"
			if mat == null:
				mat = mesh.surface_get_material(i)
				source = "embedded"
			var mat_name: String = mat.resource_name if mat else "null"
			print("%s    surface %d material (%s): %s" % [prefix, i, source, mat_name])
			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat
				print("%s      albedo_color=%s albedo_texture=%s" % [
					prefix, sm.albedo_color, sm.albedo_texture.resource_path if sm.albedo_texture else "none"
				])
	for child in node.get_children():
		_dump(child, depth + 1)
