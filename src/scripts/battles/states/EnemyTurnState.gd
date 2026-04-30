extends BattleState

## ENEMY_TURN — 敌方回合（移动+攻击，自动AI）
## 包含赏金首特殊机制：
## - bounty_irontooth_shark: 高攻撞船，策略保持近距离
## - bounty_ghost_queen: 召唤幽灵，策略优先清理小怪
##
## 2026-04-30 增强：
## - 普通敌人AI基于射程环决策（近距攻击/远距接近/中距判断）
## - 行动前延迟动画（0.5~1.0s），提升战斗节奏感
## - 伤害数字浮动文字显示（普通/暴击颜色区分）
## - 状态效果视觉提示（回合开始时图标闪烁）

var _enemy_index: int = 0
var _step: int = 0  # 0=移动 1=攻击
var _timer: float = 0.0
var _waiting_for_animation: bool = false

# 行动延迟配置
const MOVE_DELAY: float = 0.7   # 移动延迟
const ATTACK_DELAY: float = 0.8  # 攻击延迟
const DECISION_DELAY: float = 0.5  # 决策延迟

# 浮动文字场景路径
const FLOATING_TEXT_SCENE: String = "res://src/scripts/ui/FloatingText.gd"

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "ENEMY_TURN"

func enter() -> void:
    _enemy_index = 0
    _step = 0
    _waiting_for_animation = false
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

    # 回合开始：刷新状态效果（执行过期的tick）
    enemy.refresh_for_turn()

    # 赏金首特殊AI
    if _is_bounty_boss(enemy):
        _bounty_boss_ai(enemy)
    else:
        _enemy_ai_decision(enemy)

func _is_bounty_boss(enemy: ShipCombatData) -> bool:
    var ship_id: String = enemy.ship_id if enemy.has("ship_id") else ""
    return "irontooth_shark" in ship_id.to_lower() or "ghost_queen" in ship_id.to_lower()

## ============================================================
## 赏金首 AI 决策
## ============================================================

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

    # 决策延迟动画
    await _add_decision_delay(enemy, "铁牙鲨")

    # 铁牙鲨特殊：优先冲撞到近距离
    var target_ring: int = 1  # 近距
    var cost: int = enemy.get_mobility_cost_to_ring(target_ring)

    if enemy.current_ring > target_ring and cost <= enemy.mobility:
        enemy.move_to_ring(target_ring)
        print("[EnemyTurn] 铁牙鲨冲撞至近距")
        await _add_move_delay(enemy)

    # 选择高伤害武器（冲撞攻击）
    var weapon: WeaponData = _irontooth_choose_weapon(enemy, player)
    if weapon != null:
        # 冲撞攻击目标船体
        var is_hit: bool = true
        var is_crit: bool = CombatCalculator.roll_critical()
        var dmg: float = CombatCalculator.calc_damage(weapon, player, "hull", is_crit)
        player.take_damage(dmg, "hull")
        enemy.damage_dealt += int(dmg)

        print("[EnemyTurn] 铁牙鲨发动冲撞攻击！伤害: " + str(dmg))

        _show_damage_popup(player, dmg, is_crit)

        if tm and tm.has_method("play_enemy_attack_animation"):
            tm.play_enemy_attack_animation(enemy, player, weapon, is_hit, dmg)

        weapon.consume()
        enemy.add_heat(CombatCalculator.calc_heat_generation(weapon))

        await _add_attack_delay(enemy)
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
        if w.weapon_type in [WeaponData.WeaponType.RAM, 4]:  # RAM=4
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

    # 决策延迟
    await _add_decision_delay(enemy, "幽灵女王")

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
                await _add_move_delay(enemy)

        # 策略2：攻击玩家，阻止其接近召唤物
        var weapon: WeaponData = _ghost_queen_choose_weapon(enemy, player, true)
        if weapon != null:
            _enemy_execute_attack(enemy, player, weapon, _ai_choose_part(enemy, player))
            return

    # 策略3：无召唤物或召唤物安全，则召唤新的幽灵
    if tm.has_method("summon_ghost_minion") and _should_summon_ghost(enemy):
        print("[EnemyTurn] 幽灵女王召唤幽灵！")
        _show_status_effect(player, "幽灵女王召唤！", Color(0.5, 0.8, 1.0))
        tm.summon_ghost_minion()
        await _add_decision_delay(enemy, "召唤")

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
        if w.weapon_type in [WeaponData.WeaponType.SPECIAL, 5]:  # SPECIAL=5
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

## ============================================================
## 普通敌人AI（非赏金首）
## 基于射程环的决策逻辑
## ============================================================

func _enemy_ai_decision(enemy: ShipCombatData) -> void:
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_player_ship"):
        _advance_enemy()
        return

    var player: ShipCombatData = tm.get_player_ship()
    if player.check_destruction():
        _all_enemies_done()
        return

    # 状态效果视觉提示
    _show_status_effect_hints(enemy)

    # 决策延迟动画（让玩家看清是谁在行动）
    await _add_decision_delay(enemy, enemy.ship_name if enemy.has("ship_name") else enemy.ship_id)

    # AI策略：评估最佳射程环
    var best_ring: int = _ai_choose_ring(enemy, player)
    var current_ring: int = enemy.current_ring

    print("[EnemyTurn] 敌方 %s 决策: 当前=%d 目标=%d" % [enemy.ship_id, current_ring, best_ring])

    # 移动到最佳射程
    if best_ring != current_ring and enemy.can_move():
        var cost: int = enemy.get_mobility_cost_to_ring(best_ring)
        if cost <= enemy.mobility:
            enemy.move_to_ring(best_ring)
            print("[EnemyTurn] %s 移动至射程环%d（消耗%d机动值）" % [enemy.ship_id, best_ring, cost])
            await _add_move_delay(enemy)
        else:
            print("[EnemyTurn] %s 机动值不足，无法移动" % enemy.ship_id)
            await _add_decision_delay(enemy, "机动不足")

    # 选择武器并攻击
    var weapon: WeaponData = _ai_choose_weapon(enemy, player)
    if weapon != null:
        var target_part: String = _ai_choose_part(enemy, player)
        _enemy_execute_attack(enemy, player, weapon, target_part)
    else:
        # 无可用武器，显示提示并跳过
        _show_status_effect(player, "无法攻击！", Color(0.7, 0.7, 0.7))
        await _add_decision_delay(enemy, "跳过")
        _advance_enemy()

## 根据射程环决定最优目标环
## 决策规则：
## - 近距(1)：敌人贴近，优先攻击
## - 中距(2)：根据血量判断攻/守
## - 远距(3)：尝试接近（如果mobility充足）
func _ai_choose_ring(enemy: ShipCombatData, player: ShipCombatData) -> int:
    var current_ring: int = enemy.current_ring
    var player_ring: int = player.current_ring if player.has("current_ring") else 2

    # 有减速状态 → 保持远距
    if enemy.has_status(StatusEffect.StatusType.SLOW):
        return 3

    # 过热状态 → 撤退远距
    if enemy.has_status(StatusEffect.StatusType.OVERHEAT):
        return 3

    # 根据当前环位决策
    match current_ring:
        1:  # 近距：优先攻击
            # 检查是否有可用武器
            if _has_any_weapon_in_range(enemy, 1):
                return 1  # 留在近距攻击
            else:
                return 2  # 武器不在近距，退至中距

        2:  # 中距：判断攻/守
            var enemy_hp_ratio: float = float(enemy.current_hp) / float(enemy.max_hp) if enemy.max_hp > 0 else 1.0
            var player_hp_ratio: float = float(player.current_hp) / float(player.max_hp) if player.max_hp > 0 else 1.0

            # 敌人血量低 → 撤退远距
            if enemy_hp_ratio < 0.3:
                return 3

            # 玩家血量低 → 冲近距结束战斗
            if player_hp_ratio < 0.3:
                return 1

            # 有远程武器 → 保持中距
            if _has_any_weapon_in_range(enemy, 3) and not _has_any_weapon_in_range(enemy, 1):
                return 2

            # 随机决定（40%近距/40%中距/20%远距）
            var roll: float = randf()
            if roll < 0.4:
                return 1  # 接近
            elif roll < 0.8:
                return 2  # 保持
            else:
                return 3  # 拉开

        3:  # 远距：尝试接近
            # 检查移动力
            var cost_to_2: int = enemy.get_mobility_cost_to_ring(2)
            var cost_to_1: int = enemy.get_mobility_cost_to_ring(1)

            # 优先接近到中距
            if cost_to_2 <= enemy.mobility:
                return 2
            # 如果mobility充足，可尝试冲近距
            elif cost_to_1 <= enemy.mobility and randf() < 0.5:
                return 1
            else:
                return 3  # 留在远距

    return 2  # 默认中距

## 检查是否有任何武器可用于指定环
func _has_any_weapon_in_range(enemy: ShipCombatData, ring: int) -> bool:
    for w: WeaponData in enemy.weapons:
        if w.current_cooldown > 0 or not w.is_loaded:
            continue
        if w.is_in_range(ring):
            return true
    return false

## 选择最优武器（综合伤害+射程）
func _ai_choose_weapon(enemy: ShipCombatData, player: ShipCombatData) -> WeaponData:
    var valid_weapons: Array[WeaponData] = []
    var player_ring: int = player.current_ring if player.has("current_ring") else 2

    for w: WeaponData in enemy.weapons:
        if w.current_cooldown > 0 or not w.is_loaded:
            continue
        if w.is_in_range(player_ring):
            valid_weapons.append(w)

    if valid_weapons.is_empty():
        return null

    # 综合评分：优先高伤害，相同伤害选低冷却
    valid_weapons.sort_custom(func(a, b):
        var score_a: float = a.get_damage_vs(player_ring) / maxf(1.0, a.current_cooldown)
        var score_b: float = b.get_damage_vs(player_ring) / maxf(1.0, b.current_cooldown)
        return score_a > score_b
    )
    return valid_weapons[0]

## 选择攻击部位（根据HP和战略价值）
func _ai_choose_part(enemy: ShipCombatData, player: ShipCombatData) -> String:
    # 检查各部位状态
    var hull_hp: float = player.part_hp.get("hull", 100.0)
    var boiler_hp: float = player.part_hp.get("boiler", 100.0)
    var helm_hp: float = player.part_hp.get("helm", 100.0)
    var special_hp: float = player.part_hp.get("special_device", 100.0)

    # 损坏的部位不再攻击
    if "helm" in player.destroyed_parts:
        helm_hp = 0.0
    if "boiler" in player.destroyed_parts:
        boiler_hp = 0.0
    if "special_device" in player.destroyed_parts:
        special_hp = 0.0

    # 随机权重选择（倾向船体）
    var roll: float = randf()
    var cumulative: float = 0.0

    # 锅炉优先（降低敌人机动）
    if boiler_hp > 0:
        cumulative += 0.25
        if roll < cumulative:
            return "boiler"

    # 操舵室（降低敌人闪避）
    if helm_hp > 0:
        cumulative += 0.15
        if roll < cumulative:
            return "helm"

    # 特殊装置
    if special_hp > 0:
        cumulative += 0.1
        if roll < cumulative:
            return "special_device"

    # 船体（主要伤害来源）
    cumulative += 0.4
    if roll < cumulative:
        return "hull"

    return "hull"

## 执行攻击（含动画延迟+浮动文字）
func _enemy_execute_attack(enemy: ShipCombatData, player: ShipCombatData, weapon: WeaponData, part: String) -> void:
    var tm: Node = get_turn_manager()

    # 命中判定
    var hit_chance: float = CombatCalculator.calc_hit_chance(weapon, enemy.get_speed(), player, part)
    var is_hit: bool = CombatCalculator.roll_hit(hit_chance)

    if is_hit:
        var is_crit: bool = CombatCalculator.roll_critical()
        var dmg: float = CombatCalculator.calc_damage(weapon, player, part, is_crit)
        player.take_damage(dmg, part)
        enemy.damage_dealt += int(dmg)

        # 显示伤害浮动文字
        _show_damage_popup(player, dmg, is_crit)

        if tm and tm.has_method("play_enemy_attack_animation"):
            tm.play_enemy_attack_animation(enemy, player, weapon, is_hit, dmg)
    else:
        # Miss效果
        _show_miss_popup(player)
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

    # 攻击后延迟
    await _add_attack_delay(enemy)
    _advance_enemy()

## ============================================================
## 浮动文字显示
## ============================================================

func _show_damage_popup(target: ShipCombatData, damage: float, is_crit: bool) -> void:
    var screen_pos: Vector2 = _get_ship_screen_position(target)
    _create_floating_text().show_damage(damage, is_crit, screen_pos)

func _show_miss_popup(target: ShipCombatData) -> void:
    var screen_pos: Vector2 = _get_ship_screen_position(target)
    _create_floating_text().show_miss(screen_pos)

func _show_status_effect(target: ShipCombatData, msg: String, color: Color) -> void:
    var screen_pos: Vector2 = _get_ship_screen_position(target)
    _create_floating_text().show_message(msg, color, screen_pos)

func _create_floating_text() -> Node:
    var ft: Node = load(FLOATING_TEXT_SCENE).new()
    return ft

func _get_ship_screen_position(target: ShipCombatData) -> Vector2:
    if target.has("position_2d"):
        # 转换世界坐标到屏幕坐标
        var world_pos: Vector2 = target.position_2d
        var viewport_size: Vector2 = get_viewport_rect().size
        var screen_x: float = world_pos.x * viewport_size.x / 1280.0  # 假设设计分辨率1280
        var screen_y: float = world_pos.y * viewport_size.y / 720.0   # 假设设计分辨率720
        return Vector2(screen_x + randf() * 40 - 20, screen_y + randf() * 40 - 20)
    return Vector2(400 + randf() * 100, 300 + randf() * 100)

## ============================================================
## 状态效果视觉提示
## ============================================================

func _show_status_effect_hints(enemy: ShipCombatData) -> void:
    if enemy.status_effects.is_empty():
        return

    # 获取所有激活的状态效果
    for type in enemy.status_effects.keys():
        var effect: StatusEffect = enemy.status_effects[type]
        if effect.duration_remaining <= 0:
            continue

        var icon: String = _get_status_icon(type)
        var color: Color = _get_status_color(type)
        var name: String = effect.get_display_name()

        print("[EnemyTurn] %s 状态: %s (剩余%d回合)" % [enemy.ship_id, name, effect.duration_remaining])

        # 在敌方位置显示状态效果提示（回合开始闪烁）
        var screen_pos: Vector2 = _get_ship_screen_position(enemy)
        _create_floating_text().show_status(name, color, screen_pos + Vector2(0, -30))

func _get_status_icon(type: StatusEffect.StatusType) -> String:
    match type:
        StatusEffect.StatusType.FIRE:      return "🔥"
        StatusEffect.StatusType.FLOOD:     return "💧"
        StatusEffect.StatusType.SLOW:       return "❄️"
        StatusEffect.StatusType.DISORIENT: return "🌀"
        StatusEffect.StatusType.PARALYSIS: return "⚡"
        StatusEffect.StatusType.OVERHEAT:  return "🌡️"
        StatusEffect.StatusType.STEALTH:   return "👻"
    return "❓"

func _get_status_color(type: StatusEffect.StatusType) -> Color:
    match type:
        StatusEffect.StatusType.FIRE:      return Color(1.0, 0.4, 0.1)
        StatusEffect.StatusType.FLOOD:     return Color(0.3, 0.6, 1.0)
        StatusEffect.StatusType.SLOW:      return Color(0.5, 0.8, 1.0)
        StatusEffect.StatusType.DISORIENT: return Color(0.7, 0.5, 1.0)
        StatusEffect.StatusType.PARALYSIS: return Color(1.0, 0.9, 0.2)
        StatusEffect.StatusType.OVERHEAT:  return Color(1.0, 0.3, 0.0)
        StatusEffect.StatusType.STEALTH:   return Color(0.6, 0.6, 0.8)
    return Color.WHITE

## ============================================================
## 行动延迟动画
## ============================================================

## 决策延迟（显示敌方正在思考）
func _add_decision_delay(enemy: ShipCombatData, action_name: String = "") -> void:
    var delay: float = DECISION_DELAY + randf() * 0.3  # 0.5~0.8s
    print("[EnemyTurn] %s %s ... (等待%.1fs)" % [enemy.ship_id, action_name, delay])
    await get_tree().create_timer(delay).timeout

## 移动延迟
func _add_move_delay(enemy: ShipCombatData) -> void:
    var delay: float = MOVE_DELAY + randf() * 0.4  # 0.7~1.1s
    await get_tree().create_timer(delay).timeout

## 攻击延迟
func _add_attack_delay(enemy: ShipCombatData) -> void:
    var delay: float = ATTACK_DELAY + randf() * 0.4  # 0.8~1.2s
    await get_tree().create_timer(delay).timeout

## ============================================================
## 回合结束
## ============================================================

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
    _waiting_for_animation = false