extends CanvasLayer

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var panel: Control = $Backdrop
@onready var barnaby_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FounderCards/Barnaby
@onready var whisper_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FounderCards/Whisper
@onready var turbo_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FounderCards/Turbo

var _buttons: Array[Button] = []
var _founder_ids: Array[StringName] = [&"barnaby", &"whisper", &"turbo"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buttons = [barnaby_button, whisper_button, turbo_button]
	for index: int in _buttons.size():
		var button := _buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_choose.bind(_founder_ids[index]))
		button.gui_input.connect(_on_founder_button_gui_input.bind(index))
	if game_state.has_founder():
		panel.hide()
	else:
		_show_selection()


func _process(_delta: float) -> void:
	if panel.visible and not game_state.has_founder():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not panel.visible or game_state.has_founder():
		return
	if event.is_action_pressed("ui_focus_next"):
		_cycle_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_prev"):
		_cycle_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		var index := _buttons.find(focused)
		if index >= 0:
			_choose(_founder_ids[index])
			get_viewport().set_input_as_handled()


func _show_selection() -> void:
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	barnaby_button.grab_focus()


func _cycle_focus(direction: int) -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	var current_index := _buttons.find(focused)
	if current_index < 0:
		current_index = 0
	else:
		current_index = wrapi(current_index + direction, 0, _buttons.size())
	_buttons[current_index].grab_focus()


func _on_founder_button_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_choose(_founder_ids[index])
			get_viewport().set_input_as_handled()


func _choose(founder_id: StringName) -> void:
	if game_state.select_founder(founder_id):
		panel.hide()
