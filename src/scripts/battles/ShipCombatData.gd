class_name ShipCombatData
extends Node

## 战斗中的船只动态数据（与静态 ShipResource 分离）

# 信号
signal hp_changed(current: int, max: int)
signal status_changed(effect: StatusEffect)
signal part_destroyed(part_name: String)
signal ship_destroyed()
signal mobility_changed(current: int, max: int)
signal focus_changed(turret_index: int, current: int, max: int)

# 基础属性
var ship_id: String = ""
var current_hp: int = 100
var max_hp: int = 100
var mobility: int = 10
var max_mobility: int = 10
var focus: Array[int] = [3, 3]  # 每门副炮的专注值

# 位置与状态
var current_ring: int = 2  # 1=近距/2=中距/3=远距
var position_2d: Vector2 = Vector2.ZERO
var facing: float = 0.0  # 度
var base_speed: int = 10  # 基础航速

# 状态效果
var status_effects: Dictionary = {}  # StatusType(int) -> StatusEffect
var overheating_value: int = 0
var overheating_threshold: int = 100
var is_paralyzed: bool = false

# 部件状态 (HP百分比)
var part_hp: Dictionary = {
    "hull": 100.0,
    "boiler": 100.0,
    "helm": 100.0,
    "special_device": 100.0,
    "weapon_slots": []  # 每门武器的HP百分比数组
}

var destroyed_parts: Array[String] = []
var intercept_bonus: float = 0.0  # 来自操舵室加成

# 战斗计数
var turn_in_combat: int = 0
var damage_dealt: int = 0
var damage_taken: int = 0

# 引用的武器数据
var weapons: Array[WeaponData] = []

func _init() -> void:
    pass

## 初始化战斗数据
func setup(
    p_ship_id: String,
    p_max_hp: int,
    p_max_mobility: int,
    p_weapons: Array[WeaponData],
    p_speed: int = 10,
    p_overheat_threshold: int = 100
) -> void:
    ship_id = p_ship_id
    max_hp = p_max_hp
    current_hp = p_max_hp
    max_mobility = p_max_mobility
    mobility = p_max_mobility
    weapons = p_weapons
    base_speed = p_speed
    overheating_threshold = p_overheat_threshold

    # 初始化武器槽HP
    for w in weapons:
        part_hp["weapon_slots"].append(100.0)

    # 默认状态
    current_ring = 2
    status_effects.clear()
    destroyed_parts.clear()
    overheating_value = 0
    is_paralyzed = false
    focus.clear()
    for i in range(weapons.size() if weapons else 1):
        focus.append(3)

## ---------- 伤害处理 ----------
func take_damage(damage: float, part_target: String = "hull") -> void:
    if has_status(StatusEffect.StatusType.STEALTH):
        return  # 隐形状态下无法被命中

    var actual_damage: float = damage

    # 护甲减免
    var armor_val: float = _get_armor_value(part_target)
    var armor_reduction: float = armor_val / (armor_val + 100.0)
    actual_damage *= (1.0 - armor_reduction)

    # 伤害浮动 ±10%
    actual_damage *= randf_range(0.9, 1.1)

    # 部位HP扣除
    if part_target != "hull":
        _damage_part(part_target, actual_damage)

    # 船体HP扣除
    current_hp = maxi(0, current_hp - int(actual_damage))
    hp_changed.emit(current_hp, max_hp)

    if current_hp <= 0:
        ship_destroyed.emit()
    elif part_target != "hull" and part_hp.get(part_target, 100.0) <= 0:
        _handle_part_destruction(part_target)

func _get_armor_value(part: String) -> float:
    if part == "hull":
        return 20.0  # 默认船体护甲
    # 装甲升级可增加此值
    return 10.0

func _damage_part(part: String, amount: float) -> void:
    if part == "weapon_slots":
        return  # 需指定索引
    var current: float = part_hp.get(part, 100.0)
    var reduction = (amount / max_hp) * 100.0
    part_hp[part] = maxi(0.0, current - reduction)

    if part_hp[part] <= 0 and not destroyed_parts.has(part):
        _handle_part_destruction(part)

func _handle_part_destruction(part: String) -> void:
    if destroyed_parts.has(part):
        return
    destroyed_parts.append(part)
    part_destroyed.emit(part)

    match part:
        "helm":
            is_paralyzed = true
            apply_status(StatusEffect.make_paralysis())
        "boiler":
            apply_status(StatusEffect.make_overheat(3, 2))
        "special_device":
            pass  # SE技能禁用

## ---------- 治疗与修理 ----------
func heal(amount: int) -> void:
    current_hp = mini(max_hp, current_hp + amount)
    hp_changed.emit(current_hp, max_hp)

func repair_part(part: String, amount: int) -> void:
    if part == "hull":
        heal(amount)
        return
    var current: float = part_hp.get(part, 0.0)
    part_hp[part] = clampf(current + amount, 0.0, 100.0)

    if destroyed_parts.has(part):
        destroyed_parts.erase(part)
        if part == "helm":
            is_paralyzed = false
            _remove_status_type(StatusEffect.StatusType.PARALYSIS)

## ---------- 状态效果 ----------
func apply_status(effect: StatusEffect) -> void:
    var t: int = effect.type
    if t == StatusEffect.StatusType.NONE:
        return

    # 叠加规则：同类状态不叠加，取最强
    if status_effects.has(t):
        var existing: StatusEffect = status_effects[t]
        if effect.severity > existing.severity:
            effect.duration_remaining = maxi(effect.duration_remaining, existing.duration_remaining)
            status_effects[t] = effect
        elif effect.duration_remaining > existing.duration_remaining:
            status_effects[t] = effect
    else:
        status_effects[t] = effect

    status_changed.emit(effect)

func has_status(type: StatusEffect.StatusType) -> bool:
    return status_effects.has(type)

func get_status(type: StatusEffect.StatusType) -> StatusEffect:
    return status_effects.get(type)

func _remove_status_type(type: StatusEffect.StatusType) -> void:
    status_effects.erase(type)

## 回合开始时刷新状态（过热的tick在其他地方）
func refresh_for_turn() -> void:
    turn_in_combat += 1
    mobility = max_mobility

    # 专注值回复
    for i in range(focus.size()):
        focus[i] = mini(focus[i] + 1, 3)
        focus_changed.emit(i, focus[i], 3)

    # 过热值自然冷却
    overheating_value = maxi(0, overheating_value - 20)

    # 状态效果tick
    var to_remove: Array[int] = []
    for t in status_effects.keys():
        var eff: StatusEffect = status_effects[t]
        if eff.tick():
            to_remove.append(t)
    for t in to_remove:
        status_effects.erase(t)

    # 武器冷却
    for w in weapons:
        w.tick_cooldown()

## ---------- 特殊机制 ----------
func add_heat(amount: int) -> void:
    overheating_value = mini(overheating_value + amount, overheating_threshold)
    if overheating_value >= overheating_threshold:
        apply_status(StatusEffect.make_overheat(2, 1))

func get_speed() -> int:
    var speed: int = base_speed
    if has_status(StatusEffect.StatusType.SLOW):
        speed = int(speed * 0.5)
    return speed

func can_move() -> bool:
    if is_paralyzed:
        return false
    if has_status(StatusEffect.StatusType.OVERHEAT):
        return false
    return true

func check_destruction() -> bool:
    if current_hp <= 0:
        return true
    # 操舵室+锅炉同时被毁
    if destroyed_parts.has("helm") and destroyed_parts.has("boiler"):
        return true
    return false

## ---------- 射程环移动 ----------
func get_mobility_cost_to_ring(target_ring: int) -> int:
    if not can_move():
        return 999
    var diff: int = abs(current_ring - target_ring)
    var costs: Array[int] = [0, 20, 40]
    var cost: int = costs[diff] if diff < costs.size() else 80

    if has_status(StatusEffect.StatusType.OVERHEAT):
        cost *= 2
    return cost

func move_to_ring(target_ring: int) -> bool:
    var cost: int = get_mobility_cost_to_ring(target_ring)
    if cost == 999 or cost > mobility:
        return false
    mobility -= cost
    current_ring = target_ring
    mobility_changed.emit(mobility, max_mobility)
    return true
