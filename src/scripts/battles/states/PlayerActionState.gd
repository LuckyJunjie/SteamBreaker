extends BattleState

## PLAYER_ACTION — 玩家选择武器攻击/道具/修理/防御/特殊装置

enum ActionType { ATTACK, ITEM, REPAIR, DEFEND, PARTY_SKILL, SKIP }

var pending_action: Dictionary = {}
var is_waiting: bool = true

signal action_selected(action: Dictionary)
signal action_executed(result: Dictionary)

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "PLAYER_ACTION"

func enter() -> void:
    is_waiting = true
    pending_action.clear()
    print("[PlayerAction] 选择行动（武器/道具/修理/防御/跳过）")
    _show_action_panel()

func _show_action_panel() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_action_panel"):
        tm.show_action_panel(true)

func handle_input(event: InputEvent) -> void:
    if not is_waiting:
        return
    # S键跳过
    if event is InputEventKey and event.pressed and event.keycode == KEY_S:
        _execute_skip()

## ─── 对外暴露的API（供UI按钮调用） ─────────────────────────
func request_attack(weapon_index: int, target_id: String, part: String = "hull") -> void:
    if not is_waiting:
        return
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_player_ship"):
        return

    var ship: ShipCombatData = tm.get_player_ship()
    var weapon: WeaponData = ship.weapons[weapon_index] if weapon_index < ship.weapons.size() else null

    if not weapon:
        _show_error("无可用武器")
        return

    if not _can_use_weapon(weapon, ship):
        _show_error("武器不可用（冷却/过热/超距）")
        return

    pending_action = {
        "type": ActionType.ATTACK,
        "weapon_index": weapon_index,
        "target_id": target_id,
        "part": part
    }
    _execute_attack(weapon_index, target_id, part)

func request_defend() -> void:
    if not is_waiting:
        return
    pending_action = {"type": ActionType.DEFEND}
    _execute_defend()

func request_party_skill(skill_index: int, target_id: String = "") -> void:
    if not is_waiting:
        return
    pending_action = {
        "type": ActionType.PARTY_SKILL,
        "skill_index": skill_index,
        "target_id": target_id
    }
    _execute_party_skill(skill_index, target_id)

func request_skip() -> void:
    if not is_waiting:
        return
    _execute_skip()

## ─── 攻击执行 ─────────────────────────────────────────────
func _execute_attack(weapon_index: int, target_id: String, part: String) -> void:
    is_waiting = false
    var tm: Node = get_turn_manager()
    if not tm:
        _transition_to_enemy_turn()
        return

    var player_ship: ShipCombatData = tm.get_player_ship()
    var enemy: ShipCombatData = tm.get_enemy_by_id(target_id)
    var weapon: WeaponData = player_ship.weapons[weapon_index]

    # 过热值消耗
    player_ship.add_heat(CombatCalculator.calc_heat_generation(weapon))

    # 命中判定
    var hit_chance: float = CombatCalculator.calc_hit_chance(
        weapon, player_ship.get_speed(), enemy, part
    )
    var is_hit: bool = CombatCalculator.roll_hit(hit_chance)

    var result: Dictionary = {
        "weapon_index": weapon_index,
        "target_id": target_id,
        "part": part,
        "hit": is_hit,
        "damage": 0.0,
        "critical": false
    }

    if is_hit:
        var is_crit: bool = CombatCalculator.roll_critical()
        result["critical"] = is_crit
        var dmg: float = CombatCalculator.calc_damage(weapon, enemy, part, is_crit)
        result["damage"] = dmg
        enemy.take_damage(dmg, part)
        player_ship.damage_dealt += int(dmg)
        enemy.damage_taken += int(dmg)

        # 特殊效果处理
        _apply_weapon_special_effects(weapon, enemy, part)
    else:
        _show_miss_effect(enemy)

    # 武器进入冷却
    weapon.consume()
    action_executed.emit(result)

    # 播放命中/未命中动画
    if tm.has_method("play_attack_animation"):
        tm.play_attack_animation(weapon, target_id, is_hit, result.get("damage", 0.0))

    # 迎击判定
    state_machine.set_state("INTERCEPT")

## ─── 防御执行 ─────────────────────────────────────────────
func _execute_defend() -> void:
    is_waiting = false
    print("[PlayerAction] 防御姿态")
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("get_player_ship"):
        var ship: ShipCombatData = tm.get_player_ship()
        # 防御：下回合+15%闪避（通过临时状态实现）
        var defend_eff := StatusEffect.new(StatusEffect.StatusType.NONE, 1, 1, false)
        # 用一个假状态标记防御姿态，CHECK_END时应用
    _transition_to_enemy_turn()

## ─── 伙伴技能 ─────────────────────────────────────────────
func _execute_party_skill(skill_index: int, target_id: String) -> void:
    is_waiting = false
    print("[PlayerAction] 伙伴技能 #%d" % skill_index)
    # 延迟到PARTY_SKILL状态执行
    state_machine.set_state("PARTY_SKILL")

## ─── 跳过 ─────────────────────────────────────────────────
func _execute_skip() -> void:
    is_waiting = false
    print("[PlayerAction] 跳过行动")
    _transition_to_enemy_turn()

## ─── 状态流转 ─────────────────────────────────────────────
func _transition_to_enemy_turn() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_action_panel"):
        tm.show_action_panel(false)
    state_machine.set_state("ENEMY_TURN")

## ─── 武器可用性检查 ───────────────────────────────────────
func _can_use_weapon(weapon: WeaponData, ship: ShipCombatData) -> bool:
    # 过热
    if ship.has_status(StatusEffect.StatusType.OVERHEAT):
        return false
    # 冷却中
    if weapon.current_cooldown > 0:
        return false
    # 未装填
    if not weapon.is_loaded:
        return false
    # 射程检查
    if not weapon.is_in_range(ship.current_ring):
        return false
    # 指定部位武器被摧毁
    return true

## ─── 特殊效果 ─────────────────────────────────────────────
func _apply_weapon_special_effects(weapon: WeaponData, target: ShipCombatData, part: String) -> void:
    for fx: String in weapon.special_effects:
        match fx:
            "fire":
                target.apply_status(StatusEffect.make_fire(2, 1))
            "flood":
                if randf() <= 0.2:
                    target.apply_status(StatusEffect.make_flood(3, 1))
            "slow":
                target.apply_status(StatusEffect.make_slow(3, 1))
            "disorient":
                target.apply_status(StatusEffect.make_disorient(2, 1))

## ─── 辅助 ─────────────────────────────────────────────────
func _show_miss_effect(target: ShipCombatData) -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_miss_effect"):
        tm.show_miss_effect(target)

func _show_error(msg: String) -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_notification"):
        tm.show_notification(msg)

func update(delta: float) -> void:
    pass

func exit() -> void:
    is_waiting = false
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_action_panel"):
        tm.show_action_panel(false)
