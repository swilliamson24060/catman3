extends Node
## Temporary: verifies the actual pixel colors of the loaded body material's
## textures at runtime (not just whether load() succeeded). Safe to delete
## after use.

func _ready() -> void:
	await get_tree().process_frame
	print("--- Texture pixel check ---")

	var player := get_tree().get_first_node_in_group("player_cat")
	var founder_select := get_tree().root.find_child("FounderSelectUI", true, false)

	for founder_id in ["barnaby", "whisper", "turbo"]:
		var founder_data := DataRegistry.get_founder_cat(founder_id)
		CatAppearance.apply_to_player(player, founder_id, founder_data.get("coat", {}))

		var body: MeshInstance3D = player.get_node_or_null(CatAppearance.BODY_PATH)
		var mat: StandardMaterial3D = body.get_surface_override_material(0)

		print("%s: albedo_texture=%s emission_texture=%s albedo_color=%s" % [
			founder_id,
			mat.albedo_texture.resource_path if mat.albedo_texture else "NONE",
			mat.emission_texture.resource_path if mat.emission_texture else "NONE",
			mat.albedo_color,
		])

		if mat.albedo_texture:
			var img: Image = mat.albedo_texture.get_image()
			if img == null:
				print("  albedo image is null (compressed format can't read back on CPU!)")
			else:
				# sample a known fur pixel location and a known eye pixel location
				var fur_uv := Vector2(0.843748, 0.97499)
				var eye_uv := Vector2(0.96875, 0.546914)
				var fur_px := Vector2i(int(fur_uv.x * img.get_width()), int(fur_uv.y * img.get_height()))
				var eye_px := Vector2i(int(eye_uv.x * img.get_width()), int(eye_uv.y * img.get_height()))
				print("  fur pixel @%s = %s" % [fur_px, img.get_pixel(fur_px.x, fur_px.y)])
				print("  eye pixel @%s = %s" % [eye_px, img.get_pixel(eye_px.x, eye_px.y)])

	print("--- Texture pixel check complete ---")
