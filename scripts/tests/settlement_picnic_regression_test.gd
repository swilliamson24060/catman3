extends SceneTree

const PICNIC_SCENE: PackedScene = preload("res://scenes/picnic/picnic.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var settlement := root.get_node("SettlementManager") as Phase2SettlementManager
	var game_state := root.get_node("GameState") as Phase1GameState
	game_state.reset()

	assert(settlement.is_position_inside_settlement(Vector3(12.0, 0.0, 12.0)), "Ground visibly inside the settlement walls must allow building")
	assert(settlement.is_position_inside_settlement(Vector3(-14.5, 0.0, 14.5)), "The inner wall edge must remain controlled territory")
	assert(not settlement.is_position_inside_settlement(Vector3(14.6, 0.0, 0.0)), "Ground beyond the visible walls must remain outside the settlement")

	var picnic := PICNIC_SCENE.instantiate() as Phase1Picnic
	root.add_child(picnic)
	assert(game_state.register_picnic(picnic), "A picnic must register before it can be relocated")
	picnic.pack_up()
	assert(not game_state.has_picnic(), "Packing must immediately clear the picnic slot for relocation")
	await process_frame
	assert(not is_instance_valid(picnic), "Packing must remove the old picnic from the world")

	print("SETTLEMENT_PICNIC_REGRESSION_TEST_PASS")
	quit(0)
