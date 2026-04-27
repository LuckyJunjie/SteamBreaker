extends CanvasLayer
class_name SaveLoadUI

## Steam Breaker Save/Load UI
## 存档/读档界面

signal save_selected(slot: int)
signal load_selected(slot: int)
signal new_game_requested()
signal ui_closed()

const MAX_SLOTS := 10

@onready var main_container: VBoxContainer = null
@onready var title_label: Label = null
@onready var slots_container: VBoxContainer = null
@onready var buttons_container: HBoxContainer = null
@onready var status_label: Label = null

var _save_manager: Node = null
var _slots: Array[Button] = []
var _is_save_mode: bool = true
var _current_preview_data: SaveData = null

# ============================================
# Initialization / 初始化
# ============================================

func _ready():
    print("[SaveLoadUI] Initializing...")
    _setup_ui()
    _find_save_manager()
    refresh_slot_list()

func _setup_ui() -> void:
    # Main container
    main_container = VBoxContainer.new()
    main_container.set_anchors_preset(Control.PRESET_CENTER)
    main_container.custom_minimum_size = Vector2(500, 400)
    main_container.position = Vector2(-250, -200)
    add_child(main_container)

    # Title
    title_label = Label.new()
    title_label.text = "存档"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 24)
    title_label.custom_minimum_size = Vector2(500, 40)
    main_container.add_child(title_label)

    # Slots scroll container
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(500, 300)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    main_container.add_child(scroll)

    slots_container = VBoxContainer.new()
    slots_container.custom_minimum_size = Vector2(480, 300)
    scroll.add_child(slots_container)

    # Separator
    var sep := HSeparator.new()
    sep.custom_minimum_size = Vector2(500, 2)
    main_container.add_child(sep)

    # Buttons
    buttons_container = HBoxContainer.new()
    buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
    main_container.add_child(buttons_container)

    _create_buttons()

    # Status label
    status_label = Label.new()
    status_label.text = ""
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 14)
    main_container.add_child(status_label)

    # Close button (ESC)
    var close_btn := Button.new()
    close_btn.text = "关闭 (ESC)"
    close_btn.custom_minimum_size = Vector2(120, 30)
    close_btn.pressed.connect(_on_close_pressed)
    main_container.add_child(close_btn)

func _create_buttons() -> void:
    var new_game_btn := Button.new()
    new_game_btn.text = "新游戏"
    new_game_btn.custom_minimum_size = Vector2(100, 40)
    new_game_btn.pressed.connect(_on_new_game_pressed)
    buttons_container.add_child(new_game_btn)

    var refresh_btn := Button.new()
    refresh_btn.text = "刷新"
    refresh_btn.custom_minimum_size = Vector2(80, 40)
    refresh_btn.pressed.connect(refresh_slot_list)
    buttons_container.add_child(refresh_btn)

func _find_save_manager() -> void:
    var root := get_tree().root
    _save_manager = root.find_child("SaveManager", true, false)
    if not _save_manager:
        print("[SaveLoadUI] SaveManager not found, creating temporary one")
        _save_manager = Node.new()
        _save_manager.set_script(load("res://scripts/systems/SaveManager.gd"))
        root.add_child(_save_manager)

# ============================================
# Public API / 公开接口
# ============================================

func set_save_mode(is_save: bool) -> void:
    _is_save_mode = is_save
    if title_label:
        title_label.text = is_save ? "存档" : "读档"
    refresh_slot_list()

func set_preview_data(data: SaveData) -> void:
    _current_preview_data = data

func show() -> void:
    visible = true
    refresh_slot_list()

func hide() -> void:
    visible = false

func refresh_slot_list() -> void:
    if not slots_container:
        return
    
    # Clear existing slots
    for child in slots_container.get_children():
        child.queue_free()
    _slots.clear()
    
    # Get save info
    var saves: Array[Dictionary] = []
    if _save_manager and _save_manager.has_method("list_saves"):
        saves = _save_manager.list_saves()
    else:
        # Generate empty slots
        for i in range(MAX_SLOTS):
            saves.append({"slot": i, "has_save": false})
    
    # Create slot buttons
    for save_info in saves:
        var slot_btn: Button = _create_slot_button(save_info)
        slots_container.add_child(slot_btn)
        _slots.append(slot_btn)

# ============================================
# Slot Button Creation / 槽位按钮创建
# ============================================

func _create_slot_button(info: Dictionary) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size = Vector2(480, 60)
    
    var hbox := HBoxContainer.new()
    btn.add_child(hbox)
    
    # Slot number
    var slot_label := Label.new()
    slot_label.text = "槽位 %d" % info["slot"]
    slot_label.custom_minimum_size = Vector2(80, 30)
    hbox.add_child(slot_label)
    
    # Info container
    var info_vbox := VBoxContainer.new()
    hbox.add_child(info_vbox)
    
    if info.get("has_save", false):
        # Has save - show details
        var name_label := Label.new()
        name_label.text = info.get("player_name", "船长")
        name_label.add_theme_font_size_override("font_size", 16)
        info_vbox.add_child(name_label)
        
        var detail_label := Label.new()
        var ts: String = info.get("timestamp_formatted", "未知")
        var gold_val: int = info.get("gold", 0)
        var progress: int = info.get("story_progress", 0)
        detail_label.text = "%s | 金币: %d | 进度: %d" % [ts, gold_val, progress]
        detail_label.add_theme_font_size_override("font_size", 12)
        detail_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        info_vbox.add_child(detail_label)
    else:
        # Empty slot
        var empty_label := Label.new()
        empty_label.text = "[ 空槽位 ]"
        empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
        info_vbox.add_child(empty_label)
    
    # Action hint
    var hint_label := Label.new()
    hint_label.text = _is_save_mode ? "点击存档" : "点击读档"
    hint_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
    hbox.add_child(hint_label)
    
    # Connect
    var slot_num: int = info["slot"]
    btn.pressed.connect(_on_slot_pressed.bind(slot_num))
    
    return btn

# ============================================
# Event Handlers / 事件处理
# ============================================

func _on_slot_pressed(slot: int) -> void:
    if _is_save_mode:
        _handle_save(slot)
    else:
        _handle_load(slot)

func _handle_save(slot: int) -> void:
    var data: SaveData
    if _current_preview_data:
        data = _current_preview_data
    else:
        # Collect from current game state
        data = _collect_current_state()
    
    if _save_manager and _save_manager.has_method("save"):
        var success: bool = _save_manager.save(slot, data)
        if success:
            _show_status("存档成功: 槽位 %d" % slot)
            refresh_slot_list()
        else:
            _show_status("存档失败: 槽位 %d" % slot)
    else:
        # Direct save without SaveManager
        data.timestamp = Time.get_unix_time_from_system()
        var path: String = "user://saves/slot_%d.json" % slot
        var dir := DirAccess.open("user://saves")
        if not dir:
            DirAccess.make_dir_recursive("user://saves")
            dir = DirAccess.open("user://saves")
        if dir:
            var file := FileAccess.open(path, FileAccess.WRITE)
            if file:
                file.store_string(data.to_json_string())
                file.close()
                _show_status("存档成功: 槽位 %d" % slot)
                refresh_slot_list()
            else:
                _show_status("存档失败: 写入错误")
        else:
            _show_status("存档失败: 目录错误")

func _handle_load(slot: int) -> void:
    if not _save_manager:
        _show_status("错误: 未找到存档管理器")
        return
    
    if _save_manager.has_method("load"):
        var data: SaveData = _save_manager.load(slot)
        if data:
            _show_status("读档成功: 槽位 %d" % slot)
            hide()
            load_selected.emit(slot)
        else:
            _show_status("读档失败: 槽位 %d" % slot)
    else:
        # Direct load without SaveManager
        var path: String = "user://saves/slot_%d.json" % slot
        if not FileAccess.file_exists(path):
            _show_status("读档失败: 文件不存在")
            return
        
        var file := FileAccess.open(path, FileAccess.READ)
        if not file:
            _show_status("读档失败: 无法打开文件")
            return
        
        var json_str: String = file.get_as_text()
        file.close()
        
        var data: SaveData = SaveData.from_json_string(json_str)
        if data:
            _show_status("读档成功: 槽位 %d" % slot)
            hide()
            load_selected.emit(slot)
        else:
            _show_status("读档失败: 解析错误")

func _on_new_game_pressed() -> void:
    new_game_requested.emit()
    hide()

func _on_close_pressed() -> void:
    hide()
    ui_closed.emit()

func _show_status(message: String) -> void:
    if status_label:
        status_label.text = message

# ============================================
# State Collection / 状态收集
# ============================================

func _collect_current_state() -> SaveData:
    var data: SaveData = SaveData.new()
    data.player_name = "船长"
    data.gold = 1000
    data.empire_bonds = 0
    data.story_progress = 0
    data.timestamp = Time.get_unix_time_from_system()
    
    # Try to get from game state
    var root := get_tree().root
    var game_state: Node = root.find_child("GameState", true, false)
    if not game_state:
        game_state = root.find_child("GameManager", true, false)
    
    if game_state:
        data.player_name = game_state.get("player_name", "船长")
        data.gold = game_state.get("gold", 1000)
        data.empire_bonds = game_state.get("empire_bonds", 0)
        data.story_progress = game_state.get("story_progress", 0)
        data.story_flags = game_state.get("story_flags", {})
    
    # Get ship loadout
    var ship_factory: Node = root.find_child("ShipFactory", true, false)
    if ship_factory and ship_factory.has("current_loadout"):
        data.ship_loadout = ship_factory.current_loadout.duplicate()
    
    return data

# ============================================
# Input Handling / 输入处理
# ============================================

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _on_close_pressed()
        elif event.keycode == KEY_F5:
            refresh_slot_list()