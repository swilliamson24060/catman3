extends SceneTree

const SAVE_PATH := "/tmp/catmando_milestone9_save_test.json"
const VisualResolverScript := preload("res://world/visual_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var grid: Node = root.get_node("GridService")
	var audio: Node = root.get_node("AudioService")
	var save_service: Node = root.get_node("SaveService")
	var game_state: Node = root.get_node("GameState")
	var inventory: Node = root.get_node("Inventory")

	# One shared AStar grid serves many queries and only rebuilds after a tile edit.
	grid.call("reset_pathfinding_diagnostics")
	for i in range(24):
		assert(not grid.call("find_path", Vector2i.ZERO, Vector2i(10, 10)).is_empty())
	var path_diag: Dictionary = grid.call("get_pathfinding_diagnostics")
	assert(path_diag.queries == 24 and path_diag.grid_rebuilds == 1, "Path queries must reuse one built grid")
	var astar_instance_id: int = path_diag.grid_instance_id
	grid.call("set_tile_state", Vector2i(5, 5), 1)
	grid.call("find_path", Vector2i.ZERO, Vector2i(10, 10))
	path_diag = grid.call("get_pathfinding_diagnostics")
	assert(path_diag.grid_rebuilds == 2 and path_diag.grid_instance_id == astar_instance_id, "Tile edits must rebuild the pooled grid in place")

	# Missing final assets still produce short, pooled, data-configured tones.
	for cue_id: String in ["building_constructed", "animal_recruited", "achievement_unlocked", "pattern_discovered"]:
		assert(bool(audio.call("play_cue", cue_id)), "Configured cue must always be playable: %s" % cue_id)
	assert(not bool(audio.call("play_cue", "missing_cue")), "Unknown cues must fail quietly")
	var audio_diag: Dictionary = audio.call("get_pool_diagnostics")
	assert(audio_diag.pool_size == 6 and audio_diag.configured_players == 4, "One-shot audio must use the shared pool")

	# A sprite path resolves to a billboard without changing placement code.
	var visual: Node3D = VisualResolverScript.resolve(
		{"sprite_path": "res://inventory/icons/wood.png"},
		func() -> Node3D: return Node3D.new()
	)
	assert(visual is Sprite3D, "A valid sprite_path must select the 2D fallback")
	assert((visual as Sprite3D).billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Fallback sprites must face the camera")
	visual.free()

	# Two atomic saves retain the previous snapshot. Corrupting the primary
	# recovers the backup; a future-version primary is rejected transactionally.
	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	_cleanup_save_files()
	game_state.cheese = 31
	assert(bool(save_service.call("save_game", SAVE_PATH)))
	game_state.cheese = 47
	assert(bool(save_service.call("save_game", SAVE_PATH)))
	assert(FileAccess.file_exists(SAVE_PATH + ".bak"), "Second save must retain a backup")
	_write_text(SAVE_PATH, "{ definitely corrupt")
	game_state.cheese = 99
	assert(bool(save_service.call("load_game", SAVE_PATH)), "Corrupt primary must recover from backup")
	assert(game_state.cheese == 31, "Backup recovery must restore the previous complete snapshot")
	_write_text(SAVE_PATH, JSON.stringify({"version": 999, "phase2_economy": {"cheese": 1}}))
	game_state.cheese = 88
	assert(not bool(save_service.call("load_game", SAVE_PATH)), "Future save versions must be rejected")
	assert(game_state.cheese == 88, "Rejected saves must not mutate live state")
	assert(not FileAccess.file_exists(SAVE_PATH + ".tmp"), "Atomic save must not leave a temporary file")

	# Hand-edited inventory values are bounded or dropped during restore.
	inventory.call("restore", [
		{"item_id": "wood", "quantity": -4, "age": -10.0},
		{"item_id": "wood", "quantity": 10000, "age": -2.0},
	])
	assert(inventory.call("get_slot", 0).is_empty(), "Non-positive restored stacks must be dropped")
	var restored_slot: Dictionary = inventory.call("get_slot", 1)
	assert(restored_slot.quantity == 99 and restored_slot.age == 0.0, "Restored stacks and ages must be clamped")

	_cleanup_save_files()
	print("MILESTONE_9_POLISH_SMOKE_TEST_PASS")
	quit(0)


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(contents)
	file.close()


func _cleanup_save_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
