class_name CompanionSkill
extends Node

## 伙伴技能系统
## 管理战斗中伙伴主动技能的释放、士气消耗和技能效果
## 挂在 BattleManager 或作为单例autoload

signal morale_changed(companion_id: String, current: int, maximum: int)
signal skill_used(companion_id: String, skill_id: String, result: Dictionary)
signal skill_cooldown_ready(companion_id: String, skill_id: String)
signal skill_exec_failed(reason: String)

## 每场战斗的士气数据  companion_id -> { morale: int, max_morale: int, skills: Array[Skill] }
var _battle_morale: Dictionary = {}

## 获取/初始化伙伴在战斗中的士气数据
func get_or_init_morale(companion: Companion) -> Dictionary:
    if not _battle_morale.has(companion.companion_id):
        var max_morale: int = companion.base_stats.get("morale_max", 3)
        _battle_morale[companion.companion_id] = {
            "morale": max_morale,
            "max_morale": max_morale,
            "companion": companion,
            "skill_cooldowns": {}  # skill_id -> remaining_cooldown
        }
    return _battle_morale[companion.companion_id]

## 重置所有战斗士气（每场战斗开始时调用）
func reset_battle_morale(companions: Array[Companion]) -> void:
    _battle_morale.clear()
    for c in companions:
        get_or_init_morale(c)

## 伙伴获取士气（击杀敌人/受伤触发）
func gain_morale(companion_id: String, amount: int) -> void:
    if not _battle_morale.has(companion_id):
        return
    var data: Dictionary = _battle_morale[companion_id]
    data["morale"] = mini(data["morale"] + amount, data["max_morale"])
    morale_changed.emit(companion_id, data["morale"], data["max_morale"])

## 获取当前士气
func get_current_morale(companion_id: String) -> int:
    if _battle_morale.has(companion_id):
        return _battle_morale[companion_id]["morale"]
    return 0

func get_max_morale(companion_id: String) -> int:
    if _battle_morale.has(companion_id):
        return _battle_morale[companion_id]["max_morale"]
    return 0

## 伙伴技能是否可释放
func can_use_skill(companion: Companion, skill: Skill) -> bool:
    var data: Dictionary = get_or_init_morale(companion)
    if data["morale"] < skill.mp_cost:
        return false
    var cooldowns: Dictionary = data["skill_cooldowns"]
    if cooldowns.get(skill.skill_id, 0) > 0:
        return false
    return true

## 释放伙伴技能
## 返回结果字典 { success: bool, message: String, effect_data: Dictionary }
func execute_skill(
    companion: Companion,
    skill: Skill,
    player_ship: ShipCombatData,
    enemy_ships: Array[ShipCombatData]
) -> Dictionary:
    var result: Dictionary = {"success": false, "message": "", "effect_data": {}}

    # 消耗士气
    var data: Dictionary = get_or_init_morale(companion)
    if data["morale"] < skill.mp_cost:
        result["message"] = "士气不足，无法释放技能"
        skill_exec_failed.emit(result["message"])
        return result

    data["morale"] -= skill.mp_cost
    morale_changed.emit(companion.companion_id, data["morale"], data["max_morale"])

    # 触发冷却
    data["skill_cooldowns"][skill.skill_id] = skill.cooldown

    # 执行具体技能效果
    var effect_result: Dictionary = _apply_skill_effect(skill, player_ship, enemy_ships)
    result["success"] = true
    result["message"] = "%s 释放了「%s」！" % [companion.name, skill.name]
    result["effect_data"] = effect_result

    skill_used.emit(companion.companion_id, skill.skill_id, effect_result)
    return result

## 根据技能类型执行效果
func _apply_skill_effect(skill: Skill, player_ship: ShipCombatData, enemy_ships: Array[ShipCombatData]) -> Dictionary:
    match skill.effect_type:
        "targeted_attack":
            return _effect_targeted_attack(skill, player_ship, enemy_ships)
        "heal":
            return _effect_heal(skill, player_ship)
        "utility":
            return _effect_utility(skill, player_ship, enemy_ships)
        "buff":
            return _effect_buff(skill, player_ship)
        "debuff":
            return _effect_debuff(skill, enemy_ships)
    return {"type": "none"}

## ---------- 珂尔莉：桅顶狙击 ----------
## 高几率破坏敌方操舵室
func _effect_targeted_attack(skill: Skill, player_ship: ShipCombatData, enemy_ships: Array[ShipCombatData]) -> Dictionary:
    var params: Dictionary = skill.effect_params
    var target_part: String = params.get("target_part", "helm")
    var hit_bonus: int = params.get("hit_bonus", 0)
    var damage_mult: float = params.get("damage_multiplier", 0.8)

    if enemy_ships.is_empty():
        return {"type": "targeted_attack", "hit": false, "reason": "无目标"}

    var target: ShipCombatData = enemy_ships[0]
    # 基础命中60%（操舵室）+ 命中加成
    var hit_rate: float = 0.60 + (hit_bonus * 0.01)
    hit_rate = clampf(hit_rate, 0.05, 0.95)

    var hit: bool = randf() <= hit_rate

    if hit:
        # 计算伤害（基于玩家攻击力 * 伤害倍率）
        var base_damage: float = player_ship.base_speed * 8.0 * damage_mult
        target.take_damage(base_damage, target_part)
        return {
            "type": "targeted_attack",
            "hit": true,
            "target": target.ship_id,
            "part": target_part,
            "damage": base_damage,
            "message": "精准命中敌方操舵室！"
        }
    else:
        return {
            "type": "targeted_attack",
            "hit": false,
            "target": target.ship_id,
            "message": "射击偏出，未命中！"
        }

## ---------- 铁砧：紧急抢修 ----------
## 消耗士气，恢复船体耐久
func _effect_heal(skill: Skill, player_ship: ShipCombatData) -> Dictionary:
    var params: Dictionary = skill.effect_params
    var heal_amount: int = params.get("heal_amount", 300)
    var repair_disable: bool = params.get("repair_disable", false)

    player_ship.heal(heal_amount)

    # 额外修复受损部件（恢复10%）
    var repaired_parts: Array[String] = []
    for part in ["hull", "boiler", "helm", "special_device"]:
        if player_ship.part_hp.has(part):
            var cur: float = player_ship.part_hp[part]
            if cur < 100.0:
                player_ship.part_hp[part] = clampf(cur + 10.0, 0.0, 100.0)
                repaired_parts.append(part)

    return {
        "type": "heal",
        "heal_amount": heal_amount,
        "repaired_parts": repaired_parts,
        "message": "紧急抢修完成，恢复了 %d 点耐久！" % heal_amount
    }

## ---------- 深蓝：洋流牵引 ----------
## 将敌方拉近一个射程环
func _effect_utility(skill: Skill, player_ship: ShipCombatData, enemy_ships: Array[ShipCombatData]) -> Dictionary:
    var params: Dictionary = skill.effect_params
    var pull_rings: int = params.get("pull_rings", 1)

    if enemy_ships.is_empty():
        return {"type": "utility", "pulled": false, "reason": "无目标"}

    var target: ShipCombatData = enemy_ships[0]
    var old_ring: int = target.current_ring
    var new_ring: int = maxi(1, target.current_ring - pull_rings)

    if new_ring == old_ring:
        return {
            "type": "utility",
            "pulled": false,
            "target": target.ship_id,
            "message": "敌方已在最近距，无法再拉近！"
        }

    target.current_ring = new_ring
    # 洋流牵引不消耗敌方机动值
    return {
        "type": "utility",
        "pulled": true,
        "target": target.ship_id,
        "old_ring": old_ring,
        "new_ring": new_ring,
        "message": "深蓝引导洋流，将敌人从 %s 拉向 %s！" % [_ring_name(old_ring), _ring_name(new_ring)]
    }

## ---------- BUFF / DEBUFF ----------
func _effect_buff(skill: Skill, player_ship: ShipCombatData) -> Dictionary:
    return {"type": "buff", "message": "BUFF效果（待实现）"}

func _effect_debuff(skill: Skill, enemy_ships: Array[ShipCombatData]) -> Dictionary:
    return {"type": "debuff", "message": "DEBUFF效果（待实现）"}

## ---------- 回合更新 ----------
func on_turn_start(companion_id: String) -> void:
    if not _battle_morale.has(companion_id):
        return
    var data: Dictionary = _battle_morale[companion_id]
    # 冷却减少
    var cooldowns: Dictionary = data["skill_cooldowns"]
    var ready_skills: Array[String] = []
    for sid in cooldowns.keys():
        cooldowns[sid] = maxi(0, cooldowns[sid] - 1)
        if cooldowns[sid] == 0:
            ready_skills.append(sid)
            skill_cooldown_ready.emit(companion_id, sid)

    # 回复1点士气
    data["morale"] = mini(data["morale"] + 1, data["max_morale"])
    morale_changed.emit(companion_id, data["morale"], data["max_morale"])

## ---------- 辅助 ----------
func _ring_name(ring: int) -> String:
    match ring:
        1: return "近距"
        2: return "中距"
        3: return "远距"
    return "未知"

## 获取伙伴当前可用技能列表
func get_available_skills(companion: Companion) -> Array[Skill]:
    var data: Dictionary = get_or_init_morale(companion)
    var unlocked_ids: Array[String] = companion.get_unlocked_skill_ids()
    var available: Array[Skill] = []
    var cooldowns: Dictionary = data["skill_cooldowns"]

    for sid in unlocked_ids:
        var skill: Skill = load("res://src/resources/skills/skill_%s.tres" % sid)
        if skill == null:
            # 尝试直接加载
            skill = _load_skill_by_id(sid)
        if skill != null:
            if cooldowns.get(sid, 0) == 0:
                available.append(skill)
    return available

func _load_skill_by_id(skill_id: String) -> Skill:
    # 尝试多种路径
    var paths: Array[String] = [
        "res://src/resources/skills/%s.tres" % skill_id,
        "res://resources/skills/%s.tres" % skill_id
    ]
    for p in paths:
        if ResourceLoader.exists(p):
            return load(p)
    return null
