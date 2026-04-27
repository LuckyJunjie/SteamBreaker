extends Node

## Steam Breaker Game State Autoload
## 全局游戏状态管理器

# ============================================
# Player Info / 玩家信息
# ============================================
@export var player_name: String = "船长"
@export var gold: int = 1000
@export var empire_bonds: int = 0

# ============================================
# Story Progress / 剧情进度
# ============================================
@export var story_progress: int = 0
@export var story_flags: Dictionary = {}  # key-value story flags

# ============================================
# Player Ship / 玩家船只
# ============================================
var player_ship: Node = null

# ============================================
# Current Zone / 当前区域
# ============================================
enum ZoneType { PORT, SEA }
var current_zone: ZoneType = ZoneType.PORT
var current_port_id: String = ""
var current_sea_area: String = ""

# ============================================
# Signals / 信号
# ============================================
signal gold_changed(amount: int, total: int)
signal empire_bonds_changed(amount: int, total: int)
signal story_progress_changed(progress: int)
signal zone_changed(zone: ZoneType, location_id: String)
signal ship_reference_changed(ship: Node)

# ============================================
# Initialization / 初始化
# ============================================

func _ready():
	print("[GameState] Initialized. Player: %s, Gold: %d" % [player_name, gold])

# ============================================
# Gold Management / 金币管理
# ============================================

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(amount, gold)
	print("[GameState] Gold +%d → %d" % [amount, gold])

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(-amount, gold)
		print("[GameState] Gold -%d → %d" % [amount, gold])
		return true
	else:
		print("[GameState] Not enough gold! Need %d, have %d" % [amount, gold])
		return false

func set_gold(amount: int) -> void:
	gold = maxi(0, amount)
	gold_changed.emit(amount - gold, gold)

# ============================================
# Empire Bonds / 帝国债券管理
# ============================================

func add_bonds(amount: int) -> void:
	empire_bonds += amount
	empire_bonds_changed.emit(amount, empire_bonds)
	print("[GameState] Empire Bonds +%d → %d" % [amount, empire_bonds])

func spend_bonds(amount: int) -> bool:
	if empire_bonds >= amount:
		empire_bonds -= amount
		empire_bonds_changed.emit(-amount, empire_bonds)
		return true
	return false

# ============================================
# Story Progress / 剧情进度管理
# ============================================

func advance_story(new_progress: int) -> void:
	story_progress = maxi(story_progress, new_progress)
	story_progress_changed.emit(story_progress)
	print("[GameState] Story progress → %d" % story_progress)

func set_story_flag(key: String, value: Variant) -> void:
	story_flags[key] = value
	print("[GameState] Story flag set: %s = %v" % [key, value])

func get_story_flag(key: String, default: Variant = null) -> Variant:
	return story_flags.get(key, default)

func has_story_flag(key: String) -> bool:
	return story_flags.has(key)

# ============================================
# Ship Management / 船只管理
# ============================================

func set_player_ship(ship: Node) -> void:
	player_ship = ship
	ship_reference_changed.emit(ship)
	print("[GameState] Player ship set: %s" % ship.name if ship else "null")

func get_player_ship() -> Node:
	return player_ship

# ============================================
# Zone Management / 区域管理
# ============================================

func enter_port(port_id: String) -> void:
	current_zone = ZoneType.PORT
	current_port_id = port_id
	current_sea_area = ""
	zone_changed.emit(current_zone, port_id)
	print("[GameState] Entered port: %s" % port_id)

func enter_sea(sea_area: String) -> void:
	current_zone = ZoneType.SEA
	current_port_id = ""
	current_sea_area = sea_area
	zone_changed.emit(current_zone, sea_area)
	print("[GameState] Entered sea area: %s" % sea_area)

func is_at_port() -> bool:
	return current_zone == ZoneType.PORT

func is_at_sea() -> bool:
	return current_zone == ZoneType.SEA

# ============================================
# Save Data Integration / 存档数据集成
# ============================================

func get_save_data() -> Dictionary:
	"""Export current state as dictionary for SaveData."""
	return {
		"player_name": player_name,
		"gold": gold,
		"empire_bonds": empire_bonds,
		"story_progress": story_progress,
		"story_flags": story_flags.duplicate(true),
		"current_zone": current_zone,
		"current_port_id": current_port_id,
		"current_sea_area": current_sea_area,
	}

func apply_save_data(data: Dictionary) -> void:
	"""Apply dictionary data from SaveData."""
	player_name = data.get("player_name", "船长")
	gold = data.get("gold", 1000)
	empire_bonds = data.get("empire_bonds", 0)
	story_progress = data.get("story_progress", 0)
	story_flags = data.get("story_flags", {}).duplicate(true)
	
	var zone: int = data.get("current_zone", ZoneType.PORT)
	current_zone = zone
	current_port_id = data.get("current_port_id", "")
	current_sea_area = data.get("current_sea_area", "")
	
	print("[GameState] Save data applied. Gold=%d, Story=%d" % [gold, story_progress])

func reset() -> void:
	"""Reset to default/new game state."""
	player_name = "船长"
	gold = 1000
	empire_bonds = 0
	story_progress = 0
	story_flags = {}
	current_zone = ZoneType.PORT
	current_port_id = ""
	current_sea_area = ""
	player_ship = null
	print("[GameState] Reset to default state")