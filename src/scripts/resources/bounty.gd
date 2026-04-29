class_name Bounty
extends Resource

## 赏金数据资源

@export var bounty_id: String = ""
@export var name: String = ""
@export var rank: String = ""          # sea / ocean / legendary
@export var reward_gold: int = 0
@export var reward_items: Array[String] = []
@export var required_story_flag: String = ""
@export var spawn_location: String = ""
@export var encounter_conditions: Dictionary = {}
@export var dialogue: Dictionary = {}
@export var special_mechanics: Dictionary = {}
@export var is_defeated: bool = false
