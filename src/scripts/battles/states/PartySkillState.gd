extends BattleState

## PARTY_SKILL — 伙伴技能释放

var _skill_executed: bool = false
var _timer: float = 0.0

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "PARTY_SKILL"

func enter() -> void:
    _skill_executed = false
    _timer = 0.0
    print("[PartySkill] 伙伴技能释放阶段")
    _execute_skill()

func _execute_skill() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("execute_party_skill"):
        var result: Dictionary = tm.execute_party_skill()
        # 播放伙伴技能演出
        await get_tree().create_timer(1.2).timeout
    _skill_executed = true
    _transition()

func _transition() -> void:
    state_machine.set_state("INTERCEPT")

func update(delta: float) -> void:
    _timer += delta

func exit() -> void:
    _skill_executed = false
