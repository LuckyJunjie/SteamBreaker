extends BattleState

## ENEMY_TURN — 敌方回合（移动+攻击，自动AI）
## 包含赏金首特殊机制：
## - bounty_irontooth_shark: 高攻撞船，策略保持近距离
## - bounty_ghost_queen: 召唤幽灵，策略优先清理小怪

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

    # 赏金首特殊AI
    if _is_bounty_boss(enemy):
        _bounty_boss_ai(enemy)
    else:
        _enemy_ai_decision(enemy)

func _is_bounty_boss(enemy: ShipCombatData) -> bool:
    var ship_id: String = enemy.ship_id if enemy.has("ship_id") else ""
    return "irontooth_shark" in ship_id.to_lower() or "ghost_queen" in ship_id.to_lower()

## 赏金首 AI 决策
func _bounty_boss_ai(enemy: ShipCombatData) -> void:
    var ship_id: String = enemy.ship_id if enemy.has("ship_id") else ""
    
    if "irontooth_shark" in ship_id.to_lower():
        _irontooth_shark_strategy(enemy)
    elif "ghost_queen" in ship_id.to_lower():
        _ghost_queen_strategy(enemy)
    else:
        _enemy_ai_decision(enemy)

## 「铁牙」独眼鲨 — 高攻撞船，策略：保持近距离
func _irontooth_shark_strategy(enemy: ShipCombatData) -> void:
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_player_ship"):
        _advance_enemy()
        return
    
    var player: ShipCombatData = tm.get_player_ship()
    if player.check_destruction():
        _all_enemies_done()
        return
    
    print("[EnemyTurn] 铁牙鲨 AI 激活 - 保持近距离策略")
    
    # 铁牙鲨特殊：优先冲撞到近距离
    var target_ring: int = 1  # 近距
    var cost: int = enemy.get_mobility_cost_to_ring(target_ring)
    
    if enemy.current_ring > target_ring and cost <= enemy.mobility:
        enemy.move_to_ring(target_ring)
        print("[EnemyTurn] 铁牙鲨冲撞至近距")
        await get_tree().create_timer(0.6).timeout
    
    # 选择高伤害武器（冲撞攻击）
    var weapon: WeaponData = _irontooth_choose_weapon(enemy, player)
    if weapon != null:
        # 冲撞攻击目标船体
        var dmg: float = CombatCalculator.calc_damage(weapon, player, "hull", false)
        player.take_damage(dmg, "hull")
        enemy.damage_dealt += int(dmg)
        
        print("[EnemyTurn] 铁牙鲨发动冲撞攻击！伤害: " + str(dmg))
        
        if tm and tm.has_method("play_enemy_attack_animation"):
            tm.play_enemy_attack_animation(enemy, player, weapon, true, dmg)
        
        weapon.consume()
        enemy.add_heat(CombatCalculator.calc_heat_generation(weapon))
        
        await get_tree().create_timer(0.9).timeout
    else:
        # 无可用武器则普攻
        _enemy_execute_attack(enemy, player, _ai_choose_weapon(enemy, player), "hull")

func _irontooth_choose_weapon(enemy: ShipCombatData, player: ShipCombatData) -> WeaponData:
    # 优先选择铁牙鲨专属重击武器（ram/charge类型）
    var best_weapon: WeaponData = null
    var highest_damage: int = 0
    
    for w: WeaponData in enemy.weapons:
        if w.current_cooldown > 0 or not w.is_loaded:
            continue
        # 冲撞攻击无视距离
        if w.weapon_type in ["ram", "charge"]:
            return w
        if w.damage > highest_damage:
            highest_damage = w.damage
            best_weapon = w
    
    return best_weapon

## 幽灵船「悔恨女王」— 召唤幽灵，策略：优先清理小怪
func _ghost_queen_strategy(enemy: ShipCombatData) -> void:
    var tm: Node = get_turn_manager()
    if not tm:
        _advance_enemy()
        return
    
    print("[EnemyTurn] 幽灵女王 AI 激活 - 优先清理小怪策略")
    
    # 获取场上所有敌人（包括召唤物）
    var all_enemies: Array = []
    if tm.has_method("get_enemy_ships"):
        all_enemies = tm.get_enemy_ships()
    
    # 获取玩家船只
    var player: ShipCombatData = null
    if tm.has_method("get_player_ship"):
        player = tm.get_player_ship()
    
    # 检查是否有召唤的幽灵小怪需要保护
    var has_summoned_ghosts: bool = false
    for e: ShipCombatData in all_enemies:
        if e != enemy and "ghost_minion" in (e.ship_id if e.has("ship_id") else "").to_lower():
            has_summoned_ghosts = true
            break
    
    if has_summoned_ghosts and player and not player.check_destruction():
        # 策略1：玩家接近召唤物时，女王撤退到远距
        var player_ring: int = player.current_ring if player.has("current_ring") else 2
        
        if player_ring <= 2 and enemy.current_ring < 3:
            # 移动到远距保护召唤物
            var cost: int = enemy.get_mobility_cost_to_ring(3)
            if cost <= enemy.mobility:
                enemy.move_to_ring(3)
                print("[EnemyTurn] 幽灵女王撤退至远距")
                await get_tree().create_timer(0.5).timeout
        
        # 策略2：攻击玩家，阻止其接近召唤物
        var weapon: WeaponData = _ghost_queen_choose_weapon(enemy, player, true)
        if weapon != null:
            _enemy_execute_attack(enemy, player, weapon, _ai_choose_part(enemy, player))
            return
    
    # 策略3：无召唤物或召唤物安全，则召唤新的幽灵
    if tm.has_method("summon_ghost_minion") and _should_summon_ghost(enemy):
        print("[EnemyTurn] 幽灵女王召唤幽灵！")
        tm.summon_ghost_minion()
        await get_tree().create_timer(0.5).timeout
    
    # 策略4：攻击玩家
    if player and not player.check_destruction():
        var weapon: WeaponData = _ghost_queen_choose_weapon(enemy, player, false)
        if weapon != null:
            _enemy_execute_attack(enemy, player, weapon, _ai_choose_part(enemy, player))
            return
    
    _advance_enemy()

func _ghost_queen_choose_weapon(enemy: ShipCombatData, player: ShipCombatData, prioritize_range: bool) -> WeaponData:
    var valid_weapons: Array[WeaponData] = []
    
    for w: WeaponData in enemy.weapons:
        if w.current_cooldown > 0 or not w.is_loaded:
            continue
        if prioritize_range and not w.is_in_range(player.current_ring):
            continue
        if w.is_in_range(player.current_ring):
            valid_weapons.append(w)
    
    if valid_weapons.is_empty():
        return null
    
    # 幽灵女王优先使用灵魂攻击（法球类）
    for w: WeaponData in valid_weapons:
        if w.weapon_type in ["spell", "magic", "soul"]:
            return w
    
    # 其次选择远程武器
    valid_weapons.sort_custom(func(a, b): 
        if a.is_in_range(3) and not b.is_in_range(3):
            return true
        return a.damage > b.damage
    )
    return valid_weapons[0]

func _should_summon_ghost(enemy: ShipCombatData) -> bool:
    # 随机30%几率召唤，或当场上幽灵少于2只时必定召唤
    return randf() < 0.3

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