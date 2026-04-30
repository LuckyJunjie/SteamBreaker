extends Node

## Steam Breaker Companion Manager
## 伙伴管理系统

# ============================================
# Companion Data / 伙伴数据
# ============================================
var _recruited_companions: Dictionary = {}  # companion_id -> CompanionState
var _affection_data: Dictionary = {}         # companion_id -> affection int
var _story_flags: Dictionary = {}            # companion_id -> story_flags dict

# ============================================
# Signals / 信号
# ============================================
signal companion_recruited(companion_id: String)
signal companion_affection_changed(companion_id: String, old_val: int, new_val: int)
signal companion_bond_level_up(companion_id: String, new_level: int)
signal companion_skill_triggered(companion_id: String, skill_id: String, context: String, effect_data: Dictionary)

# ============================================
# Inner Class: CompanionState / 内部类：伙伴状态
# ============================================
class CompanionState:
	var companion_id: String
	var affection: int = 0
	var story_flags: Dictionary = {}
	var skill_ids: Array[String] = []
	var is_recruited: bool = false
	
	func _init(id: String = ""):
		companion_id = id
	
	func get_bond_level() -> int:
		if affection <= 20:  return 0  # 陌生
		elif affection <= 40: return 1 # 相识
		elif affection <= 60: return 2 # 信任
		elif affection <= 80: return 3 # 亲密
		else:                  return 4 # 灵魂
	
	func get_bond_level_name() -> String:
		var levels: Array[String] = ["陌生", "相识", "信任", "亲密", "灵魂"]
		return levels[get_bond_level()]
	
	func to_dict() -> Dictionary:
		return {
			"companion_id": companion_id,
			"affection": affection,
			"story_flags": story_flags.duplicate(true),
			"skill_ids": skill_ids.duplicate(),
			"is_recruited": is_recruited,
		}
	
	static func from_dict(d: Dictionary) -> CompanionState:
		var cs := CompanionState.new(d.get("companion_id", ""))
		cs.affection = d.get("affection", 0)
		cs.story_flags = d.get("story_flags", {}).duplicate(true)
		cs.skill_ids = d.get("skill_ids", []).duplicate()
		cs.is_recruited = d.get("is_recruited", false)
		return cs

# ============================================
# Initialization / 初始化
# ============================================

func _ready():
	print("[CompanionManager] Initialized with %d recruited companions" % _recruited_companions.size())

# ============================================
# Recruit / 招募伙伴
# ============================================

func recruit_companion(companion_id: String) -> bool:
	if _recruited_companions.has(companion_id):
		print("[CompanionManager] %s already recruited" % companion_id)
		return false
	
	var comp_res: Resource = ResourceCache.get_companion(companion_id)
	if not comp_res:
		push_error("[CompanionManager] Companion resource not found: %s" % companion_id)
		return false
	
	var state := CompanionState.new(companion_id)
	state.affection = comp_res.get("affection") if comp_res else 0
	state.story_flags = (comp_res.get("story_flags") if comp_res else {}).duplicate(true)
	state.skill_ids = (comp_res.get("skill_ids") if comp_res else []).duplicate()
	state.is_recruited = true
	
	_recruited_companions[companion_id] = state
	_affection_data[companion_id] = state.affection
	_story_flags[companion_id] = state.story_flags
	
	companion_recruited.emit(companion_id)
	print("[CompanionManager] Recruited: %s (affection=%d)" % [companion_id, state.affection])
	return true

func unrecruit_companion(companion_id: String) -> void:
	if _recruited_companions.has(companion_id):
		_recruited_companions.erase(companion_id)
		_affection_data.erase(companion_id)
		_story_flags.erase(companion_id)
		print("[CompanionManager] Removed: %s" % companion_id)

func is_recruited(companion_id: String) -> bool:
	return _recruited_companions.has(companion_id)

func get_recruited_ids() -> Array[String]:
	return _recruited_companions.keys()

# ============================================
# Affection / 好感度管理
# ============================================

func get_affection(companion_id: String) -> int:
	if _recruited_companions.has(companion_id):
		return _recruited_companions[companion_id].affection
	return 0

func set_affection(companion_id: String, value: int) -> void:
	if not _recruited_companions.has(companion_id):
		return
	var state: CompanionState = _recruited_companions[companion_id]
	var old_val: int = state.affection
	state.affection = clampi(value, 0, 100)
	_affection_data[companion_id] = state.affection
	companion_affection_changed.emit(companion_id, old_val, state.affection)
	print("[CompanionManager] %s affection: %d → %d" % [companion_id, old_val, state.affection])

func add_affection(companion_id: String, amount: int) -> void:
	if not _recruited_companions.has(companion_id):
		return
	var state: CompanionState = _recruited_companions[companion_id]
	var old_level: int = state.get_bond_level()
	set_affection(companion_id, state.affection + amount)
	var new_level: int = state.get_bond_level()
	if new_level > old_level:
		companion_bond_level_up.emit(companion_id, new_level)
		print("[CompanionManager] %s bond level UP to: %s" % [companion_id, state.get_bond_level_name()])

# ============================================
# Bond Level / 羁绊等级
# ============================================

func get_bond_level(companion_id: String) -> int:
	if _recruited_companions.has(companion_id):
		return _recruited_companions[companion_id].get_bond_level()
	return 0

func get_max_bond_level() -> int:
	var max_level := 0
	for companion_id in _recruited_companions.keys():
		var state: CompanionState = _recruited_companions[companion_id]
		max_level = maxi(max_level, state.get_bond_level())
	return max_level

func get_highest_bond_companion_id() -> String:
	var max_level := 0
	var best_id := ""
	for companion_id in _recruited_companions.keys():
		var state: CompanionState = _recruited_companions[companion_id]
		if state.get_bond_level() > max_level:
			max_level = state.get_bond_level()
			best_id = companion_id
	return best_id

func get_bond_level_name(companion_id: String) -> String:
	if _recruited_companions.has(companion_id):
		return _recruited_companions[companion_id].get_bond_level_name()
	return "陌生"

# ============================================
# Gift System / 礼物系统
# ============================================

## Give gift to companion. Returns affection change amount.
## item_id: 物品ID（见 ResourceCache 的 items）
## Returns: 好感度变化值
func give_gift(companion_id: String, item_id: String) -> int:
	if not _recruited_companions.has(companion_id):
		print("[CompanionManager] Cannot give gift: %s not recruited" % companion_id)
		return 0
	
	var comp_res: Resource = ResourceCache.get_companion(companion_id)
	if not comp_res:
		return 0
	
	var likes: Array = comp_res.get("likes") if comp_res else []
	var dislikes: Array = comp_res.get("dislikes") if comp_res else []
	
	var change: int = 0
	if item_id in likes:
		change = randi_range(5, 15)  # 随机+5~+15
	elif item_id in dislikes:
		change = -5
	else:
		change = randi_range(1, 5)  # 中性礼物+1~+5
	
	add_affection(companion_id, change)
	print("[CompanionManager] Gift '%s' to %s → affection %+d" % [item_id, companion_id, change])
	return change

## Check if item is liked by companion
func is_item_liked(companion_id: String, item_id: String) -> bool:
	var comp_res: Resource = ResourceCache.get_companion(companion_id)
	if not comp_res:
		return false
	return item_id in (comp_res.get("likes") if comp_res else [])

## Check if item is disliked by companion
func is_item_disliked(companion_id: String, item_id: String) -> bool:
	var comp_res: Resource = ResourceCache.get_companion(companion_id)
	if not comp_res:
		return false
	return item_id in (comp_res.get("dislikes") if comp_res else [])

# ============================================
# Story Flags / 剧情标志
# ============================================

func set_companion_story_flag(companion_id: String, key: String, value: Variant) -> void:
	if _story_flags.has(companion_id):
		_story_flags[companion_id][key] = value
	if _recruited_companions.has(companion_id):
		_recruited_companions[companion_id].story_flags[key] = value

func get_companion_story_flag(companion_id: String, key: String, default: Variant = null) -> Variant:
	if _story_flags.has(companion_id):
		return _story_flags[companion_id].get(key, default)
	return default

# ============================================
# Skills / 技能管理
# ============================================

func get_companion_skill_ids(companion_id: String) -> Array[String]:
	if _recruited_companions.has(companion_id):
		return _recruited_companions[companion_id].skill_ids.duplicate()
	return []

func get_unlocked_skill_ids(companion_id: String) -> Array[String]:
	if not _recruited_companions.has(companion_id):
		return []
	var state: CompanionState = _recruited_companions[companion_id]
	var level: int = state.get_bond_level()
	# skill_ids[0] unlocks at bond 1, skill_ids[1] at bond 2, etc.
	var unlocked: Array[String] = []
	for i in range(state.skill_ids.size()):
		# bond level 1+ unlocks skill 0, bond 2+ unlocks skill 1...
		if level > i:
			unlocked.append(state.skill_ids[i])
	return unlocked

# ============================================
# Out-of-Battle Skills / 战斗外技能
# ============================================

## 战斗外技能触发
## context: "sailing" | "port" | "exploration"
## 返回: { triggered: bool, companion_id, skill_id, effect_data, message }
func trigger_out_of_battle_skill(skill_id: String, context: String = "sailing") -> Dictionary:
	var result: Dictionary = {
		"triggered": false,
		"skill_id": skill_id,
		"context": context,
		"companion_id": "",
		"effect_data": {},
		"message": ""
	}

	# 查找拥有该技能的伙伴
	var owner_id: String = ""
	for comp_id in _recruited_companions.keys():
		var unlocked: Array[String] = get_unlocked_skill_ids(comp_id)
		if skill_id in unlocked:
			owner_id = comp_id
			break

	if owner_id == "":
		print("[CompanionManager] trigger_out_of_battle_skill: skill '%s' not unlocked by any companion" % skill_id)
		result["message"] = "技能未解锁"
		return result

	# 根据技能类型和场景获取效果
	var effect: Dictionary = _get_out_of_battle_effect(skill_id, context)
	if effect.is_empty():
		print("[CompanionManager] trigger_out_of_battle_skill: no %s effect for skill '%s'" % [context, skill_id])
		result["message"] = "该技能在当前场景无效"
		return result

	result["triggered"] = true
	result["companion_id"] = owner_id
	result["effect_data"] = effect
	result["message"] = effect.get("message", "")

	companion_skill_triggered.emit(owner_id, skill_id, context, effect)
	print("[CompanionManager] Out-of-battle skill triggered: %s (%s) by %s → %s" % [
		skill_id, context, owner_id, result["message"]
	])

	return result


func _get_out_of_battle_effect(skill_id: String, context: String) -> Dictionary:
	var all_effects: Dictionary = _build_out_of_battle_effects_map()
	if not all_effects.has(skill_id):
		return {}
	var ctx_effects: Dictionary = all_effects[skill_id]
	return ctx_effects.get(context, {})


func _build_out_of_battle_effects_map() -> Dictionary:
	return {
		"skill_snipe_helm": {
			"sailing": {
				"message": "珂尔莉发现前方有隐蔽暗礁，及时调整航线！",
				"effect_type": "avoid_damage",
				"value": 50
			},
			"port": {
				"message": "珂尔莉在港口打听消息，获得商店情报。",
				"effect_type": "shop_discount",
				"value": 10
			}
		},
		"skill_eagle_eye": {
			"sailing": {
				"message": "珂尔莉的锐眼发现了隐藏的漂浮物！",
				"effect_type": "discover_hidden",
				"value": 1
			},
			"exploration": {
				"message": "珂尔莉发现了一处隐蔽的洞穴入口！",
				"effect_type": "reveal_area",
				"value": 1
			}
		},
		"skill_overdrive": {
			"port": {
				"message": "铁砧改造了引擎，航行速度提升！",
				"effect_type": "speed_boost",
				"value": 20
			},
			"sailing": {
				"message": "铁砧紧急修复了受损管道！",
				"effect_type": "durability_restore",
				"value": 30
			}
		},
		"skill_reinforce_hull": {
			"sailing": {
				"message": "铁砧提醒：注意前方礁石带！",
				"effect_type": "durability_warning",
				"value": 1
			}
		},
		"skill_whale_call": {
			"sailing": {
				"message": "深蓝引导鲸群护航，减少了遭遇海盗的概率！",
				"effect_type": "reduce_pirate_encounter",
				"value": 30
			},
			"exploration": {
				"message": "深蓝感知到深海中有古老的沉船残骸！",
				"effect_type": "treasure_hunt",
				"value": 1
			}
		},
		"skill_deepsonar": {
			"sailing": {
				"message": "深蓝的声呐探测到附近的洋流变化。",
				"effect_type": "current_warning",
				"value": 1
			},
			"exploration": {
				"message": "深蓝探测到前方有隐藏的洞穴系统！",
				"effect_type": "reveal_area",
				"value": 1
			}
		}
	}

# ============================================
# Companion Info / 伙伴信息
# ============================================

func get_companion_display_info(companion_id: String) -> Dictionary:
	if not _recruited_companions.has(companion_id):
		return {}
	var state: CompanionState = _recruited_companions[companion_id]
	var comp_res: Resource = ResourceCache.get_companion(companion_id)
	return {
		"companion_id": companion_id,
		"name": comp_res.get("name") if comp_res else companion_id if comp_res else companion_id,
		"species": comp_res.get("species") if comp_res else "" if comp_res else "",
		"portrait": comp_res.get("portrait") if comp_res else null,
		"affection": state.affection,
		"bond_level": state.get_bond_level(),
		"bond_level_name": state.get_bond_level_name(),
		"personality": comp_res.get("personality") if comp_res else "" if comp_res else "",
		"is_recruited": state.is_recruited,
	}

func get_all_companions_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for comp_id in _recruited_companions.keys():
		result.append(get_companion_display_info(comp_id))
	return result

# ============================================
# Save Data Integration / 存档数据集成
# ============================================

## Get save data for SaveManager. Returns Array[Dictionary].
func get_save_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for comp_id in _recruited_companions.keys():
		var state: CompanionState = _recruited_companions[comp_id]
		data.append(state.to_dict())
	return data

## Apply save data from SaveManager. Takes Array[Dictionary].
func apply_save_data(data_list: Array[Dictionary]) -> void:
	_recruited_companions.clear()
	_affection_data.clear()
	_story_flags.clear()
	
	for d in data_list:
		var state := CompanionState.from_dict(d)
		_recruited_companions[state.companion_id] = state
		_affection_data[state.companion_id] = state.affection
		_story_flags[state.companion_id] = state.story_flags
	
	print("[CompanionManager] Applied %d companion records from save" % _recruited_companions.size())

# ============================================
# Debug & Reset / 调试与重置
# ============================================

func reset() -> void:
	_recruited_companions.clear()
	_affection_data.clear()
	_story_flags.clear()
	print("[CompanionManager] Reset")