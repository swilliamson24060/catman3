extends Node
## Gravity Cat-Stack Scaffolds: a compact wind-driven balance challenge.
## Press G to begin, then use Left/Right to counter the prevailing wind.

signal challenge_started(duration: float)
signal balance_changed(balance: float, remaining: float)
signal challenge_resolved(success: bool)

const DEFAULT_DURATION := 8.0
const FAILURE_LIMIT := 1.0
const SUCCESS_LIMIT := 0.35
const PLAYER_ADJUSTMENT := 0.18
const WIND_DRIFT_PER_SECOND := 0.14

var active: bool = false
var balance: float = 0.0
var remaining: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_G and not active:
		start_challenge()
	elif active and event.keycode == KEY_LEFT:
		adjust_balance(-PLAYER_ADJUSTMENT)
	elif active and event.keycode == KEY_RIGHT:
		adjust_balance(PLAYER_ADJUSTMENT)


func _process(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	var wind: Vector2i = WeatherService.wind_direction()
	var signed_wind := float(wind.x + wind.y)
	balance += signed_wind * WIND_DRIFT_PER_SECOND * delta
	remaining = maxf(remaining - delta, 0.0)
	balance_changed.emit(balance, remaining)
	if absf(balance) >= FAILURE_LIMIT:
		_resolve(false)
	elif remaining <= 0.0:
		_resolve(absf(balance) <= SUCCESS_LIMIT)


func start_challenge(duration: float = DEFAULT_DURATION) -> bool:
	if active or duration <= 0.0:
		return false
	active = true
	balance = 0.0
	remaining = duration
	challenge_started.emit(duration)
	balance_changed.emit(balance, remaining)
	return true


func adjust_balance(amount: float) -> void:
	if not active:
		return
	balance = clampf(balance + amount, -FAILURE_LIMIT, FAILURE_LIMIT)
	balance_changed.emit(balance, remaining)


func cancel_challenge() -> void:
	if active:
		_resolve(false)


func _resolve(success: bool) -> void:
	active = false
	challenge_resolved.emit(success)
