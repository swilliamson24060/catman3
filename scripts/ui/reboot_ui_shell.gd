class_name RebootUIShell
extends CanvasLayer

const SCREEN_NAMES := ["Community Board", "Village Almanac", "Investigation", "Day Journal", "Optional Map", "Settings", "Guidance History"]
var top_bar: PanelContainer
var status_label: Label
var context_label: Label
var carried_label: Label
var menu_panel: PanelContainer
var menu_box: VBoxContainer
var content_panel: PanelContainer
var content_title: Label
var content_text: RichTextLabel
var settings_box: VBoxContainer
var hint_panel: PanelContainer
var hint_text: RichTextLabel
var _modal_open := false
var _capturing_action: StringName = &""
var _history: Array[String] = []
var _panel_style: StyleBoxFlat

func _ready() -> void:
	layer = 20
	_build_theme_shell()
	_connect_services()
	_refresh_status()
	_show_onboarding_once()

func _unhandled_input(event: InputEvent) -> void:
	if not _capturing_action.is_empty() and (event is InputEventKey or event is InputEventJoypadButton):
		if event.is_pressed():
			get_node("/root/UserExperienceService").remap_action(_capturing_action, event)
			_history.append("Input binding updated: %s" % _capturing_action)
			_capturing_action = &""
			_show_settings()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_menu"):
		if _modal_open: close_all()
		else: open_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_almanac"):
		open_screen("Village Almanac"); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("request_hint"):
		request_hint(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		_quick_save(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		_quick_load(); get_viewport().set_input_as_handled()

func _process(_delta: float) -> void: _refresh_status()

func open_menu() -> void:
	_close_legacy_panels(); menu_panel.visible = true; content_panel.visible = false; _open_modal()
	var first := menu_box.get_child(1) as Button
	if first != null: first.grab_focus()

func open_screen(screen_name: String) -> void:
	menu_panel.visible = false; content_panel.visible = true; settings_box.visible = false; content_text.visible = true; content_title.text = screen_name
	match screen_name:
		"Community Board": _open_legacy_panel("CommunityBoard")
		"Village Almanac": _show_almanac()
		"Investigation": _show_investigation_help()
		"Day Journal": _show_journal()
		"Optional Map": _show_map()
		"Settings": _show_settings()
		"Guidance History": _show_history()
	_open_modal(); $Content/Body/VBox/Close.grab_focus()

func close_all() -> void:
	menu_panel.visible = false; content_panel.visible = false; hint_panel.visible = false; _close_legacy_panels(); _close_modal()

func request_hint() -> void:
	var text: String = get_node("/root/UserExperienceService").request_next_hint()
	_history.append("Requested guidance: %s" % text)
	hint_text.text = "[b]Player-requested guidance[/b]\n%s\n\nThe Almanac retains this note." % text
	hint_panel.visible = true; _open_modal(); $Hint/Margin/VBox/Close.grab_focus()

func _build_theme_shell() -> void:
	_panel_style = StyleBoxFlat.new(); _panel_style.bg_color = Color(0.035, 0.055, 0.05, 0.96); _panel_style.border_color = Color(0.85, 0.74, 0.38); _panel_style.set_border_width_all(2); _panel_style.set_corner_radius_all(10)
	top_bar = PanelContainer.new(); top_bar.name = "TopBar"; add_child(top_bar); top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top_bar.offset_left = 16; top_bar.offset_top = 14; top_bar.offset_right = -16; top_bar.offset_bottom = 94; top_bar.add_theme_stylebox_override("panel", _panel_style)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 14); margin.add_theme_constant_override("margin_right", 14); margin.add_theme_constant_override("margin_top", 8); margin.add_theme_constant_override("margin_bottom", 8); top_bar.add_child(margin)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); margin.add_child(row)
	status_label = Label.new(); status_label.custom_minimum_size.x = 235; row.add_child(status_label)
	context_label = Label.new(); context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(context_label)
	carried_label = Label.new(); carried_label.custom_minimum_size.x = 170; row.add_child(carried_label)
	var menu_button := Button.new(); menu_button.text = "Menu"; menu_button.pressed.connect(open_menu); row.add_child(menu_button)
	var almanac_button := Button.new(); almanac_button.text = "Almanac"; almanac_button.pressed.connect(func() -> void: open_screen("Village Almanac")); row.add_child(almanac_button)
	var hint_button := Button.new(); hint_button.text = "Hint"; hint_button.pressed.connect(request_hint); row.add_child(hint_button)
	menu_panel = PanelContainer.new(); menu_panel.name = "Menu"; add_child(menu_panel); menu_panel.add_theme_stylebox_override("panel", _panel_style); menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); menu_panel.position -= Vector2(240, 250); menu_panel.size = Vector2(480, 500)
	var menu_margin := MarginContainer.new(); menu_margin.add_theme_constant_override("margin_left", 20); menu_margin.add_theme_constant_override("margin_right", 20); menu_margin.add_theme_constant_override("margin_top", 18); menu_margin.add_theme_constant_override("margin_bottom", 18); menu_panel.add_child(menu_margin)
	menu_box = VBoxContainer.new(); menu_box.add_theme_constant_override("separation", 8); menu_margin.add_child(menu_box)
	var title := Label.new(); title.text = "Village Journal"; title.add_theme_font_size_override("font_size", 26); menu_box.add_child(title)
	for screen: String in SCREEN_NAMES:
		var button := Button.new(); button.text = screen; button.pressed.connect(open_screen.bind(screen)); menu_box.add_child(button)
	var save := Button.new(); save.text = "Save game"; save.pressed.connect(_quick_save); menu_box.add_child(save)
	var load := Button.new(); load.text = "Load game"; load.pressed.connect(_quick_load); menu_box.add_child(load)
	var close := Button.new(); close.text = "Return to village"; close.pressed.connect(close_all); menu_box.add_child(close); menu_panel.visible = false
	content_panel = PanelContainer.new(); content_panel.name = "Content"; add_child(content_panel); content_panel.add_theme_stylebox_override("panel", _panel_style); content_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content_panel.offset_left = 150; content_panel.offset_top = 105; content_panel.offset_right = -150; content_panel.offset_bottom = -55
	var content_margin := MarginContainer.new(); content_margin.name = "Body"; content_margin.add_theme_constant_override("margin_left", 24); content_margin.add_theme_constant_override("margin_right", 24); content_margin.add_theme_constant_override("margin_top", 20); content_margin.add_theme_constant_override("margin_bottom", 20); content_panel.add_child(content_margin)
	var content_box := VBoxContainer.new(); content_box.name = "VBox"; content_box.add_theme_constant_override("separation", 10); content_margin.add_child(content_box)
	content_title = Label.new(); content_title.add_theme_font_size_override("font_size", 26); content_box.add_child(content_title)
	content_text = RichTextLabel.new(); content_text.bbcode_enabled = true; content_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_text.focus_mode = Control.FOCUS_ALL; content_box.add_child(content_text)
	settings_box = VBoxContainer.new(); settings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_box.add_child(settings_box)
	var content_close := Button.new(); content_close.name = "Close"; content_close.text = "Close"; content_close.pressed.connect(close_all); content_box.add_child(content_close); content_panel.visible = false
	hint_panel = PanelContainer.new(); hint_panel.name = "Hint"; add_child(hint_panel); hint_panel.add_theme_stylebox_override("panel", _panel_style); hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); hint_panel.position -= Vector2(300, 150); hint_panel.size = Vector2(600, 300)
	var hint_margin := MarginContainer.new(); hint_margin.name = "Margin"; hint_margin.add_theme_constant_override("margin_left", 20); hint_margin.add_theme_constant_override("margin_right", 20); hint_margin.add_theme_constant_override("margin_top", 18); hint_margin.add_theme_constant_override("margin_bottom", 18); hint_panel.add_child(hint_margin)
	var hint_box := VBoxContainer.new(); hint_box.name = "VBox"; hint_margin.add_child(hint_box)
	hint_text = RichTextLabel.new(); hint_text.custom_minimum_size = Vector2(540, 190); hint_text.bbcode_enabled = true; hint_box.add_child(hint_text)
	var hint_close := Button.new(); hint_close.name = "Close"; hint_close.text = "Keep exploring"; hint_close.pressed.connect(close_all); hint_box.add_child(hint_close); hint_panel.visible = false
	_apply_accessibility(get_node("/root/UserExperienceService").preferences)

func _connect_services() -> void:
	var experience := get_node("/root/UserExperienceService")
	experience.preferences_changed.connect(_apply_accessibility)
	experience.lesson_recorded.connect(_on_lesson_recorded)
	get_node("/root/ResidentManager").priority_changed.connect(func(_id: StringName) -> void: experience.record_lesson(&"community_priority"))
	get_node("/root/CommunityProjectService").project_progress_changed.connect(func(_id: StringName, _summary: String) -> void: experience.record_lesson(&"project_contribution"))
	get_node("/root/RumorService").rumor_acquired.connect(func(_id: StringName, _text: String) -> void: experience.record_lesson(&"rumors"))
	get_node("/root/InvestigationService").investigation_completed.connect(func(_result: Dictionary) -> void: experience.record_lesson(&"investigation"))
	get_node("/root/SeasonalResonanceService").component_changed.connect(func(_slot: int, _component: StringName) -> void: experience.record_lesson(&"component_placement"))
	get_node("/root/SeasonalResonanceService").feedback_changed.connect(_on_resonance_feedback)

func _refresh_status() -> void:
	if status_label == null: return
	var calendar := get_node("/root/CalendarService"); var weather := get_node("/root/WeatherService")
	status_label.text = "Day %d · %s\nNow: %s · Next: %s" % [calendar.current_day, str(calendar.period_id()).capitalize(), str(weather.weather_id()).capitalize(), str(weather.forecast_for_offset(1)).capitalize()]
	var residents := get_node("/root/ResidentManager"); var project := get_node("/root/CommunityProjectService")
	context_label.text = "Community priority: %s\n%s" % [residents.priority_display_name(), project.progress_summary()]
	var carried: StringName = project.carried_material
	carried_label.text = "Carrying\n%s" % ("Nothing" if carried.is_empty() else str(carried).trim_prefix("material_").replace("_", " ").capitalize())

func _show_almanac() -> void:
	var hud := get_tree().get_first_node_in_group("resident_hud")
	content_text.text = hud.almanac_document() if hud != null and hud.has_method("almanac_document") else "The Village Almanac is gathering notes."
	var experience := get_node("/root/UserExperienceService")
	if not experience.last_hint.is_empty(): content_text.text += "\n\n[b]Requested guidance[/b]\n%s" % experience.last_hint

func _show_investigation_help() -> void: content_text.text = "[b]Investigation table[/b]\nBring unidentified finds to the workshop table. A resident adds context, but no specialty can block progress. Interpreted findings remain in the Almanac."
func _show_journal() -> void: content_text.text = "[b]Persistent journal[/b]\n%s\n\n[b]Guidance and system messages[/b]\n%s" % [get_node("/root/CommunityProjectService").progress_summary(), "\n".join(_history) if not _history.is_empty() else "No critical messages have been missed."]
func _show_map() -> void: content_text.text = "[b]Optional landmark map — not required for play[/b]\n\nCottages · Village center · Workshop\n                 │\n      Garden — Woodland gate\n                 │\n           Three-branch route\n                 │\n            Ancient ruin\n\nResident locations remain in the Almanac. Rumor markers appear only when requested."
func _show_history() -> void: content_text.text = "[b]Retained information[/b]\n%s" % ("\n\n".join(_history) if not _history.is_empty() else "Core objectives, discoveries, and patterns remain in their dedicated screens.")

func _show_settings() -> void:
	content_text.visible = false; settings_box.visible = true
	for child: Node in settings_box.get_children(): child.queue_free()
	var service := get_node("/root/UserExperienceService")
	_add_check("Interaction uses toggle mode", &"interaction_toggle", bool(service.get_preference(&"interaction_toggle")))
	_add_slider("Text size", &"text_scale", float(service.get_preference(&"text_scale")), 0.85, 1.5, 0.05)
	_add_check("High contrast panels", &"high_contrast", bool(service.get_preference(&"high_contrast")))
	_add_slider("Camera shake", &"camera_shake", float(service.get_preference(&"camera_shake")), 0.0, 1.0, 0.1)
	_add_check("Subtitles", &"subtitles", bool(service.get_preference(&"subtitles")))
	_add_check("Show subtitle speaker", &"subtitle_speaker", bool(service.get_preference(&"subtitle_speaker")))
	_add_check("Reduced flash", &"reduced_flash", bool(service.get_preference(&"reduced_flash")))
	var heading := Label.new(); heading.text = "Remappable actions — activate, then press a key or controller button"; settings_box.add_child(heading)
	for action: StringName in service.REMAPPABLE_ACTIONS:
		var button := Button.new(); button.text = String(action).replace("_", " ").capitalize(); button.pressed.connect(_capture_action.bind(action)); settings_box.add_child(button)

func _add_check(label_text: String, key: StringName, value: bool) -> void:
	var check := CheckBox.new(); check.text = label_text; check.button_pressed = value; check.toggled.connect(func(enabled: bool) -> void: get_node("/root/UserExperienceService").set_preference(key, enabled)); settings_box.add_child(check)
func _add_slider(label_text: String, key: StringName, value: float, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new(); var label := Label.new(); label.text = label_text; label.custom_minimum_size.x = 180; row.add_child(label)
	var slider := HSlider.new(); slider.min_value = minimum; slider.max_value = maximum; slider.step = step; slider.value = value; slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.value_changed.connect(func(new_value: float) -> void: get_node("/root/UserExperienceService").set_preference(key, new_value)); row.add_child(slider); settings_box.add_child(row)
func _capture_action(action: StringName) -> void: _capturing_action = action; content_title.text = "Press a new key or controller button for %s" % String(action).replace("_", " ")

func _apply_accessibility(prefs: Dictionary) -> void:
	var scale_factor := clampf(float(prefs.get("text_scale", 1.0)), 0.85, 1.5)
	for node: Node in find_children("*", "Label", true, false): (node as Label).add_theme_font_size_override("font_size", roundi(16.0 * scale_factor))
	for node: Node in find_children("*", "Button", true, false): (node as Button).add_theme_font_size_override("font_size", roundi(16.0 * scale_factor))
	if _panel_style != null:
		_panel_style.bg_color = Color(0.005, 0.008, 0.006, 1.0) if bool(prefs.get("high_contrast", false)) else Color(0.035, 0.055, 0.05, 0.96)
		_panel_style.border_color = Color.WHITE if bool(prefs.get("high_contrast", false)) else Color(0.85, 0.74, 0.38)

func _on_resonance_feedback(result: Dictionary) -> void:
	get_node("/root/UserExperienceService").record_lesson(&"resonance_initial_clue")
	var cue: Dictionary = get_node("/root/UserExperienceService").tier_accessible_cue(int(result.get("tier", 0)))
	_history.append("Resonance %s %s — %s." % [cue.symbol, cue.name, cue.motion])
func _on_lesson_recorded(lesson_id: StringName) -> void: _history.append(get_node("/root/UserExperienceService").lesson_text(lesson_id))
func _quick_save() -> void: _history.append("Game saved." if get_node("/root/SaveService").save_game() else "Save failed; previous data was preserved.")
func _quick_load() -> void: _history.append("Game loaded." if get_node("/root/SaveService").load_game() else "No compatible save was loaded."); _refresh_status()
func _show_onboarding_once() -> void:
	var service := get_node("/root/UserExperienceService")
	if &"movement_interaction" in service.completed_lessons: return
	service.record_lesson(&"movement_interaction")
func _open_legacy_panel(panel_name: String) -> void:
	var hud := get_tree().get_first_node_in_group("resident_hud")
	if hud != null and hud.has_method("open_named_panel"): hud.open_named_panel(panel_name)
func _close_legacy_panels() -> void:
	var hud := get_tree().get_first_node_in_group("resident_hud")
	if hud != null and hud.has_method("close_navigation_panels"): hud.close_navigation_panels()
func _open_modal() -> void:
	if _modal_open: return
	_modal_open = true; get_node("/root/CalendarService").push_modal_pause(); var player := get_tree().get_first_node_in_group("reboot_player") as RebootFounderCat; if player != null: player.input_enabled = false
func _close_modal() -> void:
	if not _modal_open: return
	_modal_open = false; get_node("/root/CalendarService").pop_modal_pause(); var player := get_tree().get_first_node_in_group("reboot_player") as RebootFounderCat; if player != null: player.input_enabled = true
