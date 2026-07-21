extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const FOG_REVEAL_RADIUS = 5
var gravity = 9.8

func _ready():
	add_to_group("player_cat")

func _physics_process(delta):
	# Add the gravity if falling.
	if not is_on_floor():
		velocity.y -= gravity * delta

	var current_tile := GridService.world_to_grid(global_position)
	GridService.reveal_around(current_tile, FOG_REVEAL_RADIUS)
	_update_thermal_buff(current_tile)

	# Effective speed reads live from StatsService -- founder cat traits
	# (Turbo's +25%) and Thermal Warmth Grid's temp buff both land here
	# with zero special-casing.
	var effective_speed: float = StatsService.get_effective("global_player", "movement_speed", SPEED)

	# Process absolute input directions.
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_back"):
		direction.z += 1.0
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1.0

	# Normalize the vector so diagonal movement isn't faster.
	direction = direction.normalized()

	# Apply the directions to the character velocity and handle smooth rotation
	if direction != Vector3.ZERO:
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed

		# Calculate the angle the player should face based on movement direction
		var target_angle = atan2(-direction.x, -direction.z)

		# Smoothly rotate the player's body toward that target angle
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, effective_speed)
		velocity.z = move_toward(velocity.z, 0, effective_speed)

	# Execute the engine movement calculation.
	move_and_slide()

## Thermal Warmth Grid (Step 6, mechanic 4): a temporary, removable speed
## buff while standing on a warm tile -- comes and goes via StatsService's
## temp-modifier pipeline rather than the permanent founder/resonance pool.
const WARMTH_BUFF_THRESHOLD := 0.35
const WARMTH_BUFF_SOURCE := "thermal_warmth"

func _update_thermal_buff(current_tile: Vector2i) -> void:
	var heat := ThermalService.get_heat(current_tile)
	if heat >= WARMTH_BUFF_THRESHOLD:
		StatsService.add_temp_modifier(WARMTH_BUFF_SOURCE, "global_player", "movement_speed", "additive", heat * 1.5)
	else:
		StatsService.remove_temp_modifier(WARMTH_BUFF_SOURCE, "global_player", "movement_speed")
