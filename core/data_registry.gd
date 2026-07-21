extends Node
## Autoload "DataRegistry". Loads every core JSON file and every expansion
## fragment, merges them into namespaced registries, then validates
## cross-references. No other script should ever hardcode a stat -- it reads
## from here.
##
## Loading is two-pass: gather every fragment (core first, then each
## expansion file) into the registries, THEN validate references. This lets
## a single expansion file introduce a new animal and the new resource it
## produces together, in any order.
##
## Ids are namespaced ("core:building_mouse_hut",
## "expansion_x:wool") to prevent collisions between independently authored
## expansions. Getters accept either the bare id (assumed "core:") or an
## already-namespaced id, so JSON authored with plain ids keeps working
## unmodified.

const CORE_NAMESPACE := "core"
const CORE_DATA_DIR := "res://data/"
const EXPANSIONS_DIR := "res://expansions/"

var _buildings: Dictionary = {}         # "namespace:id" -> Dictionary
var _founder_cats: Dictionary = {}
var _animal_types: Dictionary = {}
var _items: Dictionary = {}
var _resonance_patterns: Dictionary = {}
var _achievements: Dictionary = {}
var _audio_cues: Dictionary = {}
var _body_colors: Dictionary = {}
var _eye_colors: Dictionary = {}
var _decorations: Dictionary = {}

var load_errors: Array[String] = []

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_buildings.clear()
	_founder_cats.clear()
	_animal_types.clear()
	_items.clear()
	_resonance_patterns.clear()
	_achievements.clear()
	_audio_cues.clear()
	_body_colors.clear()
	_eye_colors.clear()
	_decorations.clear()
	load_errors.clear()

	# --- Pass 1: gather + merge everything, core first, then expansions ---
	_load_fragment(CORE_DATA_DIR + "buildings.json", "buildings", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "cats.json", "founder_cats", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "animal_types.json", "animal_types", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "items.json", "items", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "resonance_patterns.json", "resonance_patterns", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "achievements.json", "achievements", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "audio_cues.json", "audio_cues", CORE_NAMESPACE)
	# coat_palette.json has three top-level arrays in one file -- _load_fragment
	# just reads whichever top_level_key it's told to, so three calls against
	# the same path pulls all three into their own registries.
	_load_fragment(CORE_DATA_DIR + "coat_palette.json", "body_colors", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "coat_palette.json", "eye_colors", CORE_NAMESPACE)
	_load_fragment(CORE_DATA_DIR + "coat_palette.json", "decorations", CORE_NAMESPACE)

	for file_path in _list_expansion_files():
		var mod_namespace := file_path.get_file().get_basename()
		_load_fragment(file_path, "buildings", mod_namespace)
		_load_fragment(file_path, "founder_cats", mod_namespace)
		_load_fragment(file_path, "animal_types", mod_namespace)
		_load_fragment(file_path, "items", mod_namespace)
		_load_fragment(file_path, "resonance_patterns", mod_namespace)
		_load_fragment(file_path, "achievements", mod_namespace)
		_load_fragment(file_path, "audio_cues", mod_namespace)
		# An expansion can grow the shared coat palette too -- e.g. add three
		# more body_colors and the total unique-look space jumps accordingly,
		# with zero changes to AppearanceService.
		_load_fragment(file_path, "body_colors", mod_namespace)
		_load_fragment(file_path, "eye_colors", mod_namespace)
		_load_fragment(file_path, "decorations", mod_namespace)

	# --- Pass 2: now that everything is merged, validate cross-references ---
	_validate_references()

	print("[DataRegistry] Loaded %d buildings, %d founder cats, %d animal types, %d items, %d resonance patterns, %d achievements, %d audio cues, %d/%d/%d coat colors/eyes/decorations" % [
		_buildings.size(), _founder_cats.size(), _animal_types.size(), _items.size(), _resonance_patterns.size(), _achievements.size(), _audio_cues.size(),
		_body_colors.size(), _eye_colors.size(), _decorations.size()
	])
	if load_errors.is_empty():
		print("[DataRegistry] Validation passed with no errors.")
	else:
		for err in load_errors:
			push_warning("[DataRegistry] %s" % err)

func _list_expansion_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(EXPANSIONS_DIR)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(EXPANSIONS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files

func _load_fragment(file_path: String, top_level_key: String, mod_namespace: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var text := FileAccess.get_file_as_string(file_path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has(top_level_key):
		return

	var target := _registry_for(top_level_key)
	for entry in parsed[top_level_key]:
		if not (entry is Dictionary) or not entry.has("id"):
			load_errors.append("Entry without an 'id' in %s (%s)" % [file_path, top_level_key])
			continue
		var qualified_id := "%s:%s" % [mod_namespace, entry["id"]]
		target[qualified_id] = entry

func _registry_for(top_level_key: String) -> Dictionary:
	match top_level_key:
		"buildings":
			return _buildings
		"founder_cats":
			return _founder_cats
		"animal_types":
			return _animal_types
		"items":
			return _items
		"resonance_patterns":
			return _resonance_patterns
		"achievements":
			return _achievements
		"audio_cues":
			return _audio_cues
		"body_colors":
			return _body_colors
		"eye_colors":
			return _eye_colors
		"decorations":
			return _decorations
	return {}

## Bare ids default to the core: namespace, but that's only a shortcut, not
## a hard rule: a bare id that isn't core content -- e.g. an expansion's
## founder cat, surfaced through founder_card.gd's already-generic
## `founder_data.get("id", "")`, which only ever knows the plain id an
## expansion author wrote -- still needs to resolve. So on a core-namespace
## miss, fall back to a scan for any namespace's entry with this bare id,
## the same leniency _id_exists_anywhere already applies during validation.
## Ambiguous if two expansions reuse the same bare id, but that's a modder
## authoring collision no engine code can resolve on their behalf.
func _resolve(registry: Dictionary, id: String) -> Dictionary:
	if id == "":
		return {}
	if id.contains(":"):
		return registry.get(id, {})
	var core_id := "%s:%s" % [CORE_NAMESPACE, id]
	if registry.has(core_id):
		return registry[core_id]
	for key in registry.keys():
		if key.ends_with(":" + id):
			return registry[key]
	return {}

func _id_exists_anywhere(registry: Dictionary, plain_or_qualified_id: String) -> bool:
	if plain_or_qualified_id == "":
		return false
	if registry.has(plain_or_qualified_id):
		return true
	for key in registry.keys():
		if key.ends_with(":" + plain_or_qualified_id):
			return true
	return false

func _validate_references() -> void:
	for pattern in _resonance_patterns.values():
		var anchor: String = pattern.get("anchor_building_type", "")
		if not _id_exists_anywhere(_buildings, anchor):
			load_errors.append("Resonance pattern '%s' references unknown anchor building '%s'" % [pattern.get("id"), anchor])
		for offset in pattern.get("required_offsets", []):
			var bt: String = offset.get("building_type", "")
			if not _id_exists_anywhere(_buildings, bt):
				load_errors.append("Resonance pattern '%s' references unknown building '%s'" % [pattern.get("id"), bt])

	for animal in _animal_types.values():
		var housing: String = animal.get("housing_building_type", "")
		if not _id_exists_anywhere(_buildings, housing):
			load_errors.append("Animal type '%s' references unknown housing building '%s'" % [animal.get("id"), housing])
		for job in animal.get("job_roles", []):
			if job.has("output") and not _id_exists_anywhere(_items, job["output"]):
				load_errors.append("Animal type '%s' job role '%s' produces unknown item '%s'" % [animal.get("id"), job.get("id", "?"), job["output"]])

	for achievement in _achievements.values():
		var condition: Dictionary = achievement.get("condition", {})
		var building_id: String = condition.get("building_id", "")
		if building_id != "" and not _id_exists_anywhere(_buildings, building_id):
			load_errors.append("Achievement '%s' condition references unknown building '%s'" % [achievement.get("id"), building_id])
		var species_id: String = condition.get("species_id", "")
		if species_id != "" and not _id_exists_anywhere(_animal_types, species_id):
			load_errors.append("Achievement '%s' condition references unknown animal type '%s'" % [achievement.get("id"), species_id])
		for content_id in achievement.get("unlocks", []):
			if not _id_exists_anywhere(_buildings, content_id) and not _id_exists_anywhere(_items, content_id) and not _id_exists_anywhere(_animal_types, content_id):
				load_errors.append("Achievement '%s' unlocks unknown content id '%s'" % [achievement.get("id"), content_id])

# --- Public getters -------------------------------------------------------

func get_building(id: String) -> Dictionary:
	return _resolve(_buildings, id)

func get_all_buildings() -> Array:
	return _buildings.values()

func get_founder_cat(id: String) -> Dictionary:
	return _resolve(_founder_cats, id)

func get_animal_type(id: String) -> Dictionary:
	return _resolve(_animal_types, id)

func get_item(id: String) -> Dictionary:
	return _resolve(_items, id)

func get_resonance_pattern(id: String) -> Dictionary:
	return _resolve(_resonance_patterns, id)

func get_all_resonance_patterns() -> Array:
	return _resonance_patterns.values()

func get_all_founder_cats() -> Array:
	return _founder_cats.values()

func get_all_animal_types() -> Array:
	return _animal_types.values()

func get_achievement(id: String) -> Dictionary:
	return _resolve(_achievements, id)

func get_all_achievements() -> Array:
	return _achievements.values()

func get_audio_cue(id: String) -> Dictionary:
	return _resolve(_audio_cues, id)

func get_all_body_colors() -> Array:
	return _body_colors.values()

func get_all_eye_colors() -> Array:
	return _eye_colors.values()

func get_all_decorations() -> Array:
	return _decorations.values()

func get_animal_types_with_housing_available(built_building_ids: Array) -> Array:
	var available: Array = []
	for animal in _animal_types.values():
		if animal.get("housing_building_type", "") in built_building_ids:
			available.append(animal)
	return available

## Builds a runtime InventoryItem resource from an items.json entry, for use
## by the Inventory / TownStorage systems.
func make_inventory_item(id: String) -> InventoryItem:
	var data := get_item(id)
	if data.is_empty():
		push_warning("[DataRegistry] Unknown item id: %s" % id)
		return null
	var item := InventoryItem.new()
	item.id = data.get("id", id)
	item.display_name = data.get("display_name", item.id)
	item.max_stack = data.get("max_stack", 99)
	item.description = data.get("description", "")
	item.properties = data.get("properties", {})
	var icon_path: String = data.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path)
	return item

## Applies a generic {target, stat, modifier_type, value} bonus list -- the
## same shape used for Founder Cat traits and Resonance Pattern bonuses.
## This is the single entry point both use, so a bonus behaves identically
## regardless of what triggered it.
func apply_global_bonuses(bonuses: Array) -> void:
	StatsService.add_modifiers(bonuses)
	for bonus in bonuses:
		print("[DataRegistry] Applying bonus -> target=%s stat=%s type=%s value=%s" % [
			bonus.get("target"), bonus.get("stat"), bonus.get("modifier_type"), bonus.get("value")
		])
