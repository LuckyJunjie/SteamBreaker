class_name BattleStateMachine
extends Node

## 战斗状态机 — Godot 4 实现

signal state_changed(from_name: String, to_name: String)
signal state_update(state_name: String, delta: float)

const TurnStartStateScript = preload("res://scripts/battles/states/TurnStartState.gd")
const PlayerMoveStateScript = preload("res://scripts/battles/states/PlayerMoveState.gd")
const PlayerActionStateScript = preload("res://scripts/battles/states/PlayerActionState.gd")
const PartySkillStateScript = preload("res://scripts/battles/states/PartySkillState.gd")
const InterceptStateScript = preload("res://scripts/battles/states/InterceptState.gd")
const EnemyTurnStateScript = preload("res://scripts/battles/states/EnemyTurnState.gd")
const DamageResolveStateScript = preload("res://scripts/battles/states/DamageResolveState.gd")
const StatusEffectStateScript = preload("res://scripts/battles/states/StatusEffectState.gd")
const CheckEndStateScript = preload("res://scripts/battles/states/CheckEndState.gd")
const BattleEndStateScript = preload("res://scripts/battles/states/BattleEndState.gd")

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
        "TURN_START":      TurnStartStateScript.new(self),
        "PLAYER_MOVE":     PlayerMoveStateScript.new(self),
        "PLAYER_ACTION":   PlayerActionStateScript.new(self),
        "PARTY_SKILL":     PartySkillStateScript.new(self),
        "INTERCEPT":       InterceptStateScript.new(self),
        "ENEMY_TURN":      EnemyTurnStateScript.new(self),
        "DAMAGE_RESOLVE":  DamageResolveStateScript.new(self),
        "STATUS_EFFECT":   StatusEffectStateScript.new(self),
        "CHECK_END":       CheckEndStateScript.new(self),
        "BATTLE_END":      BattleEndStateScript.new(self),
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
