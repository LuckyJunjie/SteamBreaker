class_name BattleStateMachine
extends Node

## 战斗状态机 — Godot 4 实现

signal state_changed(from_name: String, to_name: String)
signal state_update(state_name: String, delta: float)

var current_state: BattleState
var states: Dictionary = {}
var battle_manager: Node = null

func _init() -> void:
    pass

func setup(p_battle_manager: Node) -> void:
    battle_manager = p_battle_manager
    _register_states()

func _register_states() -> void:
    states = {
        "TURN_START":       TurnStartState.new(self),
        "PLAYER_MOVE":      PlayerMoveState.new(self),
        "PLAYER_ACTION":    PlayerActionState.new(self),
        "PARTY_SKILL":      PartySkillState.new(self),
        "INTERCEPT":        InterceptState.new(self),
        "ENEMY_TURN":       EnemyTurnState.new(self),
        "DAMAGE_RESOLVE":  DamageResolveState.new(self),
        "STATUS_EFFECT":    StatusEffectState.new(self),
        "CHECK_END":        CheckEndState.new(self),
        "BATTLE_END":       BattleEndState.new(self),
    }

func start() -> void:
    set_state("TURN_START")

func set_state(state_name: String) -> void:
    if not states.has(state_name):
        push_error("[BattleStateMachine] Unknown state: " + state_name)
        return
    var prev: BattleState = current_state
    if prev != null:
        prev.exit()
    current_state = states[state_name]
    if battle_manager:
        current_state.battle_manager = battle_manager
    current_state.enter()
    state_changed.emit(prev.name if prev else "", current_state.name)
    print("[StateMachine] " + (prev.name if prev else "NULL") + " -> " + current_state.name)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.update(delta)
        state_update.emit(current_state.name, delta)

## ─── 基类状态 ───────────────────────────────────────────────
class BattleState:
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
