extends Node
## GameManager.gd - 游戏主控制器
## 职责：管理当前港口/海域/游戏状态，场景切换，跨系统协调

# === 信号定义 ===
signal current_port_changed(port_id: String)
signal current_sea_area_changed(area_id: String)
signal player_gold_changed(gold: int)
signal game_state_changed(state: String)
signal scene_change_requested(target_scene: String, params: Dictionary)

# === 枚举 ===
enum PlayState { TITLE, WORLD_MAP, PORT, BATTLE, SHOP, TAVERN, SHIP_EDITOR, SAVE_LOAD }
enum SeaArea { RUSTY_BAY, INDUSTRIAL_PORT, PIRATE_COVE, STORM_RIDGE, ABYSSAL_TRENCH, UNKNOWN }

# === 港口定义 ===
const PORTS := {
	"rusty_bay": {
		"name": "铁锈湾",
		"desc": "欢迎来到老船长的避风港",
		"sea_area": "rusty_bay",
		"position": Vector2(180, 280),
		"is_start_port": true,
		"available": true,
		"unlock_conditions": []
	},
	"industrial_port": {
		"name": "工业港",
		"desc": "帝国雷钢技术的中心枢纽",
		"sea_area": "industrial_port",
		"position": Vector2(820, 120),
		"is_start_port": false,
		"available": true,
		"unlock_conditions": []
	},
	"pirate_cove": {
		"name": "海盗港",
		"desc": "无法无天的法外之地",
		"sea_area": "pirate_cove",
		"position": Vector2(1050, 420),
		"is_start_port": false,
		"available": true,
		"unlock_conditions": []
	},
	"storm_ridge": {
		"name": "风暴岭",
		"desc": "雷电交加的危险海域",
		"sea_area": "storm_ridge",
		"position": Vector2(560, 80),
		"is_start_port": false,
		"available": false,
		"unlock_conditions": ["story:chapter_2_complete"]
	},
	"abyssal_trench": {
		"name": "深渊海沟",
		"desc": "传说中有去无回的海域",
		"sea_area": "abyssal_trench",
		"position": Vector2(920, 580),
		"is_start_port": false,
		"available": false,
		"unlock_conditions": ["story:chapter_3_complete"]
	}
}

# === 海域定义 ===
const SEA_AREAS := {
	"rusty_bay": {
		"name": "锈海湾",
		"desc": "蒸汽朋克风格的主城海域",
		"color": Color(0.5, 0.35, 0.2, 0.3),
		"port_id": "rusty_bay",
		"bounty_hints": ["irontooth_shark"],
		"difficulty": 1
	},
	"industrial_port": {
		"name": "工业海峡",
		"desc": "帝国战舰巡逻的工业航道",
		"color": Color(0.4, 0.45, 0.5, 0.3),
		"port_id": "industrial_port",
		"bounty_hints": ["patrol_ironclad"],
		"difficulty": 2
	},
	"pirate_cove": {
		"name": "海盗湾",
		"desc": "臭名昭著的海盗巢穴",
		"color": Color(0.5, 0.2, 0.3, 0.3),
		"port_id": "pirate_cove",
		"bounty_hints": ["ghost_queen"],
		"difficulty": 2
	},
	"storm_ridge": {
		"name": "风暴岭",
		"desc": "雷电交加的死亡海域",
		"color": Color(0.3, 0.3, 0.6, 0.3),
		"port_id": "storm_ridge",
		"bounty_hints": ["thunder_dragon"],
		"difficulty": 3
	},
	"abyssal_trench": {
		"name": "深渊海沟",
		"desc": "伸手不见五指的极深海域",
		"color": Color(0.1, 0.05, 0.15, 0.3),
		"port_id": "abyssal_trench",
		"bounty_hints": ["deep_one"],
		"difficulty": 4
	}
}

# === 玩家状态 ===
var current_state: PlayState = PlayState.WORLD_MAP
var current_port_id: String = "rusty_bay"
var current_sea_area_id: String = "rusty_bay"
var player_gold: int = 5000
var explored_areas: Array[String] = ["rusty_bay"]
var unlocked_ports: Array[String] = ["rusty_bay"]
var player_ship_name: String = "蒸汽破浪号"

# === 伙伴系统 ===
var recruited_companions: Array[Dictionary] = []

# === 随机遭遇 ===
var random_encounter_chance: float = 0.25  # 25% 遭遇概率

func _ready() -> void:
	print("[GameManager] Initialized")
	_add_to_autoload()
	_load_game_data()

func _add_to_autoload() -> void:
	# 确保 GameManager 在 /root 路径下可用
	if not has_node("/root/GameManager"):
		get_tree().root.add_child(self)
		print("[GameManager] Added to scene tree")

# === 港口管理 ===

func get_current_port() -> Dictionary:
	return PORTS.get(current_port_id, {})

func get_port_by_id(port_id: String) -> Dictionary:
	return PORTS.get(port_id, {})

func set_current_port(port_id: String) -> void:
	if PORTS.has(port_id):
		current_port_id = port_id
		current_sea_area_id = PORTS[port_id].get("sea_area", port_id)
		current_port_changed.emit(port_id)
		_unlock_port_area(port_id)
		print("[GameManager] Port changed to: ", port_id)
	else:
		push_warning("[GameManager] Unknown port: " + port_id)

func _unlock_port_area(port_id: String) -> void:
	if not port_id in explored_areas:
		explored_areas.append(port_id)
	if not port_id in unlocked_ports:
		unlocked_ports.append(port_id)
	# 解锁对应海域
	var sea_id = PORTS[port_id].get("sea_area", port_id)
	if not sea_id in explored_areas:
		explored_areas.append(sea_id)

func is_port_unlocked(port_id: String) -> bool:
	return port_id in unlocked_ports

func is_area_explored(area_id: String) -> bool:
	return area_id in explored_areas

# === 海域漫游 ===

func get_current_sea_area() -> Dictionary:
	return SEA_AREAS.get(current_sea_area_id, {})

func set_sea_area(area_id: String) -> void:
	current_sea_area_id = area_id
	current_sea_area_changed.emit(area_id)
	_unlock_area(area_id)
	print("[GameManager] Sea area changed to: ", area_id)

func _unlock_area(area_id: String) -> void:
	if not area_id in explored_areas:
		explored_areas.append(area_id)

func get_ship_position() -> Vector2:
	# 根据当前海域返回船只在世界地图上的位置
	var port_data = PORTS.get(current_port_id, {})
	if port_data:
		return port_data.get("position", Vector2(180, 280))
	return Vector2(180, 280)

# === 随机遭遇判定 ===

func roll_sea_encounter() -> Dictionary:
	"""
	在海域航行时进行随机遭遇判定
	返回遭遇类型和详细信息
	"""
	if not is_area_explored(current_sea_area_id):
		return {"type": "none", "desc": "未探索海域，无法遭遇"}
	
	var roll = randf()
	if roll > random_encounter_chance:
		return {"type": "none", "desc": "海面平静，继续航行"}
	
	# 遭遇类型随机
	var encounter_types = ["merchant", "enemy_ship", "bounty_target", "treasure", "storm"]
	var type = encounter_types[randi() % encounter_types.size()]
	
	match type:
		"merchant":
			return {
				"type": "merchant",
				"desc": "一艘商船缓缓靠近...",
				"bounty_hint": null,
				"difficulty": 0
			}
		"enemy_ship":
			return {
				"type": "enemy_ship",
				"desc": "前方发现敌舰！准备战斗！",
				"bounty_hint": null,
				"difficulty": 1
			}
		"bounty_target":
			var hints = SEA_AREAS.get(current_sea_area_id, {}).get("bounty_hints", [])
			if not hints.is_empty():
				return {
					"type": "bounty_target",
					"desc": "悬赏目标出现！",
					"bounty_hint": hints[randi() % hints.size()],
					"difficulty": 2
				}
			return {"type": "none", "desc": "海面平静"}
		"treasure":
			return {
				"type": "treasure",
				"desc": "发现一个漂浮的宝箱！",
				"gold_bonus": randi() % 500 + 100,
				"difficulty": 0
			}
		"storm":
			return {
				"type": "storm",
				"desc": "突如其来的暴风雨！",
				"difficulty": 3
			}
	
	return {"type": "none", "desc": "海面平静"}

# === 赏金追踪 ===

func get_bounty_tracker_hints() -> Array[Dictionary]:
	"""
	返回当前进行中赏金的位置提示
	"""
	var hints: Array[Dictionary] = []
	var bounty_manager = _get_bounty_manager()
	if bounty_manager and bounty_manager.has_method("get_bounty_tracker_hints"):
		hints = bounty_manager.get_bounty_tracker_hints()
	return hints

func _get_bounty_manager() -> Node:
	if has_node("/root/BattleManager"):
		var bm = get_node("/root/BattleManager")
		if bm.has_method("get_bounty_manager"):
			return bm.get_bounty_manager()
	if has_node("/root/BountyManager"):
		return get_node("/root/BountyManager")
	return null

# === 伙伴系统 ===

func recruit_companion(comp_data) -> void:
	print("[GameManager] Recruiting companion: ", comp_data.get("name", "?"))
	recruited_companions.append(comp_data)

func get_recruited_companions() -> Array:
	return recruited_companions.duplicate()

# === 金币管理 ===

func add_gold(amount: int) -> void:
	player_gold += amount
	player_gold_changed.emit(player_gold)
	print("[GameManager] Gold added: ", amount, " | Total: ", player_gold)

func spend_gold(amount: int) -> bool:
	if player_gold >= amount:
		player_gold -= amount
		player_gold_changed.emit(player_gold)
		return true
	else:
		print("[GameManager] Not enough gold: need ", amount, " have ", player_gold)
		return false

func get_player_gold() -> int:
	return player_gold

# === 物品管理 ===

var player_inventory: Array[Dictionary] = []

func buy_item(item: Dictionary) -> bool:
	var price = item.get("price", 0)
	if spend_gold(price):
		player_inventory.append(item.duplicate())
		print("[GameManager] Bought item: ", item.get("name", "?"))
		return true
	return false

func get_inventory() -> Array:
	return player_inventory.duplicate()

# === 场景切换 ===

func change_scene_to_port(port_id: String) -> void:
	set_current_port(port_id)
	scene_change_requested.emit("port", {"port_id": port_id})
	_change_to_scene("res://scenes/worlds/PortScene.tscn")

func change_scene_to_world_map() -> void:
	current_state = PlayState.WORLD_MAP
	scene_change_requested.emit("world_map", {})
	_change_to_scene("res://scenes/worlds/WorldMap.tscn")

func change_scene_to_battle(encounter_data: Dictionary) -> void:
	current_state = PlayState.BATTLE
	# 存储 encounter_data 到 GameState，供 BattleManager 初始化使用
	GameState.battle_encounter_data = encounter_data
	scene_change_requested.emit("battle", encounter_data)
	_change_to_scene("res://scenes/battles/Battle.tscn")

func _change_to_scene(scene_path: String) -> void:
	print("[GameManager] Loading scene: ", scene_path)
	var tree = get_tree()
	if tree:
		var error = tree.change_scene_to_file(scene_path)
		if error != OK:
			push_error("[GameManager] Failed to change scene to: " + scene_path + " | Error: " + str(error))
		else:
			print("[GameManager] Scene changed successfully")

# === 起航逻辑 ===

func depart_from_port() -> void:
	"""
	从港口起航，返回世界地图
	"""
	print("[GameManager] Departing from port: ", current_port_id)
	change_scene_to_world_map()

func sail_to_port(port_id: String) -> void:
	"""
	从世界地图航行到指定港口
	"""
	if not is_port_unlocked(port_id):
		print("[GameManager] Port not unlocked: ", port_id)
		return
	
	print("[GameManager] Sailing to port: ", port_id)
	set_current_port(port_id)
	
	# 航行过程中可能有随机遭遇
	var encounter = roll_sea_encounter()
	
	if encounter.get("type") == "none":
		# 无遭遇，直接进入港口
		change_scene_to_port(port_id)
	elif encounter.get("type") in ["enemy_ship", "bounty_target", "storm"]:
		# 战斗相关遭遇
		change_scene_to_battle(encounter)
	else:
		# 其他遭遇类型（商船/宝箱），简单处理直接进港
		change_scene_to_port(port_id)

func sail_to_sea_area(area_id: String) -> void:
	"""
	在世界地图上选择航行到某海域（无港口）
	"""
	if not is_area_explored(area_id):
		print("[GameManager] Area not explored: ", area_id)
		return
	
	print("[GameManager] Sailing to sea area: ", area_id)
	var encounter = roll_sea_encounter()
	
	if encounter.get("type") == "none":
		set_sea_area(area_id)
		change_scene_to_world_map()
	elif encounter.get("type") in ["enemy_ship", "bounty_target", "storm"]:
		set_sea_area(area_id)
		change_scene_to_battle(encounter)
	else:
		set_sea_area(area_id)
		change_scene_to_world_map()

# === 存档/加载 ===

func _load_game_data() -> void:
	# 尝试从 SaveManager 加载已保存的数据
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.has_method("get_current_save"):
			var data = sm.get_current_save()
			if data:
				_apply_save_data(data)

func _apply_save_data(data) -> void:
	if data.has("player_gold"):
		player_gold = data.get("player_gold", 5000)
	if data.has("explored_areas"):
		explored_areas = data.get("explored_areas", ["rusty_bay"])
	if data.has("unlocked_ports"):
		unlocked_ports = data.get("unlocked_ports", ["rusty_bay"])
	if data.has("current_port_id"):
		current_port_id = data.get("current_port_id", "rusty_bay")
	print("[GameManager] Game data loaded")

# === 状态查询 ===

func is_in_port() -> bool:
	return current_state == PlayState.PORT

func is_on_world_map() -> bool:
	return current_state == PlayState.WORLD_MAP

func get_game_state() -> PlayState:
	return current_state

func get_save_dict() -> Dictionary:
	return {
		"player_gold": player_gold,
		"explored_areas": explored_areas,
		"unlocked_ports": unlocked_ports,
		"current_port_id": current_port_id,
		"current_sea_area_id": current_sea_area_id,
		"player_ship_name": player_ship_name,
		"recruited_companions": recruited_companions,
		"inventory": player_inventory
	}
