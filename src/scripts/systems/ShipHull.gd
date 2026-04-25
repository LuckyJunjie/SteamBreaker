extends Resource
class_name ShipHull

@export var hull_name: String = "Unnamed Hull"
@export var hull_type: String = "Unknown"
@export var max_hp: int = 100
@export var armor: int = 0
@export var speed: float = 1.0
@export var min_range: float = 1.0
@export var max_range: float = 3.0
@export var base_damage: int = 10
@export var fire_rate: float = 1.0
@export var steering: float = 1.0

# 改装系统字段
@export var part_id: String = ""
@export var part_name: String = ""
@export var part_type: String = "hull"
@export var weight: float = 0.0
@export var price: int = 0
@export var description: String = ""
@export var cargo_capacity: float = 150.0
@export var weapon_slot_main: int = 2
@export var weapon_slot_sub: int = 1
@export var defense_bonus: int = 0
@export var special_tags: Array[String] = []

func _to_string() -> String:
    return "[ShipHull: %s (%s), HP=%d, Armor=%d]" % [hull_name, hull_type, max_hp, armor]
