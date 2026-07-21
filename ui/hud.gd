extends CanvasLayer
## Small always-on overlay showing the run's current effective stats. Reads
## purely from StatsService, so it reflects Founder Cat traits now and
## Resonance Pattern bonuses later with zero changes here.

@onready var label: Label = $Control/Panel/Margin/Label

func _ready() -> void:
	StatsService.modifiers_changed.connect(_refresh)
	EventBus.animal_recruited.connect(func(_id, _species): _refresh())
	EventBus.building_placed_as_blueprint.connect(func(_id, _pos): _refresh())
	EventBus.building_constructed.connect(func(_id, _pos): _refresh())
	EventBus.weather_changed.connect(func(_id): _refresh())
	EventBus.animal_on_strike.connect(func(_id, _striking): _refresh())
	TownStorage.inventory_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var construction_speed := StatsService.get_effective("global_construction", "speed", 1.0)
	var harvest := StatsService.get_effective("global_player", "resource_harvest", 1.0)
	var recruitment := StatsService.get_effective("global_mice", "recruitment_rate", 1.0)
	var mice := AnimalManager.recruited_count("mouse")
	var mice_capacity := AnimalManager.housing_capacity("mouse")
	var striking := AnimalManager.striking_count()
	var catnip := TownStorage.get_item_count("catnip")
	var morale := StatsService.get_effective("global_town", "morale", 0.0)
	var weather := WeatherService.weather_id().capitalize()
	label.text = "Construction Speed: x%.2f\nResource Harvest: x%.2f\nMouse Recruitment: x%.2f\nMice: %d/%d (%d on strike)\nTown Catnip: %d\nTown Morale: %.0f\nWeather: %s" % [
		construction_speed, harvest, recruitment, mice, mice_capacity, striking, catnip, morale, weather
	]
