extends BattleState

## BATTLE_END — 战斗结束，弹出结果

var winner: int = -1
var loot: Dictionary = {}

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "BATTLE_END"

func enter() -> void:
    print("[BattleEnd] 战斗结束")

    var tm: Node = get_turn_manager()
    if tm and tm.has_method("get_battle_result"):
        var result: Dictionary = tm.get_battle_result()
        winner = result.get("winner", -1)
        loot = result.get("loot", {})

    # 播放结束动画
    _play_battle_end_animation()

    # 显示结算UI
    _show_battle_end_ui()

    # 通知战斗管理器
    if tm and tm.has_method("on_battle_end"):
        tm.on_battle_end(winner, loot)

    # 关键节点自动存档：战斗胜利时触发
    if winner == 1 and SaveManager and SaveManager.has_method("trigger_auto_save"):
        SaveManager.trigger_auto_save("battle_victory")

func _play_battle_end_animation() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("play_battle_end_animation"):
        tm.play_battle_end_animation(winner)

func _show_battle_end_ui() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_battle_end_ui"):
        tm.show_battle_end_ui(winner, loot)

func update(delta: float) -> void:
    pass

func exit() -> void:
    winner = -1
    loot.clear()
