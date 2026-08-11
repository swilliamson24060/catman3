class_name RebootAlmanacNotificationService
extends Node
## Delayed "something new in your Almanac" notification -- deliberately
## decoupled from WHO resolved a discovery or HOW (a resident's field
## errand, an in-conversation resolution, the investigation table, ...) so
## every current and future resolution path shares one tunable mechanism
## instead of each hand-rolling its own toast. See DiscoveryService.investigate(),
## the single call site that schedules every notification this service fires.
##
## Also owns "notes" -- short authored, non-discovery Almanac content (a tip,
## an explanation) that shares this exact same scheduling/unread plumbing
## rather than needing its own parallel system.

signal almanac_updated(discovery_id: StringName)
signal unread_changed(has_unread: bool)

## "Turns" in this game are period changes (morning/afternoon/evening/night)
## -- the closest thing this real-time-simulation project has to a discrete
## turn counter. 5 periods is a little over a day. Override per call to
## schedule() to pace a specific kind of resolution differently -- 0 fires
## immediately, used for the top-bar note right after founder selection,
## where waiting even one period would be a bad first impression.
const DEFAULT_DELAY_PERIODS := 5

const NOTES := {
	&"note_top_bar": {
		"title": "Reading the Top Bar",
		"body": "Left: the day, time of day, and weather now and next. Center: the village's current shared priority and community project progress. Right: whatever you're currently carrying. Menu opens the full Village Journal; Almanac jumps straight to this page; Hint asks for a nudge if you're stuck.",
	},
}

var _pending: Dictionary = {}  # id (StringName) -> remaining_periods (int)
var _archived_notes: Dictionary = {}  # String(note_id) -> true
var _unread := false

func _ready() -> void:
	get_node("/root/CalendarService").resident_schedule_changed.connect(_on_period_changed)

func reset() -> void:
	_pending.clear()
	_archived_notes.clear()
	_set_unread(false)

func has_unread() -> bool:
	return _unread

## Called once the player actually opens the Almanac -- clears the badge
## without touching individual notes' archived state (see archive_note).
func acknowledge_unread() -> void:
	_set_unread(false)

func schedule(id: StringName, delay_periods: int = DEFAULT_DELAY_PERIODS) -> void:
	if delay_periods <= 0:
		_fire(id)
		return
	_pending[id] = delay_periods

func note_ids() -> Array:
	return NOTES.keys()

func note_definition(note_id: StringName) -> Dictionary:
	return (NOTES.get(note_id, {}) as Dictionary).duplicate(true)

func is_note_archived(note_id: StringName) -> bool:
	return bool(_archived_notes.get(String(note_id), false))

## Archiving is purely organizational -- it moves a note out of the active
## list so it stops crowding newer content, but the Almanac keeps showing it
## under Archived Notes. It does not touch the unread badge; that's cleared
## by simply opening the Almanac (acknowledge_unread), same as any other entry.
func archive_note(note_id: StringName) -> void:
	_archived_notes[String(note_id)] = true

func _fire(id: StringName) -> void:
	_pending.erase(id)
	almanac_updated.emit(id)
	_set_unread(true)
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if shell != null: shell.show_event_toast("Something new in the Almanac.")

func _on_period_changed(_period_id: StringName) -> void:
	var ready_ids: Array[StringName] = []
	for id: StringName in _pending.keys():
		_pending[id] = int(_pending[id]) - 1
		if int(_pending[id]) <= 0:
			ready_ids.append(id)
	for id: StringName in ready_ids:
		_fire(id)

func _set_unread(value: bool) -> void:
	if _unread == value: return
	_unread = value
	unread_changed.emit(_unread)

## Pending ids stay flat, top-level keys (unchanged from before notes/unread
## existed) with the two new fields reserved under a leading underscore --
## no real discovery/note id uses that prefix -- so this stays a trivial,
## non-breaking extension of the original shape rather than a nested migration.
func serialize_state() -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in _pending: result[String(id)] = int(_pending[id])
	result["_archived_notes"] = _archived_notes.duplicate(true)
	result["_unread"] = _unread
	return result

func restore_state(data: Dictionary) -> void:
	_pending.clear()
	_archived_notes = (data.get("_archived_notes", {}) as Dictionary).duplicate(true)
	_unread = bool(data.get("_unread", false))
	for key: String in data:
		if key in ["_archived_notes", "_unread"]: continue
		_pending[StringName(key)] = int(data[key])
	unread_changed.emit(_unread)
