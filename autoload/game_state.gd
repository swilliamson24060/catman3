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
signal build_selection_changed(display_name: String)
signal placement_validity_message_changed(message: String, is_valid: bool)
signal construction_site_placed(site: ConstructionSite)
signal construction_site_opened(site: ConstructionSite)
signal construction_site_closed
signal building_produced(building: Node3D, resource_id: StringName, amount: int)

const STARTING_CHEESE: int = 20
const STARTING_CATNIP: int = 0
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
	if amount <= 0:
		return false
	match resource_id:
		&"cheese":
			add_cheese(amount)
		&"catnip":
			add_catnip(amount)
		_:
			push_warning("No Phase 2 economy route for produced resource '%s'." % resource_id)
			return false
	building_produced.emit(producer, resource_id, amount)
	return true


func get_recruited_mouse_count() -> int:
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group("recruited_mice").size()


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
	is_build_menu_open = is_open
	build_menu_changed.emit(is_open)


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


func _modifier(property_name: StringName) -> float:
	if not has_founder():
		return 1.0
	return float(selected_founder.get(property_name))
