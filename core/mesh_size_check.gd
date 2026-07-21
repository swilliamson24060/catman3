extends Node
## Temporary: compares body vs Group mesh sizes/vertex counts to figure out
## which one is the visually dominant geometry. Safe to delete after use.

func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_cat")

	var body: MeshInstance3D = player.get_node_or_null("animal-cat2/animal-cat/root/body")
	var group: MeshInstance3D = player.get_node_or_null("animal-cat2/animal-cat/root/body/Group")

	for pair in [["body", body], ["Group", group]]:
		var name: String = pair[0]
		var node: MeshInstance3D = pair[1]
		if node == null:
			print("%s: not found" % name)
			continue
		var aabb := node.get_aabb()
		var mesh: Mesh = node.mesh
		var arrays := mesh.surface_get_arrays(0)
		var vcount: int = arrays[Mesh.ARRAY_VERTEX].size()
		print("%s: aabb_size=%s aabb_position=%s vertex_count=%d visible=%s" % [
			name, aabb.size, aabb.position, vcount, node.visible
		])
