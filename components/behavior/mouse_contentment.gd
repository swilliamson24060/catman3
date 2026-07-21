class_name MouseContentment
extends Node

signal contentment_changed(new_score: int)
signal unhappy_state_changed(is_unhappy: bool)

const MINIMUM_SCORE: int = 0
const MAXIMUM_SCORE: int = 20
const NEUTRAL_SCORE: int = 10
const UNHAPPY_THRESHOLD: int = 3
const UNHAPPY_COWORKER_DECAY_MULTIPLIER: float = 1.5

@export_range(MINIMUM_SCORE, MAXIMUM_SCORE, 1) var starting_score: int = NEUTRAL_SCORE

var score: int = NEUTRAL_SCORE


func _ready() -> void:
	score = clampi(starting_score, MINIMUM_SCORE, MAXIMUM_SCORE)


## Applies a signed contentment change and returns the resulting score.
func adjust(amount: int) -> int:
	var was_unhappy := is_unhappy()
	score = clampi(score + amount, MINIMUM_SCORE, MAXIMUM_SCORE)
	contentment_changed.emit(score)
	if was_unhappy != is_unhappy():
		unhappy_state_changed.emit(is_unhappy())
	return score


func is_unhappy() -> bool:
	return score <= UNHAPPY_THRESHOLD


## Returns decay accelerated by unhappy mice in the same future work group.
func get_coworker_adjusted_decay(base_decay: float, coworkers: Array[Node]) -> float:
	var multiplier: float = 1.0
	for coworker: Node in coworkers:
		if coworker != null and coworker != self and coworker.is_unhappy():
			multiplier *= UNHAPPY_COWORKER_DECAY_MULTIPLIER
	return base_decay * multiplier
