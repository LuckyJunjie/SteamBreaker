extends BattleState

## INTERCEPT — 迎击阶段（副炮自动拦截）

var _pending_projectiles: Array[Dictionary] = []
var _resolved: int = 0
var _total: int = 0

signal intercept_completed(results: Array[Dictionary])

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "INTERCEPT"

func enter() -> void:
    _resolved = 0
    _pending_projectiles.clear()
    print("[Intercept] 迎击阶段开始")

    # 收集本回合的待拦截弹药
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("get_pending_projectiles"):
        _pending_projectiles = tm.get_pending_projectiles()
    _total = _pending_projectiles.size()

    if _total == 0:
        _finish()
        return

    _resolve_next()

func _resolve_next() -> void:
    if _resolved >= _total:
        _finish()
        return

    var proj: Dictionary = _pending_projectiles[_resolved]
    _resolved += 1

    # 执行迎击
    var result: Dictionary = _resolve_intercept(proj)

    # 播放迎击特效
    _play_intercept_effect(result)

    await get_tree().create_timer(0.3).timeout
    _resolve_next()

func _resolve_intercept(proj: Dictionary) -> Dictionary:
    var tm: Node = get_turn_manager()
    if not tm:
        return {"destroyed": false, "proj": proj}

    var result: Dictionary = {"destroyed": false, "proj": proj}

    # 玩家副炮迎击
    var player_ship: ShipCombatData = tm.get_player_ship()
    for i in range(player_ship.focus.size()):
        if player_ship.focus[i] <= 0:
            continue
        if CombatCalculator.roll_intercept(player_ship, i):
            result["destroyed"] = true
            result["intercepted_by_player"] = true
            result["turret_index"] = i
            print("[Intercept] 玩家副炮#%d 拦截成功！" % i)
            return result

    # 敌方副炮迎击
    for enemy: ShipCombatData in tm.get_enemy_ships():
        for i in range(enemy.focus.size()):
            if enemy.focus[i] <= 0:
                continue
            if CombatCalculator.roll_intercept(enemy, i):
                result["destroyed"] = true
                result["intercepted_by_enemy"] = true
                print("[Intercept] 敌方副炮#%d 拦截成功！")
                return result

    return result

func _play_intercept_effect(result: Dictionary) -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_intercept_effect"):
        tm.show_intercept_effect(result)

func _finish() -> void:
    print("[Intercept] 迎击结算完毕")
    intercept_completed.emit(_pending_projectiles)
    state_machine.set_state("DAMAGE_RESOLVE")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _pending_projectiles.clear()
    _resolved = 0
    _total = 0
