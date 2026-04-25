extends ShipPart
class_name ShipSecondary

@export var damage: int = 0
@export var intercept_power: int = 0      # 拦截能力
@export var focus_max: int = 3            # 专注值上限
@export var range_type: String = "anti_missile"  # anti_missile / anti_torpedo / anti_ship

func _to_string() -> String:
    return "[ShipSecondary: %s, dmg=%d, intercept=%d]" % [part_name, damage, intercept_power]
