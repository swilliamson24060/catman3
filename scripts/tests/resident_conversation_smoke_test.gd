extends SceneTree
## Regression guard for two general (all-residents) conversation mechanics:
## 1) The first-ever conversation with any resident is a one-time
##    introduction establishing their specialty -- nothing else, even if
##    something's already pending they could otherwise help with.
## 2) From then on, if the player has a portable, unidentified find (not one
##    requiring a field trip -- see garden_plaque_smoke_test.gd for that
##    case), asking a resident about it either resolves it immediately (their
##    specialty matches) or gets a polite decline naming what they do know.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save -- reset after boot, not before.
	root.get_node("DiscoveryService").reset()
	root.get_node("UserExperienceService").reset_story_state()
	root.get_node("ResidentManager").new_game()
	await process_frame
	await process_frame

	var manager := root.get_node("ResidentManager")
	var resident_hud := world.get_tree().get_first_node_in_group("resident_hud")
	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(resident_hud != null, "ResidentHUD must be present")
	_check(shell != null, "RebootUIShell must be present")
	var mara: ResidentAgent = manager.get_agent(&"resident_mara")
	var elowen: ResidentAgent = manager.get_agent(&"resident_elowen")
	_check(mara != null, "resident_mara must exist")
	_check(elowen != null, "resident_elowen must exist")
	if resident_hud == null or shell == null or mara == null or elowen == null:
		world.queue_free()
		await process_frame
		push_error(_failure if not _failure.is_empty() else "missing a required node")
		quit(1)
		return

	# First-ever conversation: introduction only.
	mara.interaction_anchor.interact(null)
	await process_frame
	_check(resident_hud.dialogue_panel.visible, "a first meeting must open the dialogue panel, not stay silent")
	var intro_text: String = resident_hud.dialogue_text.text.to_lower()
	_check(intro_text.contains("haven't properly met") or intro_text.contains("gardening"), "the first meeting should introduce Mara and her specialty: got '%s'" % resident_hud.dialogue_text.text)
	manager.close_dialogue()
	await process_frame

	# Second conversation, nothing pending: her normal conversation, not the intro again.
	mara.interaction_anchor.interact(null)
	await process_frame
	var second_text: String = resident_hud.dialogue_text.text.to_lower()
	_check(not second_text.contains("haven't properly met"), "the introduction must only show once, not every conversation")
	_check(second_text.contains("hope to"), "subsequent conversations should fall back to the normal, ongoing conversation text: got '%s'" % resident_hud.dialogue_text.text)
	manager.close_dialogue()
	await process_frame

	# A portable, unidentified find (rain lens -- resident_specialty "history",
	# not Mara's "gardening") pending: talking to her must offer a choice, not
	# volunteer anything automatically.
	root.get_node("DiscoveryService").find(&"component_rain_lens")
	mara.interaction_anchor.interact(null)
	await process_frame
	_check(shell.ask_panel.visible, "an unresolved find must be offered as a choice, not decided automatically")
	_check(not resident_hud.dialogue_panel.visible, "nothing should be said until a topic is chosen or declined")
	_check(shell.ask_title_label.text.contains(mara.display_name()), "the choice prompt should name the resident being asked: got '%s'" % shell.ask_title_label.text)
	_check(shell.ask_list_box.get_child_count() == 1 and str((shell.ask_list_box.get_child(0) as Button).text) == root.get_node("DiscoveryService").unidentified_name(&"component_rain_lens"), "the pending find must appear in the topic list by its unidentified name")

	# Declining ("never mind") must fall back to her normal conversation, not silence.
	shell._on_ask_never_mind()
	await process_frame
	_check(resident_hud.dialogue_panel.visible and resident_hud.dialogue_text.text.to_lower().contains("hope to"), "declining to bring anything up should still fall back to the normal conversation: got '%s'" % resident_hud.dialogue_text.text)
	manager.close_dialogue()
	await process_frame

	# Asking the wrong specialist about it declines by name.
	mara.interaction_anchor.interact(null)
	await process_frame
	shell._on_ask_topic_chosen(&"component_rain_lens")
	await process_frame
	var decline_text: String = resident_hud.dialogue_text.text
	_check(decline_text.begins_with("Sorry! I don't know about"), "a mismatched specialty must decline by name, not silently ignore the find: got '%s'" % decline_text)
	_check(decline_text.to_lower().contains("gardening"), "declining should still say what she does know: got '%s'" % decline_text)
	_check(root.get_node("DiscoveryService").state(&"component_rain_lens") == &"investigation_available", "a decline must not resolve the find")
	manager.close_dialogue()
	await process_frame

	# Elowen's own first meeting, then asking her (specialty matches) resolves it.
	elowen.interaction_anchor.interact(null)
	await process_frame
	_check(resident_hud.dialogue_text.text.to_lower().contains("history"), "Elowen's own introduction should mention her specialty")
	manager.close_dialogue()
	await process_frame

	elowen.interaction_anchor.interact(null)
	await process_frame
	_check(shell.ask_panel.visible, "Elowen must also offer a choice rather than resolving the find on sight")
	shell._on_ask_topic_chosen(&"component_rain_lens")
	await process_frame
	var resolved_text: String = resident_hud.dialogue_text.text
	_check(resolved_text.begins_with("About that"), "a matching specialty should explain the find, not decline or stay generic: got '%s'" % resolved_text)
	_check(resolved_text.contains("shaped to gather rain"), "the explanation must be the discovery's actual interpretation text: got '%s'" % resolved_text)
	_check(root.get_node("DiscoveryService").state(&"component_rain_lens") == &"interpreted", "a matching specialist asked directly must actually resolve the find")
	_check(root.get_node("AlmanacNotificationService").serialize_state().has("component_rain_lens"), "resolving it must queue a delayed Almanac notification")
	manager.close_dialogue()
	await process_frame

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("RESIDENT_CONVERSATION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
