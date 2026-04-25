extends BattleState

## ENEMY_TURN — 敌方回合（移动+攻击，自动AI）

var _enemy_index: int = 0
var _step: int = 0  # 0=移动 1=攻击
var _timer: float = 0.0
var _waiting_for_animation: bool = false

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "ENEMY_TURN"

func enter() -> void:
    _enemy_index = 0
    _step = 0
    print("[EnemyTurn] 敌方回合开始")
    _process_next_enemy()

func _process_next_enemy() -> void:
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_enemy_ships"):
        _all_enemies_done()
        return

    var enemies: Array = tm.get_enemy_ships()
    if _enemy_index >= enemies.size():
        _all_enemies_done()
        return

    var enemy: ShipCombatData = enemies[_enemy_index]
    if not enemy or enemy.check_destruction():
        _enemy_index += 1
        _process_next_enemy()
        return

    # 敌方AI决策
    _enemy_ai_decision(enemy)

func _enemy_ai_decision(enemy: ShipCombatData) -> void:
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_player_ship"):
        _advance_enemy()
        return

    var player: ShipCombatData = tm.get_player_ship()
    if player.check_destruction():
        _all_enemies_done()
        return

    # AI策略：评估最佳射程环
    var best_ring: int = _ai_choose_ring(enemy, player)

    # 移动到最佳射程
    if best_ring != enemy.current_ring and enemy.can_move():
        var cost: int = enemy.get_mobility_cost_to_ring(best_ring)
        if cost <= enemy.mobility:
            enemy.move_to_ring(best_ring)
            await get_tree().create_timer(0.5).timeout

    # 选择武器并攻击
    var weapon: WeaponData = _ai_choose_weapon(enemy, player)
    if weapon != null:
        var target_part: String = _ai_choose_part(enemy, player)
        _enemy_execute_attack(enemy, player, weapon, target_part)
    else:
        await get_tree().create_timer(0.4).timeout
        _advance_enemy()

func _ai_choose_ring(enemy: ShipCombatData, player: ShipCombatData) -> int:
    # 简单AI：保持中距，倾向远距
    if enemy.has_status(StatusEffect.StatusType.SLOW):
        return 3  # 减速时保持远距
    var roll: float = randf()
    if roll < 0.4:
        return 2  # 中距 40%
    elif roll < 0.8:
        return 3  # 远距 40%
    else:
        return 1  # 近距 20%

func _ai_choose_weapon(enemy: ShipCombatData, player: ShipCombatData) -> WeaponData:
    var valid_weapons: Array[WeaponData] = []
    for w: WeaponData in enemy.weapons:
        if w.current_cooldown > 0 or not w.is_loaded:
            continue
        if w.is_in_range(player.current_ring):
            valid_weapons.append(w)
    if valid_weapons.is_empty():
        return null
    # 优先选择伤害最高的可用武器
    valid_weapons.sort_custom(func(a, b): return a.damage > b.damage)
    return valid_weapons[0]

func _ai_choose_part(enemy: ShipCombatData, player: ShipCombatData) -> String:
    # 简单AI：随机部位，倾向船体
    var roll: float = randf()
    if roll < 0.6:
        return "hull"
    elif roll < 0.75:
        return "boiler"
    elif roll < 0.85:
        return "helm"
    elif roll < 0.95:
        return "weapon_slot"
    else:
        return "special_device"

func _enemy_execute_attack(enemy: ShipCombatData, player: ShipCombatData, weapon: WeaponData, part: String) -> void:
    var tm: Node = get_turn_manager()
    var hit_chance: float = CombatCalculator.calc_hit_chance(weapon, enemy.get_speed(), player, part)
    var is_hit: bool = CombatCalculator.roll_hit(hit_chance)

    if is_hit:
        var is_crit: bool = CombatCalculator.roll_critical()
        var dmg: float = CombatCalculator.calc_damage(weapon, player, part, is_crit)
        player.take_damage(dmg, part)
        enemy.damage_dealt += int(dmg)
        if tm and tm.has_method("play_enemy_attack_animation"):
            tm.play_enemy_attack_animation(enemy, player, weapon, is_hit, dmg)
    else:
        if tm and tm.has_method("show_miss_effect"):
            tm.show_miss_effect(player)

    weapon.consume()
    enemy.add_heat(CombatCalculator.calc_heat_generation(weapon))

    # 将弹药加入待拦截列表
    if tm and tm.has_method("add_pending_projectile"):
        tm.add_pending_projectile({
            "from": enemy.ship_id,
            "to": player.ship_id,
            "weapon": weapon,
            "hit": is_hit
        })

    await get_tree().create_timer(0.8).timeout
    _advance_enemy()

func _advance_enemy() -> void:
    _enemy_index += 1
    _process_next_enemy()

func _all_enemies_done() -> void:
    print("[EnemyTurn] 所有敌方行动完毕")
    state_machine.set_state("DAMAGE_RESOLVE")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _enemy_index = 0
    _step = 0
