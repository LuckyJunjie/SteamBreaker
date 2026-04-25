extends BattleState

## TURN_START — 回合开始，初始化回合数据

var _timer: float = 0.0
var _done: bool = false

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "TURN_START"

func enter() -> void:
    _done = false
    _timer = 0.0
    print("[TurnStart] 回合开始初始化")
    # 下帧执行（等待子节点就绪）
    await get_tree().process_frame
    _execute()

func _execute() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("get_player_ship"):
        var ship: ShipCombatData = tm.get_player_ship()
        if ship:
            ship.refresh_for_turn()
            print("[TurnStart] 机动值刷新: %d/%d" % [ship.mobility, ship.max_mobility])

    # 敌方刷新
    var tm2: Node = get_turn_manager()
    if tm2 and tm2.has_method("get_enemy_ships"):
        for enemy in tm2.get_enemy_ships():
            if enemy and enemy.has_method("refresh_for_turn"):
                enemy.refresh_for_turn()

    await get_tree().create_timer(0.3).timeout
    _done = true
    state_machine.set_state("PLAYER_MOVE")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _done = false
