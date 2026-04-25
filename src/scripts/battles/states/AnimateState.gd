extends BattleState

## ANIMATE — 动画结算（用于播放攻击/移动/迎击动画的中间状态）

enum AnimType { ATTACK, MOVE, INTERCEPT, STATUS, SPECIAL }

var _animation_queue: Array[Dictionary] = []
var _current_idx: int = 0
var _waiting: bool = false

signal all_animations_done

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "ANIMATE"

func enter() -> void:
    _current_idx = 0
    _waiting = false
    print("[Animate] 动画结算阶段")
    _play_next()

func queue_animation(type: AnimType, data: Dictionary) -> void:
    _animation_queue.append({"type": type, "data": data, "done": false})

func _play_next() -> void:
    if _current_idx >= _animation_queue.size():
        all_animations_done.emit()
        state_machine.set_state("DAMAGE_RESOLVE")
        return

    var anim: Dictionary = _animation_queue[_current_idx]
    if anim.get("done", false):
        _current_idx += 1
        _play_next()
        return

    _waiting = true
    _execute_animation(anim)

func _execute_animation(anim: Dictionary) -> void:
    var tm: Node = get_turn_manager()
    if not tm:
        _on_animation_complete()
        return

    match anim["type"]:
        AnimType.ATTACK:
            if tm.has_method("play_attack_animation"):
                tm.play_attack_animation(
                    anim["data"].get("weapon"),
                    anim["data"].get("target_id"),
                    anim["data"].get("hit", false),
                    anim["data"].get("damage", 0.0)
                )
        AnimType.MOVE:
            if tm.has_method("play_move_animation"):
                tm.play_move_animation(anim["data"].get("ship_id"), anim["data"].get("from_ring"), anim["data"].get("to_ring"))
        AnimType.INTERCEPT:
            if tm.has_method("show_intercept_effect"):
                tm.show_intercept_effect(anim["data"])

    # 等待动画时长（假设每动画最多2秒）
    await get_tree().create_timer(1.0).timeout
    _on_animation_complete()

func _on_animation_complete() -> void:
    _waiting = false
    _animation_queue[_current_idx]["done"] = true
    _current_idx += 1
    _play_next()

func update(delta: float) -> void:
    pass

func exit() -> void:
    _animation_queue.clear()
    _current_idx = 0
    _waiting = false
