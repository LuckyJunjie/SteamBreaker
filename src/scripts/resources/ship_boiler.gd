extends ShipPart
class_name ShipBoiler

@export var speed_bonus: int = 0          # 航速加成
@export var overheat_threshold: float = 80.0
@export var heat_recovery: float = 5.0    # 每回合过热恢复
@export var maneuver_power: int = 0      # 机动值回复

func _to_string() -> String:
    return "[ShipBoiler: %s, speed=%d, heat=%d]" % [part_name, speed_bonus, overheat_threshold]
