extends BattleState

## STATUS_EFFECT — 状态效果处理（过热门火漏水等）

var _ships_processed: int = 0
var _total_ships: int = 0

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "STATUS_EFFECT"

func enter() -> void:
    _ships_processed = 0
    _total_ships = 0
    print("[StatusEffect] 状态效果处理")
    var tm: Node = get_turn_manager()
    if not tm:
        _finish()
        return

    var ships: Array = []
    if tm.has_method("get_player_ship"):
        var p: ShipCombatData = tm.get_player_ship()
        if p:
            ships.append(p)
    if tm.has_method("get_enemy_ships"):
        ships.append_array(tm.get_enemy_ships())

    _total_ships = ships.size()
    _process_ships(ships)

func _process_ships(ships: Array) -> void:
    for ship: ShipCombatData in ships:
        _process_ship(ship)
    _ships_processed += 1
    if _ships_processed < _total_ships:
        return
    await get_tree().create_timer(0.2).timeout
    _finish()

func _process_ship(ship: ShipCombatData) -> void:
    if ship.check_destruction():
        return

    # 火灾/漏水持续伤害
    for t in ship.status_effects.keys():
        var eff: StatusEffect = ship.status_effects[t]
        var tick_dmg: int = CombatCalculator.calc_status_tick_damage(ship.max_hp, eff)
        if tick_dmg > 0:
            ship.take_damage(float(tick_dmg), "hull")
            _show_status_effect_popup(ship, eff, tick_dmg)

        # 特殊状态效果处理
        match eff.type:
            StatusEffect.StatusType.OVERHEAT:
                # 过热每回合减少持续时间（已在refresh_for_turn处理）
                pass
            StatusEffect.StatusType.PARALYSIS:
                # 瘫痪船只无法行动
                pass
            StatusEffect.StatusType.SLOW:
                # 减速降低50%速度（被动）
                pass
            StatusEffect.StatusType.STEALTH:
                # 隐形被攻击时解除
                pass

    # 自然解除已结束的状态
    _cleanup_expired_effects(ship)

func _cleanup_expired_effects(ship: ShipCombatData) -> void:
    var to_remove: Array[int] = []
    for t in ship.status_effects.keys():
        var eff: StatusEffect = ship.status_effects[t]
        if eff.duration_remaining <= 0:
            to_remove.append(t)
    for t in to_remove:
        ship.status_effects.erase(t)

func _show_status_effect_popup(ship: ShipCombatData, eff: StatusEffect, tick_dmg: int) -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_status_effect_popup"):
        tm.show_status_effect_popup(ship, eff.get_display_name(), tick_dmg)

func _finish() -> void:
    print("[StatusEffect] 状态效果处理完毕")
    state_machine.set_state("CHECK_END")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _ships_processed = 0
    _total_ships = 0
