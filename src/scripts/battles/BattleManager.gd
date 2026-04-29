class_name BattleManager
extends Node2D

enum Phase { PLAYER_TURN, ENEMY_TURN, ANIMATING, GAME_OVER }

var current_phase: Phase = Phase.PLAYER_TURN
var selected_ship: Node2D = null
var ships: Array[ShipCombatData] = []

# 伤害事件队列（供 DamageResolveState消费）
var _damage_events: Array[Dictionary] = []
# 待处理的抛射体列表
var _pending_projectiles: Array[Dictionary] = []

var _battle_location: String = ""
var _bounty_manager_ref: Node = null

signal phase_changed(phase: Phase)
signal turn_ended()

func _ready():
	print("[BattleManager] Battle initialized")

func _process(delta):
	pass

## ─── 船只管理 ────────────────────────────────────────────────

func get_player_ship() -> ShipCombatData:
	for ship in ships:
		if ship is ShipCombatData and _is_player_ship(ship.ship_id):
			return ship
	return null

func get_enemy_by_id(enemy_id: String) -> ShipCombatData:
	for ship in ships:
		if ship is ShipCombatData and ship.ship_id == enemy_id:
			return ship
	return null

func get_all_ships() -> Array[ShipCombatData]:
	return ships.duplicate()

func AddShip(ship: ShipCombatData) -> void:
	ships.append(ship)
	print("[BattleManager] Ship added: ", ship.ship_id)

func _is_player_ship(ship_id: String) -> bool:
	# 根据ship_id前缀判断是否为玩家船只
	# 约定: player_xxx 为玩家船只
	return ship_id.begins_with("player_") or ship_id.begins_with("Player")

## ─── 伤害事件 ────────────────────────────────────────────────

func add_damage_event(damage: Dictionary) -> void:
	_damage_events.append(damage)
	print("[BattleManager] Damage event added: ", damage.get("target_id", "?"))

func flush_damage_events() -> Array[Dictionary]:
	var events = _damage_events.duplicate()
	_damage_events.clear()
	return events

## ─── 抛射体 ──────────────────────────────────────────────────

func get_pending_projectiles() -> Array[Dictionary]:
	return _pending_projectiles.duplicate()

func clear_pending_projectiles() -> void:
	_pending_projectiles.clear()

## ─── 原有接口（保留兼容）───────────────────────────────────

func StartBattle():
	current_phase = Phase.PLAYER_TURN
	phase_changed.emit(current_phase)
	print("[BattleManager] Battle started")

func EndTurn():
	if current_phase == Phase.PLAYER_TURN:
		current_phase = Phase.ENEMY_TURN
	elif current_phase == Phase.ENEMY_TURN:
		current_phase = Phase.PLAYER_TURN
	phase_changed.emit(current_phase)
	turn_ended.emit()
	print("[BattleManager] Phase: ", Phase.keys()[current_phase])

func SelectShip(ship: Node2D):
	selected_ship = ship
	print("[BattleManager] Selected ship: ", ship.name)

func GetShipsInRange(origin: Vector2, min_range: float, max_range: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for ship in ships:
		var dist: float = origin.distance_to(ship.position_2d)
		if dist >= min_range and dist <= max_range:
			result.append(ship)
	return result

func get_battle_location() -> String:
	return _battle_location

func set_battle_location(loc: String) -> void:
	_battle_location = loc

func get_bounty_manager() -> Node:
	if _bounty_manager_ref:
		return _bounty_manager_ref
	# 查找场景中的 BountyManager
	_bounty_manager_ref = get_tree().get_first_node_in_group("bounty_manager")
	return _bounty_manager_ref

func CheckGameOver() -> bool:
	var player_ships: int = 0
	var enemy_ships: int = 0
	for ship in ships:
		if _is_player_ship(ship.ship_id):
			player_ships += 1
		else:
			enemy_ships += 1
	if player_ships == 0 or enemy_ships == 0:
		current_phase = Phase.GAME_OVER
		phase_changed.emit(current_phase)
		return true
	return false
