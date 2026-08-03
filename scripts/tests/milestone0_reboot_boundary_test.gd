extends SceneTree

const REBOOT_SCENE := preload("res://scenes/world/village_clearing.tscn")
const LEGACY_SCENE := preload("res://scenes/world/main.tscn")
const SAVE_PATH := "/tmp/catmando_milestone0_legacy_save.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	assert(bool(ProjectSettings.get_setting("feature/reboot_mode", false)))
	assert(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/world/village_clearing.tscn")
	var reboot := REBOOT_SCENE.instantiate()
	var legacy := LEGACY_SCENE.instantiate()
	assert(reboot != null and reboot.name == "VillageClearing")
	assert(legacy != null and legacy.name == "Main")
	reboot.free()
	legacy.free()
	assert(root.has_node("CalendarService"))
	assert(root.has_node("ResidentManager"))
	assert(root.has_node("SeasonalResonanceService"))
	assert(not root.get_node("SeasonalResonanceService").supports_seasonal_evaluation())

	_write_legacy_save()
	var save_service := root.get_node("SaveService")
	var founder_before: String = save_service.current.founder_cat_id
	assert(not save_service.load_game(SAVE_PATH), "Legacy saves must be rejected transactionally in reboot mode")
	assert(save_service.current.founder_cat_id == founder_before)
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	ProjectSettings.set_setting("feature/reboot_mode", false)
	assert(save_service.load_game(SAVE_PATH), "Legacy saves must migrate in legacy mode")
	assert(save_service.current.save_generation == "legacy")
	assert(save_service.current.founder_cat_id == "legacy_founder")
	ProjectSettings.set_setting("feature/reboot_mode", true)
	DirAccess.remove_absolute(SAVE_PATH)
	print("MILESTONE_0_REBOOT_BOUNDARY_TEST_PASS")
	quit(0)

func _write_legacy_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"version": 3, "founder_cat_id": "legacy_founder"}))
	file.close()
