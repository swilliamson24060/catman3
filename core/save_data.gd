extends Resource
class_name SaveData
## Everything about a single run that needs to persist. Kept intentionally
## small and flat; systems added later (achievements, town storage, animal
## rosters) extend this rather than each inventing their own save format.

@export var founder_cat_id: String = ""
@export var discovered_patterns: Array[String] = []
@export var unlocked_content: Array[String] = []
@export var achievement_progress: Dictionary = {}
