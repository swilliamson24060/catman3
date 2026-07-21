extends CanvasLayer

@onready var cheese_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CheeseLabel
@onready var catnip_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CatnipLabel
@onready var recruited_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/RecruitedLabel
@onready var debug_time_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DebugTimeLabel
@onready var founder_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/FounderLabel
@onready var placement_instructions: Label = $PlacementInstructions
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var feedback_label: Label = $FeedbackLabel
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var mouse_name_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/MouseName
@onready var dialogue_text: Label = $DialoguePanel/MarginContainer/VBoxContainer/DialogueText
@onready var offer_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/OfferLabel
@onready var accept_button: Button = $DialoguePanel/MarginContainer/VBoxContainer/Buttons/AcceptButton
@onready var inspection_panel: PanelContainer = $MouseInspectionPanel
@onready var inspection_name: Label = $MouseInspectionPanel/MarginContainer/VBoxContainer/MouseName
@onready var contentment_label: Label = $MouseInspectionPanel/MarginContainer/VBoxContainer/ContentmentLabel
@onready var mood_label: Label = $MouseInspectionPanel/MarginContainer/VBoxContainer/MoodLabel
@onready var hunger_label: Label = $MouseInspectionPanel/MarginContainer/VBoxContainer/HungerLabel
@onready var fatigue_label: Label = $MouseInspectionPanel/MarginContainer/VBoxContainer/FatigueLabel
@onready var inspection_close_button: Button = $MouseInspectionPanel/MarginContainer/VBoxContainer/CloseButton
@onready var decline_button: Button = $DialoguePanel/MarginContainer/VBoxContainer/Buttons/DeclineButton
@onready var build_menu: PanelContainer = $BuildMenu
@onready var build_selection_label: Label = $BuildStatus
@onready var construction_count_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ConstructionCountLabel
@onready var site_panel: PanelContainer = $ConstructionSitePanel
@onready var site_title: Label = $ConstructionSitePanel/MarginContainer/VBoxContainer/Title
@onready var site_progress: Label = $ConstructionSitePanel/MarginContainer/VBoxContainer/Progress
@onready var site_bowl: Label = $ConstructionSitePanel/MarginContainer/VBoxContainer/Bowl
@onready var resonance_banner: PanelContainer = $ResonanceBanner
@onready var resonance_name: Label = $ResonanceBanner/MarginContainer/VBoxContainer/PatternName
@onready var resonance_description: Label = $ResonanceBanner/MarginContainer/VBoxContainer/Description
@onready var resonance_bonuses: Label = $ResonanceBanner/MarginContainer/VBoxContainer/Bonuses
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock
@onready var event_bus: Node = get_node("/root/EventBus")
@onready var data_registry: Node = get_node("/root/DataRegistry")
@onready var scaffold_service: Node = get_node("/root/ScaffoldService")
@onready var weather_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/WeatherLabel
@onready var scaffold_status: Label = $ScaffoldStatus

var _feedback_time_remaining: float = 0.0
var _dialogue_mouse: Phase1WildMouse
var _offer_already_declined: bool = false
var _show_need_debug: bool = false
var _show_work_debug: bool = false
var _inspected_mouse: Phase1WildMouse
var _managed_site: ConstructionSite
var _resonance_banner_generation: int = 0


func _ready() -> void:
	game_state.cheese_changed.connect(_on_cheese_changed)
	game_state.catnip_changed.connect(_on_catnip_changed)
	game_state.recruited_mouse_count_changed.connect(_on_recruited_count_changed)
	game_state.founder_selected.connect(_on_founder_selected)
	game_state.placement_mode_changed.connect(_on_placement_mode_changed)
	game_state.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	game_state.feedback_requested.connect(_on_feedback_requested)
	game_state.dialogue_opened.connect(_on_dialogue_opened)
	game_state.dialogue_closed.connect(_on_dialogue_closed)
	game_state.mouse_inspected.connect(_on_mouse_inspected)
	game_state.build_menu_changed.connect(_on_build_menu_changed)
	game_state.build_selection_changed.connect(_on_build_selection_changed)
	game_state.placement_validity_message_changed.connect(_on_build_placement_message)
	game_state.construction_site_placed.connect(_on_construction_site_count_changed)
	game_state.construction_site_opened.connect(_on_construction_site_opened)
	game_state.construction_site_closed.connect(_on_construction_site_closed)
	event_bus.pattern_discovered.connect(_on_pattern_discovered)
	event_bus.weather_changed.connect(_on_weather_changed)
	scaffold_service.challenge_started.connect(_on_scaffold_started)
	scaffold_service.balance_changed.connect(_on_scaffold_balance_changed)
	scaffold_service.challenge_resolved.connect(_on_scaffold_resolved)
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	inspection_close_button.pressed.connect(inspection_panel.hide)
	placement_instructions.hide()
	interaction_prompt.hide()
	feedback_label.hide()
	dialogue_panel.hide()
	inspection_panel.hide()
	build_menu.hide()
	build_selection_label.hide()
	site_panel.hide()
	resonance_banner.hide()
	scaffold_status.hide()
	_on_weather_changed(str(get_node("/root/WeatherService").call("weather_id")))
	_on_construction_site_count_changed(null)
	_on_cheese_changed(game_state.get_cheese())
	_on_catnip_changed(game_state.get_catnip())
	_on_recruited_count_changed(game_state.get_recruited_mouse_count())
	debug_time_label.visible = OS.is_debug_build()
	debug_time_label.text = "Debug: F8 needs  •  F9 speed  •  F10 work scores"
	hunger_label.hide()
	fatigue_label.hide()
	if game_state.has_founder():
		_on_founder_selected(game_state.selected_founder)
	else:
		founder_label.text = "Founder: Not chosen"


func _input(event: InputEvent) -> void:
	if site_panel.visible:
		if event.is_action_pressed("select_building_1"):
			_managed_site.add_bribe_cheese(1)
			_refresh_site_panel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("select_building_2"):
			_managed_site.add_bribe_cheese(3)
			_refresh_site_panel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("select_building_3"):
			_managed_site.return_bribe_cheese()
			_refresh_site_panel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("select_building_4"):
			_managed_site.debug_contribute_work(20.0)
			_refresh_site_panel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("select_building_5"):
			_managed_site.cancel_site()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("release_mouse"):
			game_state.close_construction_site()
			get_viewport().set_input_as_handled()
			return
	if OS.is_debug_build() and event.is_action_pressed("toggle_need_debug"):
		_toggle_need_debug()
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event.is_action_pressed("cycle_simulation_speed"):
		var multiplier := simulation_clock.cycle_debug_time_multiplier()
		debug_time_label.text = "Debug time: %.0fx  •  F8 needs  •  F9 speed" % multiplier
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event.is_action_pressed("toggle_work_debug"):
		_show_work_debug = not _show_work_debug
		for node: Node in get_tree().get_nodes_in_group("recruited_mice"):
			var mouse := node as Phase1WildMouse
			if mouse != null:
				mouse.set_work_debug_visible(_show_work_debug)
		game_state.request_feedback("Work evaluation debug %s." % ("enabled" if _show_work_debug else "disabled"))
		get_viewport().set_input_as_handled()
		return
	if not dialogue_panel.visible:
		return
	if event.is_action_pressed("release_mouse"):
		_on_decline_pressed()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _feedback_time_remaining <= 0.0:
		return
	_feedback_time_remaining -= delta
	if _feedback_time_remaining <= 0.0:
		feedback_label.hide()


func _on_mouse_inspected(mouse: Phase1WildMouse) -> void:
	_inspected_mouse = mouse
	inspection_name.text = mouse.get_display_name()
	contentment_label.text = "Contentment: %d / %d" % [
		mouse.get_contentment_score(),
		20,
	]
	mood_label.text = "Mood: %s" % mouse.get_contentment_band()
	hunger_label.text = "Hunger: %s (%.2f)" % [mouse.get_hunger_description(), mouse.get_hunger()]
	fatigue_label.text = "Fatigue: %s (%.2f)" % [mouse.get_fatigue_description(), mouse.get_fatigue()]
	hunger_label.visible = _show_need_debug and OS.is_debug_build()
	fatigue_label.visible = _show_need_debug and OS.is_debug_build()
	inspection_panel.show()


func _on_dialogue_opened(mouse: Phase1WildMouse) -> void:
	_dialogue_mouse = mouse
	_offer_already_declined = false
	mouse_name_label.text = mouse.get_display_name()
	dialogue_text.text = mouse.get_dialogue_text()
	var recruitment_lines := mouse.get_recruitment_dialogue()
	if not recruitment_lines.is_empty():
		dialogue_text.text += "\n\n" + recruitment_lines[0]
	offer_label.text = "Recruit for %d cheese?" % mouse.get_recruitment_cost()
	accept_button.text = "Accept (%d cheese)" % mouse.get_recruitment_cost()
	dialogue_panel.show()
	interaction_prompt.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	accept_button.grab_focus()


func _on_dialogue_closed() -> void:
	dialogue_panel.hide()
	_dialogue_mouse = null
	if game_state.has_founder():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_accept_pressed() -> void:
	if not is_instance_valid(_dialogue_mouse):
		game_state.close_mouse_dialogue()
		return
	var declined_cost := _dialogue_mouse.get_recruitment_cost()
	if _dialogue_mouse.try_recruit():
		game_state.close_mouse_dialogue()
	else:
		_offer_already_declined = true
		dialogue_text.text = "%s counts your cheese, then shakes their head. You could not meet the %d-cheese price. Their next offer may be different." % [
			_dialogue_mouse.get_display_name(),
			declined_cost,
		]
		offer_label.text = "Current funds: %d cheese" % game_state.cheese
		accept_button.grab_focus()


func _on_decline_pressed() -> void:
	if is_instance_valid(_dialogue_mouse) and not _dialogue_mouse.is_recruited and not _offer_already_declined:
		_dialogue_mouse.revise_price_after_decline()
	game_state.close_mouse_dialogue()


func _on_placement_mode_changed(is_active: bool) -> void:
	placement_instructions.visible = is_active
	interaction_prompt.visible = not is_active and not interaction_prompt.text.is_empty() and not dialogue_panel.visible


func _on_interaction_prompt_changed(prompt: String) -> void:
	interaction_prompt.text = prompt
	interaction_prompt.visible = not prompt.is_empty() and not placement_instructions.visible and not dialogue_panel.visible


func _on_feedback_requested(message: String) -> void:
	feedback_label.text = message
	feedback_label.show()
	_feedback_time_remaining = 3.5


func _on_cheese_changed(new_amount: int) -> void:
	cheese_label.text = "Cheese: %d" % new_amount


func _on_founder_selected(founder: FounderData) -> void:
	founder_label.text = "Founder: %s" % founder.display_name


func _on_catnip_changed(new_amount: int) -> void:
	catnip_label.text = "Catnip: %d" % new_amount


func _on_recruited_count_changed(new_count: int) -> void:
	recruited_label.text = "Recruited mice: %d" % new_count


func _toggle_need_debug() -> void:
	_show_need_debug = not _show_need_debug
	for node: Node in get_tree().get_nodes_in_group("wild_mice") + get_tree().get_nodes_in_group("recruited_mice"):
		var mouse := node as Phase1WildMouse
		if mouse != null:
			mouse.set_need_debug_visible(_show_need_debug)
	if is_instance_valid(_inspected_mouse):
		_on_mouse_inspected(_inspected_mouse)
	game_state.request_feedback("Mouse needs debug %s." % ("enabled" if _show_need_debug else "disabled"))


func _on_build_menu_changed(is_open: bool) -> void:
	build_menu.visible = is_open


func _on_build_selection_changed(display_name: String) -> void:
	build_selection_label.text = "Building: %s" % display_name
	build_selection_label.visible = not display_name.is_empty()


func _on_build_placement_message(message: String, is_valid: bool) -> void:
	build_selection_label.text = "%s
%s" % [build_selection_label.text.split("
")[0], message]
	build_selection_label.modulate = Color(0.65, 1.0, 0.7) if is_valid else Color(1.0, 0.65, 0.6)


func _on_construction_site_count_changed(_site: ConstructionSite) -> void:
	construction_count_label.text = "Active construction sites: %d" % get_tree().get_nodes_in_group("construction_sites").size()


func _on_construction_site_opened(site: ConstructionSite) -> void:
	_managed_site = site
	site.work_progress_changed.connect(_on_site_progress_changed)
	site.bribe_cheese_changed.connect(_on_site_bowl_changed)
	site_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_site_panel()


func _on_construction_site_closed() -> void:
	site_panel.hide()
	_managed_site = null
	call_deferred("_on_construction_site_count_changed", null)
	if game_state.has_founder():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_site_progress_changed(_work: float, _required: float) -> void:
	_refresh_site_panel()


func _on_site_bowl_changed(_amount: int) -> void:
	_refresh_site_panel()


func _refresh_site_panel() -> void:
	if not is_instance_valid(_managed_site):
		return
	site_title.text = _managed_site.get_display_name()
	site_progress.text = "Construction: %d%%" % roundi(_managed_site.get_progress_ratio() * 100.0)
	site_bowl.text = "Bribe bowl: %d cheese" % _managed_site.bribe_cheese


func _on_pattern_discovered(pattern_id: String) -> void:
	var pattern: Dictionary = data_registry.call("get_resonance_pattern", pattern_id)
	if pattern.is_empty():
		return
	resonance_name.text = str(pattern.get("display_name", pattern_id))
	resonance_description.text = str(pattern.get("description", ""))
	var lines: Array[String] = []
	for bonus: Dictionary in pattern.get("bonuses", []):
		var value := float(bonus.get("value", 0.0))
		var value_text := "x%.2f" % value if bonus.get("modifier_type", "multiplier") == "multiplier" else "%+.0f%%" % (value * 100.0)
		lines.append("%s %s: %s" % [
			str(bonus.get("target", "")).replace("_", " ").capitalize(),
			str(bonus.get("stat", "")).replace("_", " ").capitalize(),
			value_text,
		])
	resonance_bonuses.text = "\n".join(lines)
	_resonance_banner_generation += 1
	var generation := _resonance_banner_generation
	resonance_banner.modulate.a = 1.0
	resonance_banner.show()
	await get_tree().create_timer(5.0).timeout
	if generation != _resonance_banner_generation:
		return
	var tween := create_tween()
	tween.tween_property(resonance_banner, "modulate:a", 0.0, 0.6)
	await tween.finished
	if generation == _resonance_banner_generation:
		resonance_banner.hide()


func _on_weather_changed(weather_id: String) -> void:
	weather_label.text = "Weather: %s" % weather_id.capitalize()


func _on_scaffold_started(_duration: float) -> void:
	scaffold_status.show()


func _on_scaffold_balance_changed(balance: float, remaining: float) -> void:
	var marker := roundi((balance + 1.0) * 10.0)
	var bar := "----------|----------"
	marker = clampi(marker, 0, bar.length() - 1)
	bar = bar.substr(0, marker) + "▲" + bar.substr(marker + 1)
	scaffold_status.text = "CAT-STACK BALANCE  %.1fs\n[%s]\n← / → counter the wind" % [remaining, bar]


func _on_scaffold_resolved(success: bool) -> void:
	scaffold_status.text = "Cat-stack stable!" if success else "The cat-stack toppled!"
	game_state.request_feedback(scaffold_status.text)
	await get_tree().create_timer(2.0).timeout
	scaffold_status.hide()
