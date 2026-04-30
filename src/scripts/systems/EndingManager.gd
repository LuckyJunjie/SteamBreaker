extends Node
class_name EndingManager

## Steam Breaker 结局管理器
## 判定结局类型、生成结局幻灯片/旁白数据

# ========== 信号定义 ==========
signal ending_determined(ending_type: EndingType)
signal ending_shown(ending_type: EndingType)
signal slideshow_advance(index: int, slide: Dictionary)
signal ending_complete()

# ========== 枚举定义 ==========
enum EndingType {
    NORMAL_RETIREMENT,   # 普通隐退
    COMPANION_ENDING,    # 伙伴结局
    WEALTHY_ENDING,      # 富豪结局
    LEGENDARY_ENDING,    # 传说结局
    TRAGIC_ENDING,       # 悲剧结局
    UNKNOWN              # 未知（默认）
}

# ========== 常量 ==========
const WEALTH_THRESHOLD: int = 100000      # 富豪结局金币阈值
const AFFECTION_THRESHOLD: int = 80        # 伙伴结局好感度阈值
const TRAGIC_AFFECTION_THRESHOLD: int = 50 # 悲剧结局判定（好感度低于此且无伙伴）

# ========== 导出变量 ==========
@export var current_ending: EndingType = EndingType.UNKNOWN
@export var slideshow_slides: Array[Dictionary] = []
@export var current_slide_index: int = 0

# ========== 私有变量 ==========
var _ending_criteria_scores: Dictionary = {}
var _selected_companion_id: String = ""
var _narrative_text: String = ""

# ========== 节点引用 ==========
var _companion_manager: Node = null
var _bounty_manager: Node = null
var _story_manager: Node = null
var _game_state_node: Node = null

# ========== 内置方法 ==========
func _ready() -> void:
    print("[EndingManager] Initialized")
    _cache_node_references()

func _cache_node_references() -> void:
    var root := get_tree().root
    _companion_manager = root.find_child("CompanionManager", true, false)
    _bounty_manager = root.find_child("BountyManager", true, false)
    _story_manager = root.find_child("StoryManager", true, false)
    _game_state_node = root.find_child("GameState", true, false)

# ========== 公开 API ==========

## 计算并判定结局类型
func determine_ending() -> EndingType:
    print("[EndingManager] Calculating ending...")
    _cache_node_references()
    
    var determined := check_ending_conditions()
    current_ending = determined
    _generate_slideshow(determined)
    ending_determined.emit(determined)
    
    return determined

## 检查结局条件并返回结局类型
func check_ending_conditions() -> EndingType:
    var gold: int = _get_player_gold()
    var highest_bond: int = 0
    var highest_companion: String = ""
    var defeated_epic_bounties: int = _get_defeated_epic_bounties_count()
    
    # 1. 获取最高羁绊等级
    if _companion_manager and _companion_manager.has_method("get_max_bond_level"):
        highest_bond = _companion_manager.get_max_bond_level()
        highest_companion = _companion_manager.get_highest_bond_companion_id() if _companion_manager.has_method("get_highest_bond_companion_id") else ""
    
    # 2. 检查是否有伙伴死亡（悲剧线索）
    var any_companion_dead: bool = _check_any_companion_dead()
    
    # 3. 判定结局
    var ending: EndingType = EndingType.NORMAL_RETIREMENT
    
    # 悲剧结局判定（最高优先级）
    if any_companion_dead or _is_story_failed():
        ending = EndingType.TRAGIC_ENDING
        _narrative_text = "在漫长的旅途中，你失去了重要的伙伴。\n曾经的战友，如今只剩回忆。"
        print("[EndingManager] Ending: TRAGIC (companion dead or story failed)")
    
    # 传说结局（击败所有史诗赏金首）
    elif defeated_epic_bounties >= _get_total_epic_bounty_count() and defeated_epic_bounties > 0:
        ending = EndingType.LEGENDARY_ENDING
        _narrative_text = "所有的史诗赏金首都已倒在你的炮口之下。\n你的名字被铭刻在每一个港口的传说之中。"
        print("[EndingManager] Ending: LEGENDARY (all epic bounties defeated)")
    
    # 富豪结局
    elif gold >= WEALTH_THRESHOLD:
        ending = EndingType.WEALTHY_ENDING
        _narrative_text = "十万金币的财富让你成为沿海最富有的船主。\n铁锈湾的酒馆里，人们还在传唱你的故事。"
        print("[EndingManager] Ending: WEALTHY (gold >= %d)" % WEALTH_THRESHOLD)
    
    # 伙伴结局（羁绊等级 >= 2）
    elif highest_bond >= 2 and highest_companion != "":
        ending = EndingType.COMPANION_ENDING
        _selected_companion_id = highest_companion
        _narrative_text = _get_companion_ending_narrative(highest_companion, highest_bond)
        print("[EndingManager] Ending: COMPANION (%s, bond_level=%d)" % [highest_companion, highest_bond])
    
    # 普通隐退（兜底）
    else:
        ending = EndingType.NORMAL_RETIREMENT
        _narrative_text = "你选择放下武器，回到铁锈湾的岸边。\n日落时分，远处传来汽笛的鸣响。"
        print("[EndingManager] Ending: NORMAL_RETIREMENT")
    
    return ending

## 触发结局显示
func trigger_ending(type: EndingType) -> void:
    if type == EndingType.UNKNOWN:
        type = check_ending_conditions()
    
    current_ending = type
    _generate_slideshow(type)
    
    # 发送信号
    ending_determined.emit(type)
    print("[EndingManager] Ending triggered: %s" % get_ending_name())
    
    # 显示结局画面
    _show_ending_screen(type)

## 获取结局名称
func get_ending_name() -> String:
    match current_ending:
        EndingType.NORMAL_RETIREMENT:
            return "普通隐退"
        EndingType.COMPANION_ENDING:
            return "伙伴结局"
        EndingType.WEALTHY_ENDING:
            return "富豪结局"
        EndingType.LEGENDARY_ENDING:
            return "传说结局"
        EndingType.TRAGIC_ENDING:
            return "悲剧结局"
        _:
            return "未知结局"

## 获取幻灯片总数
func get_slideshow_length() -> int:
    return slideshow_slides.size()

## 获取当前幻灯片
func get_current_slide() -> Dictionary:
    if current_slide_index >= 0 and current_slide_index < slideshow_slides.size():
        return slideshow_slides[current_slide_index]
    return {}

## 前进到下一张幻灯片
func advance_slideshow() -> bool:
    if current_slide_index < slideshow_slides.size() - 1:
        current_slide_index += 1
        slideshow_advance.emit(current_slide_index, slideshow_slides[current_slide_index])
        return true
    else:
        ending_complete.emit()
        return false

## 重置幻灯片到开头
func reset_slideshow() -> void:
    current_slide_index = 0
    slideshow_slides.clear()

## 获取结局旁白文本
func get_narrative_text() -> String:
    return _narrative_text

## 获取结局预览信息（用于 UI）
func get_ending_preview() -> Dictionary:
    return {
        "ending_type": current_ending,
        "ending_name": get_ending_name(),
        "narrative": _narrative_text,
        "slides_count": slideshow_slides.size(),
        "companion_id": _selected_companion_id if current_ending == EndingType.COMPANION_ENDING else ""
    }

## 检查是否可以触发结局
func can_trigger_ending() -> bool:
    # 必须完成终章
    if _story_manager:
        if not _story_manager.is_chapter_completed(StoryManager.Chapter.EPILOGUE):
            return false
    return true

# ========== 私有方法 ==========
func _get_player_gold() -> int:
    if _game_state_node:
        return _game_state_node.get("gold", 0)
    return 0

func _get_defeated_epic_bounties_count() -> int:
    if not _bounty_manager:
        return 0
    
    var completed: Dictionary = _bounty_manager.get_completed_bounties()
    var epic_count: int = 0
    
    for bounty_id in completed:
        if _is_epic_bounty(bounty_id):
            epic_count += 1
    
    return epic_count

func _get_total_epic_bounty_count() -> int:
    # 史诗赏金首定义
    var epic_bounties: Array[String] = [
        "bounty_irontooth_shark",
        "bounty_ghost_queen"
        # TODO: 后续添加更多史诗赏金首
    ]
    return epic_bounties.size()

func _is_epic_bounty(bounty_id: String) -> bool:
    var epic_bounties: Array[String] = [
        "bounty_irontooth_shark",
        "bounty_ghost_queen"
    ]
    return bounty_id in epic_bounties

func _check_any_companion_dead() -> bool:
    if _companion_manager and _companion_manager.has_method("is_companion_dead"):
        for companion_id in ["tiechan", "shenlan", "keerli"]:
            if _companion_manager.is_companion_dead(companion_id):
                return true
    return false

func _is_story_failed() -> bool:
    if _story_manager:
        return _story_manager.has_flag("main_story_failed") or _story_manager.get("current_chapter", 0) < 0
    return false

func _get_companion_ending_narrative(companion_id: String, affection: int) -> String:
    var narratives: Dictionary = {
        "tiechan": "铁砧决定留在铁锈湾，开了一家修理铺。\n每当你的船需要维修，他总是第一个赶到。\n有些羁绊，比钢铁还要坚固。",
        "shenlan": "深蓝邀请你一起巡游深海。\n鲸群的歌声在远方回荡，你们的身影消失在海平线上。\n这才是真正的自由。",
        "keerli": "珂尔莉带着你飞向高空浮岛。\n云端的驿站里，你们经营着新的飞行队。\n天空的另一端，有无限的可能。"
    }
    return narratives.get(companion_id, "你与伙伴的旅程还在继续...")

func _generate_slideshow(ending: EndingType) -> void:
    slideshow_slides.clear()
    
    # 添加通用开头
    slideshow_slides.append({
        "type": "title",
        "title": "结局",
        "subtitle": get_ending_name(),
        "bg_color": Color(0.1, 0.1, 0.15, 1.0)
    })
    
    # 添加旁白幻灯片
    var paragraphs: Array[String] = _narrative_text.split("\n")
    for paragraph in paragraphs:
        slideshow_slides.append({
            "type": "narrative",
            "text": paragraph,
            "speaker": ""
        })
    
    # 添加结局专属幻灯片
    match ending:
        EndingType.COMPANION_ENDING:
            _add_companion_slides()
        EndingType.WEALTHY_ENDING:
            _add_wealthy_slides()
        EndingType.LEGENDARY_ENDING:
            _add_legendary_slides()
        EndingType.TRAGIC_ENDING:
            _add_tragic_slides()
        _:
            _add_normal_slides()
    
    # 添加制作人员名单
    slideshow_slides.append({
        "type": "credits",
        "title": "制作人员",
        "text": "Steam Breaker\n\n主策: Master Jay\n程序: Chiron\n美术: (待定)\n音乐: (待定)"
    })
    
    # 添加重新开始选项
    slideshow_slides.append({
        "type": "end",
        "title": "感谢游玩",
        "text": "返回标题画面"
    })
    
    print("[EndingManager] Generated %d slides for ending %s" % [slideshow_slides.size(), get_ending_name()])

func _add_companion_slides() -> void:
    var companion_names: Dictionary = {
        "tiechan": "铁砧",
        "shenlan": "深蓝",
        "keerli": "珂尔莉"
    }
    var name: String = companion_names.get(_selected_companion_id, "伙伴")
    
    slideshow_slides.append({
        "type": "companion_art",
        "title": name + "结局",
        "text": name + "与你的羁绊经受住了时间的考验。\n未来的日子里，你们将一起面对更多的挑战。",
        "companion_id": _selected_companion_id
    })

func _add_wealthy_slides() -> void:
    slideshow_slides.append({
        "type": "scene",
        "title": "富豪结局",
        "text": "你的船队成为海域上最富有的存在。\n每一座港口都有你的产业，每一条航路都有你的船帆。",
        "location": "铁锈湾"
    })

func _add_legendary_slides() -> void:
    slideshow_slides.append({
        "type": "scene",
        "title": "传说结局",
        "text": "所有的敌人都已倒下。\n你的名字被铭刻在每一座灯塔之上，指引着后来的航行者。",
        "location": "海域各处"
    })

func _add_tragic_slides() -> void:
    slideshow_slides.append({
        "type": "scene",
        "title": "悲剧结局",
        "text": "有些人永远无法回来了。\n但你活下去，带着他们的记忆，继续前进。",
        "location": "铁锈湾"
    })

## 显示结局画面
func _show_ending_screen(type: EndingType) -> void:
    # 加载并显示结局场景
    var ending_scene = preload("res://scenes/ui/EndingScreen.tscn")
    if ending_scene:
        var instance = ending_scene.instantiate()
        # 设置结局数据
        if instance.has_method("setup"):
            instance.setup(type, _narrative_text)
        # 添加到场景树
        get_tree().root.add_child(instance)
        print("[EndingManager] Ending screen shown")
    else:
        print("[EndingManager] WARNING: EndingScreen.tscn not found, using fallback")

func _add_normal_slides() -> void:
    slideshow_slides.append({
        "type": "scene",
        "title": "普通隐退",
        "text": "铁锈湾的日落依旧美丽。\n你的船安静地停泊在港湾，有人在等你回家。",
        "location": "铁锈湾"
    })

## 获取存档数据
func get_save_data() -> Dictionary:
    return {
        "current_ending": current_ending,
        "selected_companion_id": _selected_companion_id,
        "narrative_text": _narrative_text
    }

## 应用存档数据
func apply_save_data(data: Dictionary) -> void:
    current_ending = data.get("current_ending", EndingType.UNKNOWN)
    _selected_companion_id = data.get("selected_companion_id", "")
    _narrative_text = data.get("narrative_text", "")