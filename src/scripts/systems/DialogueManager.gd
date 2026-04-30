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

## _current_companion_state 可以是 Companion 或 CompanionManager.CompanionState
var _current_companion_state: Variant = null
var _current_companion_id: String = ""

## 对话预定义库（示例）
func _ready() -> void:
    _init_dialogue_library()
    _load_dialogue_trees_from_files()


## 尝试从 JSON 文件加载对话树
func _load_dialogue_trees_from_files() -> void:
    var base_path: String = "res://resources/dialogues/"
    var companion_ids: Array[String] = ["companion_keerli", "companion_tiechan", "companion_shenlan"]

    for cid in companion_ids:
        var file_path: String = base_path + cid + "_dialogues.json"
        if ResourceLoader.exists(file_path):
            var json_text: String = FileAccess.get_file_as_string(file_path)
            var json_data: JSON = JSON.new()
            if json_data.parse(json_text) == OK:
                var parsed: Dictionary = json_data.get_data()
                if parsed is Dictionary:
                    _merge_dialogue_tree(parsed)
                    print("[DialogueManager] Loaded dialogue tree from: ", file_path)


## 合并从 JSON 加载的对话到库中（已存在的会被覆盖）
func _load_dialogue_tree(dialogue_id: String, tree_data: Dictionary) -> void:
    if tree_data.is_empty():
        return
    _dialogue_library[dialogue_id] = tree_data
    print("[DialogueManager] Registered dialogue tree: ", dialogue_id)


func _merge_dialogue_tree(data: Dictionary) -> void:
    for did in data.keys():
        _dialogue_library[did] = data[did]

## ---------- 核心API ----------

## 开始一段对话
## companion: Companion 或 CompanionManager.CompanionState
func start_dialogue(companion_or_state: Variant, dialogue_id: String = "") -> Dictionary:
    _current_companion_state = companion_or_state
    if companion_or_state.has_method("get_companion_id"):
        _current_companion_id = companion_or_state.companion_id
    else:
        _current_companion_id = str(companion_or_state)

    # 如果未指定ID，尝试获取当前好感度对应的默认对话
    if dialogue_id == "":
        dialogue_id = _get_default_dialogue_id(companion_or_state)

    if not _dialogue_library.has(dialogue_id):
        dialogue_id = _get_fallback_dialogue_id(companion_or_state)

    _active_dialogue = _dialogue_library[dialogue_id].duplicate(true)
    _active_dialogue["dialogue_id"] = dialogue_id
    dialogue_started.emit(_current_companion_id, dialogue_id)

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
    if _active_dialogue.is_empty() or _current_companion_state == null:
        return {"success": false, "message": "无进行中的对话"}

    var options: Array = _active_dialogue.get("options", [])
    if option_index < 0 or option_index >= options.size():
        return {"success": false, "message": "无效选项"}

    var option: Dictionary = options[option_index]
    var option_text: String = option.get("text", "")
    var affection_delta: int = option.get("affection_delta", 0)
    var reward: Dictionary = option.get("reward", {})

    dialogue_option_selected.emit(_current_companion_id, option_index, option_text)

    # 应用好感度变化（CompanionState 有 add_affection）
    var old_affection: int = _current_companion_state.affection
    _current_companion_state.add_affection(affection_delta)
    var new_affection: int = _current_companion_state.affection

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

    dialogue_ended.emit(_current_companion_id, _active_dialogue.get("dialogue_id", ""), affection_delta)

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
    var cid: String = _current_companion_id
    var did: String = _active_dialogue.get("dialogue_id", "") if not _active_dialogue.is_empty() else ""
    var result: Dictionary = {
        "ended": true,
        "companion_id": cid,
        "dialogue_id": did
    }
    _active_dialogue = {}
    _current_companion_state = null
    _current_companion_id = ""
    return result

## 跳过/关闭对话（不产生好感度变化）
func skip_dialogue() -> void:
    _active_dialogue = {}
    _current_companion_state = null
    _current_companion_id = ""

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

    # =============================================
    # bond_talk_* 羁绊对话（CompanionPanel 触发）
    # =============================================

    # --- bond_talk_keerli ---
    _dialogue_library["bond_talk_keerli_1"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……站在这里干什么？海风把你的脑子吹傻了吗？",
        "mood": "neutral",
        "options": [
            {
                "text": "欣赏你站在风里的样子，很有气势。",
                "next_dialogue": "bond_talk_keerli_1a",
                "affection_delta": 3
            },
            {
                "text": "在想今天的航路怎么走。",
                "next_dialogue": "bond_talk_keerli_1b",
                "affection_delta": 1
            },
            {
                "text": "没什么，随便逛逛。",
                "next_dialogue": "bond_talk_keerli_1c",
                "affection_delta": 0
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_1a"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……哼，算你有眼光。不过可别被风吹跑了，你还欠我一趟飞行的约定呢。",
        "mood": "proud",
        "options": [
            {
                "text": "说定了，等天气好我一定带你飞。",
                "affection_delta": 4,
                "is_correct": true
            },
            {
                "text": "飞行的事以后再说吧。",
                "affection_delta": -1
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_1b"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "哼，至少比发呆强。……要不要我帮你看看风向？我在高空看得很清楚。",
        "mood": "neutral",
        "options": [
            {
                "text": "拜托你了，珂尔莉。",
                "affection_delta": 3,
                "is_correct": true
            },
            {
                "text": "不用，我有自己的判断。",
                "affection_delta": 0
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_1c"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "无聊。……别挡我的风就行。",
        "mood": "neutral",
        "options": []
    }

    _dialogue_library["bond_talk_keerli_2"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "喂，船长。……你相信天空有尽头吗？",
        "mood": "peaceful",
        "options": [
            {
                "text": "我相信。也许我们能一起找到。",
                "next_dialogue": "bond_talk_keerli_2a",
                "affection_delta": 4
            },
            {
                "text": "科学上还没有证明。",
                "next_dialogue": "bond_talk_keerli_2b",
                "affection_delta": -2
            },
            {
                "text": "你为什么突然问这个？",
                "next_dialogue": "bond_talk_keerli_2c",
                "affection_delta": 2
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_2a"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……哼，算你有点见识。有一天，我会带你一起去看。",
        "mood": "proud",
        "options": [
            {
                "text": "一言为定。",
                "affection_delta": 5,
                "is_correct": true
            },
            {
                "text": "等你做到了再说吧。",
                "affection_delta": -2
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_2b"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……无趣的家伙。我不是在和你谈科学。",
        "mood": "angry",
        "options": []
    }

    _dialogue_library["bond_talk_keerli_2c"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……没什么。只是有时候会想起以前的事。别管了。",
        "mood": "sad",
        "options": [
            {
                "text": "以后想聊的时候再说吧。",
                "affection_delta": 2
            },
            {
                "text": "我可以听你说。",
                "affection_delta": 4,
                "is_correct": true
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_3"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……船长。我的羽毛今天有点乱。你、你可别盯着看！",
        "mood": "proud",
        "options": [
            {
                "text": "（转过身去）好了，你可以整理了。",
                "next_dialogue": "bond_talk_keerli_3a",
                "affection_delta": 3
            },
            {
                "text": "乱也很可爱啊。",
                "next_dialogue": "bond_talk_keerli_3b",
                "affection_delta": -3
            },
            {
                "text": "需要帮忙吗？",
                "next_dialogue": "bond_talk_keerli_3c",
                "affection_delta": 1
            }
        ]
    }

    _dialogue_library["bond_talk_keerli_3a"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……算你识相。",
        "mood": "happy",
        "options": []
    }

    _dialogue_library["bond_talk_keerli_3b"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "你、你脑子真的被海风吹坏了！谁要你说可爱！",
        "mood": "angry",
        "options": []
    }

    _dialogue_library["bond_talk_keerli_3c"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……不用。我自己来就好。（小声）……谢了。",
        "mood": "proud",
        "options": []
    }

    # --- bond_talk_tiechan ---
    _dialogue_library["bond_talk_tiechan_1"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……船长。我的关节需要上油了。这批机械油质量一般。",
        "mood": "neutral",
        "options": [
            {
                "text": "下次给你弄更好的。还有哪里需要保养？",
                "next_dialogue": "bond_talk_tiechan_1a",
                "affection_delta": 4
            },
            {
                "text": "将就着用吧，我们的补给有限。",
                "next_dialogue": "bond_talk_tiechan_1b",
                "affection_delta": -2
            },
            {
                "text": "机械改造后一直这样吗？",
                "next_dialogue": "bond_talk_tiechan_1c",
                "affection_delta": 2
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_1a"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……嗯。胸腔的齿轮也有点问题。不过都能撑住。……谢谢。",
        "mood": "neutral",
        "options": [
            {
                "text": "不用客气，你辛苦了。",
                "affection_delta": 4,
                "is_correct": true
            },
            {
                "text": "能修就自己修吧。",
                "affection_delta": -1
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_1b"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……了解。",
        "mood": "neutral",
        "options": []
    }

    _dialogue_library["bond_talk_tiechan_1c"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……嗯。那是很久以前的事了。改造之后，每个月都要保养。不保养就会锈死。",
        "mood": "sad",
        "options": [
            {
                "text": "那一定很疼吧。",
                "affection_delta": 5,
                "is_correct": true
            },
            {
                "text": "改造是你自己选的吗？",
                "affection_delta": 3
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_2"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……船长。你知道钢铁和血肉的区别吗？",
        "mood": "neutral",
        "options": [
            {
                "text": "钢铁不会痛，但血肉更有温度。",
                "next_dialogue": "bond_talk_tiechan_2a",
                "affection_delta": 4
            },
            {
                "text": "钢铁更耐用。",
                "next_dialogue": "bond_talk_tiechan_2b",
                "affection_delta": 0
            },
            {
                "text": "为什么突然问这个？",
                "next_dialogue": "bond_talk_tiechan_2c",
                "affection_delta": 1
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_2a"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……有意思的答案。我有时候也会想，如果全是钢铁，会不会就不需要那么在意很多事情了。",
        "mood": "peaceful",
        "options": [
            {
                "text": "但你现在这样就很好。",
                "affection_delta": 6,
                "is_correct": true
            },
            {
                "text": "也许吧。",
                "affection_delta": 1
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_2b"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……是。但耐用不一定更好。",
        "mood": "neutral",
        "options": []
    }

    _dialogue_library["bond_talk_tiechan_2c"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……没什么。只是有时候会想这些有的没的。忽略吧。",
        "mood": "neutral",
        "options": []
    }

    _dialogue_library["bond_talk_tiechan_3"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……船长。这个给你。（拿出一个齿轮）我多做一个备用的。",
        "mood": "neutral",
        "options": [
            {
                "text": "谢谢你，铁砧。我会好好保管的。",
                "next_dialogue": "bond_talk_tiechan_3a",
                "affection_delta": 5
            },
            {
                "text": "这个有什么用？",
                "next_dialogue": "bond_talk_tiechan_3b",
                "affection_delta": 1
            },
            {
                "text": "你自己不用吗？",
                "next_dialogue": "bond_talk_tiechan_3c",
                "affection_delta": 3
            }
        ]
    }

    _dialogue_library["bond_talk_tiechan_3a"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……嗯。如果船上的零件坏了，这个可以应急。……希望用不上。",
        "mood": "peaceful",
        "options": []
    }

    _dialogue_library["bond_talk_tiechan_3b"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……通用齿轮。大部分机械都能用。……问这么多干什么，收下就是了。",
        "mood": "neutral",
        "options": []
    }

    _dialogue_library["bond_talk_tiechan_3c"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……我用不上。我身体里的是特殊规格的。……但船长你不一样，你还是血肉之躯。",
        "mood": "sad",
        "options": [
            {
                "text": "……我会小心的。谢谢你。",
                "affection_delta": 4,
                "is_correct": true
            }
        ]
    }

    # --- bond_talk_shenlan ---
    _dialogue_library["bond_talk_shenlan_1"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……船长。你看，那片云在唱歌。你听到了吗？",
        "mood": "peaceful",
        "options": [
            {
                "text": "我听到了，像笛子一样的声音。",
                "next_dialogue": "bond_talk_shenlan_1a",
                "affection_delta": 4
            },
            {
                "text": "云不会唱歌，深蓝。",
                "next_dialogue": "bond_talk_shenlan_1b",
                "affection_delta": -2
            },
            {
                "text": "你对声音很敏感呢。",
                "next_dialogue": "bond_talk_shenlan_1c",
                "affection_delta": 2
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_1a"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……是啊。那是风穿过云层的声音。海洋和天空是相连的，船长。它们在对话。",
        "mood": "peaceful",
        "options": [
            {
                "text": "有一天你能教我听懂它们吗？",
                "affection_delta": 5,
                "is_correct": true
            },
            {
                "text": "这听起来有点玄。",
                "affection_delta": 0
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_1b"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……没关系。有一天你会听到的。在那之前，我会替你听。",
        "mood": "peaceful",
        "options": []
    }

    _dialogue_library["bond_talk_shenlan_1c"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……鱼人的耳朵和人类不一样。我们能听到更深的东西。洋流、潮汐、还有……海洋的心跳。",
        "mood": "peaceful",
        "options": [
            {
                "text": "听起来很神奇。",
                "affection_delta": 4,
                "is_correct": true
            },
            {
                "text": "那是一种怎样的感觉？",
                "affection_delta": 5,
                "is_correct": true
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_2"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……船长。你有没有想过，大海为什么是蓝色的？",
        "mood": "peaceful",
        "options": [
            {
                "text": "因为它映照着天空的颜色？",
                "next_dialogue": "bond_talk_shenlan_2a",
                "affection_delta": 3
            },
            {
                "text": "因为光线折射？",
                "next_dialogue": "bond_talk_shenlan_2b",
                "affection_delta": 1
            },
            {
                "text": "因为大海在思念着什么。",
                "next_dialogue": "bond_talk_shenlan_2c",
                "affection_delta": 5
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_2a"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……是的。但也不全是。海洋的颜色也取决于它承载的东西——生命、记忆、还有眼泪。",
        "mood": "peaceful",
        "options": [
            {
                "text": "……原来如此。",
                "affection_delta": 3
            },
            {
                "text": "大海也会哭吗？",
                "affection_delta": 6,
                "is_correct": true
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_2b"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……那也是一部分。但海洋比物理法则更深。它有灵魂，船长。",
        "mood": "peaceful",
        "options": []
    }

    _dialogue_library["bond_talk_shenlan_2c"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……是的。你懂。海洋在等待，等待能听懂它的人。……船长，你愿意继续听吗？",
        "mood": "happy",
        "options": [
            {
                "text": "我愿意。",
                "affection_delta": 7,
                "is_correct": true
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_3"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……船长。我有时候会梦到深海里的光。那是一种你们从未见过的蓝。",
        "mood": "peaceful",
        "options": [
            {
                "text": "能带我去看看吗？",
                "next_dialogue": "bond_talk_shenlan_3a",
                "affection_delta": 4
            },
            {
                "text": "深海太危险了。",
                "next_dialogue": "bond_talk_shenlan_3b",
                "affection_delta": -1
            },
            {
                "text": "那一定很美。",
                "next_dialogue": "bond_talk_shenlan_3c",
                "affection_delta": 3
            }
        ]
    }

    _dialogue_library["bond_talk_shenlan_3a"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……有一天。也许等我们走得更远，那片海会为我们打开。……谢谢你，船长。",
        "mood": "happy",
        "options": []
    }

    _dialogue_library["bond_talk_shenlan_3b"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……是的。那里有你们无法承受的黑暗。但也有光。",
        "mood": "peaceful",
        "options": []
    }

    _dialogue_library["bond_talk_shenlan_3c"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……是的。很美。有一天我会画给你看。用海的颜色。",
        "mood": "happy",
        "options": []
    }

    # 羁绊对话入口（随机选择或按好感度选择）
    _dialogue_library["bond_talk_keerli"] = {
        "companion_id": "companion_keerli",
        "speaker_name": "珂尔莉",
        "text": "……有事？",
        "mood": "neutral",
        "options": [
            {"text": "想找你聊聊。", "next_dialogue": "bond_talk_keerli_1", "affection_delta": 1},
            {"text": "关于天空的事。", "next_dialogue": "bond_talk_keerli_2", "affection_delta": 1},
            {"text": "你今天看起来有点不一样。", "next_dialogue": "bond_talk_keerli_3", "affection_delta": 1}
        ]
    }

    _dialogue_library["bond_talk_tiechan"] = {
        "companion_id": "companion_tiechan",
        "speaker_name": "铁砧",
        "text": "……什么事？",
        "mood": "neutral",
        "options": [
            {"text": "想看看你的状况。", "next_dialogue": "bond_talk_tiechan_1", "affection_delta": 1},
            {"text": "关于机械的事。", "next_dialogue": "bond_talk_tiechan_2", "affection_delta": 1},
            {"text": "这个给你。", "next_dialogue": "bond_talk_tiechan_3", "affection_delta": 1}
        ]
    }

    _dialogue_library["bond_talk_shenlan"] = {
        "companion_id": "companion_shenlan",
        "speaker_name": "深蓝",
        "text": "……船长。海洋有话想跟你说。",
        "mood": "peaceful",
        "options": [
            {"text": "我想听。", "next_dialogue": "bond_talk_shenlan_1", "affection_delta": 1},
            {"text": "海在说什么？", "next_dialogue": "bond_talk_shenlan_2", "affection_delta": 1},
            {"text": "关于深海的事。", "next_dialogue": "bond_talk_shenlan_3", "affection_delta": 1}
        ]
    }

## ---------- 对话选择逻辑 ----------

func _get_default_dialogue_id(companion_or_state: Variant) -> String:
    var cid: String
    var level: int
    var has_story_flags: bool = companion_or_state.has("story_flags")

    if companion_or_state.has_method("get_companion_id"):
        cid = companion_or_state.companion_id
        level = companion_or_state.get_bond_level()
    else:
        cid = str(companion_or_state)
        level = 0

    # 高等级优先
    if level >= 3 and _dialogue_library.has(cid + "_intimate"):
        return cid + "_intimate"

    # 特殊状态对话（后续可扩展）
    if has_story_flags and companion_or_state.story_flags.has("fear_thunder") and _dialogue_library.has(cid + "_thunder"):
        return cid + "_thunder"

    return cid + "_intro"

func _get_fallback_dialogue_id(companion_or_state: Variant) -> String:
    var cid: String
    if companion_or_state.has_method("get_companion_id"):
        cid = companion_or_state.companion_id
    else:
        cid = str(companion_or_state)
    return cid + "_intro"

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
