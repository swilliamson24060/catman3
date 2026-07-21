extends Node
## Temporary smoke test for founder-cat coat/eye coloring. Verifies
## CatAppearance resolves the body mesh and assigns the per-founder baked
## texture (with emission for the eyes) correctly. Safe to delete once
## verified visually in the editor.

func _ready() -> void:
	await get_tree().process_frame
	print("--- Appearance self-test ---")

	var player := get_tree().get_first_node_in_group("player_cat")
	print("player found: ", player != null)

	for founder_id in ["barnaby", "whisper", "turbo"]:
		var founder_data := DataRegistry.get_founder_cat(founder_id)
		var coat: Dictionary = founder_data.get("coat", {})
		CatAppearance.apply_to_player(player, founder_id, coat)

		var body := player.get_node_or_null(CatAppearance.BODY_PATH)
		var body_mat: StandardMaterial3D = body.get_surface_override_material(0) if body else null

		print("%s -> body_found=%s has_albedo_tex=%s has_emission_tex=%s emission_enabled=%s" % [
			founder_id,
			body != null,
			(body_mat.albedo_texture != null) if body_mat else false,
			(body_mat.emission_texture != null) if body_mat else false,
			body_mat.emission_enabled if body_mat else "n/a",
		])
		if body_mat and body_mat.albedo_texture:
			print("  albedo_texture path: ", body_mat.albedo_texture.resource_path)
		if body_mat and body_mat.emission_texture:
			print("  emission_texture path: ", body_mat.emission_texture.resource_path)

	print("--- Appearance self-test complete ---")
