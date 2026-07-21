extends Node
## Autoload "StatsService". Accumulates {target, stat, modifier_type, value}
## bonuses from any source -- Founder Cat traits, Resonance Pattern bonuses,
## and any future mechanic -- and exposes a single get_effective() so no
## system needs to know or care where a bonus came from.

signal modifiers_changed()

var _multipliers: Dictionary = {}  # "target|stat" -> Array[float]
var _additives: Dictionary = {}    # "target|stat" -> float
var _source_modifiers: Dictionary = {} # source_id -> Array[Dictionary]

# Named, removable modifiers -- for transient effects (standing on a warm
# tile, a temporary strike penalty, wind-buffed drift) that need to come
# and go without touching the permanent pool above. Keyed the same way,
# but each entry is itself keyed by source_id so a source can update or
# remove just its own contribution.
var _temp_multipliers: Dictionary = {} # "target|stat" -> {source_id: float}
var _temp_additives: Dictionary = {}   # "target|stat" -> {source_id: float}

func add_modifiers(bonuses: Array) -> void:
	if bonuses.is_empty():
		return
	for bonus in bonuses:
		_add_modifier(bonus)
	modifiers_changed.emit()

## Installs an idempotent permanent bonus source. Reapplying the same source
## replaces its previous values, which makes save loading safe to repeat.
func set_source_modifiers(source_id: String, bonuses: Array) -> void:
	if source_id.is_empty():
		add_modifiers(bonuses)
		return
	_source_modifiers[source_id] = bonuses.duplicate(true)
	modifiers_changed.emit()

func _add_modifier(bonus: Dictionary) -> void:
	var key := "%s|%s" % [bonus.get("target", ""), bonus.get("stat", "")]
	var value: float = bonus.get("value", 0.0)
	if bonus.get("modifier_type", "multiplier") == "multiplier":
		if not _multipliers.has(key):
			_multipliers[key] = []
		_multipliers[key].append(value)
	else:
		_additives[key] = _additives.get(key, 0.0) + value

## Adds or updates a named, removable modifier. Calling again with the same
## source_id just updates the value (safe to call every frame from e.g. a
## "while standing on a warm tile" check) -- it's a no-op if the value
## hasn't actually changed, so it doesn't spam modifiers_changed.
func add_temp_modifier(source_id: String, target: String, stat: String, modifier_type: String, value: float) -> void:
	var key := "%s|%s" % [target, stat]
	var bucket: Dictionary = _temp_multipliers if modifier_type == "multiplier" else _temp_additives
	if not bucket.has(key):
		bucket[key] = {}
	if bucket[key].has(source_id) and bucket[key][source_id] == value:
		return
	bucket[key][source_id] = value
	modifiers_changed.emit()

## Removes a source's temp modifier, if it has one, from both buckets
## (a source only ever occupies one, but this stays a safe no-op either way).
func remove_temp_modifier(source_id: String, target: String, stat: String) -> void:
	var key := "%s|%s" % [target, stat]
	var changed := false
	if _temp_multipliers.has(key) and _temp_multipliers[key].has(source_id):
		_temp_multipliers[key].erase(source_id)
		changed = true
	if _temp_additives.has(key) and _temp_additives[key].has(source_id):
		_temp_additives[key].erase(source_id)
		changed = true
	if changed:
		modifiers_changed.emit()

## Applies every accumulated multiplier (permanent then temp, as a product)
## then every accumulated additive (permanent then temp) on top of base_value.
func get_effective(target: String, stat: String, base_value: float) -> float:
	var key := "%s|%s" % [target, stat]
	var result := base_value
	for m in _multipliers.get(key, []):
		result *= m
	for m in _temp_multipliers.get(key, {}).values():
		result *= m
	for source_bonuses: Array in _source_modifiers.values():
		for bonus: Dictionary in source_bonuses:
			if "%s|%s" % [bonus.get("target", ""), bonus.get("stat", "")] == key \
					and bonus.get("modifier_type", "multiplier") == "multiplier":
				result *= float(bonus.get("value", 0.0))
	result += _additives.get(key, 0.0)
	for a in _temp_additives.get(key, {}).values():
		result += a
	for source_bonuses: Array in _source_modifiers.values():
		for bonus: Dictionary in source_bonuses:
			if "%s|%s" % [bonus.get("target", ""), bonus.get("stat", "")] == key \
					and bonus.get("modifier_type", "multiplier") != "multiplier":
				result += float(bonus.get("value", 0.0))
	return result

func reset() -> void:
	_multipliers.clear()
	_additives.clear()
	_source_modifiers.clear()
	_temp_multipliers.clear()
	_temp_additives.clear()
	modifiers_changed.emit()
