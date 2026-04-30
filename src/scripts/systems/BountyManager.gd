extends Node
class_name BountyManager

## 赏金系统管理器 - 管理所有赏金数据、接取、追踪、击杀判定与奖励发放

signal bounty_accepted(bounty_id: String)
signal bounty_abandoned(bounty_id: String)
signal bounty_completed(bounty_id: String, rewards: Dictionary)
signal bounty_updated()

const BOUNTY_RESOURCE_PATH = "res://resources/bounties/"
const SAVE_PATH = "user://bounty_progress.save"

var _all_bounties: Dictionary = {}       # bounty_id -> Bounty resource
var _active_bounties: Array[String] = [] # 已接取的赏金ID列表
var _completed_bounties: Dictionary = {} # bounty_id -> {defeated_count, first_defeat_time}
var _player_gold: int = 0
var _player_inventory: Array[String] = []

func _ready() -> void:
	print("[BountyManager] Initialized")
	add_to_group("bounty_manager")
	_load_bounty_definitions()
	_load_progress()

## 加载所有赏金定义
func _load_bounty_definitions() -> void:
	_all_bounties.clear()
	var dir := DirAccess.open(BOUNTY_RESOURCE_PATH)
	if not dir:
		push_warning("[BountyManager] Cannot open bounty directory: " + BOUNTY_RESOURCE_PATH)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := BOUNTY_RESOURCE_PATH + file_name
			var bounty = load(path)
			if bounty and bounty.has("bounty_id"):
				_all_bounties[bounty.bounty_id] = bounty
				print("[BountyManager] Loaded bounty: ", bounty.bounty_id)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[BountyManager] Total bounties loaded: ", _all_bounties.size())

## 获取所有可用赏金（未完成且满足条件）
func get_available_bounties() -> Array:
	var result: Array = []
	for bounty_id in _all_bounties:
		var bounty = _all_bounties[bounty_id]
		if _is_bounty_available(bounty):
			result.append(bounty)
	return result

## 获取已接取但未完成的赏金
func get_active_bounties() -> Array:
	var result: Array = []
	for bounty_id in _active_bounties:
		if _all_bounties.has(bounty_id):
			result.append(_all_bounties[bounty_id])
	return result

## 获取已完成的赏金记录
func get_completed_bounties() -> Dictionary:
	return _completed_bounties.duplicate()

## 检查赏金是否满足触发条件
func _is_bounty_available(bounty) -> bool:
	# 已完成的不显示
	if _completed_bounties.has(bounty.bounty_id):
		return false
	# 已接取的不重复显示
	if bounty.bounty_id in _active_bounties:
		return false
	# 检查剧情条件（通过故事标志）
	if bounty.has("required_story_flag") and bounty.required_story_flag != "":
		if not _check_story_flag(bounty.required_story_flag):
			return false
	return true

func _check_story_flag(flag: String) -> bool:
	if flag.is_empty():
		return true
	if not has_node("/root/StoryManager"):
		push_warning("[BountyManager] StoryManager not found, allowing bounty unlock")
		return true
	var sm = get_node("/root/StoryManager")
	return sm.get_flag(flag, false)

## 接取赏金
func accept_bounty(bounty_id: String) -> bool:
	if not _all_bounties.has(bounty_id):
		push_warning("[BountyManager] Unknown bounty: " + bounty_id)
		return false
	
	if bounty_id in _active_bounties:
		print("[BountyManager] Bounty already active: " + bounty_id)
		return false
	
	_active_bounties.append(bounty_id)
	bounty_accepted.emit(bounty_id)
	bounty_updated.emit()
	_save_progress()
	print("[BountyManager] Bounty accepted: " + bounty_id)
	return true

## 放弃赏金
func abandon_bounty(bounty_id: String) -> bool:
	if not bounty_id in _active_bounties:
		return false
	
	_active_bounties.erase(bounty_id)
	bounty_abandoned.emit(bounty_id)
	bounty_updated.emit()
	_save_progress()
	print("[BountyManager] Bounty abandoned: " + bounty_id)
	return true

## 检查击杀是否属于赏金首
func check_bounty_kill(defeated_ship_id: String, spawn_location: String) -> bool:
	# 遍历进行中的赏金，检查是否匹配
	for bounty_id in _active_bounties:
		var bounty = _all_bounties[bounty_id]
		if not bounty:
			continue
		
		# 检查生成位置是否匹配
		if bounty.has("spawn_location") and bounty.spawn_location == spawn_location:
			# 检查特殊机制匹配（通过被击败的敌船ID）
			if _match_bounty_target(bounty, defeated_ship_id):
				_complete_bounty(bounty)
				return true
	
	return false

func _match_bounty_target(bounty, ship_id: String) -> bool:
	# 通过赏金首类型匹配
	var bounty_type = bounty.bounty_id
	match bounty_type:
		"bounty_irontooth_shark":
			return "irontooth_shark" in ship_id.to_lower()
		"bounty_ghost_queen":
			return "ghost_queen" in ship_id.to_lower()
	return false

## 完成赏金，发放奖励
func _complete_bounty(bounty) -> void:
	_active_bounties.erase(bounty.bounty_id)
	
	# 记录完成
	var record: Dictionary = {
		"defeated_count": 1,
		"first_defeat_time": Time.get_unix_time_from_system(),
		"last_defeat_time": Time.get_unix_time_from_system()
	}
	if _completed_bounties.has(bounty.bounty_id):
		record = _completed_bounties[bounty.bounty_id]
		record["defeated_count"] += 1
		record["last_defeat_time"] = Time.get_unix_time_from_system()
	_completed_bounties[bounty.bounty_id] = record
	
	# 发放金币奖励
	var gold_reward: int = bounty.reward_gold if bounty.has("reward_gold") else 0
	_player_gold += gold_reward
	
	# 发放物品奖励
	var items_reward: Array = bounty.reward_items if bounty.has("reward_items") else []
	for item_id in items_reward:
		_player_inventory.append(item_id)
	
	# 发送完成信号
	var rewards: Dictionary = {
		"gold": gold_reward,
		"items": items_reward.duplicate()
	}
	bounty_completed.emit(bounty.bounty_id, rewards)
	bounty_updated.emit()
	_save_progress()
	
	print("[BountyManager] Bounty completed: " + bounty.bounty_id + " | Rewards: " + str(rewards))

## 获取赏金猎人档案统计
func get_bounty_hunter_stats() -> Dictionary:
	var total_defeated: int = 0
	var total_earnings: int = 0
	for record in _completed_bounties.values():
		total_defeated += record.get("defeated_count", 0)
	
	return {
		"total_bounties_completed": _completed_bounties.size(),
		"total_targets_defeated": total_defeated,
		"total_gold_earned": _player_gold,
		"inventory": _player_inventory.duplicate()
	}

## 追踪器：获取活跃赏金的位置提示
func get_bounty_tracker_hints() -> Array[Dictionary]:
	var hints: Array[Dictionary] = []
	for bounty_id in _active_bounties:
		var bounty = _all_bounties[bounty_id]
		if bounty and bounty.has("spawn_location"):
			hints.append({
				"bounty_id": bounty_id,
				"name": bounty.name,
				"location": bounty.spawn_location,
				"difficulty": bounty.rank if bounty.has("rank") else "unknown"
			})
	return hints

## 保存进度到用户目录
func _save_progress() -> void:
	var save_data: Dictionary = {
		"active_bounties": _active_bounties,
		"completed_bounties": _completed_bounties,
		"player_gold": _player_gold,
		"player_inventory": _player_inventory
	}
	var json_str := JSON.stringify(save_data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("[BountyManager] Progress saved")
	else:
		push_warning("[BountyManager] Failed to save progress")

## 加载进度
func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[BountyManager] No save file found, starting fresh")
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[BountyManager] Failed to load progress")
		return
	
	var json_str := file.get_as_text()
	file.close()
	
	var result := JSON.parse_string(json_str)
	if result and typeof(result) == TYPE_DICTIONARY:
		var data: Dictionary = result
		_active_bounties = data.get("active_bounties", [])
		_completed_bounties = data.get("completed_bounties", {})
		_player_gold = data.get("player_gold", 0)
		_player_inventory = data.get("player_inventory", [])
		print("[BountyManager] Progress loaded")
	else:
		push_warning("[BountyManager] Invalid save file format")

## 获取玩家金币
func get_player_gold() -> int:
	return _player_gold

## 获取玩家物品栏
func get_player_inventory() -> Array:
	return _player_inventory.duplicate()

# ============================================
# SaveManager Integration / 存档系统对接
# ============================================

## Get completed bounty IDs for SaveManager
func get_completed_bounty_ids() -> Array[String]:
	return _completed_bounties.keys()

## Get active bounty IDs for SaveManager
func get_active_bounty_ids() -> Array[String]:
	return _active_bounties.duplicate()

## Apply bounty progress from SaveManager
func apply_bounty_progress(completed_ids: Array[String], in_progress_ids: Array[Dictionary]) -> void:
	_completed_bounties.clear()
	_active_bounties.clear()
	
	for bid in completed_ids:
		_completed_bounties[bid] = {
			"defeated_count": 1,
			"first_defeat_time": 0,
			"last_defeat_time": 0,
		}
	
	for d in in_progress_ids:
		var bid: String = d.get("bounty_id", "")
		if bid != "" and not bid in _active_bounties:
			_active_bounties.append(bid)
	
	print("[BountyManager] Applied bounty progress: %d completed, %d in progress" % [
		_completed_bounties.size(), _active_bounties.size()])