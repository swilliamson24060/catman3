extends Node3D
class_name StrayCat
## A wandering visitor spawned by StrayCatSpawner (Step 6, mechanic 9: Stray
## Cat Visitors). Purely a passive prop, same division of labor as
## DustBunny: this node just represents "one stray cat waiting at the edge
## of the map," bobbing gently and despawning unresolved after LIFESPAN.
## StrayCatSpawner owns click detection and applying whatever the visit
## resolves to.

signal departed(cat: Node3D)

const LIFESPAN := 30.0
const BOB_SPEED := 2.5
const BOB_HEIGHT := 0.08

var _age: float = 0.0
var _base_y: float = 0.0
var _resolved: bool = false

func _ready() -> void:
	_build_visual()
	_base_y = position.y

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.4, 0.5)
	body.mesh = mesh
	body.position.y = 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.5, 0.15) # orange -- visually distinct from resident mice/cats
	body.set_surface_override_material(0, mat)
	add_child(body)

func _process(delta: float) -> void:
	if _resolved:
		return
	_age += delta
	position.y = _base_y + sin(_age * BOB_SPEED) * BOB_HEIGHT
	rotate_y(delta * 0.8)
	if _age >= LIFESPAN:
		_resolved = true # reuse the guard so departed() only ever fires once
		departed.emit(self)
		queue_free()

## Called by StrayCatSpawner when the player clicks close enough. Returns
## true the first time (caller resolves the visit); false if this cat
## already departed/was greeted this frame.
func greet() -> bool:
	if _resolved:
		return false
	_resolved = true
	queue_free()
	return true
