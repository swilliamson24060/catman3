extends SceneTree
## Regression guard for the "Elowen reads it for you" mechanic: the founder
## can't read the weathered plaque alone. Talking to a resident whose
## specialty matches (history/Elowen) sends them to read it in the field and
## report back, rather than the plaque handing over its inscription directly.
## Also covers the plaque's own visibility (real marker, clear of the tree).

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const TREE_POSITION := Vector3(-7.0, 0.0, 19.0)
const TREE_CROWN_RADIUS := 1.35 * 1.35  # matches _create_tree's crown_mesh.radius formula for OldGardenTree's scale_factor

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save -- reset after boot, not before.
	# _reading_opportunities is deliberately NOT reset here (see
	# ResidentManager.new_game()'s own comment): it's static world layout
	# registered once at spawn, not session progress.
	root.get_node("DiscoveryService").reset()
	root.get_node("RumorService").reset()
	root.get_node("UserExperienceService").reset_story_state()
	root.get_node("ResidentManager").new_game()
	await process_frame
	await process_frame

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	var resident_hud := world.get_tree().get_first_node_in_group("resident_hud")
	_check(shell != null, "RebootUIShell must be present")
	_check(resident_hud != null, "ResidentHUD must be present")

	var marker := world.get_node_or_null("PlaceholderProps/GardenPlaqueMarker")
	_check(marker != null, "the garden plaque needs its own visible marker, not just the interaction anchor's icon")
	if marker != null:
		var marker_clearance: float = (marker.position - TREE_POSITION).length() - TREE_CROWN_RADIUS
		_check(marker_clearance > 1.0, "the plaque marker must sit clear of OldGardenTree's crown, not behind it: clearance %.2fm" % marker_clearance)

	var plaque: InteractionAnchor
	for anchor_node: Node in world.get_node("AuthoredInteractionAnchors").get_children():
		if (anchor_node as InteractionAnchor).anchor_id == &"garden_plaque": plaque = anchor_node
	_check(plaque != null, "the garden_plaque anchor must exist")

	var manager := root.get_node("ResidentManager")
	var elowen: ResidentAgent = manager.get_agent(&"resident_elowen")
	_check(elowen != null, "resident_elowen must exist")

	if plaque == null or elowen == null or shell == null or resident_hud == null:
		world.queue_free()
		await process_frame
		push_error(_failure if not _failure.is_empty() else "missing a required node")
		quit(1)
		return

	# First interact: the founder can't read it alone, and is pointed at a
	# resident's specialty -- not the inscription itself.
	plaque.interact(null)
	await process_frame
	_check(shell.intro_panel.visible, "the plaque must respond with a dialog on first inspection, not stay silent")
	var faded_text: String = shell.intro_body_label.text.to_lower()
	_check(faded_text.contains("history") or faded_text.contains("worn") or faded_text.contains("smooth"), "the founder should be told it's unreadable and who might help, not shown the inscription yet: got '%s'" % shell.intro_body_label.text)
	_check(root.get_node("DiscoveryService").state(&"discovery_old_plaque") == &"investigation_available", "the plaque must still register as found so a resident can be sent to it")
	shell._on_intro_continue()  # not a raw visible=false poke -- that would skip _close_modal() and leave CalendarService's pause counter unbalanced, freezing Elowen's later travel

	# Talk to Elowen: nothing should be automatic -- she must offer a list of
	# unresolved topics to choose from, and only accept the errand once the
	# player actually picks the plaque from it. A first-ever meeting is
	# introductions only (covered separately by resident_conversation_smoke_test.gd)
	# -- mark her already met so this test stays focused on the errand mechanic.
	root.get_node("UserExperienceService").introduce_anchor(StringName("met_%s" % elowen.resident_id))
	elowen.interaction_anchor.interact(null)
	await process_frame
	_check(shell.ask_panel.visible, "an unresolved topic must offer a choice, not launch straight into the errand or her generic conversation")
	_check(not resident_hud.dialogue_panel.visible, "the choice panel must show first -- nothing should be said until the player picks a topic")
	var plaque_button: Button
	for child: Node in shell.ask_list_box.get_children():
		if child is Button and str((child as Button).text).to_lower().contains("stone"): plaque_button = child
	_check(plaque_button != null, "the plaque's unidentified name must appear as a choosable topic: got %s" % [shell.ask_list_box.get_children().map(func(c: Node) -> String: return str((c as Button).text))])
	shell._on_ask_topic_chosen(&"discovery_old_plaque")
	await process_frame
	_check(resident_hud.dialogue_panel.visible, "choosing the topic must open the resident dialogue panel")
	_check(resident_hud.dialogue_text.text.to_lower().contains("look"), "Elowen should offer to help with the chosen topic: got '%s'" % resident_hud.dialogue_text.text)
	manager.close_dialogue()
	await process_frame
	_check(bool(elowen.current_activity.get("errand", false)), "Elowen must actually be sent on the reading errand, not just told about it")

	# Period changes and fresh-game resets cancel in-flight errands. That must
	# not consume the static world opportunity, or this one interruption would
	# leave the plaque found but permanently impossible to interpret.
	manager.cancel_errand()
	manager.resolve_conversation_topic(elowen, &"discovery_old_plaque")
	manager.close_dialogue()
	await process_frame
	_check(bool(elowen.current_activity.get("errand", false)), "a canceled plaque errand must remain available to start again")

	# Fast-forward her travel and reading (same pattern milestone5/14's tests
	# use for resident work: teleport to the target once she's traveling,
	# then pump ResidentManager._process to drain the timed "reading" phase).
	var reported := false
	for _attempt in range(300):
		if elowen.current_state == ResidentAgent.State.CONTRIBUTION_TRAVEL:
			elowen.global_position = elowen.activity_position()
			elowen._physics_process(0.016)
		manager._process(0.1)
		await process_frame
		if root.get_node("DiscoveryService").state(&"discovery_old_plaque") == &"interpreted":
			reported = true
			break
	_check(reported, "Elowen must actually interpret the plaque after traveling there and reading it")
	# No popup here on purpose: the errand resolves off-screen, possibly while
	# the player is elsewhere entirely, so the translation goes straight into
	# the Almanac (see AlmanacNotificationService) rather than interrupting
	# with a dialogue -- unlike resolve_conversation_topic()'s in-conversation
	# answers, which stay a direct dialogue response to a direct question.
	_check(not resident_hud.dialogue_panel.visible, "reporting back must not pop up a dialogue -- the translation belongs in the Almanac, not an interruption")
	_check(resident_hud.almanac_document().contains("rain and morning light"), "the translation must actually be readable in the Almanac's Interpreted Finds, not just resolved with nowhere to see it")
	# Resolving must also queue a delayed Almanac notification (see
	# almanac_notification_smoke_test.gd for the tunable-delay mechanics themselves).
	_check(root.get_node("AlmanacNotificationService").serialize_state().has("discovery_old_plaque"), "interpreting the plaque must queue a delayed Almanac notification, not skip it")

	# Revisiting the plaque now shows the real inscription directly.
	plaque.interact(null)
	await process_frame
	_check(shell.intro_panel.visible and shell.intro_body_label.text.contains("rain and morning light"), "once interpreted, revisiting the plaque should show the actual inscription")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("GARDEN_PLAQUE_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
