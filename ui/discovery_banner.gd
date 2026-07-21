extends CanvasLayer
## trigger_discovery_ui() from the GDD's Architectural Resonance pseudocode
## -- a toast/banner shown when EventBus.pattern_discovered fires. Purely a
## visual reaction to the signal; ResonanceService doesn't know or care
## this exists, so a real animated/art version can replace this later with
## zero changes anywhere else.

const VISIBLE_SECONDS := 4.0

@onready var panel: PanelContainer = $Control/Panel
@onready var label: Label = $Control/Panel/Margin/Label
@onready var timer: Timer = $Timer

func _ready() -> void:
	panel.visible = false
	EventBus.pattern_discovered.connect(_on_pattern_discovered)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	timer.one_shot = true
	timer.timeout.connect(func(): panel.visible = false)

func _on_pattern_discovered(pattern_id: String) -> void:
	var pattern := DataRegistry.get_resonance_pattern(pattern_id)
	var display_name: String = pattern.get("display_name", pattern_id)
	var description: String = pattern.get("description", "")
	_show("Resonance Discovered: %s\n%s" % [display_name, description])

## Step 7: the exact same toast pattern, reacting to
## EventBus.achievement_unlocked instead -- AchievementService doesn't know
## or care this exists, same as ResonanceService above.
func _on_achievement_unlocked(achievement_id: String) -> void:
	var achievement := DataRegistry.get_achievement(achievement_id)
	var display_name: String = achievement.get("display_name", achievement_id)
	var description: String = achievement.get("description", "")
	_show("Achievement Unlocked: %s\n%s" % [display_name, description])

func _show(text: String) -> void:
	label.text = text
	panel.visible = true
	timer.start(VISIBLE_SECONDS)
