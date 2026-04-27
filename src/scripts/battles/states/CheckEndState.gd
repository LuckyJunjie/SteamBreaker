extends BattleState

## CHECK_END — 胜负判定 & 赏金击杀检查

var _winner: int = -1  # 0=玩家/1=敌方/其他=未分胜负

func _init(sm: BattleStateMachine) -> void:
	super._init(sm)
	name = "CHECK_END"

func enter() -> void:
	print("[CheckEnd] 胜负判定")
	_winner = _evaluate_battle_end()
	
	# 赏金击杀判定（玩家胜利时）
	if _winner == 0:
		_check_bounty_kills()
	
	await get_tree().create_timer(0.3).timeout

	if _winner >= 0:
		state_machine.set_state("BATTLE_END")
	else:
		# 下一回合
		var tm: Node = get_turn_manager()
		if tm and tm.has_method("advance_turn"):
			tm.advance_turn()
		state_machine.set_state("TURN_START")

func _evaluate_battle_end() -> int:
	var tm: Node = get_turn_manager()
	if not tm:
		return -1

	# 检查玩家船只
	var player: ShipCombatData = null
	if tm.has_method("get_player_ship"):
		player = tm.get_player_ship()
	if player and player.check_destruction():
		print("[CheckEnd] 玩家船只沉没")
		return 1  # 敌方胜利

	# 检查敌方船只（任一存活则继续）
	if tm.has_method("get_all_ships"):
		var all_defeated: bool = true
		for ship in tm.get_all_ships():
			if ship is ShipCombatData and not _is_player_ship(ship.ship_id):
				if not ship.check_destruction():
					all_defeated = false
					break
		if all_defeated:
			print("[CheckEnd] 所有敌方被击沉")
			return 0  # 玩家胜利

	return -1  # 继续战斗

func _check_bounty_kills() -> void:
	var tm: Node = get_turn_manager()
	if not tm or not tm.has_method("get_all_ships"):
		return
	
	# 获取所有被击沉的敌方船只ID
	var defeated_enemies: Array[String] = []
	for ship in tm.get_all_ships():
		if ship is ShipCombatData and not _is_player_ship(ship.ship_id):
			if ship.check_destruction():
				defeated_enemies.append(ship.ship_id)
	
	if defeated_enemies.is_empty():
		return
	
	# 获取战斗区域/出生点（从BattleManager获取）
	var battle_location: String = ""
	if tm.has_method("get_battle_location"):
		battle_location = tm.get_battle_location()
	
	# 调用 BountyManager 检查赏金击杀
	var bounty_manager: Node = _get_bounty_manager()
	if bounty_manager and bounty_manager.has_method("check_bounty_kill"):
		for enemy_id in defeated_enemies:
			var killed: bool = bounty_manager.check_bounty_kill(enemy_id, battle_location)
			if killed:
				print("[CheckEnd] 赏金击杀: ", enemy_id)

func _get_bounty_manager() -> Node:
	var tm: Node = get_turn_manager()
	if tm and tm.has_method("get_bounty_manager"):
		return tm.get_bounty_manager()
	# 备用：从场景树查找
	return get_tree().get_first_node_in_group("bounty_manager")

func _is_player_ship(ship_id: String) -> bool:
	return ship_id.begins_with("player_") or ship_id.begins_with("Player")

func update(delta: float) -> void:
	pass

func exit() -> void:
	_winner = -1
