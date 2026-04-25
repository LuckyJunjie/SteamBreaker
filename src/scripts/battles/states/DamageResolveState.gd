extends BattleState

## DAMAGE_RESOLVE — 伤害结算，更新状态效果

var _damage_queue: Array[Dictionary] = []
var _current_index: int = 0
var _is_processing: bool = false

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "DAMAGE_RESOLVE"

func enter() -> void:
    _current_index = 0
    _damage_queue.clear()
    print("[DamageResolve] 伤害结算开始")
    _collect_damage_events()
    _process_next()

func _collect_damage_events() -> void:
    # 从TurnManager收集本回合的伤害事件
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("flush_damage_events"):
        _damage_queue = tm.flush_damage_events()
    print("[DamageResolve] 待结算伤害事件: %d" % _damage_queue.size())

func _process_next() -> void:
    if _current_index >= _damage_queue.size():
        _finish()
        return

    var evt: Dictionary = _damage_queue[_current_index]
    _current_index += 1
    _apply_damage_event(evt)
    await get_tree().create_timer(0.2).timeout
    _process_next()

func _apply_damage_event(evt: Dictionary) -> void:
    # 播放伤害数字动画
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_damage_popup"):
        var target_id: String = evt.get("target_id", "")
        var dmg: float = evt.get("damage", 0.0)
        var is_crit: bool = evt.get("critical", false)
        tm.show_damage_popup(target_id, dmg, is_crit)

func _finish() -> void:
    print("[DamageResolve] 伤害结算完毕")
    state_machine.set_state("STATUS_EFFECT")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _damage_queue.clear()
    _current_index = 0
