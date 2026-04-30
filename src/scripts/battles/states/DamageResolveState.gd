extends BattleState

## DAMAGE_RESOLVE — 伤害结算，更新状态效果

var _damage_queue: Array[Dictionary] = []
var _current_index: int = 0
var _is_processing: bool = false
var _follow_up_triggered: bool = false  # 追击标记，防止重复触发

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "DAMAGE_RESOLVE"

func enter() -> void:
    _current_index = 0
    _damage_queue.clear()
    _follow_up_triggered = false
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

## 检查并执行追击（弱点命中后触发）
func _check_follow_up() -> void:
    if _follow_up_triggered:
        return
    for evt: Dictionary in _damage_queue:
        var part: String = evt.get("part", "")
        if CombatCalculator.check_follow_up_attack(part):
            _execute_follow_up(evt)
            _follow_up_triggered = true
            break

func _execute_follow_up(evt: Dictionary) -> void:
    var tm: Node = get_turn_manager()
    var target_id: String = evt.get("target_id", "")
    var base_dmg: float = evt.get("damage", 0.0)
    var follow_up_dmg: float = CombatCalculator.calc_follow_up_damage(base_dmg)
    print("[DamageResolve] ★追击触发！额外伤害: %.1f（基础: %.1f x 50%%）" % [follow_up_dmg, base_dmg])
    # 添加追击伤害事件
    if tm and tm.has_method("add_damage_event"):
        tm.add_damage_event({
            "source_id": evt.get("source_id", ""),
            "target_id": target_id,
            "damage": follow_up_dmg,
            "weapon": evt.get("weapon"),
            "part": evt.get("part", "hull"),
            "critical": false,
            "is_follow_up": true
        })
    # 播放追击特效（如果有）
    if tm and tm.has_method("play_follow_up_effect"):
        tm.play_follow_up_effect(target_id)

func _finish() -> void:
    # 追击检查（在STATUS_EFFECT前执行）
    _check_follow_up()
    print("[DamageResolve] 伤害结算完毕")
    state_machine.set_state("STATUS_EFFECT")

func update(delta: float) -> void:
    pass

func exit() -> void:
    _damage_queue.clear()
    _current_index = 0
