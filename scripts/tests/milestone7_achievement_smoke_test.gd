extends SceneTree

const SAVE_TEST_PATH := "/tmp/catmando_milestone7_save_test.json"
const HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const VAULT: BuildingDefinition = preload("res://resources/buildings/cheese_vault.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save_files()
	var achievements: Node = root.get_node("AchievementService")
	var save_service: Node = root.get_node("SaveService")
	var event_bus: Node = root.get_node("EventBus")
	var settlement := root.get_node("SettlementManager") as Phase2SettlementManager
	var unlock_events: Array[String] = []
	event_bus.achievement_unlocked.connect(func(id: String) -> void: unlock_events.append(id))
	save_service.call("new_game", "")

	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	settlement.restore_completed_buildings([])
	assert(not bool(achievements.call("is_unlocked", "cheese_vault")), "Cheese Vault must start locked.")

	# Phase 2 construction reaches the same data-driven achievement engine.
	var hut := HUT.completed_scene.instantiate() as CompletedBuilding
	hut.building_definition = HUT
	container.add_child(hut)
	settlement.register_completed_building(hut, HUT)
	assert(bool(achievements.call("is_unlocked", "first_mouse_hut")), "First Phase 2 hut must unlock Home Sweet Home.")

	# Four recruits persist without prematurely granting Guild of Five.
	for i: int in range(4):
		achievements.call("_on_phase2_mouse_recruited", null)
	assert(not bool(achievements.call("is_unlocked", "cheese_vault")), "Vault must remain locked before five recruits.")
	assert(bool(save_service.call("save_game", SAVE_TEST_PATH)), "Achievement progress must save.")
	save_service.call("new_game", "")
	settlement.restore_completed_buildings([])
	assert(bool(save_service.call("load_game", SAVE_TEST_PATH)), "Achievement progress must load.")
	await process_frame
	assert(not bool(achievements.call("is_unlocked", "cheese_vault")), "Restored count of four must remain locked.")

	# The fifth recruit grants achievement and content exactly once.
	achievements.call("_on_phase2_mouse_recruited", null)
	assert(bool(achievements.call("is_unlocked", "guild_of_five")), "Fifth recruit must unlock Guild of Five.")
	assert(bool(achievements.call("is_unlocked", "cheese_vault")), "Guild of Five must unlock Cheese Vault content.")
	assert(unlock_events.count("guild_of_five") == 1, "Achievement event must fire once.")
	achievements.call("_on_phase2_mouse_recruited", null)
	assert(unlock_events.count("guild_of_five") == 1, "Further recruits must not replay the reward.")

	var owner := CharacterBody3D.new()
	root.add_child(owner)
	var placement := BuildingPlacementController.new()
	owner.add_child(placement)
	assert(placement.is_definition_unlocked(VAULT), "Build gating must read the persisted content unlock.")

	assert(bool(save_service.call("save_game", SAVE_TEST_PATH)), "Unlocked content must save.")
	save_service.call("new_game", "")
	assert(bool(save_service.call("load_game", SAVE_TEST_PATH)), "Unlocked content must reload.")
	assert(bool(achievements.call("is_unlocked", "cheese_vault")), "Cheese Vault unlock must survive a fresh load.")
	_cleanup_save_files()

	print("MILESTONE_7_ACHIEVEMENT_SMOKE_TEST_PASS")
	quit(0)


func _cleanup_save_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := SAVE_TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
