extends Node
## Autoload "AppearanceService". Guarantees no two recruited animals ever
## render with the identical body_color + eye_color + decoration combo.
## Scope: applies to the recruited-animal population (mice, crabs, any
## future species via AnimalManager) -- not the 3-4 founder cats, which
## already have their own bespoke, always-distinct coat system
## (cats.json + CatAppearance) and don't have a "many instances" problem to
## solve.
##
## The whole palette is modder data (coat_palette.json's body_colors,
## eye_colors, decorations -- each independently extensible per-expansion
## through DataRegistry's normal merge pipeline). Adding one more entry to
## any of the three lists multiplies the total unique-look space; no code
## here needs to change.
##
## Uniqueness is enforced by deterministic enumeration, not
## random-and-hope: every combination is addressed by a single integer
## index (a mixed-radix counter over body_colors x eye_colors x
## decorations). Assigning an appearance walks forward from the next index,
## linear-probing past anything already claimed, so a collision is
## structurally impossible until the palette itself is fully exhausted --
## at which point (a modder-underprovisioned palette) it logs a warning and
## accepts a forced repeat rather than looping forever.

var _next_index: int = 0
var _claimed_indices: Dictionary = {}  # animal_id -> int
var _claimed_by_index: Dictionary = {} # int -> true

func _ready() -> void:
	randomize()
	# Random starting offset so two fresh games don't hand their first
	# recruit the identical look every time.
	_next_index = randi()

func total_combinations() -> int:
	var b := DataRegistry.get_all_body_colors().size()
	var e := DataRegistry.get_all_eye_colors().size()
	var d := DataRegistry.get_all_decorations().size()
	return maxi(1, b * e * d)

## Assigns and claims the next free appearance for `animal_id`. Returns
## {body_color, eye_color, decoration}, each the full palette entry
## (id/hex/pattern) ready for a visual to read directly.
func assign_appearance(animal_id: String) -> Dictionary:
	var total := total_combinations()
	var index := _next_index % total
	var attempts := 0
	while _claimed_by_index.has(index) and attempts < total:
		index = (index + 1) % total
		attempts += 1
	if attempts >= total:
		push_warning("[AppearanceService] Coat palette exhausted (%d unique combinations) -- '%s' will repeat an existing look. Add more body_colors/eye_colors/decorations to coat_palette.json (or an expansion) to grow it." % [total, animal_id])

	_claim(animal_id, index)
	_next_index = index + 1
	return _decode(index)

## Reserves a SPECIFIC index for `animal_id` -- used by AnimalManager's
## save/load restore, which already knows (from the save file) exactly
## which combo this animal had. Keeps _next_index past every restored
## index so freshly recruited animals afterward never re-collide with them.
func claim_specific(animal_id: String, index: int) -> Dictionary:
	var total := total_combinations()
	index = ((index % total) + total) % total # defensive wrap for out-of-range saves
	_claim(animal_id, index)
	if index >= _next_index:
		_next_index = index + 1
	return _decode(index)

func release_appearance(animal_id: String) -> void:
	if not _claimed_indices.has(animal_id):
		return
	var index: int = _claimed_indices[animal_id]
	_claimed_by_index.erase(index)
	_claimed_indices.erase(animal_id)

## The raw combo index currently claimed by `animal_id`, or -1 if none --
## this is the one number AnimalManager.serialize_roster() needs to persist
## per animal to round-trip its exact appearance through a save file.
func claimed_index(animal_id: String) -> int:
	return _claimed_indices.get(animal_id, -1)

func appearance_for(animal_id: String) -> Dictionary:
	if not _claimed_indices.has(animal_id):
		return {}
	return _decode(_claimed_indices[animal_id])

func _claim(animal_id: String, index: int) -> void:
	release_appearance(animal_id) # in case this id already held a different combo
	_claimed_indices[animal_id] = index
	_claimed_by_index[index] = true

func _decode(index: int) -> Dictionary:
	var body_colors := DataRegistry.get_all_body_colors()
	var eye_colors := DataRegistry.get_all_eye_colors()
	var decorations := DataRegistry.get_all_decorations()
	if body_colors.is_empty() or eye_colors.is_empty() or decorations.is_empty():
		return {}

	var d_count := decorations.size()
	var e_count := eye_colors.size()

	# Mixed-radix decode -- integer division is intentional here, not a bug.
	@warning_ignore("integer_division")
	var decoration_i := index % d_count
	@warning_ignore("integer_division")
	var eye_i := (index / d_count) % e_count
	@warning_ignore("integer_division")
	var body_i := (index / (d_count * e_count)) % body_colors.size()

	return {
		"body_color": body_colors[body_i],
		"eye_color": eye_colors[eye_i],
		"decoration": decorations[decoration_i],
	}
