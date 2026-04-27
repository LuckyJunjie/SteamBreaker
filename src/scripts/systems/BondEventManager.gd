class_name BondEventManager
extends Node

## 羁绊事件管理器
## 检测好感度阈值，触发羁绊剧情任务和奖励发放

signal bond_level_up(companion_id: String, old_level: int, new_level: int)
signal bond_event_triggered(companion_id: String, event_id: String)
signal bond_reward_granted(companion_id: String, reward_type: String, reward_id: String)
signal bond_quest_started(companion_id: String, quest_id: String, quest_name: String)
signal bond_quest_completed(companion_id: String, quest_id: String)

## 好感度阈值（对应羁绊等级）
## 等级0: 0-20, 等级1: 21-40, 等级2: 41-60, 等级3: 61-80, 等级4: 81-100
const AFFECTION_THRESHOLDS: Array[int] = [21, 41, 61, 81]

## 羁绊等级名称
const BOND_LEVEL_NAMES: Array[String] = ["陌生", "相识", "信任", "亲密", "灵魂"]

## 羁绊支线任务定义（示例，基于珂尔莉）
## 结构: companion_id -> bond_level -> { quest_id, quest_name, description, reward_type, reward_id, reward_amount }
var _bond_quests: Dictionary = {
    "companion_keerli": {
        1: {  # 相识(21) -> 信任(41)
            "quest_id": "keerli_ch1",
            "quest_name": "失落的飞行舰队",
            "description": "在某岛发现坠毁的鸟族飞艇残骸，珂尔莉要求调查...",
            "reward_type": "blueprint",
            "reward_id": "part_eagle_eye",
            "reward_amount": 1,
            "affection_reward": 20
        },
        2: {  # 信任(41) -> 亲密(61)
            "quest_id": "keerli_ch2",
            "quest_name": "天空墓场",
            "description": "前往高空浮岛，与叛徒鸟族队长战斗...",
            "reward_type": "skill",
            "reward_id": "skill_storm_eye",
            "reward_amount": 1,
            "affection_reward": 20
        },
        3: {  # 亲密(61) -> 灵魂(81)
            "quest_id": "keerli_ch3",
            "quest_name": "重建天空之翼",
            "description": "珂尔莉决定建立新的飞行队...",
            "reward_type": "skill",
            "reward_id": "skill_final_volley",
            "reward_amount": 1,
            "affection_reward": 20
        }
    },
    "companion_tiechan": {
        1: {
            "quest_id": "tiechan_ch1",
            "quest_name": "锈海寻踪",
            "description": "铁砧在废船坟场发现失踪弟弟的线索...",
            "reward_type": "blueprint",
            "reward_id": "part_reinforced_hull",
            "reward_amount": 1,
            "affection_reward": 20
        },
        2: {
            "quest_id": "tiechan_ch2",
            "quest_name": "机械之心",
            "description": "深入帝国工厂，解救被改造的机械同族...",
            "reward_type": "skill",
            "reward_id": "skill_overdrive",
            "reward_amount": 1,
            "affection_reward": 20
        }
    },
    "companion_shenlan": {
        1: {
            "quest_id": "shenlan_ch1",
            "quest_name": "深渊之声",
            "description": "深蓝感应到海洋深处的古老呼唤...",
            "reward_type": "blueprint",
            "reward_id": "part_deepsonar",
            "reward_amount": 1,
            "affection_reward": 20
        },
        2: {
            "quest_id": "shenlan_ch2",
            "quest_name": "鲸歌与海",
            "description": "与深蓝一同引导搁浅的鲸群回归深海...",
            "reward_type": "skill",
            "reward_id": "skill_whale_call",
            "reward_amount": 1,
            "affection_reward": 20
        }
    }
}

## 已完成的羁绊任务记录  companion_id -> [quest_id, ...]
var _completed_quests: Dictionary = {}

## 已领取的等级奖励记录（防止重复领取）  companion_id -> { level: bool }
var _claimed_rewards: Dictionary = {}

## ---------- 核心API ----------

## 更新好感度，自动检测阈值和触发事件
func update_affection(companion: Companion, delta: int) -> Dictionary:
    var old_level: int = companion.get_bond_level()
    companion.add_affection(delta)
    var new_level: int = companion.get_bond_level()
    var events: Array[Dictionary] = []

    # 检测等级变化
    if new_level > old_level:
        bond_level_up.emit(companion.companion_id, old_level, new_level)
        # 触发等级奖励
        var reward_event: Dictionary = _check_and_grant_level_reward(companion, old_level, new_level)
        if not reward_event.is_empty():
            events.append(reward_event)

    # 检测羁绊支线触发（每次好感度变化后检查）
    var quest_event: Dictionary = _check_quest_trigger(companion)
    if not quest_event.is_empty():
        events.append(quest_event)

    return {
        "new_affection": companion.affection,
        "bond_level": new_level,
        "bond_level_name": companion.get_bond_level_name(),
        "level_changed": new_level > old_level,
        "events": events
    }

## 检测好感度阈值是否达到并触发羁绊支线
func _check_quest_trigger(companion: Companion) -> Dictionary:
    var cid: String = companion.companion_id
    if not _bond_quests.has(cid):
        return {}

    var current_level: int = companion.get_bond_level()
    if current_level < 1:
        return {}

    # 检查当前等级对应的支线任务
    if _bond_quests[cid].has(current_level):
        var quest_def: Dictionary = _bond_quests[cid][current_level]
        var quest_id: String = quest_def["quest_id"]

        # 检查是否已完成或已开始
        if _completed_quests.has(cid) and _completed_quests[cid].has(quest_id):
            return {}  # 已完成
        if companion.story_flags.has("quest_" + quest_id):
            return {}  # 已开始

        # 触发新支线
        companion.story_flags["quest_" + quest_id] = true
        bond_quest_started.emit(cid, quest_id, quest_def["quest_name"])
        bond_event_triggered.emit(cid, "quest_started:" + quest_id)

        return {
            "type": "quest_started",
            "quest_id": quest_id,
            "quest_name": quest_def["quest_name"],
            "description": quest_def["description"]
        }

    return {}

## 等级提升奖励发放
func _check_and_grant_level_reward(companion: Companion, old_level: int, new_level: int) -> Dictionary:
    var cid: String = companion.companion_id

    if not _claimed_rewards.has(cid):
        _claimed_rewards[cid] = {}

    for lvl in range(old_level + 1, new_level + 1):
        if _claimed_rewards[cid].has(lvl):
            continue

        var reward_info: Dictionary = _get_level_reward(companion.companion_id, lvl)
        if not reward_info.is_empty():
            _deliver_reward(companion, reward_info)
            _claimed_rewards[cid][lvl] = true
            return {
                "type": "level_reward",
                "level": lvl,
                "reward_type": reward_info["reward_type"],
                "reward_id": reward_info["reward_id"],
                "message": "羁绊等级提升至「%s」！获得: %s" % [
                    BOND_LEVEL_NAMES[lvl], reward_info["reward_id"]
                ]
            }

    return {}

func _get_level_reward(companion_id: String, level: int) -> Dictionary:
    # 根据羁绊等级定义奖励
    match level:
        1:  # 相识
            return {"reward_type": "skill", "reward_id": "skill_basic_1", "message": "解锁基础技能"}
        2:  # 信任
            return {"reward_type": "blueprint", "reward_id": "blueprint_trust", "message": "获得专属部件蓝图"}
        3:  # 亲密
            return {"reward_type": "skill", "reward_id": "skill_advanced", "message": "解锁高级技能"}
        4:  # 灵魂
            return {"reward_type": "blueprint", "reward_id": "blueprint_ultimate", "message": "获得终极部件"}
    return {}

func _deliver_reward(companion: Companion, reward_info: Dictionary) -> void:
    var rtype: String = reward_info["reward_type"]
    var rid: String = reward_info["reward_id"]
    bond_reward_granted.emit(companion.companion_id, rtype, rid)
    print("[BondEvent] 奖励发放: %s -> %s (%s)" % [companion.name, rid, rtype])

## ---------- 支线任务完成 ----------
## 完成任务时调用此方法，发放好感度和额外奖励
func complete_quest(companion: Companion, quest_id: String) -> Dictionary:
    var cid: String = companion.companion_id
    if not _completed_quests.has(cid):
        _completed_quests[cid] = {}

    if _completed_quests[cid].has(quest_id):
        return {"success": false, "message": "任务已完成"}

    _completed_quests[cid][quest_id] = true

    # 查找任务定义并发放奖励
    var quest_def: Dictionary = _find_quest_def(cid, quest_id)
    var affection_gain: int = quest_def.get("affection_reward", 10)
    var reward_info: Dictionary = {}

    if quest_def.has("reward_type"):
        reward_info = {
            "reward_type": quest_def["reward_type"],
            "reward_id": quest_def["reward_id"],
            "reward_amount": quest_def.get("reward_amount", 1)
        }
        _deliver_reward(companion, reward_info)

    bond_quest_completed.emit(cid, quest_id)

    # 额外好感度奖励
    var old_level: int = companion.get_bond_level()
    companion.add_affection(affection_gain)
    var new_level: int = companion.get_bond_level()

    return {
        "success": true,
        "affection_gain": affection_gain,
        "new_affection": companion.affection,
        "level_changed": new_level > old_level,
        "reward": reward_info
    }

func _find_quest_def(companion_id: String, quest_id: String) -> Dictionary:
    if not _bond_quests.has(companion_id):
        return {}
    for lvl in _bond_quests[companion_id].values():
        if lvl.get("quest_id", "") == quest_id:
            return lvl
    return {}

## ---------- 查询API ----------
func get_bond_quest_status(companion: Companion) -> Dictionary:
    var cid: String = companion.companion_id
    var current_level: int = companion.get_bond_level()
    var available: Array[Dictionary] = []
    var completed: Array[String] = []

    if _completed_quests.has(cid):
        completed = _completed_quests[cid].keys()

    if _bond_quests.has(cid):
        for lvl in _bond_quests[cid].keys():
            if lvl <= current_level:
                var quest: Dictionary = _bond_quests[cid][lvl]
                var qid: String = quest["quest_id"]
                available.append({
                    "quest_id": qid,
                    "quest_name": quest["quest_name"],
                    "completed": completed.has(qid),
                    "level": lvl
                })

    return {
        "current_affection": companion.affection,
        "bond_level": current_level,
        "bond_level_name": companion.get_bond_level_name(),
        "available_quests": available,
        "completed_quests": completed
    }

func is_quest_completed(companion_id: String, quest_id: String) -> bool:
    if _completed_quests.has(companion_id):
        return _completed_quests[companion_id].has(quest_id)
    return false

## 获取指定伙伴当前可接取的支线
func get_current_quest(companion: Companion) -> Dictionary:
    var cid: String = companion.companion_id
    var current_level: int = companion.get_bond_level()
    if current_level < 1 or not _bond_quests.has(cid):
        return {}
    if _bond_quests[cid].has(current_level):
        var quest: Dictionary = _bond_quests[cid][current_level]
        var quest_id: String = quest["quest_id"]
        if is_quest_completed(cid, quest_id):
            return {}
        return quest
    return {}

## ---------- 序列化（存档用） ----------
func get_save_data() -> Dictionary:
    return {
        "completed_quests": _completed_quests,
        "claimed_rewards": _claimed_rewards
    }

func load_save_data(data: Dictionary) -> void:
    _completed_quests = data.get("completed_quests", {})
    _claimed_rewards = data.get("claimed_rewards", {})
