extends Node
## Temporary smoke test for Step 0 (Foundational Architecture). Confirms
## DataRegistry loaded/validated correctly and that a save file round-trips.
## Safe to delete once Step 0 is verified -- Step 1 (grid/blueprints/fog)
## will replace this with real gameplay.

func _ready() -> void:
	await get_tree().process_frame
	print("--- Step 0 self-test ---")

	var mouse := DataRegistry.get_animal_type("mouse")
	print("mouse animal type found: ", not mouse.is_empty())

	var pattern := DataRegistry.get_resonance_pattern("pattern_catnip_triangle")
	print("catnip triangle pattern found: ", not pattern.is_empty())

	var cheese := DataRegistry.make_inventory_item("cheese_mild")
	print("cheese_mild -> InventoryItem: ", cheese != null and cheese.display_name == "Mild Cheese" and cheese.properties.get("variety") == "mild")

	DataRegistry.apply_global_bonuses(DataRegistry.get_founder_cat("barnaby").get("modifiers", []))

	SaveService.new_game("barnaby")
	SaveService.current.discovered_patterns.append("pattern_catnip_triangle")
	SaveService.save_game()

	var reloaded_ok := SaveService.load_game()
	var round_trip_ok := reloaded_ok \
		and SaveService.current.founder_cat_id == "barnaby" \
		and SaveService.current.discovered_patterns.has("pattern_catnip_triangle")
	print("save/load round-trip ok: ", round_trip_ok)

	var grid_ok := GridService.grid_to_world(Vector2i(3, 4)) == Vector3(6.0, 0.0, 8.0) \
		and GridService.world_to_grid(Vector3(6.0, 0.0, 8.0)) == Vector2i(3, 4)
	print("grid <-> world mapping ok: ", grid_ok)

	print("--- Step 0 self-test complete ---")
