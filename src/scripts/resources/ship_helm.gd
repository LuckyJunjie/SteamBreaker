extends ShipPart
class_name ShipHelm

@export var turn_bonus: int = 0           # 转向加成
@export var intercept_bonus: int = 0     # 迎击加成
@export var skill_slots: int = 1          # 可装备技能数量

func _to_string() -> String:
    return "[ShipHelm: %s, turn=%d, skill_slots=%d]" % [part_name, turn_bonus, skill_slots]
