class_name ResidentHUD
extends CanvasLayer

@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var dialogue_title: Label = $DialoguePanel/Margin/VBox/Title
@onready var dialogue_text: RichTextLabel = $DialoguePanel/Margin/VBox/Text
@onready var dialogue_close: Button = $DialoguePanel/Margin/VBox/Close
@onready var board_panel: PanelContainer = $CommunityBoard
@onready var board_status: Label = $CommunityBoard/Margin/VBox/Status
@onready var project_status: Label = $CommunityBoard/Margin/VBox/ProjectStatus
@onready var propose_button: Button = $CommunityBoard/Margin/VBox/Propose
@onready var board_close: Button = $CommunityBoard/Margin/VBox/Close
@onready var locator_text: RichTextLabel = $ResidentLocator/Margin/VBox/Residents
@onready var relationship_toast: PanelContainer = $RelationshipToast
@onready var relationship_text: Label = $RelationshipToast/Margin/Text
@onready var relationship_timer: Timer = $RelationshipToast/Timer
@onready var almanac_text: RichTextLabel = $Almanac/Margin/VBox/Pages
@onready var investigation_panel: PanelContainer = $InvestigationTable
@onready var investigation_list: ItemList = $InvestigationTable/Margin/VBox/Finds
@onready var investigation_result: RichTextLabel = $InvestigationTable/Margin/VBox/Result
var _pending_investigations: Array[StringName] = []

func _ready() -> void:
	var manager := get_node("/root/ResidentManager")
	manager.dialogue_requested.connect(_on_dialogue_requested)
	manager.dialogue_closed.connect(_on_dialogue_closed)
	manager.board_requested.connect(_open_board)
	manager.priority_changed.connect(_on_priority_changed)
	manager.locator_changed.connect(_refresh_locator)
	manager.project_coordination_comment.connect(_on_project_comment)
	get_node("/root/RelationshipService").bond_changed.connect(_on_bond_changed)
	get_node("/root/CommunityProjectService").project_progress_changed.connect(_on_project_progress)
	get_node("/root/CommunityProjectService").phase_changed.connect(func(_project_id: StringName, _phase_id: StringName, _phase_index: int) -> void: _refresh_project_status())
	get_node("/root/CommunityProjectService").project_completed.connect(func(_project_id: StringName) -> void: _refresh_project_status())
	get_node("/root/RumorService").rumor_acquired.connect(func(_id: StringName, _text: String) -> void: _refresh_almanac())
	get_node("/root/DiscoveryService").discovery_changed.connect(func(_id: StringName, _state: StringName) -> void: _refresh_almanac())
	get_node("/root/InvestigationService").table_requested.connect(_open_investigation)
	get_node("/root/SeasonalResonanceService").feedback_changed.connect(func(_result: Dictionary) -> void: _refresh_almanac())
	get_node("/root/SeasonalResonanceService").activation_completed.connect(func(_pattern_id: StringName) -> void: _refresh_almanac())
	$InvestigationTable/Margin/VBox/Investigate.pressed.connect(_investigate_selected)
	$InvestigationTable/Margin/VBox/Close.pressed.connect(_close_investigation)
	dialogue_close.pressed.connect(manager.close_dialogue)
	propose_button.pressed.connect(_propose_priority)
	board_close.pressed.connect(_close_board)
	dialogue_panel.visible = false
	board_panel.visible = false
	relationship_toast.visible = false
	investigation_panel.visible = false
	relationship_timer.timeout.connect(func() -> void: relationship_toast.visible = false)
	_refresh_locator(manager.locator_entries())
	_on_priority_changed(manager.current_priority)
	_refresh_project_status()
	_refresh_almanac()

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
	_refresh_project_status()

func _refresh_project_status() -> void:
	project_status.text = get_node("/root/CommunityProjectService").progress_summary()

func _on_project_progress(_project_id: StringName, _summary: String) -> void:
	_refresh_project_status()

func _on_project_comment(text: String) -> void:
	relationship_text.text = text
	relationship_toast.visible = true
	relationship_timer.start()

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

func _refresh_almanac() -> void:
	var rumor_lines: Array[String] = []
	for rumor: Dictionary in get_node("/root/RumorService").known_rumors():
		rumor_lines.append("• %s\n  %s%s" % [rumor.text, rumor.landmark_hint, " [marker requested]" if bool(rumor.marker_enabled) else ""])
	var unidentified_lines: Array[String] = []
	for entry: Dictionary in get_node("/root/DiscoveryService").entries_for_state([&"found", &"unidentified", &"investigation_available", &"investigated"]): unidentified_lines.append("• %s — purpose unknown" % entry.label)
	var interpreted_lines: Array[String] = []
	for entry: Dictionary in get_node("/root/DiscoveryService").entries_for_state([&"interpreted"]): interpreted_lines.append("• [b]%s[/b]\n  %s" % [entry.display_name, entry.interpretation])
	var resonance := get_node("/root/SeasonalResonanceService")
	var experiment_note := "\n\nLatest experiment: %s" % str(resonance.current_result.get("tier_name", "Dormant")) if not resonance.activated else ""
	almanac_text.text = "[b]Rumors[/b]\n%s\n\n[b]Unidentified Finds[/b]\n%s\n\n[b]Interpreted Finds[/b]\n%s\n\n[b]Confirmed Patterns[/b]\n%s%s" % ["\n".join(rumor_lines) if not rumor_lines.is_empty() else "None yet.", "\n".join(unidentified_lines) if not unidentified_lines.is_empty() else "None yet.", "\n".join(interpreted_lines) if not interpreted_lines.is_empty() else "None yet.", resonance.confirmed_pattern_text(), experiment_note]

func _open_investigation(pending: Array[StringName]) -> void:
	_pending_investigations = pending.duplicate()
	investigation_list.clear()
	for discovery_id: StringName in _pending_investigations: investigation_list.add_item(get_node("/root/DiscoveryService").unidentified_name(discovery_id))
	investigation_result.text = "Choose an unidentified find. A suitable resident will meet you here; their specialty adds context but never blocks interpretation." if not pending.is_empty() else "There are no unidentified finds waiting for investigation."
	investigation_panel.visible = true
	get_node("/root/CalendarService").push_modal_pause()
	_set_player_input(false)

func _investigate_selected() -> void:
	var index := investigation_list.get_selected_items()[0] if not investigation_list.get_selected_items().is_empty() else 0
	if index < 0 or index >= _pending_investigations.size(): return
	var result: Dictionary = get_node("/root/InvestigationService").investigate(_pending_investigations[index])
	if result.is_empty(): return
	investigation_result.text = "[b]%s[/b]\n%s\n\n%s" % [result.display_name, result.interpretation, "A specialist recognized extra context." if bool(result.specialist_context) else "The resident helped interpret it without blocking progress."]
	_pending_investigations.remove_at(index)
	investigation_list.remove_item(index)
	_refresh_almanac()

func _close_investigation() -> void:
	if not investigation_panel.visible: return
	investigation_panel.visible = false
	get_node("/root/CalendarService").pop_modal_pause()
	_set_player_input(true)
