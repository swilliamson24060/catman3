class_name AwayTimer
extends RefCounted
## Tracks real-world elapsed time since a pending action started (planting a
## seed, departing on an expedition), capped at a maximum credited duration.
## Not an autoload -- one instance per pending action, owned by whichever
## service started it.

var started_at: float = 0.0
var cap_seconds: float = 0.0

func start(cap_seconds_value: float) -> void:
	started_at = Time.get_unix_time_from_system()
	cap_seconds = cap_seconds_value

## Real-world seconds elapsed since start(), clamped to [0, cap_seconds].
func credited_seconds() -> float:
	return clampf(Time.get_unix_time_from_system() - started_at, 0.0, cap_seconds)

func is_fully_credited() -> bool:
	return credited_seconds() >= cap_seconds

func serialize() -> Dictionary:
	return {"started_at": started_at, "cap_seconds": cap_seconds}

static func from_data(data: Dictionary) -> AwayTimer:
	var timer := AwayTimer.new()
	timer.started_at = float(data.get("started_at", 0.0))
	timer.cap_seconds = float(data.get("cap_seconds", 0.0))
	return timer
