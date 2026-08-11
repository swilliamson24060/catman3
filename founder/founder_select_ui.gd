extends CanvasLayer
class_name FounderSelectUI
## Pre-game modal: pauses the scene tree, builds one FounderCard per entry in
## DataRegistry's founder cat registry (fully data-driven -- a 4th CORE
## founder cat needs no changes here), and on selection starts the run:
## creates SaveData and applies the founder's traits through the same
## apply_global_bonuses() path Resonance Patterns will use later.
##
## Founders flagged `"bonus": true` in their data (DLC/expansion content,
## e.g. Comet from Expansion_SpaceMice.json) are deliberately excluded from
## this default lineup -- they aren't part of the base game's opening
## choice. A future dedicated "bonus content" screen can reuse
## DataRegistry.get_all_founder_cats() filtered the other way with zero
## engine changes; this screen just isn't it.

const FOUNDER_CARD_SCENE := preload("res://founder/founder_card.tscn")

@onready var cards_row: HBoxContainer = $Control/Panel/Margin/VBox/CardsRow

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_populate_cards()

func _populate_cards() -> void:
	# Explicit get_node("/root/...") rather than the bare autoload identifier:
	# this script is reached via a preload() chain (village_clearing.gd
	# preloads this scene at compile time), which can run before Godot has
	# finished binding autoload globals -- bare "DataRegistry" fails to
	# resolve in that path even though it works fine everywhere else.
	for founder_data in get_node("/root/DataRegistry").get_all_founder_cats():
		if founder_data.get("bonus", false):
			continue
		var card: FounderCard = FOUNDER_CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(founder_data)
		card.selected.connect(_on_founder_selected)

func _on_founder_selected(founder_id: String) -> void:
	var registry := get_node("/root/DataRegistry")
	var founder_data: Dictionary = registry.get_founder_cat(founder_id)
	if founder_data.is_empty():
		return

	get_node("/root/SaveService").new_game(founder_id)
	# Delay 0: fires immediately rather than waiting out the usual pacing --
	# this is the player's very first Almanac entry, before they've even
	# entered the village, so there's nothing to wait on.
	get_node("/root/AlmanacNotificationService").schedule(&"note_top_bar", 0)
	# Tagged with a stable source_id so this is idempotent (set_source_modifiers,
	# not add_modifiers) -- save_service.gd's load_game() re-applies the same
	# call under the same source_id on every load, so re-selecting or reloading
	# never stacks duplicate bonuses.
	registry.apply_global_bonuses(founder_data.get("modifiers", []), "founder")

	var player := get_tree().get_first_node_in_group("player_cat")
	CatAppearance.apply_to_player(player, founder_id, founder_data.get("coat", {}))

	get_tree().paused = false
	# After unpausing, not before: RebootUIShell's own panels aren't
	# process_mode ALWAYS like this modal is, so their buttons wouldn't
	# respond to clicks while get_tree().paused is still true.
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if shell != null:
		var resident_count: int = get_node("/root/ResidentManager").get_agents().size()
		shell.show_dialog("Welcome!", "Welcome to the village! You have %d residents. You should go and speak to them. You should also read the community board. But first, notice the red exclamation point in the top display? You have a new entry in the almanac! Close this dialog and click on it to read it." % resident_count)
	queue_free()
