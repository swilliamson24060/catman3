extends Node

signal preferences_changed(preferences: Dictionary)
signal hint_changed(level: int, text: String)
signal lesson_recorded(lesson_id: StringName)

const CONFIG_PATH := "user://catmando_accessibility.cfg"
const REMAPPABLE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"interact", &"camera_snap_left", &"camera_snap_right", &"ui_menu", &"open_almanac", &"request_hint", &"quick_save", &"quick_load"]
const DEFAULTS := {
	"interaction_toggle": false,
	"text_scale": 1.0,
	"high_contrast": false,
	"camera_shake": 1.0,
	"subtitles": true,
	"subtitle_speaker": true,
	"reduced_flash": false,
}

var preferences: Dictionary = DEFAULTS.duplicate(true)
var completed_lessons: Array[StringName] = []
var introduced_anchors: Array[StringName] = []
var hint_level: int = 0
var last_hint: String = ""

func _ready() -> void:
	_ensure_actions()
	load_preferences()

func reset_story_state() -> void:
	completed_lessons.clear()
	introduced_anchors.clear()
	hint_level = 0
	last_hint = ""

func serialize_state() -> Dictionary:
	return {"completed_lessons": completed_lessons, "introduced_anchors": introduced_anchors, "hint_level": hint_level, "last_hint": last_hint}

func restore_state(state: Dictionary) -> void:
	completed_lessons.clear()
	for value: Variant in state.get("completed_lessons", []):
		completed_lessons.append(StringName(str(value)))
	introduced_anchors.clear()
	for value: Variant in state.get("introduced_anchors", []):
		introduced_anchors.append(StringName(str(value)))
	hint_level = clampi(int(state.get("hint_level", 0)), 0, 3)
	last_hint = str(state.get("last_hint", ""))

func record_lesson(lesson_id: StringName) -> void:
	if lesson_id in completed_lessons:
		return
	completed_lessons.append(lesson_id)
	lesson_recorded.emit(lesson_id)

## True the first time this anchor is introduced -- callers that get true
## own showing the explanation; false means "already seen, proceed as normal."
func introduce_anchor(anchor_id: StringName) -> bool:
	if anchor_id in introduced_anchors:
		return false
	introduced_anchors.append(anchor_id)
	return true

func request_next_hint() -> String:
	# The ladder is deliberately requested, never pushed. Even its explicit step
	# describes only geometry; component roles and the activation condition remain clues.
	if &"resonance_initial_clue" not in completed_lessons:
		return "Guidance will unlock after you encounter the ruin's first Resonance clue."
	hint_level = mini(hint_level + 1, 3)
	match hint_level:
		1: last_hint = "Elowen suggests revisiting the ruin's repeated shape and listening for coordinated tones."
		2: last_hint = "Almanac synthesis: the plaque and ruin both frame three points around something living."
		3: last_hint = "Optional geometry help: arrange the three plinths as a broad triangle around the old garden tree. Experiment to learn what belongs where."
	hint_changed.emit(hint_level, last_hint)
	return last_hint

func lesson_text(lesson_id: StringName) -> String:
	return {
		&"movement_interaction": "Move with WASD, arrows, or the left stick. Interact with E or the south controller button.",
		&"community_priority": "The Community Board proposes shared priorities; residents choose how and when to help.",
		&"project_contribution": "Carry one visible material to the garden or interact at its contribution point. Work is never lost overnight.",
		&"rumors": "Rumors describe landmarks before offering an optional marker. They remain in the Almanac.",
		&"investigation": "Unidentified finds become meaningful at the workshop investigation table; resident specialty adds context without blocking progress.",
		&"component_placement": "Interpreted components can be placed and safely retrieved from the three dedicated plinths.",
		&"resonance_initial_clue": "Resonance responds in five consistent tiers. Words, symbols, and motion rhythms communicate progress without requiring color or sound.",
	}.get(lesson_id, "A new lesson was recorded in the Village Journal.")

func set_preference(key: StringName, value: Variant) -> void:
	if not preferences.has(String(key)):
		return
	preferences[String(key)] = value
	save_preferences()
	preferences_changed.emit(preferences.duplicate(true))

func get_preference(key: StringName, fallback: Variant = null) -> Variant:
	return preferences.get(String(key), fallback)

func save_preferences() -> void:
	var config := ConfigFile.new()
	for key: String in preferences:
		config.set_value("accessibility", key, preferences[key])
	for action: StringName in REMAPPABLE_ACTIONS:
		var events: Array = InputMap.action_get_events(action)
		config.set_value("input", String(action), events)
	config.save(CONFIG_PATH)

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for key: String in preferences:
		preferences[key] = config.get_value("accessibility", key, preferences[key])
	for action: StringName in REMAPPABLE_ACTIONS:
		var saved: Variant = config.get_value("input", String(action), null)
		if saved is Array and not saved.is_empty():
			InputMap.action_erase_events(action)
			for event: Variant in saved:
				if event is InputEvent: InputMap.action_add_event(action, event)

func remap_action(action: StringName, event: InputEvent, replace_same_device: bool = true) -> bool:
	if action not in REMAPPABLE_ACTIONS or event == null:
		return false
	if replace_same_device:
		for existing: InputEvent in InputMap.action_get_events(action):
			if (existing is InputEventKey and event is InputEventKey) or (existing is InputEventJoypadButton and event is InputEventJoypadButton):
				InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)
	save_preferences()
	return true

func action_has_keyboard_and_controller(action: StringName) -> bool:
	var keyboard := false
	var controller := false
	for event: InputEvent in InputMap.action_get_events(action):
		keyboard = keyboard or event is InputEventKey
		controller = controller or event is InputEventJoypadButton or event is InputEventJoypadMotion
	return keyboard and controller

func tier_accessible_cue(tier: int) -> Dictionary:
	var names := ["Dormant", "Stirring", "Echoing", "Aligned", "Activated"]
	var symbols := ["○", "•", "••", "△", "✦"]
	var motions := ["still", "single pulse", "paired pulse", "steady triangle", "radiating burst"]
	var index := clampi(tier, 0, 4)
	return {"name": names[index], "symbol": symbols[index], "motion": motions[index], "ordinal": index}

func _ensure_actions() -> void:
	_add_action(&"ui_menu", KEY_ESCAPE, JOY_BUTTON_START)
	_add_action(&"open_almanac", KEY_J, JOY_BUTTON_BACK)
	_add_action(&"request_hint", KEY_H, JOY_BUTTON_Y)
	_add_action(&"quick_save", KEY_F5, JOY_BUTTON_LEFT_SHOULDER)
	_add_action(&"quick_load", KEY_F8, JOY_BUTTON_RIGHT_SHOULDER)
	_add_controller_button(&"interact", JOY_BUTTON_A)
	_add_controller_button(&"camera_snap_left", JOY_BUTTON_DPAD_LEFT)
	_add_controller_button(&"camera_snap_right", JOY_BUTTON_DPAD_RIGHT)
	_add_controller_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_controller_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_controller_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_controller_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0)

func _add_action(action: StringName, keycode: Key, button: JoyButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var has_key := false
	for event: InputEvent in InputMap.action_get_events(action): has_key = has_key or event is InputEventKey
	if not has_key:
		var key := InputEventKey.new(); key.physical_keycode = keycode; InputMap.action_add_event(action, key)
	_add_controller_button(action, button)

func _add_controller_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: return
	var joy := InputEventJoypadButton.new(); joy.button_index = button; InputMap.action_add_event(action, joy)

func _add_controller_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value): return
	var joy := InputEventJoypadMotion.new(); joy.axis = axis; joy.axis_value = value; InputMap.action_add_event(action, joy)
