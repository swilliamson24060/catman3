class_name DaySummaryUI
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var summary_label: RichTextLabel = $Panel/Margin/VBox/Summary
@onready var continue_button: Button = $Panel/Margin/VBox/Continue

func _ready() -> void:
	add_to_group("day_summary_ui")
	get_node("/root/CalendarService").day_ended.connect(show_summary)
	continue_button.pressed.connect(close_summary)
	panel.visible = false

func show_summary(summary: Dictionary) -> void:
	if panel.visible:
		return
	title_label.text = "Day %d Journal" % int(summary.get("day", get_node("/root/CalendarService").current_day))
	var lines: Array[String] = []
	_append_section(lines, "Discoveries", summary.get("discoveries", []), "No new discoveries — the clearing still held quiet details.")
	_append_section(lines, "Community work", summary.get("project_progress", []), "Shared work will safely continue tomorrow.")
	_append_section(lines, "Relationship moments", summary.get("relationship_moments", []), "A peaceful day with room for new friendships.")
	lines.append("[b]Tomorrow[/b]\nForecast: %s" % str(summary.get("tomorrow_forecast", "clear")).capitalize())
	summary_label.text = "\n\n".join(lines)
	panel.visible = true
	get_node("/root/CalendarService").push_modal_pause()
	var player := get_tree().get_first_node_in_group("reboot_player") as RebootFounderCat
	if player != null:
		player.input_enabled = false
	continue_button.grab_focus()

func close_summary() -> void:
	if not panel.visible:
		return
	panel.visible = false
	get_node("/root/CalendarService").pop_modal_pause()
	var player := get_tree().get_first_node_in_group("reboot_player") as RebootFounderCat
	if player != null:
		player.input_enabled = true

func is_open() -> bool:
	return panel.visible

func _append_section(lines: Array[String], heading: String, entries_value: Variant, empty_text: String) -> void:
	var entries: Array = entries_value if entries_value is Array else []
	var body := empty_text
	if not entries.is_empty():
		var bullets: Array[String] = []
		for entry: Variant in entries:
			bullets.append("• %s" % str(entry))
		body = "\n".join(bullets)
	lines.append("[b]%s[/b]\n%s" % [heading, body])
