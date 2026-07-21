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
const SAVE_VERSION := 1

var current: SaveData = SaveData.new()

func new_game(founder_cat_id: String) -> void:
	current = SaveData.new()
	current.founder_cat_id = founder_cat_id

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"founder_cat_id": current.founder_cat_id,
		"discovered_patterns": current.discovered_patterns,
		"unlocked_content": current.unlocked_content,
		"inventory": Inventory.serialize(),
		"town_storage": TownStorage.serialize(),
		"buildings": BuildingManager.serialize(),
		"animals": AnimalManager.serialize_roster(),
		"phase2_economy": GameState.serialize_economy(),
		"phase2_completed_buildings": SettlementManager.serialize_completed_buildings(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveService] Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[SaveService] Saved game.")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveService] Could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("[SaveService] Save file is corrupt or unreadable -- ignoring.")
		return false

	current = SaveData.new()
	current.founder_cat_id = str(parsed.get("founder_cat_id", ""))
	current.discovered_patterns.assign(_as_string_array(parsed.get("discovered_patterns", [])))
	current.unlocked_content.assign(_as_string_array(parsed.get("unlocked_content", [])))

	Inventory.restore(_as_array(parsed.get("inventory", [])))
	TownStorage.restore(_as_array(parsed.get("town_storage", [])))
	BuildingManager.restore(_as_array(parsed.get("buildings", [])))
	AnimalManager.restore_roster(_as_array(parsed.get("animals", [])))
	GameState.restore_economy(_as_dictionary(parsed.get("phase2_economy", {})))
	SettlementManager.restore_completed_buildings(_as_array(parsed.get("phase2_completed_buildings", [])))

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
