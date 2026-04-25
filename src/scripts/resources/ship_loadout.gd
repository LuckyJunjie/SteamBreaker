extends Resource
class_name ShipLoadout

@export var ship_name: String = "未命名船只"
@export var hull: ShipHull = null
@export var boiler: ShipBoiler = null
@export var helm: ShipHelm = null
@export var main_weapons: Array[ShipWeapon] = []
@export var secondary_weapons: Array[ShipSecondary] = []
@export var special_devices: Array[ShipSpecial] = []
@export var current_hp: int = 100
@export var current_overheat: float = 0.0
@export var status_effects: Array = []

# 计算总重量
func get_total_weight() -> float:
    var total: float = 0.0
    if hull:
        total += hull.weight
    if boiler:
        total += boiler.weight
    if helm:
        total += helm.weight
    for w in main_weapons:
        if w:
            total += w.weight
    for s in secondary_weapons:
        if s:
            total += s.weight
    for sp in special_devices:
        if sp:
            total += sp.weight
    return total

# 计算载重容量（来自船体）
func get_cargo_capacity() -> float:
    if hull:
        return hull.cargo_capacity if "cargo_capacity" in hull else 150.0
    return 150.0

# 计算最大HP
func get_max_hp() -> int:
    if hull:
        return hull.max_hp
    return 100

# 计算总重量占比（0.0 - 1.0+）
func get_weight_ratio() -> float:
    var cap: float = get_cargo_capacity()
    if cap <= 0.0:
        return 999.0
    return get_total_weight() / cap

# 是否超载
func is_overloaded() -> bool:
    return get_weight_ratio() > 1.0

# 实时计算航速加成（超载时大幅降低）
func get_speed_bonus() -> int:
    if boiler:
        var base: int = boiler.speed_bonus
        if is_overloaded():
            base = int(base * 0.3)  # 超载时航速降至30%
        return base
    return 0

# 实时计算转向加成
func get_turn_bonus() -> int:
    if helm:
        return helm.turn_bonus
    return 0

# 复制当前配置（用于预览）
func duplicate() -> ShipLoadout:
    var copy: ShipLoadout = ShipLoadout.new()
    copy.ship_name = ship_name
    copy.hull = hull
    copy.boiler = boiler
    copy.helm = helm
    copy.current_hp = current_hp
    copy.current_overheat = current_overheat
    copy.main_weapons = main_weapons.duplicate()
    copy.secondary_weapons = secondary_weapons.duplicate()
    copy.special_devices = special_devices.duplicate()
    return copy

func _to_string() -> String:
    return "[ShipLoadout: %s, weight=%.1f/%.1f]" % [ship_name, get_total_weight(), get_cargo_capacity()]
