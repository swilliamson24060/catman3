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
var _celebration_modal_open: bool = false
var _celebration_choice_ids: Array[StringName] = []

func _ready() -> void:
	add_to_group("resident_hud")
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
	get_node("/root/CommunityMachineService").machine_state_changed.connect(_on_machine_state_changed)
	get_node("/root/CommunityMachineService").craft_family_unlocked.connect(func(_family_id: StringName) -> void: _refresh_almanac())
	get_node("/root/CommunityMachineService").craft_completed.connect(_on_craft_completed)
	var celebration := get_node("/root/CelebrationService")
	celebration.state_changed.connect(_on_celebration_state_changed)
	celebration.choice_requested.connect(_on_celebration_choice_requested)
	celebration.closing_line_requested.connect(_on_celebration_closing_line)
	celebration.celebration_completed.connect(_on_celebration_completed)
	celebration.demo_acknowledgement_requested.connect(_on_demo_acknowledgement)
	$InvestigationTable/Margin/VBox/Investigate.pressed.connect(_investigate_selected)
	$InvestigationTable/Margin/VBox/Close.pressed.connect(_close_investigation)
	dialogue_close.pressed.connect(manager.close_dialogue)
	propose_button.pressed.connect(_propose_priority)
	board_close.pressed.connect(_close_board)
	$CelebrationPanel/Margin/VBox/ChoiceA.pressed.connect(func() -> void: _choose_celebration(0))
	$CelebrationPanel/Margin/VBox/ChoiceB.pressed.connect(func() -> void: _choose_celebration(1))
	$CelebrationPanel/Margin/VBox/Continue.pressed.connect(_advance_celebration)
	dialogue_panel.visible = false
	board_panel.visible = false
	relationship_toast.visible = false
	investigation_panel.visible = false
	$CelebrationPanel.visible = false
	relationship_timer.timeout.connect(func() -> void: relationship_toast.visible = false)
	_refresh_locator(manager.locator_entries())
	_on_priority_changed(manager.current_priority)
	_refresh_project_status()
	_refresh_almanac()
	$ResidentLocator.visible = false
	$Almanac.visible = false

func almanac_document() -> String:
	_refresh_almanac()
	return almanac_text.text

func open_named_panel(panel_name: String) -> void:
	if panel_name == "CommunityBoard": _open_board()

func close_navigation_panels() -> void:
	if board_panel.visible: _close_board()

func _on_dialogue_requested(resident: ResidentAgent, text: String) -> void:
	var experience := get_node("/root/UserExperienceService")
	dialogue_title.text = "%s — %s" % [resident.display_name(), str(resident.definition.get("specialty", "resident")).capitalize()] if bool(experience.get_preference(&"subtitle_speaker", true)) else "Conversation"
	dialogue_text.text = text if bool(experience.get_preference(&"subtitles", true)) else "Subtitles are disabled in Settings."
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

func _on_machine_state_changed(_state_id: StringName, summary: String) -> void:
	relationship_text.text = summary
	relationship_toast.visible = true
	relationship_timer.start()
	_refresh_almanac()

func _on_craft_completed(_craft_id: StringName, display_name: String) -> void:
	relationship_text.text = "%s is ready at the workshop — a visible new use for the First Bloom." % display_name
	relationship_toast.visible = true
	relationship_timer.start()
	_refresh_almanac()

func _on_celebration_state_changed(_state_id: StringName, summary: String) -> void:
	relationship_text.text = summary
	relationship_toast.visible = true
	relationship_timer.start()
	_refresh_almanac()

func _on_celebration_choice_requested(choices: Array[Dictionary]) -> void:
	if choices.size() < 2: return
	_celebration_choice_ids = [StringName(str(choices[0].get("id", ""))), StringName(str(choices[1].get("id", "")))]
	$CelebrationPanel/Margin/VBox/Title.text = "Choose a finishing touch"
	$CelebrationPanel/Margin/VBox/Portrait.text = "✦"
	$CelebrationPanel/Margin/VBox/Text.text = "Either choice completes the preparations; it changes the gathering's look, never its success."
	$CelebrationPanel/Margin/VBox/ChoiceA.text = str(choices[0].get("label", "Choice A"))
	$CelebrationPanel/Margin/VBox/ChoiceB.text = str(choices[1].get("label", "Choice B"))
	$CelebrationPanel/Margin/VBox/ChoiceA.visible = true
	$CelebrationPanel/Margin/VBox/ChoiceB.visible = true
	$CelebrationPanel/Margin/VBox/Continue.visible = false
	_open_celebration_modal()

func _choose_celebration(index: int) -> void:
	if index < 0 or index >= _celebration_choice_ids.size(): return
	if get_node("/root/CelebrationService").choose_decoration(_celebration_choice_ids[index]): _close_celebration_modal()

func _on_celebration_closing_line(line: Dictionary, line_index: int, line_count: int) -> void:
	$CelebrationPanel/Margin/VBox/Title.text = "%s — after the gathering" % str(line.get("speaker", "Neighbor"))
	$CelebrationPanel/Margin/VBox/Portrait.text = str(line.get("portrait", "✦"))
	$CelebrationPanel/Margin/VBox/Text.text = str(line.get("text", ""))
	$CelebrationPanel/Margin/VBox/ChoiceA.visible = false
	$CelebrationPanel/Margin/VBox/ChoiceB.visible = false
	$CelebrationPanel/Margin/VBox/Continue.text = "Return to village life" if line_index + 1 >= line_count else "Continue"
	$CelebrationPanel/Margin/VBox/Continue.visible = true
	_open_celebration_modal()

func _advance_celebration() -> void:
	if get_node("/root/CelebrationService").state == &"closing":
		get_node("/root/CelebrationService").advance_closing_conversation()
	else:
		_close_celebration_modal()

func _on_celebration_completed() -> void:
	_close_celebration_modal()
	_refresh_almanac()

func _on_demo_acknowledgement() -> void:
	$CelebrationPanel/Margin/VBox/Title.text = "Vertical slice complete"
	$CelebrationPanel/Margin/VBox/Portrait.text = "✦"
	$CelebrationPanel/Margin/VBox/Text.text = "Thank you for helping the village discover The First Bloom. Your save continues into ordinary village days."
	$CelebrationPanel/Margin/VBox/ChoiceA.visible = false
	$CelebrationPanel/Margin/VBox/ChoiceB.visible = false
	$CelebrationPanel/Margin/VBox/Continue.text = "Continue playing"
	$CelebrationPanel/Margin/VBox/Continue.visible = true
	_open_celebration_modal()

func _open_celebration_modal() -> void:
	$CelebrationPanel.visible = true
	if not _celebration_modal_open:
		_celebration_modal_open = true
		get_node("/root/CalendarService").push_modal_pause()
		_set_player_input(false)
	if $CelebrationPanel/Margin/VBox/ChoiceA.visible: $CelebrationPanel/Margin/VBox/ChoiceA.grab_focus()
	else: $CelebrationPanel/Margin/VBox/Continue.grab_focus()

func _close_celebration_modal() -> void:
	$CelebrationPanel.visible = false
	if _celebration_modal_open:
		_celebration_modal_open = false
		get_node("/root/CalendarService").pop_modal_pause()
		_set_player_input(true)

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
	var machine := get_node("/root/CommunityMachineService")
	var experiment_note := "\n\nLatest experiment: %s" % str(resonance.current_result.get("tier_name", "Dormant")) if not resonance.activated else ""
	var craft_text: String = str(machine.interaction_summary())
	var celebration := get_node("/root/CelebrationService")
	var distant_text := "\n".join(celebration.distant_rumors) if not celebration.distant_rumors.is_empty() else "None yet."
	almanac_text.text = "[b]Rumors[/b]\n%s\n\n[b]Unidentified Finds[/b]\n%s\n\n[b]Interpreted Finds[/b]\n%s\n\n[b]Confirmed Patterns[/b]\n%s%s\n\n[b]Community Capability[/b]\n%s\n\n[b]Village Event[/b]\n%s\n\n[b]Distant Pattern Rumors[/b]\n%s" % ["\n".join(rumor_lines) if not rumor_lines.is_empty() else "None yet.", "\n".join(unidentified_lines) if not unidentified_lines.is_empty() else "None yet.", "\n".join(interpreted_lines) if not interpreted_lines.is_empty() else "None yet.", resonance.confirmed_pattern_text(), experiment_note, craft_text, celebration.status_summary(), distant_text]

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
