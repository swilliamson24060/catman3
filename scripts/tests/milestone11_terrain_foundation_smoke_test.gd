extends SceneTree

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	var registry := root.get_node("DataRegistry")

	_check_terrain_tiles_loaded(registry)
	_check_malformed_fragment_handling(registry)
	_check_away_timer_round_trip()
	_check_tile_fog_plot_round_trip()

	if _failure.is_empty():
		print("MILESTONE_11_TERRAIN_FOUNDATION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check_terrain_tiles_loaded(registry: Node) -> void:
	var all_ids: Array = []
	for tile: Dictionary in registry.get_all_terrain_tiles():
		all_ids.append(str(tile.get("id", "")))
	for starter_id in ["grass", "path", "sapling", "pond_edge"]:
		_check(starter_id in all_ids, "core starter tile '%s' should be loaded" % starter_id)
		_check(bool(registry.get_terrain_tile(starter_id).get("starter", false)), "core tile '%s' should be marked starter" % starter_id)

	var kelp: Dictionary = registry.get_terrain_tile("expansion_undersea:kelp_bed")
	_check(not kelp.is_empty(), "Undersea expansion's kelp_bed terrain tile should load under its namespace")
	_check(not bool(kelp.get("starter", true)), "kelp_bed should not be a starter tile")

	# Adjacency normalization: kelp_bed's neighbors are authored as bare core
	# ids ("grass", "pond_edge") -- confirm _normalize_references canonicalized
	# them the same way every other reference field is canonicalized.
	var adjacency: Dictionary = kelp.get("adjacency", {})
	_check(adjacency.get("north", []).has("grass"), "kelp_bed adjacency should resolve bare 'grass' to the core tile")

	_check(registry.load_errors.is_empty(), "clean terrain_tiles.json + expansion should not produce validation errors: %s" % str(registry.load_errors))

func _check_malformed_fragment_handling(registry: Node) -> void:
	var fixture_path := "user://milestone11_broken_fixture.json"
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string("{ this is not valid json,,,")
	file.close()

	var before: int = registry.load_errors.size()
	registry._load_fragment(fixture_path, "terrain_tiles", "broken_fixture")
	_check(registry.load_errors.size() == before + 1, "a malformed fragment file should log exactly one error, not stay silent")
	if registry.load_errors.size() > before:
		_check(registry.load_errors[registry.load_errors.size() - 1].contains(fixture_path), "the logged error should name the broken file")

	# Same file probed again (mirrors how the real loader probes one file
	# once per category) must not produce a second, duplicate error.
	registry._load_fragment(fixture_path, "buildings", "broken_fixture")
	_check(registry.load_errors.size() == before + 1, "re-probing the same broken file for a different category should not duplicate the error")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	registry.load_errors.resize(before)   # restore baseline so later checks aren't confused by this fixture

func _check_away_timer_round_trip() -> void:
	var timer := AwayTimer.new()
	timer.start(120.0)
	var restored := AwayTimer.from_data(timer.serialize())
	_check(is_equal_approx(restored.cap_seconds, 120.0), "AwayTimer.cap_seconds must survive serialize/restore")
	_check(is_equal_approx(restored.started_at, timer.started_at), "AwayTimer.started_at must survive serialize/restore")
	_check(restored.credited_seconds() >= 0.0 and restored.credited_seconds() <= 120.0, "restored AwayTimer's credited_seconds must stay within [0, cap]")

func _check_tile_fog_plot_round_trip() -> void:
	var plot := TileFogPlot.new()
	plot.plot_id = &"test_plot"
	plot.width = 4
	plot.height = 4
	plot.origin = Vector3(3.0, 0.0, -7.0)
	plot.set_tile_id(Vector2i(0, 0), "grass")
	plot.set_tile_id(Vector2i(1, 0), "path")
	plot.reveal_around(Vector2i(2, 2), 1)

	var restored := TileFogPlot.from_data(plot.serialize())
	_check(restored.plot_id == &"test_plot", "TileFogPlot.plot_id must survive round-trip")
	_check(restored.width == 4 and restored.height == 4, "TileFogPlot dimensions must survive round-trip")
	_check(restored.origin.is_equal_approx(Vector3(3.0, 0.0, -7.0)), "TileFogPlot.origin must survive round-trip")
	_check(restored.get_tile_id(Vector2i(0, 0)) == "grass", "generated tile ids must survive round-trip")
	_check(restored.get_tile_id(Vector2i(1, 0)) == "path", "generated tile ids must survive round-trip")
	_check(restored.is_revealed(Vector2i(0, 0)), "a generated cell must be revealed, before and after round-trip")
	_check(restored.is_revealed(Vector2i(2, 2)), "reveal_around's flood-fill must survive round-trip")
	_check(not restored.is_generated(Vector2i(3, 3)), "an untouched cell must remain ungenerated after round-trip")
	_check(restored.revealed_fraction() > 0.0 and restored.revealed_fraction() < 1.0, "a partially-revealed plot must report a fraction strictly between 0 and 1")

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
