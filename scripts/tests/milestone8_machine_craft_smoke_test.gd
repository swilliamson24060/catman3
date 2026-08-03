extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await process_frame
	var project := root.get_node("CommunityProjectService")
	var resonance := root.get_node("SeasonalResonanceService")
	var machine := root.get_node("CommunityMachineService")
	var save := root.get_node("SaveService")
	save.new_game("founder_milestone8")
	var clearing := CLEARING.instantiate()
	root.add_child(clearing)
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	await process_frame
	_check(machine.definition.id == "machine_garden_irrigation", "slice must contain exactly the irrigation machine definition")
	_check(machine.craft_family.id == "craft_family_natural_dyes", "slice must contain exactly one natural-dye craft family")
	var machine_scene := clearing.get_node("WorkshopMachineSlot/GardenIrrigationAssembly")
	_check(machine_scene.has_node("OperatorSocket") and machine_scene.has_node("InputSocket") and machine_scene.has_node("OutputSocket") and machine_scene.has_node("WaterVFXSocket"), "machine art replacement sockets must be stable")
	_check(machine.current_state == &"incomplete" and not machine.request_player_operation(), "incomplete machine cannot operate")
	project.restore_state({"active":true, "phase_index":3, "phase_contributors":[], "player_participated":true, "resident_participated":true})
	machine.restore_state({})
	_check(machine.installed and machine.current_state == &"installed_idle", "garden irrigation phase must install the communal machine")
	_check(not machine.craft_unlocked and not machine.request_player_operation(), "dyes must remain locked before First Bloom")
	var component_ids: Array = machine.definition.component_ids
	_check(component_ids.has("component_rain_lens") and component_ids.has("component_copper_gear") and component_ids.has("component_heirloom_seeds"), "one discovery identity must support investigation, project, and Resonance use")
	machine._on_first_bloom(&"resonance_first_bloom")
	machine._on_first_bloom(&"resonance_first_bloom")
	_check(machine.craft_unlocked and machine.unlock_count == 1, "First Bloom unlock must be idempotent")
	_check(machine.current_state == &"resonant" and machine.request_player_operation(), "unlocked machine must begin a visible craft cycle")
	await machine.craft_completed
	_check(machine.operation_count == 1 and machine.completed_crafts.size() == 1, "visible cycle must create one cloth output")
	var pip: ResidentAgent = root.get_node("ResidentManager").get_agent(&"resident_pip")
	_check(pip.activity_id() in [&"operate_irrigation", &"inspect_irrigation"], "Pip must react to machine operation")
	machine.set_broken(true)
	_check(machine.current_state == &"maintenance" and pip.activity_id() == &"maintain_irrigation", "broken state must produce Pip's maintenance routine")
	machine.set_broken(false)
	var path := "user://milestone8_machine_test.json"
	_check(save.save_game(path), "machine save must succeed")
	machine.reset()
	_check(save.load_game(path), "machine load must succeed")
	_check(machine.installed and machine.resonant and machine.craft_unlocked and machine.completed_crafts.size() == 1, "machine and craft output must persist")
	_check(machine.request_player_operation(), "craft family must remain usable after reload")
	await machine.craft_completed
	_check(machine.operation_count == 2, "reloaded craft family must create another visible output")
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path) + ".bak")
	clearing.queue_free()
	completed_buildings.queue_free()
	await process_frame
	await process_frame
	print("MILESTONE_8_MACHINE_CRAFT_SMOKE_TEST_PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
