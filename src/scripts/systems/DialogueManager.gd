class_name DialogueManager
extends Node

## 对话系统管理器
## 支持分支对话选项，正确/错误选项影响伙伴好感度

signal dialogue_started(companion_id: String, dialogue_id: String)
signal dialogue_option_selected(companion_id: String, option_index: int, option_text: String)
signal dialogue_ended(companion_id: String, dialogue_id: String, affection_delta: int)
signal dialogue_reward_ready(reward_type: String, reward_id: String, amount: int)

## 对话数据结构
## dialogue_id -> {
##   companion_id: String,
##   text: String,           # 初始对话文本
##   mood: String,            # 角色情绪 neutral/happy/angry/sad
##   options: Array[Dictionary],  # 选项列表
##     { text, affection_delta, is_correct, reward }
## }

var _dialogue_library: Dictionary = {}
var _active_dialogue: Dictionary = {}
var _current_companion: Companion = null

## 当前显示的对话选项UI节点（由外部HUD/UI创建）
var _option_buttons: Array[Button] = []

## 对话预定义库（示例）
func _ready() -> void:
    _init_dialogue_library()

## ---------- 核心API ----------

## 开始一段对话
func start_dialogue(companion: Companion, dialogue_id: String = "") -> Dictionary:
    _current_companion = companion

    # 如果未指定ID，尝试获取当前好感度对应的默认对话
    if dialogue_id == "":
        dialogue_id = _get_default_dialogue_id(companion)

    if not _dialogue_library.has(dialogue_id):
        dialogue_id = _get_fallback_dialogue_id(companion)

    _active_dialogue = _dialogue_library[dialogue_id].duplicate(true)
    _active_dialogue["dialogue_id"] = dialogue_id
    dialogue_started.emit(companion.companion_id, dialogue_id)

    return _build_dialogue_data(_active_dialogue)

## 获取当前对话的完整数据
func get_current_dialogue() -> Dictionary:
    return _build_dialogue_data(_active_dialogue)

func _build_dialogue_data(dlg: Dictionary) -> Dictionary:
    return {
        "companion_id": dlg.get("companion_id", ""),
        "dialogue_id": dlg.get("dialogue_id", ""),
        "speaker_name": dlg.get("speaker_name", ""),
        "text": dlg.get("text", ""),
        "mood": dlg.get("mood", "neutral"),
        "options": dlg.get("options", []),
        "has_options": not dlg.get("options", []).is_empty()
    }

## 选择对话选项
func select_option(option_index: int) -> Dictionary:
    if _active_dialogue.is_empty() or _current_companion == null:
        return {"success": false, "message": "无进行中的对话"}

    var options: Array = _active_dialogue.get("options", [])
    if option_index < 0 or option_index >= options.size():
        return {"success": false, "message": "无效选项"}

    var option: Dictionary = options[option_index]
    var option_text: String = option.get("text", "")
    var affection_delta: int = option.get("affection_delta", 0)
    var reward: Dictionary = option.get("reward", {})

    dialogue_option_selected.emit(_current_companion.companion_id, option_index, option_text)

    # 应用好感度变化
    var old_affection: int = _current_companion.affection
    _current_companion.add_affection(affection_delta)
    var new_affection: int = _current_companion.affection

    # 发放奖励（如果有）
    if not reward.is_empty():
        dialogue_reward_ready.emit(reward.get("type", "item"), reward.get("id", ""), reward.get("amount", 1))

    # 处理后续对话分支
    var next_dialogue_id: String = option.get("next_dialogue", "")
    var next_data: Dictionary = {}
    if next_dialogue_id != "" and _dialogue_library.has(next_dialogue_id):
        _active_dialogue = _dialogue_library[next_dialogue_id].duplicate(true)
        _active_dialogue["dialogue_id"] = next_dialogue_id
        next_data = _build_dialogue_data(_active_dialogue)
    else:
        # 结束对话
        next_data = _end_dialogue()

    dialogue_ended.emit(_current_companion.companion_id, _active_dialogue.get("dialogue_id", ""), affection_delta)

    return {
        "success": true,
        "option_text": option_text,
        "affection_delta": affection_delta,
        "old_affection": old_affection,
        "new_affection": new_affection,
        "is_correct": option.get("is_correct", false),
        "reward": reward,
        "next": next_data
    }

## 结束当前对话
func _end_dialogue() -> Dictionary:
    var cid: String = _current_companion.companion_id if _current_companion else ""
    var did: String = _active_dialogue.get("dialogue_id", "") if not _active_dialogue.is_empty() else ""
    var result: Dictionary = {
        "ended": true,
        "companion_id": cid,
        "dialogue_id": did
    }
    _active_dialogue = {}
    _current_companion = null
    return result

## 跳过/关闭对话（不产生好感度变化）
func skip_dialogue() -> void:
    _active_dialogue = {}
    _current_companion = null

## ---------- 对话库初始化 ----------
func _init_dialogue_library() -> void:
    # 珂尔莉对话
    _dialogue_library["keerli_intro"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "哼，你就是那个船长？看起来不怎么样嘛。",
        "mood": "proud",
        "options": [
            {
                "text": "确实，我还有很多要学的。请多指教。",
                "affection_delta": 5,
                "is_correct": true,
                "next_dialogue": "keerli_friendly"
            },
            {
                "text": "等你看到我的船再说这话吧。",
                "affection_delta": -2,
                "is_correct": false
            },
            {
                "text": "……",
                "affection_delta": 0,
                "is_correct": false
            }
        ]
    }

    _dialogue_library["keerli_friendly"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……算你有点自知之明。好吧，跟着我，保证不让你掉进海里。",
        "mood": "happy",
        "options": []
    }

    _dialogue_library["keerli_thunder"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……雷、雷声？！我、我只是羽毛有点乱，不是在害怕！",
        "mood": "angry",
        "options": [
            {
                "text": "（假装没注意到）这雷声确实很响呢。",
                "affection_delta": 3,
                "is_correct": true
            },
            {
                "text": "哈哈！珂尔莉你怕雷吗？",
                "affection_delta": -5,
                "is_correct": false,
                "dislike_triggered": true
            }
        ]
    }

    # 铁砧对话
    _dialogue_library["tiechan_intro"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……船长。我的锅炉需要加油了。",
        "mood": "neutral",
        "options": [
            {
                "text": "当然，机油够吗？再多带一些。",
                "affection_delta": 5,
                "is_correct": true,
                "reward": {"type": "item", "id": "item_engine_oil", "amount": 2}
            },
            {
                "text": "你的船你自己保养啊。",
                "affection_delta": -3,
                "is_correct": false
            }
        ]
    }

    # 深蓝对话
    _dialogue_library["shenlan_intro"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……海洋在歌唱……你也听得到吗，船长？",
        "mood": "peaceful",
        "options": [
            {
                "text": "我能感受到海风的呼唤。",
                "affection_delta": 4,
                "is_correct": true
            },
            {
                "text": "我只听到你在嘀咕。",
                "affection_delta": -2,
                "is_correct": false
            },
            {
                "text": "海豚和鲸鱼的声音是什么样的？",
                "affection_delta": 6,
                "is_correct": true,
                "is_special": true
            }
        ]
    }

    # 羁绊高等级对话（亲密+）
    _dialogue_library["keerli_intimate"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "喂，船长……谢谢你一直照顾我。我不会承认第二遍的！",
        "mood": "happy",
        "options": [
            {
                "text": "我知道，你不用说。",
                "affection_delta": 5,
                "is_correct": true
            },
            {
                "text": "你说什么？我没听清。",
                "affection_delta": 2,
                "is_correct": false
            }
        ]
    }

    _dialogue_library["tiechan_intimate"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……机油的味道，让我想起家的感觉。你……也是。",
        "mood": "happy",
        "options": [
            {
                "text": "（拍拍他的肩膀）我们是一家人。",
                "affection_delta": 8,
                "is_correct": true
            },
            {
                "text": "你刚才说什么？",
                "affection_delta": 0,
                "is_correct": false
            }
        ]
    }

    _dialogue_library["shenlan_intimate"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "船长……海洋告诉我，我们相遇不是偶然。我愿意追随你到尽头。",
        "mood": "peaceful",
        "options": [
            {
                "text": "我也一样，深蓝。",
                "affection_delta": 8,
                "is_correct": true
            },
            {
                "text": "……海洋还会说什么？",
                "affection_delta": 3,
                "is_correct": false
            }
        ]
    }

## ---------- 对话选择逻辑 ----------

func _get_default_dialogue_id(companion: Companion) -> String:
    var cid: String = companion.companion_id
    var level: int = companion.get_bond_level()

    # 高等级优先
    if level >= 3 and _dialogue_library.has(cid + "_intimate"):
        return cid + "_intimate"

    # 特殊状态对话（后续可扩展）
    if companion.story_flags.has("fear_thunder") and _dialogue_library.has(cid + "_thunder"):
        return cid + "_thunder"

    return cid + "_intro"

func _get_fallback_dialogue_id(companion: Companion) -> String:
    return companion.companion_id + "_intro"

## ---------- 外部UI调用API ----------
## 获取当前对话选项列表（供UI渲染）
func get_current_options() -> Array:
    return _active_dialogue.get("options", [])

func get_current_text() -> String:
    return _active_dialogue.get("text", "")

func get_current_mood() -> String:
    return _active_dialogue.get("mood", "neutral")

func has_active_dialogue() -> bool:
    return not _active_dialogue.is_empty()

## ---------- 好感度变化提示 ----------
## 根据选项返回合适的反馈文本
func get_affection_feedback_text(companion: Companion, delta: int) -> String:
    if delta > 0:
        if delta >= 6:
            return "%s看起来非常高兴！" % companion.name
        elif delta >= 3:
            return "%s露出了微笑。" % companion.name
        else:
            return "%s对你的印象有所改善。" % companion.name
    elif delta < 0:
        if companion.dislikes.has("item_thunder_rod"):
            return "%s似乎不太高兴。" % companion.name
        else:
            return "%s的表情有些微妙的变化。" % companion.name
    return "%s没有任何反应。" % companion.name

## 注册自定义对话（供外部扩展）
func register_dialogue(dialogue_id: String, data: Dictionary) -> void:
    _dialogue_library[dialogue_id] = data

## 获取对话库统计（调试用）
func get_dialogue_stats() -> Dictionary:
    var stats: Dictionary = {}
    for did in _dialogue_library.keys():
        var cid: String = _dialogue_library[did].get("companion_id", "unknown")
        if not stats.has(cid):
            stats[cid] = 0
        stats[cid] += 1
    return stats
