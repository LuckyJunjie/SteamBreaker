class_name BattleState
extends RefCounted

var state_machine: BattleStateMachine
var battle_manager: Node = null
var name: String = "Base"

func _init(sm: BattleStateMachine) -> void:
    state_machine = sm

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(delta: float) -> void:
    pass

func handle_input(event: InputEvent) -> void:
    pass

func next_phase() -> void:
    pass

func get_turn_manager() -> Node:
    return state_machine.battle_manager

# 状态本身不挂在场景树上，统一透传到状态机节点。
func get_tree() -> SceneTree:
    return state_machine.get_tree()
