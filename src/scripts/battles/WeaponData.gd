class_name WeaponData
extends Resource

## 武器定义数据（Resource，可配置）

enum WeaponType {
    MAIN_GUN,
    SUB_GUN,
    TORPEDO,
    RAM,
    BOARDING,
    SPECIAL
}

enum AmmoType {
    STANDARD,
    ARMOR_PIERCE,
    HIGH_EXPLOSIVE,
    HOLY_WATER
}

# 基础属性
var weapon_id: String = ""
var display_name: String = ""
var weapon_type: WeaponType = WeaponType.MAIN_GUN
var damage: int = 0
var accuracy: int = 0
var heat_cost: int = 0
var range_min: int = 0
var range_max: int = 999
var cooldown: int = 0
var ammo_type: AmmoType = AmmoType.STANDARD
var ammo_cost: int = 1

# 特殊属性
var can_target_parts: bool = false
var part_accuracy_mod: Dictionary = {}
var intercept_rate: float = 0.0
var special_effects: Array[String] = []

# 状态
var is_loaded: bool = true
var current_cooldown: int = 0

func _init(
    p_weapon_id: String = "",
    p_name: String = "",
    p_type: WeaponType = WeaponType.MAIN_GUN,
    p_damage: int = 0,
    p_accuracy: int = 0,
    p_heat: int = 0,
    p_range_min: int = 0,
    p_range_max: int = 999,
    p_cooldown: int = 0
) -> void:
    weapon_id = p_weapon_id
    display_name = p_name
    weapon_type = p_type
    damage = p_damage
    accuracy = p_accuracy
    heat_cost = p_heat
    range_min = p_range_min
    range_max = p_range_max
    cooldown = p_cooldown

    # 默认部位命中修正
    part_accuracy_mod = {
        "hull":          1.0,
        "boiler":        0.7,
        "helm":          0.6,
        "weapon_slot":   0.65,
        "special_device": 0.55
    }

## 检查武器是否可用于指定射程环 (1=近/2=中/3=远)
func can_fire_at_ring(ring: int) -> bool:
    match weapon_type:
        WeaponType.MAIN_GUN:  return true  # 全距离可用
        WeaponType.SUB_GUN:   return ring <= 2  # 中距及以内
        WeaponType.TORPEDO:   return ring == 3  # 仅远距
        WeaponType.RAM:       return ring == 1  # 仅近距
        WeaponType.BOARDING: return ring == 1  # 仅近距
        WeaponType.SPECIAL:   return true
    return true

## 获取对指定目标的伤害（含距离系数/弹种系数）
func get_damage_vs(target_ring: int, part: String = "hull") -> float:
    var dmg: float = damage

    # 距离伤害系数
    match weapon_type:
        WeaponType.MAIN_GUN:
            match target_ring:
                1: dmg *= 0.8   # 近距主炮减伤
                2: dmg *= 1.0
                3: dmg *= 1.0
        WeaponType.SUB_GUN:
            match target_ring:
                1: dmg *= 1.5  # 副炮近距+50%
                2: dmg *= 1.0
                3: dmg *= 0.0   # 远距不可用
        WeaponType.TORPEDO:
            match target_ring:
                3: dmg *= 1.0
                2: dmg *= 0.7
                1: dmg *= 0.0   # 近距不可用
        WeaponType.RAM:
            dmg *= 2.0 if target_ring == 1 else 0.0
        WeaponType.BOARDING:
            dmg *= 1.5 if target_ring == 1 else 0.0

    # 弹种系数
    match ammo_type:
        AmmoType.ARMOR_PIERCE:   dmg *= 1.5
        AmmoType.HIGH_EXPLOSIVE: dmg *= 2.0
        AmmoType.HOLY_WATER:     dmg *= 1.3

    return dmg

## 检查武器是否在射程内（按距离格数）
func is_in_range(ring: int) -> bool:
    return can_fire_at_ring(ring)

## 消耗弹药/冷却
func consume() -> void:
    is_loaded = false
    current_cooldown = cooldown

func tick_cooldown() -> void:
    if current_cooldown > 0:
        current_cooldown -= 1
    if current_cooldown == 0:
        is_loaded = true

## 预设工厂
static func create_main_gun(id: String, name: String, dmg: int, rng_min: int, rng_max: int) -> WeaponData:
    var w := WeaponData.new(id, name, WeaponData.WeaponType.MAIN_GUN, dmg, 0, 0, rng_min, rng_max)
    return w

static func create_sub_gun(id: String, name: String, dmg: int, intercept: float = 0.15) -> WeaponData:
    var w := WeaponData.new(id, name, WeaponData.WeaponType.SUB_GUN, dmg, 0, 0, 0, 30)
    w.intercept_rate = intercept
    return w
