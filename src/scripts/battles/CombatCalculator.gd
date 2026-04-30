class_name CombatCalculator
extends Node

## 命中与伤害计算工具（静态方法集合）

# 静态配置（可由 GameState 覆盖）
const BASE_HIT_RATE: float = 0.75
const PART_HIT_RATES: Dictionary = {
    "hull":          1.0,
    "boiler":        0.7,
    "helm":          0.6,
    "weapon_slot":   0.65,
    "special_device": 0.55
}
const RING_HIT_MODIFIER: Dictionary = {
    1:  0.30,  # 近距(近战)+30%
    2:  0.0,   # 中距
    3: -0.20   # 远距-20%
}
const SPEED_DIFF_MODIFIER: float = 0.01  # 每点速度差 ±1%，上限±15%

## 命中率计算
static func calc_hit_chance(
    weapon: WeaponData,
    attacker_speed: int,
    target: ShipCombatData,
    part: String = "hull"
) -> float:
    # 基础命中率
    var chance: float = BASE_HIT_RATE

    # 距离修正
    var ring: int = target.current_ring
    var ring_mod: float = RING_HIT_MODIFIER.get(ring, 0.0)
    chance += ring_mod

    # 速度差修正
    var speed_diff: int = attacker_speed - target.get_speed()
    var speed_mod: float = clampf(float(speed_diff) * SPEED_DIFF_MODIFIER, -0.15, 0.15)
    chance += speed_mod

    # 武器精度加成
    chance += weapon.accuracy * 0.01

    # 部位命中修正
    var part_rate: float = PART_HIT_RATES.get(part, 1.0)
    chance *= part_rate

    # 混乱状态
    if target.has_status(StatusEffect.StatusType.DISORIENT):
        chance -= 0.15

    # 隐形状态 → 命中率为0
    if target.has_status(StatusEffect.StatusType.STEALTH):
        chance = 0.0

    return clampf(chance, 0.05, 0.95)

## 伤害计算
static func calc_damage(
    weapon: WeaponData,
    target: ShipCombatData,
    part: String = "hull",
    is_critical: bool = false
) -> float:
    var dmg: float = weapon.get_damage_vs(target.current_ring, part)

    # 护甲减免
    var armor_val: float = target._get_armor_value(part)
    var armor_reduction: float = armor_val / (armor_val + 100.0)
    dmg *= (1.0 - armor_reduction)

    # 暴击
    if is_critical:
        dmg *= 2.0

    return dmg

## 暴击判定
static func roll_critical() -> bool:
    return randf() <= 0.10  # 10%基础暴击率

## 命中判定
static func roll_hit(chance: float) -> bool:
    return randf() <= chance

## 迎击率计算
static func calc_intercept_rate(
    interceptor: ShipCombatData,
    sub_turret_index: int
) -> float:
    var base_rate: float = 0.15
    var focus_val: int = interceptor.focus[sub_turret_index] if sub_turret_index < interceptor.focus.size() else 1

    var rate: float = base_rate + interceptor.intercept_bonus

    # 专注值倍率
    match focus_val:
        3: rate *= 2.0
        2: rate *= 1.5
        1: rate *= 1.0
        0: rate = 0.0

    return clampf(rate, 0.0, 0.95)

## 迎击判定
static func roll_intercept(interceptor: ShipCombatData, sub_turret_index: int) -> bool:
    var rate: float = calc_intercept_rate(interceptor, sub_turret_index)
    if randf() <= rate:
        # 消耗专注值
        if sub_turret_index < interceptor.focus.size():
            interceptor.focus[sub_turret_index] = maxi(0, interceptor.focus[sub_turret_index] - 1)
        return true
    return false

## 过热值累积
static func calc_heat_generation(weapon: WeaponData) -> int:
    return weapon.heat_cost

## 持续伤害（火灾/漏水每回合）
static func calc_status_tick_damage(max_hp: int, effect: StatusEffect) -> int:
    match effect.type:
        StatusEffect.StatusType.FIRE:
            return int(max_hp * 0.10 * effect.severity)
        StatusEffect.StatusType.FLOOD:
            return int(max_hp * 0.05 * effect.severity)
    return 0

## 射程环间移动消耗（机动值%）
static func get_mobility_cost(from_ring: int, to_ring: int) -> int:
    if from_ring == to_ring:
        return 0
    var diff: int = abs(from_ring - to_ring)
    match diff:
        1: return 20
        2: return 40
    return 80

## 追击判定（弱点命中后触发追击）
## 弱点部位：boiler（锅炉）/ helm（操舵室）
static func check_follow_up_attack(damaged_part: String) -> bool:
    return damaged_part in ["boiler", "helm"]

## 追击伤害计算（为基础伤害的50%，不消耗行动）
static func calc_follow_up_damage(base_damage: float) -> float:
    return base_damage * 0.5
