extends CanvasLayer
## Cat-Nap Fast-Forward's "dreamy pastel screen shader" -- a full-screen
## tint that fades in while Dream Mode is active, gently cycling through
## pastel hues, and fades back out when it ends. Pure reaction to
## EventBus.dream_mode_changed; DreamModeService doesn't know this exists.

const FADE_SPEED := 2.5
const TARGET_ALPHA := 0.22

@onready var tint: ColorRect = $Tint
@onready var event_bus: Node = get_node("/root/EventBus")

var _target_alpha: float = 0.0
var _hue_t: float = 0.0

func _ready() -> void:
	tint.color = Color(1.0, 0.85, 0.95, 0.0)
	event_bus.dream_mode_changed.connect(_on_dream_mode_changed)

func _on_dream_mode_changed(active: bool) -> void:
	_target_alpha = TARGET_ALPHA if active else 0.0

func _process(delta: float) -> void:
	_hue_t += delta
	var current := tint.color
	current.a = move_toward(current.a, _target_alpha, FADE_SPEED * delta)
	current.r = 0.9 + 0.1 * sin(_hue_t * 0.7)
	current.g = 0.8 + 0.1 * sin(_hue_t * 0.5 + 2.0)
	current.b = 0.9 + 0.1 * sin(_hue_t * 0.3 + 4.0)
	tint.color = current
