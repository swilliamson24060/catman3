extends Node
## Global signal bus (autoload "EventBus"). Every cross-system interaction
## fires through here instead of scripts holding direct references to each
## other, per the GDD's "event-driven state machines" requirement.

signal building_placed_as_blueprint(building_id: String, grid_pos: Vector2i)
signal building_constructed(building_id: String, grid_pos: Vector2i)
signal animal_recruited(animal_id: String, species_id: String)
signal animal_assigned_job(animal_id: String, job_role: String)
signal pattern_discovered(pattern_id: String)
signal achievement_unlocked(achievement_id: String)
signal weather_changed(weather_id: String)
signal priority_target_set(grid_pos: Vector2i)
signal building_damaged(building_id: String, grid_pos: Vector2i, durability: float)
signal building_collapsed(building_id: String, grid_pos: Vector2i)
signal dream_mode_changed(active: bool)
signal item_spoiled(item_id: String, amount: int)
signal animal_on_strike(animal_id: String, on_strike: bool)
signal wind_changed(direction: Vector2i)
signal stray_cat_appeared(grid_pos: Vector2i)
signal stray_cat_departed(grid_pos: Vector2i)
signal stray_cat_visit_resolved(outcome: String)
