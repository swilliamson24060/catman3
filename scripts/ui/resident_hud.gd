class_name ResidentHUD
extends CanvasLayer

@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var dialogue_title: Label = $DialoguePanel/Margin/VBox/Title
@onready var dialogue_text: RichTextLabel = $DialoguePanel/Margin/VBox/Text
@onready var dialogue_close: Button = $DialoguePanel/Margin/VBox/Close
@onready var board_panel: PanelContainer = $CommunityBoard
@onready var board_status: Label = $CommunityBoard/Margin/VBox/Status
@onready var propose_button: Button = $CommunityBoard/Margin/VBox/Propose
@onready var board_close: Button = $CommunityBoard/Margin/VBox/Close
@onready var locator_text: RichTextLabel = $ResidentLocator/Margin/VBox/Residents
@onready var relationship_toast: PanelContainer = $RelationshipToast
@onready var relationship_text: Label = $RelationshipToast/Margin/Text
@onready var relationship_timer: Timer = $RelationshipToast/Timer

func _ready() -> void:
	var manager := get_node("/root/ResidentManager")
	manager.dialogue_requested.connect(_on_dialogue_requested)
	manager.dialogue_closed.connect(_on_dialogue_closed)
	manager.board_requested.connect(_open_board)
	manager.priority_changed.connect(_on_priority_changed)
	manager.locator_changed.connect(_refresh_locator)
	get_node("/root/RelationshipService").bond_changed.connect(_on_bond_changed)
	dialogue_close.pressed.connect(manager.close_dialogue)
	propose_button.pressed.connect(_propose_priority)
	board_close.pressed.connect(_close_board)
	dialogue_panel.visible = false
	board_panel.visible = false
	relationship_toast.visible = false
	relationship_timer.timeout.connect(func() -> void: relationship_toast.visible = false)
	_refresh_locator(manager.locator_entries())
	_on_priority_changed(manager.current_priority)

func _on_dialogue_requested(resident: ResidentAgent, text: String) -> void:
	dialogue_title.text = "%s — %s" % [resident.display_name(), str(resident.definition.get("specialty", "resident")).capitalize()]
	dialogue_text.text = text
	dialogue_panel.visible = true
	dialogue_close.grab_focus()
	_set_player_input(false)

func _on_dialogue_closed(_resident_id: StringName) -> void:
	dialogue_panel.visible = false
	_set_player_input(true)

func _open_board() -> void:
	board_panel.visible = true
	get_node("/root/CalendarService").push_modal_pause()
	_set_player_input(false)
	propose_button.grab_focus()

func _close_board() -> void:
	if not board_panel.visible:
		return
	board_panel.visible = false
	get_node("/root/CalendarService").pop_modal_pause()
	_set_player_input(true)

func _propose_priority() -> void:
	get_node("/root/ResidentManager").propose_priority(&"project_restore_garden")

func _on_priority_changed(_priority_id: StringName) -> void:
	var manager := get_node("/root/ResidentManager")
	board_status.text = "Current priority: %s" % manager.priority_display_name()
	propose_button.disabled = manager.current_priority == &"project_restore_garden"
	propose_button.text = "Garden restoration proposed" if propose_button.disabled else "Propose: Restore the garden"

func _refresh_locator(entries: Array[Dictionary]) -> void:
	var lines: Array[String] = ["[b]Resident Almanac[/b]"]
	for entry: Dictionary in entries:
		lines.append("[b]%s[/b] — %s\n%s" % [entry.display_name, entry.location, entry.activity])
	locator_text.text = "\n\n".join(lines)

func _set_player_input(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("reboot_player") as RebootFounderCat
	if player != null:
		player.input_enabled = enabled

func _on_bond_changed(_resident_a: StringName, _resident_b: StringName, _new_bond: int, visible_message: String) -> void:
	relationship_text.text = visible_message
	relationship_toast.visible = true
	relationship_timer.start()
