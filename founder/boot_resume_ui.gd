extends CanvasLayer
class_name BootResumeUI
## Pre-game modal shown only when a save already exists at boot (see
## village_clearing.gd's _maybe_show_founder_select): the reboot used to
## silently auto-load in this case, giving a returning player no way to
## start fresh without deleting the save file by hand. Mirrors
## FounderSelectUI's self-contained shape -- pauses itself, does its own
## work, frees itself -- rather than reporting back through a signal.
##
## The scene's own layer (30) must stay above RebootUIShell's (20): _on_resume()
## below calls load_game(), which replays rumor_acquired for every
## already-known rumor (see RumorService.restore_state) while this modal is
## still on screen -- that fires RebootUIShell's own "Rumor: ..." toast, and
## on a lower layer it rendered on top of this full-attention modal instead
## of behind it.

const FOUNDER_SELECT_UI := preload("res://founder/founder_select_ui.tscn")

@onready var subtitle_label: Label = $Control/Panel/Margin/VBox/Subtitle
@onready var resume_button: Button = $Control/Panel/Margin/VBox/Resume
@onready var new_game_button: Button = $Control/Panel/Margin/VBox/NewGame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var registry := get_node("/root/DataRegistry")
	var save_service := get_node("/root/SaveService")
	var founder_id: String = save_service.peek_founder_cat_id()
	var founder_data: Dictionary = registry.get_founder_cat(founder_id)
	var founder_name := str(founder_data.get("display_name", founder_id))
	if founder_name.is_empty():
		subtitle_label.text = "A saved village was found."
		resume_button.text = "Resume"
	else:
		subtitle_label.text = "Continue %s's village, or start a new one?" % founder_name
		resume_button.text = "Resume %s's Village" % founder_name
	resume_button.pressed.connect(_on_resume)
	new_game_button.pressed.connect(_on_start_new)

func _on_resume() -> void:
	var save_service := get_node("/root/SaveService")
	save_service.load_game()
	_apply_founder_appearance(save_service.current.founder_cat_id)
	get_tree().paused = false
	queue_free()

## Deliberately doesn't touch the save file on disk -- new_game() (called
## once a founder is actually picked, inside FounderSelectUI) only resets
## live in-memory state; the old save is simply overwritten the next time
## the player saves, same as any other game's "New Game" over an old slot.
func _on_start_new() -> void:
	get_parent().add_child(FOUNDER_SELECT_UI.instantiate())
	queue_free()

## Mirrors village_clearing.gd's own _apply_founder_appearance() -- kept
## local rather than reached-into on the parent so this modal stays as
## self-contained as FounderSelectUI is.
func _apply_founder_appearance(founder_id: String) -> void:
	if founder_id.is_empty():
		return
	var founder_data: Dictionary = get_node("/root/DataRegistry").get_founder_cat(founder_id)
	if founder_data.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player_cat")
	CatAppearance.apply_to_player(player, founder_id, founder_data.get("coat", {}))
