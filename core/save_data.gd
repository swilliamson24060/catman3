extends Resource
class_name SaveData
## Everything about a single run that needs to persist. Kept intentionally
## small and flat; systems added later (achievements, town storage, animal
## rosters) extend this rather than each inventing their own save format.

@export var founder_cat_id: String = ""
@export var discovered_patterns: Array[String] = []
@export var unlocked_content: Array[String] = []
@export var achievement_progress: Dictionary = {}
@export var save_generation: String = "reboot"
@export var world_seed: int = 1337
@export var calendar_state: Dictionary = {}
@export var weather_state: Dictionary = {}
@export var resident_state: Dictionary = {}
@export var relationship_state: Dictionary = {}
@export var community_project_state: Dictionary = {}
@export var rumor_state: Dictionary = {}
@export var discovery_state: Dictionary = {}
@export var investigation_state: Dictionary = {}
@export var seasonal_resonance_state: Dictionary = {}
@export var community_machine_state: Dictionary = {}
@export var celebration_state: Dictionary = {}
@export var user_experience_state: Dictionary = {}
@export var growth_plot_state: Dictionary = {}
@export var exploration_state: Dictionary = {}
