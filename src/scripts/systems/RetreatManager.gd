extends Node2D
class_name RetreatManager

## Steam Breaker 隐退入口管理器
## 铁锈湾场景中的隐退入口逻辑

# ========== 信号定义 ==========
signal retreat_entered()
signal ending_preview_requested()
signal confirm_retreat()
signal cancel_retreat()

# ========== 枚举 ==========
enum RetreatState {
    IDLE,           # 默认状态，等待玩家交互
    PREVIEW,        # 显示结局预览
    CONFIRMED,      # 玩家确认隐退
    ENDING_PLAYBACK # 结局播放中
}

# ========== 常量 ==========
const RETREAT_LOCATION_NAME: String = "铁锈湾"
const RETREAT_NPC_NAME: String = "老渔夫"

# ========== 导出变量 ==========
@export var current_state: RetreatState = RetreatState.IDLE
@export var can_retreat: bool = true

# ========== 私有变量 ==========
var _ending_manager: Node = null
var _story_manager: Node = null
var _game_state_node: Node = null
var _dialogue_active: bool = false

# ========== 内置方法 ==========
func _ready() -> void:
    print("[RetreatManager] Initialized at ", RETREAT_LOCATION_NAME)
    _cache_node_references()
    _check_retreat_eligibility()

func _cache_node_references() -> void:
    var root := get_tree().root
    _ending_manager = root.find_child("EndingManager", true, false)
    _story_manager = root.find_child("StoryManager", true, false)
    _game_state_node = root.find_child("GameState", true, false)

# ========== 公开 API ==========

## 检查是否可以隐退
func check_retreat_eligibility() -> Dictionary:
    var eligibility: Dictionary = {
        "can_retreat": false,
        "reasons": [],
        "ending_preview": null
    }
    
    # 检查章节进度（需完成至少序章）
    if _story_manager:
        var chapter: int = _story_manager.get("current_chapter", 0)
        if chapter < StoryManager.Chapter.PROLOGUE:
            eligibility["reasons"].append("尚未开始旅程，无法隐退")
        else:
            eligibility["can_retreat"] = true
    else:
        # 无 StoryManager 时，允许自由隐退
        eligibility["can_retreat"] = true
    
    # 检查是否有进行中的赏金
    if _ending_manager == null:
        _cache_node_references()
    
    # 生成结局预览
    if eligibility["can_retreat"] and _ending_manager:
        eligibility["ending_preview"] = _ending_manager.get_ending_preview()
    
    return eligibility

## 显示隐退预览 UI
func show_retreat_preview() -> Dictionary:
    var preview: Dictionary = check_retreat_eligibility()
    
    if preview["can_retreat"]:
        current_state = RetreatState.PREVIEW
        ending_preview_requested.emit()
        print("[RetreatManager] Showing retreat preview")
    else:
        print("[RetreatManager] Cannot retreat: ", preview["reasons"])
    
    return preview

## 确认隐退
func confirm_retreat() -> void:
    var eligibility: Dictionary = check_retreat_eligibility()
    
    if not eligibility["can_retreat"]:
        print("[RetreatManager] Cannot confirm retreat - not eligible")
        cancel_retreat.emit()
        return
    
    print("[RetreatManager] Retreat confirmed by player")
    current_state = RetreatState.CONFIRMED
    retreat_entered.emit()
    
    # 触发结局判定
    if _ending_manager:
        var ending: int = _ending_manager.determine_ending()
        print("[RetreatManager] Ending determined: ", _ending_manager.get_ending_name())
    
    # 强制存档
    _force_final_save()

## 取消隐退
func cancel_retreat_action() -> void:
    print("[RetreatManager] Retreat cancelled")
    current_state = RetreatState.IDLE
    cancel_retreat.emit()

## 开始结局幻灯片播放
func start_ending_playback() -> void:
    if _ending_manager == null:
        push_error("[RetreatManager] EndingManager not found!")
        return
    
    current_state = RetreatState.ENDING_PLAYBACK
    _ending_manager.reset_slideshow()
    
    print("[RetreatManager] Starting ending playback")
    
    # 连接结局管理器信号
    if not _ending_manager.ending_complete.is_connected(_on_ending_complete):
        _ending_manager.ending_complete.connect(_on_ending_complete)

## 推进幻灯片
func advance_ending_slideshow() -> bool:
    if _ending_manager == null:
        return false
    
    var has_next: bool = _ending_manager.advance_slideshow()
    
    if not has_next:
        print("[RetreatManager] Slideshow complete")
    
    return has_next

## 获取当前幻灯片
func get_current_slide() -> Dictionary:
    if _ending_manager:
        return _ending_manager.get_current_slide()
    return {}

## 获取结局类型名称
func get_current_ending_name() -> String:
    if _ending_manager:
        return _ending_manager.get_ending_name()
    return "未知结局"

## 获取结局旁白
func get_ending_narrative() -> String:
    if _ending_manager:
        return _ending_manager.get_narrative_text()
    return ""

## 获取老渔夫对话数据
func get_old_fisherman_dialogue() -> Array[Dictionary]:
    var eligibility: Dictionary = check_retreat_eligibility()
    
    if eligibility["can_retreat"]:
        return [
            {
                "speaker": RETREAT_NPC_NAME,
                "text": "哦，是你啊，船长。",
                "options": [
                    {"text": "我想隐退", "action": "RETREAT", "next": 1},
                    {"text": "再等等", "action": "CANCEL", "next": -1}
                ]
            },
            {
                "speaker": RETREAT_NPC_NAME,
                "text": "想好了？一旦离开这片海域，就再也回不去了。",
                "options": [
                    {"text": "确定", "action": "CONFIRM", "next": 2},
                    {"text": "再想想", "action": "CANCEL", "next": -1}
                ]
            },
            {
                "speaker": RETREAT_NPC_NAME,
                "text": "好，去吧。愿蒸汽与你的灵魂同在。",
                "options": []
            }
        ]
    else:
        return [
            {
                "speaker": RETREAT_NPC_NAME,
                "text": "年轻人，你的旅程才刚刚开始。\n等你在海上闯出点名堂，再来找我吧。",
                "options": [
                    {"text": "明白了", "action": "CLOSE", "next": -1}
                ]
            }
        ]

## 开始与老渔夫的对话
func start_dialogue() -> void:
    _dialogue_active = true
    print("[RetreatManager] Starting dialogue with ", RETREAT_NPC_NAME)

## 结束对话
func end_dialogue() -> void:
    _dialogue_active = false
    print("[RetreatManager] Dialogue ended")

## 检查是否在对话中
func is_in_dialogue() -> bool:
    return _dialogue_active

## 获取当前状态名称
func get_state_name() -> String:
    return RetreatState.keys()[current_state]

# ========== 私有方法 ==========
func _check_retreat_eligibility() -> void:
    var eligibility: Dictionary = check_retreat_eligibility()
    can_retreat = eligibility["can_retreat"]
    
    if not can_retreat:
        print("[RetreatManager] Retreat not available: ", eligibility["reasons"])

func _force_final_save() -> void:
    # 隐退前强制保存游戏
    var save_manager: Node = null
    var root := get_tree().root
    save_manager = root.find_child("SaveManager", true, false)
    
    if save_manager and save_manager.has_method("save"):
        print("[RetreatManager] Forcing final save before retreat...")
        # 保存到槽位 9（临时/自动存档槽）
        var data = save_manager._collect_game_state() if save_manager.has_method("_collect_game_state") else null
        var result: bool = save_manager.save(9, data)
        print("[RetreatManager] Final save ", "succeeded" if result else "failed")

func _on_ending_complete() -> void:
    print("[RetreatManager] Ending playback complete")
    ending_complete.emit()

func _on_retreat_confirmed() -> void:
    confirm_retreat()

func _on_retreat_cancelled() -> void:
    cancel_retreat_action()

# ========== 与 UI 系统的接口 ==========

## 获取铁锈湾入口节点位置（用于 UI 高亮）
func get_retreat_entry_position() -> Vector2:
    return position

## 检查玩家是否在入口范围内
func is_player_in_range(player_pos: Vector2, threshold: float = 50.0) -> bool:
    return position.distance_to(player_pos) <= threshold

## 获取存档提示文本
func get_save_reminder_text() -> String:
    return "隐退后将无法返回，是否确认？"

## 获取结局解锁提示
func get_ending_hint_text() -> String:
    if _ending_manager:
        var preview: Dictionary = _ending_manager.get_ending_preview()
        if preview.has("ending_name") and preview["ending_name"] != "未知结局":
            return "根据你的旅程，你将获得「" + preview["ending_name"] + "」"
    return "完成旅程后可解锁结局"