extends Node

## Steam Breaker 主线剧情管理器
## 管理章节进度、剧情事件触发、派系声望

# ========== 信号定义 ==========
signal chapter_changed(chapter: int, chapter_name: String)
signal story_event_triggered(event_id: String, event_data: Dictionary)
signal faction_reputation_changed(faction: Faction, old_val: int, new_val: int)
signal story_progress_updated(progress: int)

# ========== 枚举定义 ==========
enum Faction { EMPIRE, PIRATES, DEEP_SEA_CHAPEL }
enum Chapter {
    PROLOGUE = 0,   # 序章：修复蒸汽破浪号
    CHAPTER_1 = 1, # 第一章：抵达帝国港口
    CHAPTER_2 = 2, # 第二章：三势力探索
    CHAPTER_3 = 3, # 第三章：深海遗迹
    CHAPTER_4 = 4, # 第四章：最终抉择
    EPILOGUE = 5,   # 终章：战后
    END = 6         # 结局（不可逆）
}

# ========== 常量 ==========
const CHAPTER_NAMES: Dictionary = {
    Chapter.PROLOGUE: "序章 - 重启之火",
    Chapter.CHAPTER_1: "第一章 - 铁与烟",
    Chapter.CHAPTER_2: "第二章 - 三岔路口",
    Chapter.CHAPTER_3: "第三章 - 深海的呼唤",
    Chapter.CHAPTER_4: "第四章 - 抉择之时",
    Chapter.EPILOGUE: "终章 - 战后余波",
    Chapter.END: "结局"
}

const EPISODE_BOUNTIES: Array[String] = [
    "bounty_irontooth_shark",
    "bounty_ghost_queen",
    "bounty_irontooth_shark",  # 可重复挑战
]

# ========== 导出变量 ==========
@export var current_chapter: int = Chapter.PROLOGUE
@export var current_story_flags: Dictionary = {}
@export var faction_reputation: Dictionary = {
    Faction.EMPIRE: 0,
    Faction.PIRATES: 0,
    Faction.DEEP_SEA_CHAPEL: 0
}

# ========== 私有变量 ==========
var _event_listeners: Dictionary = {}
var _triggered_events: Array[String] = []
var _chapter_completion_flags: Dictionary = {}

# ========== 节点引用 ==========
var _game_state_node: Node = null

# ========== 内置方法 ==========
func _ready() -> void:
    print("[StoryManager] Initialized - Chapter: ", CHAPTER_NAMES.get(current_chapter, "Unknown"))
    _game_state_node = _get_game_state_node()
    _load_progress()

func _get_game_state_node() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs

# ========== 公开 API ==========

## 获取当前章节名称
func get_chapter_name() -> String:
    return CHAPTER_NAMES.get(current_chapter, "未知章节")

## 获取章节进度百分比（0.0 ~ 1.0）
func get_chapter_progress() -> float:
    # 各章节有不同目标，暂时返回线性进度
    return clamp(float(current_chapter) / float(Chapter.END), 0.0, 1.0)

## 检查剧情标志
func has_flag(flag: String) -> bool:
    return current_story_flags.has(flag)

## 设置剧情标志
func set_flag(flag: String, value: bool = true) -> void:
    current_story_flags[flag] = value
    story_progress_updated.emit(current_chapter)
    _save_progress()
    _check_event_triggers(flag)

## 获取剧情标志值
func get_flag(flag: String, default = false):
    return current_story_flags.get(flag, default)

## 推进章节
func advance_chapter() -> void:
    if current_chapter < Chapter.END:
        var old_chapter = current_chapter
        current_chapter += 1
        _on_chapter_changed(old_chapter, current_chapter)
        chapter_changed.emit(current_chapter, get_chapter_name())
        _save_progress()

## 设置具体章节（用于调试或剧情跳切）
func set_chapter(chapter: int) -> void:
    if chapter >= Chapter.PROLOGUE and chapter <= Chapter.END:
        var old = current_chapter
        current_chapter = chapter
        chapter_changed.emit(current_chapter, get_chapter_name())
        _save_progress()

## 检查章节是否完成
func is_chapter_completed(chapter: int) -> bool:
    return _chapter_completion_flags.get(chapter, false)

## 标记章节完成
func complete_chapter(chapter: int) -> void:
    _chapter_completion_flags[chapter] = true
    print("[StoryManager] Chapter %d completed" % chapter)
    _save_progress()

## 获取派系声望
func get_faction_reputation(faction: Faction) -> int:
    return faction_reputation.get(faction, 0)

## 修改派系声望
func modify_faction_reputation(faction: Faction, delta: int) -> void:
    var old_val: int = faction_reputation.get(faction, 0)
    var new_val: int = clamp(old_val + delta, -100, 100)
    faction_reputation[faction] = new_val
    faction_reputation_changed.emit(faction, old_val, new_val)
    print("[StoryManager] Faction %s reputation: %d -> %d" % [Faction.keys()[faction], old_val, new_val])
    _save_progress()

## 检查派系关系阶段
func get_faction_relationship_phase(faction: Faction) -> String:
    var rep: int = get_faction_reputation(faction)
    if rep >= 75:
        return "allied"      # 盟友
    elif rep >= 40:
        return "friendly"    # 友好
    elif rep >= 10:
        return "neutral"     # 中立
    elif rep >= -30:
        return "unfriendly" # 不友好
    else:
        return "hostile"      # 敌对

## 触发剧情事件
func trigger_event(event_id: String, event_data: Dictionary = {}) -> void:
    if event_id in _triggered_events:
        print("[StoryManager] Event %s already triggered, skipping" % event_id)
        return
    
    _triggered_events.append(event_id)
    set_flag("event_" + event_id, true)
    story_event_triggered.emit(event_id, event_data)
    print("[StoryManager] Event triggered: %s" % event_id)

## 检查事件是否已触发
func is_event_triggered(event_id: String) -> bool:
    return event_id in _triggered_events

## 注册剧情事件监听器
func add_event_listener(event_id: String, callback: Callable) -> void:
    if not _event_listeners.has(event_id):
        _event_listeners[event_id] = []
    _event_listeners[event_id].append(callback)

## 移除剧情事件监听器
func remove_event_listener(event_id: String, callback: Callable) -> void:
    if _event_listeners.has(event_id):
        _event_listeners[event_id].erase(callback)

## 获取主线进度（用于 UI 显示）
func get_main_story_progress() -> Dictionary:
    return {
        "chapter": current_chapter,
        "chapter_name": get_chapter_name(),
        "progress": get_chapter_progress(),
        "flags_count": current_story_flags.size(),
        "events_triggered": _triggered_events.size()
    }

## 检查是否可进入终章
func can_enter_final_chapter() -> bool:
    # 需要完成第四章的关键选择标志
    return has_flag("main_story_chapter4_complete") or current_chapter >= Chapter.EPILOGUE

## 检查是否可以触发结局
func can_trigger_ending() -> bool:
    return current_chapter >= Chapter.EPILOGUE and is_chapter_completed(Chapter.EPILOGUE)

## 获取存档数据
func get_save_data() -> Dictionary:
    return {
        "current_chapter": current_chapter,
        "story_flags": current_story_flags.duplicate(true),
        "faction_reputation": faction_reputation.duplicate(true),
        "triggered_events": _triggered_events.duplicate(),
        "chapter_completion_flags": _chapter_completion_flags.duplicate(true)
    }

## 应用存档数据
func apply_save_data(data: Dictionary) -> void:
    current_chapter = data.get("current_chapter", Chapter.PROLOGUE)
    current_story_flags = data.get("story_flags", {}).duplicate(true)
    faction_reputation = data.get("faction_reputation", {
        Faction.EMPIRE: 0,
        Faction.PIRATES: 0,
        Faction.DEEP_SEA_CHAPEL: 0
    }).duplicate(true)
    _triggered_events = data.get("triggered_events", []).duplicate()
    _chapter_completion_flags = data.get("chapter_completion_flags", {}).duplicate(true)
    print("[StoryManager] Save data applied, chapter: ", get_chapter_name())

## 重置剧情进度
func reset_progress() -> void:
    current_chapter = Chapter.PROLOGUE
    current_story_flags.clear()
    faction_reputation = {
        Faction.EMPIRE: 0,
        Faction.PIRATES: 0,
        Faction.DEEP_SEA_CHAPEL: 0
    }
    _triggered_events.clear()
    _chapter_completion_flags.clear()
    _save_progress()
    print("[StoryManager] Progress reset")

# ========== 私有方法 ==========
func _on_chapter_changed(old_chapter: int, new_chapter: int) -> void:
    print("[StoryManager] Chapter changed: %s -> %s" % [
        CHAPTER_NAMES.get(old_chapter, "?"),
        CHAPTER_NAMES.get(new_chapter, "?")
    ])
    
    # 通知 GameState
    if _game_state_node:
        _game_state_node.set("story_progress", new_chapter)

func _check_event_triggers(flag: String) -> void:
    # 检查是否有监听该标志的事件
    if _event_listeners.has(flag):
        for callback in _event_listeners[flag]:
            if callback.is_valid():
                callback.call()

func _save_progress() -> void:
    var save_data: Dictionary = get_save_data()
    var json_str := JSON.stringify(save_data)
    var path := "user://story_progress.save"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(json_str)
        file.close()
        print("[StoryManager] Progress saved")

func _load_progress() -> void:
    var path := "user://story_progress.save"
    if not FileAccess.file_exists(path):
        print("[StoryManager] No save file found, starting fresh")
        return
    
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        print("[StoryManager] Failed to load progress")
        return
    
    var json_str := file.get_as_text()
    file.close()
    
    var result: Variant = JSON.parse_string(json_str)
    if result and typeof(result) == TYPE_DICTIONARY:
        apply_save_data(result as Dictionary)
        print("[StoryManager] Progress loaded")
    else:
        print("[StoryManager] Invalid save file format")