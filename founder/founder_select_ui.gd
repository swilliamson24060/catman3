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
	for founder_data in DataRegistry.get_all_founder_cats():
		if founder_data.get("bonus", false):
			continue
		var card: FounderCard = FOUNDER_CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(founder_data)
		card.selected.connect(_on_founder_selected)

func _on_founder_selected(founder_id: String) -> void:
	var founder_data := DataRegistry.get_founder_cat(founder_id)
	if founder_data.is_empty():
		return

	SaveService.new_game(founder_id)
	DataRegistry.apply_global_bonuses(founder_data.get("modifiers", []))

	var player := get_tree().get_first_node_in_group("player_cat")
	CatAppearance.apply_to_player(player, founder_id, founder_data.get("coat", {}))

	get_tree().paused = false
	queue_free()
