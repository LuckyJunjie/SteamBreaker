extends ShipPart
class_name ShipWeapon

@export var damage: int = 0
@export var range_min: float = 0.0
@export var range_max: float = 0.0
@export var overheat_cost: float = 0.0
@export var ammo_type: String = "solid_shot"
@export var armor_pierce: int = 0
@export var fire_rate: float = 1.0

func _to_string() -> String:
    return "[ShipWeapon: %s, dmg=%d, range=%.0f-%.0f]" % [part_name, damage, range_min, range_max]
