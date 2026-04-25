extends BattleState

## CHECK_END — 胜负判定

var _winner: int = -1  # 0=玩家/1=敌方/其他=未分胜负

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "CHECK_END"

func enter() -> void:
    print("[CheckEnd] 胜负判定")
    _winner = _evaluate_battle_end()
    await get_tree().create_timer(0.3).timeout

    if _winner >= 0:
        state_machine.set_state("BATTLE_END")
    else:
        # 下一回合
        var tm: Node = get_turn_manager()
        if tm and tm.has_method("advance_turn"):
            tm.advance_turn()
        state_machine.set_state("TURN_START")

func _evaluate_battle_end() -> int:
    var tm: Node = get_turn_manager()
    if not tm:
        return -1

    # 检查玩家船只
    if tm.has_method("get_player_ship"):
        var player: ShipCombatData = tm.get_player_ship()
        if player and player.check_destruction():
            print("[CheckEnd] 玩家船只沉没")
            return 1  # 敌方胜利

    # 检查敌方船只
    if tm.has_method("get_enemy_ships"):
        var all_defeated: bool = true
        for enemy: ShipCombatData in tm.get_enemy_ships():
            if enemy and not enemy.check_destruction():
                all_defeated = false
                break
        if all_defeated:
            print("[CheckEnd] 所有敌方被击沉")
            return 0  # 玩家胜利

    return -1  # 继续战斗

func update(delta: float) -> void:
    pass

func exit() -> void:
    _winner = -1
