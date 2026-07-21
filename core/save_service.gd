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
const SAVE_VERSION := 3

var current: SaveData = SaveData.new()

func new_game(founder_cat_id: String) -> void:
	current = SaveData.new()
	current.founder_cat_id = founder_cat_id
	AchievementService.reset_progress()

func save_game(save_path: String = SAVE_PATH) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"founder_cat_id": current.founder_cat_id,
		"discovered_patterns": current.discovered_patterns,
		"unlocked_content": current.unlocked_content,
		"achievement_progress": AchievementService.serialize_progress(),
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

	current = SaveData.new()
	current.founder_cat_id = str(parsed.get("founder_cat_id", ""))
	current.discovered_patterns.assign(_as_string_array(parsed.get("discovered_patterns", [])))
	current.unlocked_content.assign(_as_string_array(parsed.get("unlocked_content", [])))
	current.achievement_progress = _as_dictionary(parsed.get("achievement_progress", {}))
	AchievementService.set_tracking_enabled(false)
	AchievementService.restore_progress(current.achievement_progress)

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
