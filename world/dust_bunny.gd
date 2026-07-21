extends Node3D
class_name DustBunny
## A small swattable creature that spawns near active construction sites.
## Gently bobs in place; despawns unrewarded if left alone too long
## (LIFESPAN), or grants its reward the moment something calls swat().
## Purely a passive prop -- DustBunnySpawner owns spawning, click detection,
## and applying the reward; this node just represents "one dust bunny."

signal expired(bunny: Node3D)

const LIFESPAN := 25.0
const BOB_SPEED := 4.0
const BOB_HEIGHT := 0.05

var _age: float = 0.0
var _base_y: float = 0.0
var _swatted: bool = false

func _ready() -> void:
	_build_visual()
	_base_y = position.y

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	body.mesh = mesh
	body.position.y = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.73, 0.7)
	body.set_surface_override_material(0, mat)
	add_child(body)

func _process(delta: float) -> void:
	if _swatted:
		return
	_age += delta
	position.y = _base_y + sin(_age * BOB_SPEED) * BOB_HEIGHT
	rotate_y(delta * 1.5)
	if _age >= LIFESPAN:
		_swatted = true # reuse the guard so expired() only ever fires once
		expired.emit(self)
		queue_free()

## Called by DustBunnySpawner when the player clicks close enough. Returns
## true the first time (caller applies the reward); false if this bunny was
## already swatted/expired this frame.
func swat() -> bool:
	if _swatted:
		return false
	_swatted = true
	queue_free()
	return true
