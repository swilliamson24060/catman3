class_name Phase1GameState
extends Node

signal cheese_changed(new_amount: int)
signal catnip_changed(new_amount: int)
signal recruited_mouse_count_changed(new_count: int)
signal founder_selected(founder: FounderData)
signal picnic_placed(picnic: Node3D)
signal picnic_started(picnic: Node3D)
signal placement_mode_changed(is_active: bool)
signal interaction_prompt_changed(prompt: String)
signal feedback_requested(message: String)
signal dialogue_opened(mouse: Phase1WildMouse)
signal dialogue_closed
signal mouse_recruited(mouse: Phase1WildMouse)
signal mouse_inspected(mouse: Phase1WildMouse)
signal build_menu_changed(is_open: bool)
signal build_decision_pending_changed(is_pending: bool)
signal build_selection_changed(display_name: String)
signal placement_validity_message_changed(message: String, is_valid: bool)
signal construction_site_placed(site: ConstructionSite)
signal construction_site_opened(site: ConstructionSite)
signal construction_site_closed
signal building_produced(building: Node3D, resource_id: StringName, amount: int)
signal settlement_resource_changed(resource_id: StringName, new_amount: int)

const STARTING_CHEESE: int = 20
const STARTING_CATNIP: int = 0
const MINIMUM_MICE_FOR_BUILDING: int = 2
const FOUNDER_RESOURCES: Array[FounderData] = [
	preload("res://resources/founders/barnaby.tres"),
	preload("res://resources/founders/whisper.tres"),
	preload("res://resources/founders/turbo.tres"),
]

var cheese: int = STARTING_CHEESE:
	set(value):
		cheese = maxi(value, 0)
		cheese_changed.emit(cheese)

var catnip: int = STARTING_CATNIP:
	set(value):
		catnip = maxi(value, 0)
		catnip_changed.emit(catnip)

var selected_founder: FounderData
var placed_picnic: Node3D
var active_dialogue_mouse: Phase1WildMouse
var active_construction_site: ConstructionSite
var is_build_menu_open: bool = false
var _build_decision_pending: bool = false
var _extra_resources: Dictionary = {}


func _ready() -> void:
	construction_site_placed.connect(_on_construction_site_placed)


## Returns whether the current inventory can cover an amount.
func can_afford(amount: int) -> bool:
	return amount >= 0 and cheese >= amount


## Adds a non-negative amount of cheese.
func add_cheese(amount: int) -> void:
	if amount <= 0:
		return
	cheese += amount


## Spends cheese atomically and reports whether the purchase succeeded.
func spend_cheese(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	cheese -= amount
	return true


## Returns the current cheese balance.
func get_cheese() -> int:
	return cheese


func can_afford_cheese(amount: int) -> bool:
	return can_afford(amount)


func get_resource_amount(resource_id: StringName) -> int:
	match resource_id:
		&"cheese":
			return cheese
		&"catnip":
			return catnip
	return maxi(int(_extra_resources.get(resource_id, 0)), 0)


func can_store_resource(resource_id: StringName, amount: int) -> bool:
	return not resource_id.is_empty() and amount > 0


func can_afford_resources(costs: Dictionary) -> bool:
	for raw_id: Variant in costs:
		var amount := int(costs[raw_id])
		if amount < 0 or get_resource_amount(StringName(str(raw_id))) < amount:
			return false
	return true


## Checks the complete recipe before removing anything, preventing partial loss.
func spend_resources(costs: Dictionary) -> bool:
	if not can_afford_resources(costs):
		return false
	for raw_id: Variant in costs:
		var resource_id := StringName(str(raw_id))
		var amount := int(costs[raw_id])
		match resource_id:
			&"cheese":
				cheese -= amount
			&"catnip":
				catnip -= amount
			_:
				_extra_resources[resource_id] = maxi(int(_extra_resources.get(resource_id, 0)) - amount, 0)
				settlement_resource_changed.emit(resource_id, int(_extra_resources[resource_id]))
	return true


## Returns the current catnip balance.
func get_catnip() -> int:
	return catnip


func add_catnip(amount: int) -> void:
	if amount <= 0:
		return
	catnip += amount


func spend_catnip(amount: int) -> bool:
	if amount < 0 or catnip < amount:
		return false
	catnip -= amount
	return true


## Deposits a building output into the Phase 2 settlement economy.
## Keeping this routing here gives producers one generic, data-driven API while
## preserving the existing strongly signalled HUD balances.
func deposit_resource(resource_id: StringName, amount: int, producer: Node3D = null) -> bool:
	if not can_store_resource(resource_id, amount):
		return false
	match resource_id:
		&"cheese":
			add_cheese(amount)
		&"catnip":
			add_catnip(amount)
		_:
			_extra_resources[resource_id] = get_resource_amount(resource_id) + amount
			settlement_resource_changed.emit(resource_id, int(_extra_resources[resource_id]))
	building_produced.emit(producer, resource_id, amount)
	return true


func serialize_economy() -> Dictionary:
	return {"cheese": cheese, "catnip": catnip, "resources": _extra_resources.duplicate(true)}


func restore_economy(data: Dictionary) -> void:
	cheese = maxi(int(data.get("cheese", STARTING_CHEESE)), 0)
	catnip = maxi(int(data.get("catnip", STARTING_CATNIP)), 0)
	_extra_resources.clear()
	var resources: Variant = data.get("resources", {})
	if resources is Dictionary:
		for raw_id: Variant in resources:
			var resource_id := StringName(str(raw_id))
			if resource_id.is_empty():
				continue
			_extra_resources[resource_id] = maxi(int(resources[raw_id]), 0)
			settlement_resource_changed.emit(resource_id, int(_extra_resources[resource_id]))


func get_recruited_mouse_count() -> int:
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group("recruited_mice").size()


func is_build_system_unlocked() -> bool:
	return get_recruited_mouse_count() >= MINIMUM_MICE_FOR_BUILDING


## Selects a founder once for the current play session.
func select_founder(founder_id: StringName) -> bool:
	if has_founder():
		return false
	for founder: FounderData in FOUNDER_RESOURCES:
		if founder.internal_id == founder_id:
			selected_founder = founder
			founder_selected.emit(founder)
			return true
	return false


func has_founder() -> bool:
	return selected_founder != null


func has_picnic() -> bool:
	return is_instance_valid(placed_picnic)


func register_picnic(picnic: Node3D) -> bool:
	if has_picnic() or picnic == null:
		return false
	placed_picnic = picnic
	picnic_placed.emit(picnic)
	return true


func unregister_picnic(picnic: Node3D) -> bool:
	if picnic == null or placed_picnic != picnic:
		return false
	placed_picnic = null
	return true


func set_placement_mode(is_active: bool) -> void:
	placement_mode_changed.emit(is_active)


func set_interaction_prompt(prompt: String) -> void:
	interaction_prompt_changed.emit(prompt)


func request_feedback(message: String) -> void:
	feedback_requested.emit(message)


func is_dialogue_open() -> bool:
	return is_instance_valid(active_dialogue_mouse)


func toggle_build_menu() -> void:
	set_build_menu_open(not is_build_menu_open)


func set_build_menu_open(is_open: bool) -> void:
	if is_open and not is_build_system_unlocked():
		is_build_menu_open = false
		build_menu_changed.emit(false)
		request_feedback("Recruit at least %d mice before choosing a building." % MINIMUM_MICE_FOR_BUILDING)
		return
	is_build_menu_open = is_open
	build_menu_changed.emit(is_open)


func begin_build_decision() -> void:
	if not is_build_system_unlocked():
		set_build_menu_open(false)
		return
	if not _build_decision_pending:
		_build_decision_pending = true
		build_decision_pending_changed.emit(true)
	set_build_menu_open(true)


func is_build_decision_pending() -> bool:
	return _build_decision_pending


func _on_construction_site_placed(_site: ConstructionSite) -> void:
	if not _build_decision_pending:
		return
	_build_decision_pending = false
	build_decision_pending_changed.emit(false)


func set_build_selection(display_name: String) -> void:
	build_selection_changed.emit(display_name)


func set_placement_validity(message: String, is_valid: bool) -> void:
	placement_validity_message_changed.emit(message, is_valid)


func is_construction_site_open() -> bool:
	return is_instance_valid(active_construction_site)


func open_construction_site(site: ConstructionSite) -> bool:
	if site == null or is_construction_site_open() or is_dialogue_open():
		return false
	active_construction_site = site
	set_interaction_prompt("")
	construction_site_opened.emit(site)
	return true


func close_construction_site() -> void:
	active_construction_site = null
	construction_site_closed.emit()


## Opens the shared dialogue UI for one mouse at a time.
func open_mouse_dialogue(mouse: Phase1WildMouse) -> bool:
	if mouse == null or is_dialogue_open():
		return false
	active_dialogue_mouse = mouse
	set_interaction_prompt("")
	dialogue_opened.emit(mouse)
	return true


## Closes dialogue and lets the active mouse resume its picnic behavior.
func close_mouse_dialogue() -> void:
	if is_instance_valid(active_dialogue_mouse):
		active_dialogue_mouse.close_negotiation()
	active_dialogue_mouse = null
	dialogue_closed.emit()


## Applies the founder's bonus to recruitment probability or recruitment progress.
func get_recruitment_rate(base_rate: float) -> float:
	return base_rate * _modifier(&"recruitment_rate_multiplier")


func get_building_speed(base_speed: float) -> float:
	return base_speed * _modifier(&"building_speed_multiplier")


func get_cheese_yield(base_amount: float) -> float:
	return base_amount * _modifier(&"cheese_yield_multiplier")


func get_worker_pay(base_amount: float) -> float:
	return base_amount * _modifier(&"worker_pay_multiplier")


func get_resource_discovery_rate(base_rate: float) -> float:
	return base_rate * _modifier(&"resource_discovery_multiplier")


func get_stray_recruitment_rate(base_rate: float) -> float:
	return base_rate * _modifier(&"stray_recruitment_multiplier")


func reset() -> void:
	cheese = STARTING_CHEESE
	catnip = STARTING_CATNIP
	selected_founder = null
	placed_picnic = null
	active_dialogue_mouse = null
	active_construction_site = null
	is_build_menu_open = false
	_build_decision_pending = false
	_extra_resources.clear()


func _modifier(property_name: StringName) -> float:
	if not has_founder():
		return 1.0
	return float(selected_founder.get(property_name))
