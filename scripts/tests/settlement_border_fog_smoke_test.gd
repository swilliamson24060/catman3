extends SceneTree

const FOG_SCRIPT := preload("res://world/fog_renderer.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var settlement_manager := root.get_node("SettlementManager") as Phase2SettlementManager
	var inside := Vector3(14.0, 0.1, 0.0)
	var outside := Vector3(18.0, 0.1, 0.0)
	var constrained := settlement_manager.constrain_position_to_settlement(inside, outside)
	assert(settlement_manager.is_position_inside_settlement(constrained), "Founder and mouse movement must stop inside the settlement border")
	assert(constrained.x <= Phase2SettlementManager.INITIAL_WALLED_HALF_EXTENT, "Movement must not cross the initial border")

	var fog := MultiMeshInstance3D.new()
	fog.set_script(FOG_SCRIPT)
	root.add_child(fog)
	await process_frame
	assert(bool(fog.call("is_position_fogged", outside)), "Territory outside the settlement must begin fogged")

	var edge_building := Node3D.new()
	root.add_child(edge_building)
	edge_building.global_position = Vector3(14.0, 0.0, 0.0)
	settlement_manager.register_influence_source(edge_building, 7.0)
	var expanded_position := Vector3(19.0, 0.1, 0.0)
	assert(settlement_manager.is_position_inside_settlement(expanded_position), "An edge building must expand the settlement border")
	assert(not bool(fog.call("is_position_fogged", expanded_position)), "Fog must dissipate over newly expanded territory")
	assert(bool(fog.call("is_position_fogged", Vector3(22.0, 0.1, 0.0))), "Fog beyond the new building influence must remain")
	assert(settlement_manager.constrain_position_to_settlement(inside, expanded_position).is_equal_approx(expanded_position), "Movement must unlock inside expanded territory")

	print("SETTLEMENT_BORDER_FOG_SMOKE_TEST_PASS")
	quit(0)
