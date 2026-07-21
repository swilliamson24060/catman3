extends Node
## Autoload "DreamModeService". Cat-Nap Fast-Forward (Step 6, mechanic 5):
## toggles a global 5x time-scale ("Dream Mode") on a hotkey and emits
## EventBus.dream_mode_changed so other systems react instead of polling
## Engine.time_scale directly -- today that's the pastel screen overlay
## (ui/dream_overlay.gd) and AnimalManager's ghost-path gizmos, but nothing
## stops a future system (a "Dream Mode" particle effect, a lullaby track)
## from listening to the exact same signal.
##
## Triggered by pressing N, standing in for the GDD's "napping" action --
## a real trigger (walking onto a bed/cushion prop) can replace this later
## without anything downstream changing, since they'd all still just react
## to dream_mode_changed.

const TIME_SCALE := 5.0
const NAP_KEY := KEY_N

var active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == NAP_KEY:
		toggle()

func toggle() -> void:
	set_active(not active)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	Engine.time_scale = TIME_SCALE if active else 1.0
	EventBus.dream_mode_changed.emit(active)
	print("[DreamModeService] Dream Mode %s (time_scale=%.1f)" % ["ON" if active else "OFF", Engine.time_scale])
