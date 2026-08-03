extends Node
## Autoload "SaveService". Owns the current run's SaveData (meta-progression:
## founder cat, discovered patterns, unlocked content) and round-trips it to
## disk as plain JSON (not a binary resource) so save files stay easy to
## inspect and diff-friendly for modding/debugging.
##
## Step 9 polish: world state (buildings, animals, inventory, town storage)
## isn't mirrored onto SaveData -- it's owned live by each autoload, so
## save_game()/load_game() just ask each one to serialize/restore itself.
## Every field read from the parsed JSON is defensively type-checked so a
## corrupt or hand-edited save file degrades to "skip that piece" rather
## than crashing the load.

const SAVE_PATH := "user://catmando_save.json"
const SAVE_VERSION := 4
const LEGACY_SAVE_VERSION := 3
const SAVE_GENERATION_REBOOT := "reboot"
const SAVE_GENERATION_LEGACY := "legacy"

var current: SaveData = SaveData.new()

func new_game(founder_cat_id: String) -> void:
	current = SaveData.new()
	current.founder_cat_id = founder_cat_id
	current.save_generation = _current_save_generation()
	current.world_seed = int(Time.get_unix_time_from_system())
	WeatherService.configure_seed(current.world_seed, 1)
	CalendarService.restore_state({"day": 1, "period": "morning"})
	var resident_manager := get_node_or_null("/root/ResidentManager")
	if resident_manager != null:
		resident_manager.new_game()
	var relationship_service := get_node_or_null("/root/RelationshipService")
	if relationship_service != null:
		relationship_service.reset()
	var project_service := get_node_or_null("/root/CommunityProjectService")
	if project_service != null:
		project_service.reset()
	get_node("/root/RumorService").reset()
	get_node("/root/DiscoveryService").reset()
	get_node("/root/InvestigationService").reset()
	get_node("/root/SeasonalResonanceService").reset()
	AchievementService.reset_progress()

func save_game(save_path: String = SAVE_PATH) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"save_generation": current.save_generation,
		"founder_cat_id": current.founder_cat_id,
		"discovered_patterns": current.discovered_patterns,
		"unlocked_content": current.unlocked_content,
		"achievement_progress": AchievementService.serialize_progress(),
		"world_seed": current.world_seed,
		"calendar_state": CalendarService.serialize_state(),
		"weather_state": WeatherService.serialize_state(),
		"resident_state": get_node("/root/ResidentManager").serialize_state(),
		"relationship_state": get_node("/root/RelationshipService").serialize_state(),
		"community_project_state": get_node("/root/CommunityProjectService").serialize_state(),
		"rumor_state": get_node("/root/RumorService").serialize_state(),
		"discovery_state": get_node("/root/DiscoveryService").serialize_state(),
		"investigation_state": get_node("/root/InvestigationService").serialize_state(),
		"seasonal_resonance_state": get_node("/root/SeasonalResonanceService").serialize_state(),
		"inventory": Inventory.serialize(),
		"town_storage": TownStorage.serialize(),
		"buildings": BuildingManager.serialize(),
		"animals": AnimalManager.serialize_roster(),
		"phase2_economy": GameState.serialize_economy(),
		"phase2_completed_buildings": SettlementManager.serialize_completed_buildings(),
	}
	var encoded := JSON.stringify(data, "\t")
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var temp_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveService] Could not open temporary save file for writing.")
		return false
	file.store_string(encoded)
	file.flush()
	file.close()
	if FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(absolute_path, backup_path) != OK:
			DirAccess.remove_absolute(temp_path)
			push_warning("[SaveService] Could not rotate the previous save into a backup.")
			return false
	if DirAccess.rename_absolute(temp_path, absolute_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		push_warning("[SaveService] Could not commit the temporary save.")
		return false
	print("[SaveService] Saved game.")
	return true

func load_game(save_path: String = SAVE_PATH) -> bool:
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var parsed := _read_save_dictionary(absolute_path)
	if parsed.is_empty():
		var backup_path := absolute_path + ".bak"
		parsed = _read_save_dictionary(backup_path)
		if not parsed.is_empty():
			push_warning("[SaveService] Primary save was unreadable; recovered the previous backup.")
	if parsed.is_empty():
		push_warning("[SaveService] Save file and backup are missing or unreadable -- ignoring.")
		return false
	var version := int(parsed.get("version", 1))
	if version > SAVE_VERSION:
		push_warning("[SaveService] Save version %d is newer than supported version %d." % [version, SAVE_VERSION])
		return false

	var migration := _migrate_to_current(parsed, version)
	if not bool(migration.get("ok", false)):
		push_warning("[SaveService] %s" % str(migration.get("message", "Save migration failed.")))
		return false
	parsed = migration.get("data", {})
	var save_generation := str(parsed.get("save_generation", SAVE_GENERATION_LEGACY))
	var expected_generation := _current_save_generation()
	if save_generation != expected_generation:
		push_warning("[SaveService] This is a %s save, but the project is running in %s mode. Switch feature/reboot_mode to load it; no data was changed." % [save_generation, expected_generation])
		return false

	current = SaveData.new()
	current.save_generation = save_generation
	current.founder_cat_id = str(parsed.get("founder_cat_id", ""))
	current.discovered_patterns.assign(_as_string_array(parsed.get("discovered_patterns", [])))
	current.unlocked_content.assign(_as_string_array(parsed.get("unlocked_content", [])))
	current.achievement_progress = _as_dictionary(parsed.get("achievement_progress", {}))
	current.world_seed = int(parsed.get("world_seed", 1337))
	current.calendar_state = _as_dictionary(parsed.get("calendar_state", {}))
	current.weather_state = _as_dictionary(parsed.get("weather_state", {}))
	current.resident_state = _as_dictionary(parsed.get("resident_state", {}))
	current.relationship_state = _as_dictionary(parsed.get("relationship_state", {}))
	current.community_project_state = _as_dictionary(parsed.get("community_project_state", {}))
	current.rumor_state = _as_dictionary(parsed.get("rumor_state", {}))
	current.discovery_state = _as_dictionary(parsed.get("discovery_state", {}))
	current.investigation_state = _as_dictionary(parsed.get("investigation_state", {}))
	current.seasonal_resonance_state = _as_dictionary(parsed.get("seasonal_resonance_state", {}))
	AchievementService.set_tracking_enabled(false)
	AchievementService.restore_progress(current.achievement_progress)
	WeatherService.restore_state(current.weather_state.merged({"world_seed": current.world_seed}, false))
	CalendarService.restore_state(current.calendar_state)
	get_node("/root/RelationshipService").restore_state(current.relationship_state)
	get_node("/root/CommunityProjectService").restore_state(current.community_project_state)
	get_node("/root/RumorService").restore_state(current.rumor_state)
	get_node("/root/DiscoveryService").restore_state(current.discovery_state)
	get_node("/root/InvestigationService").restore_state(current.investigation_state)
	get_node("/root/ResidentManager").restore_state(current.resident_state)
	get_node("/root/SeasonalResonanceService").restore_state(current.seasonal_resonance_state)

	Inventory.restore(_as_array(parsed.get("inventory", [])))
	TownStorage.restore(_as_array(parsed.get("town_storage", [])))
	BuildingManager.restore(_as_array(parsed.get("buildings", [])))
	AnimalManager.restore_roster(_as_array(parsed.get("animals", [])))
	GameState.restore_economy(_as_dictionary(parsed.get("phase2_economy", {})))
	SettlementManager.restore_completed_buildings(_as_array(parsed.get("phase2_completed_buildings", [])))
	ResonanceService.reapply_discovered_bonuses()
	AchievementService.set_tracking_enabled(true)

	print("[SaveService] Loaded game.")
	return true

func _migrate_to_current(source: Dictionary, version: int) -> Dictionary:
	if version < 1:
		return {"ok": false, "message": "Save version %d is invalid; no data was changed." % version}
	if version <= LEGACY_SAVE_VERSION:
		var migrated := source.duplicate(true)
		migrated["version"] = SAVE_VERSION
		migrated["save_generation"] = SAVE_GENERATION_LEGACY
		print("[SaveService] Migrated legacy save schema v%d to v%d at the compatibility boundary." % [version, SAVE_VERSION])
		return {"ok": true, "data": migrated}
	if version == SAVE_VERSION:
		var current_data := source.duplicate(true)
		if not current_data.has("save_generation"):
			return {"ok": false, "message": "Save schema v%d has no save_generation marker; no data was changed." % SAVE_VERSION}
		return {"ok": true, "data": current_data}
	return {"ok": false, "message": "Save version %d has no migration path; no data was changed." % version}

func _current_save_generation() -> String:
	return SAVE_GENERATION_REBOOT if bool(ProjectSettings.get_setting("feature/reboot_mode", true)) else SAVE_GENERATION_LEGACY

func _as_array(value) -> Array:
	return value if value is Array else []

func _as_string_array(value) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for v in value:
			if v is String:
				out.append(v)
	return out

func _as_dictionary(value) -> Dictionary:
	return value if value is Dictionary else {}

func _read_save_dictionary(absolute_path: String) -> Dictionary:
	if not FileAccess.file_exists(absolute_path):
		return {}
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
