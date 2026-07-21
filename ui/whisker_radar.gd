extends CanvasLayer
## Whisker-Radar Hot/Cold (Step 6, mechanic 2): two on-screen "whiskers"
## that vibrate faster and wider as the player cat gets closer to a hidden
## (still-fogged) rare resource node. Pure reaction to GridService's
## spatial data + the player's live position -- no gameplay state lives
## here, and it never needs to know moonstone is the only rare item today;
## any future item flagged is_rare on a ResourceNode is picked up for free.

const MAX_RANGE := 12.0
const MIN_HZ := 0.4
const MAX_HZ := 6.0
const MIN_AMPLITUDE_DEG := 2.0
const MAX_AMPLITUDE_DEG := 14.0

@onready var left_whisker: Line2D = $Control/LeftWhisker
@onready var right_whisker: Line2D = $Control/RightWhisker
@onready var grid_service: Node = get_node("/root/GridService")

var _phase: float = 0.0

## Exposed for verification/tooling -- the current 0..1 "closeness" value
## driving the whiskers, so a test can assert it moves the right direction
## without having to eyeball the animation.
var last_closeness: float = 0.0

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player_cat")
	if player == null:
		return

	var dist := float(grid_service.call("nearest_hidden_rare_distance", player.global_position))
	var closeness := 0.0 if dist == INF else clampf(1.0 - dist / MAX_RANGE, 0.0, 1.0)
	last_closeness = closeness

	var hz := lerpf(MIN_HZ, MAX_HZ, closeness)
	var amplitude := lerpf(MIN_AMPLITUDE_DEG, MAX_AMPLITUDE_DEG, closeness)

	_phase += delta * hz * TAU
	var wiggle := sin(_phase) * amplitude

	left_whisker.rotation_degrees = -20.0 + wiggle
	right_whisker.rotation_degrees = 20.0 - wiggle
