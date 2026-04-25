extends ShipPart
class_name ShipSpecial

@export var skill_id: String = ""
@export var cooldown: int = 0
@export var target_type: String = "enemy_ship"  # enemy_ship / self / ally
@export var effect_type: String = "damage"      # damage / buff / debuff / utility
@export var effect_value: Dictionary = {}       # 具体数值参数

func _to_string() -> String:
    return "[ShipSpecial: %s, skill=%s, cooldown=%d]" % [part_name, skill_id, cooldown]
