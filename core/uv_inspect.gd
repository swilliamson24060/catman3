extends Node
## Temporary: samples the body mesh's actual UVs against colormap.png to find
## which swatch colors are "fur" vs "eyes" so we can palette-swap the real
## texture instead of flattening it (which was erasing the eyes). Safe to
## delete after use.

const TEXTURE_PATH := "res://kenney_cube-pets_1/Models/Textures/colormap.png"

func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_cat")
	var body: MeshInstance3D = player.get_node_or_null("animal-cat2/animal-cat/root/body")
	if body == null:
		print("[UVInspect] body not found")
		return

	var mesh: Mesh = body.mesh
	print("[UVInspect] body surfaces: ", mesh.get_surface_count())
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	print("[UVInspect] vertex count: ", verts.size(), " uv count: ", uvs.size())

	var tex: Texture2D = load(TEXTURE_PATH)
	var img: Image = tex.get_image()
	print("[UVInspect] texture size: ", img.get_size())

	var color_counts: Dictionary = {}  # rounded color string -> {count, sample_uv, sample_vert}
	for i in uvs.size():
		var uv := uvs[i]
		var px := int(clamp(uv.x, 0.0, 0.9999) * img.get_width())
		var py := int(clamp(uv.y, 0.0, 0.9999) * img.get_height())
		var c := img.get_pixel(px, py)
		var key := "%d,%d,%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
		if not color_counts.has(key):
			color_counts[key] = {"count": 0, "uv": uv, "vert": verts[i]}
		color_counts[key]["count"] += 1

	print("[UVInspect] distinct colors sampled by body vertices:")
	for key in color_counts.keys():
		var info = color_counts[key]
		print("  color=%s count=%d sample_uv=%s sample_vert=%s" % [key, info["count"], info["uv"], info["vert"]])
