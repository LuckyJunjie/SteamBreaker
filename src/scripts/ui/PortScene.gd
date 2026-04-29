extends Node2D
# === PortScene.gd ===
# 港口场景主控制器
# 职责：显示4个交互点（船坞/酒馆/公会/商店），管理场景切换

signal open_ship_editor()
signal open_tavern()
signal open_bounty_board()
signal open_shop()
signal exit_port()

# 港口配置
const PORT_NAME = "铁锈湾"
const PORT_DESC = "欢迎来到老船长的避风港"

# 可交互点定义（position为场景坐标）
const INTERACT_POINTS = {
    "shipyard": {
        "position": Vector2(200, 300),
        "label": "船坞",
        "icon": "🏠",
        "desc": "船只改装与维修"
    },
    "tavern": {
        "position": Vector2(500, 200),
        "label": "酒馆「沉锚」",
        "icon": "🍺",
        "desc": "招募伙伴 & 闲聊"
    },
    "bounty_board": {
        "position": Vector2(700, 350),
        "label": "赏金公会",
        "icon": "📋",
        "desc": "接取悬赏任务"
    },
    "shop": {
        "position": Vector2(400, 450),
        "label": "杂货商店",
        "icon": "🛒",
        "desc": "购买道具与部件"
    }
}

var _hovered_point: String = ""
var _active_panel: Control = null

# UI节点引用（通过路径查找）
var _port_title: Label = null
var _desc_label: Label = null
var _interaction_hint: Label = null
var _back_btn: Button = null

# 交互点图标节点（通过名称映射）
var _point_icons: Dictionary = {}
var _point_labels: Dictionary = {}

var _game_manager = null


func _ready() -> void:
    print("[PortScene] Ready - ", PORT_NAME)
    _find_nodes()
    _connect_signals()
    _setup_interact_points()
    _load_game_manager()
    _sync_port_data()
    _show_port_overview()


func _find_nodes() -> void:
    _port_title = _find_child_by_name("PortTitle")
    _desc_label = _find_child_by_name("DescLabel")
    _interaction_hint = _find_child_by_name("InteractionHint")
    _back_btn = _find_child_by_name("BackBtn")
    
    # 映射交互点图标
    _point_icons = {
        "shipyard": _find_child_by_name("ShipyardIcon"),
        "tavern": _find_child_by_name("TavernIcon"),
        "bounty_board": _find_child_by_name("BountyIcon"),
        "shop": _find_child_by_name("ShopIcon")
    }
    
    # 映射交互点标签
    _point_labels = {
        "shipyard": _find_child_by_name("ShipyardLabel"),
        "tavern": _find_child_by_name("TavernLabel"),
        "bounty_board": _find_child_by_name("BountyLabel"),
        "shop": _find_child_by_name("ShopLabel")
    }
    
    print("[PortScene] Found nodes - title:", _port_title, " hint:", _interaction_hint)


func _find_child_by_name(name: String) -> Node:
    # 递归查找子节点
    var result = _recursive_find(get_tree().root, name)
    return result


func _recursive_find(node: Node, name: String) -> Node:
    if node.name == name:
        return node
    for child in node.get_children():
        var found = _recursive_find(child, name)
        if found:
            return found
    return null


func _load_game_manager() -> void:
    # GameManager 是 systems/ 目录下的非 autoload 节点，改用 GameState autoload
    if has_node("/root/GameState"):
        _game_manager = get_node("/root/GameState")
        print("[PortScene] GameState found")


# 处理输入
func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _handle_mouse_motion(event.position)
    elif event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _handle_click(event.position)
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _on_back_pressed()


func _handle_mouse_motion(pos: Vector2) -> void:
    var hovered = _get_point_at_position(pos)
    if hovered != _hovered_point:
        _hovered_point = hovered
        _update_hover_state()
        if hovered != "":
            var info = INTERACT_POINTS[hovered]
            _show_interaction_hint("%s %s" % [info["icon"], info["desc"]])
        else:
            _hide_interaction_hint()


func _handle_click(pos: Vector2) -> void:
    var point = _get_point_at_position(pos)
    if point != "":
        _activate_point(point)


func _get_point_at_position(pos: Vector2) -> String:
    # 简单的圆形碰撞检测（半径80px）
    for key in INTERACT_POINTS:
        var pp = INTERACT_POINTS[key]["position"]
        if pos.distance_to(pp) < 80:
            return key
    return ""


# 高亮交互点
func _update_hover_state() -> void:
    for key in INTERACT_POINTS:
        var is_hovered = (key == _hovered_point)
        _set_point_highlight(key, is_hovered)


func _set_point_highlight(key: String, highlighted: bool) -> void:
    var icon = _point_icons.get(key)
    if icon:
        if highlighted:
            icon.modulate = Color(1.0, 0.8, 0.3)  # 金黄色高亮
            var tween = create_tween()
            tween.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.15)
        else:
            icon.modulate = Color(1.0, 1.0, 1.0)
            var tween = create_tween()
            tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.15)
    
    var lbl = _point_labels.get(key)
    if lbl:
        if highlighted:
            lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
        else:
            lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


# 激活交互点
func _activate_point(point_id: String) -> void:
    print("[PortScene] Activate point: ", point_id)
    
    match point_id:
        "shipyard":
            _open_ship_editor()
        "tavern":
            _open_tavern()
        "bounty_board":
            _open_bounty_board()
        "shop":
            _open_shop()


# === 子面板打开/关闭 ===

func _open_ship_editor() -> void:
    print("[PortScene] Opening ShipEditor...")
    open_ship_editor.emit()
    
    var editor_scene = load("res://scenes/ui/ShipEditor.tscn")
    if editor_scene:
        var instance = editor_scene.instantiate()
        _show_panel(instance, "ShipEditor")
    else:
        push_error("[PortScene] ERROR: ShipEditor.tscn not found at expected path")


func _open_tavern() -> void:
    print("[PortScene] Opening Tavern...")
    open_tavern.emit()
    var panel = _create_tavern_panel()
    _show_panel(panel, "Tavern")


func _open_bounty_board() -> void:
    print("[PortScene] Opening BountyBoard...")
    open_bounty_board.emit()
    
    var panel = _create_bounty_panel()
    _show_panel(panel, "BountyBoard")


func _open_shop() -> void:
    print("[PortScene] Opening Shop...")
    open_shop.emit()
    
    var panel = _create_shop_panel()
    _show_panel(panel, "Shop")


func _show_panel(panel: Control, panel_name: String) -> void:
    _clear_panels()
    
    # 隐藏港口交互点
    _set_interact_points_visible(false)
    
    if not has_node("PanelsContainer"):
        var container = Node.new()
        container.name = "PanelsContainer"
        add_child(container)
    
    get_node("PanelsContainer").add_child(panel)
    _active_panel = panel
    
    print("[PortScene] Showing panel: ", panel_name)


func _clear_panels() -> void:
    if has_node("PanelsContainer"):
        var container = get_node("PanelsContainer")
        for child in container.get_children():
            child.queue_free()


func _close_active_panel() -> void:
    _clear_panels()
    _set_interact_points_visible(true)
    _active_panel = null


func _set_interact_points_visible(visible: bool) -> void:
    for key in INTERACT_POINTS:
        var icon = _point_icons.get(key)
        if icon:
            icon.visible = visible
        var lbl = _point_labels.get(key)
        if lbl:
            lbl.visible = visible


# === UI提示 ===

func _show_interaction_hint(text: String) -> void:
    if _interaction_hint:
        _interaction_hint.text = text
        _interaction_hint.visible = true


func _hide_interaction_hint() -> void:
    if _interaction_hint:
        _interaction_hint.visible = false


# === 初始港口概览 ===

func _show_port_overview() -> void:
    if _port_title:
        _port_title.text = PORT_NAME
    if _desc_label:
        _desc_label.text = PORT_DESC

## 从 GameManager 同步当前港口数据
func _sync_port_data() -> void:
    if not _game_manager:
        return
    var port_data = _game_manager.get_current_port()
    if not port_data.is_empty():
        # 更新端口名称和描述（通过运行时变量覆盖常量）
        var dynamic_port_name = port_data.get("name", PORT_NAME)
        var dynamic_port_desc = port_data.get("desc", PORT_DESC)
        print("[PortScene] Synced port data: ", dynamic_port_name)
        # 注意：由于 const 常量无法运行时修改，这里通过变量方式使用
        # _port_title.text 在 _show_port_overview 中被设置为 PORT_NAME
        # 改为直接设置
        if _port_title:
            _port_title.text = dynamic_port_name
        if _desc_label:
            _desc_label.text = dynamic_port_desc


# === 酒馆面板创建 ===

func _create_tavern_panel() -> Control:
    var panel = Control.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.name = "TavernPanel"
    
    # 背景
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.1, 0.15, 0.97)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(bg)
    
    # 标题
    var title = Label.new()
    title.text = "🍺 酒馆「沉锚」"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 30)
    title.size = Vector2(900, 50)
    title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
    panel.add_child(title)
    
    # 返回按钮
    var back_btn = Button.new()
    back_btn.text = "← 返回港口"
    back_btn.position = Vector2(30, 30)
    back_btn.pressed.connect(_close_active_panel)
    panel.add_child(back_btn)
    
    # 招募内容
    var content = VBoxContainer.new()
    content.position = Vector2(100, 100)
    content.size = Vector2(700, 450)
    panel.add_child(content)
    
    # 分割线
    var sep1 = Label.new()
    sep1.text = "—— 伙伴招募 ——"
    sep1.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    content.add_child(sep1)
    
    # 已招募伙伴
    var recruited = _get_recruited_companions()
    var recruited_lbl = Label.new()
    if recruited.is_empty():
        recruited_lbl.text = "已招募: 尚无伙伴"
        recruited_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    else:
        var names = recruited.map(func(c): return c.name).join(", ")
        recruited_lbl.text = "已招募: " + names
    content.add_child(recruited_lbl)
    
    # 空行
    content.add_child(_make_spacer(10))
    
    # 酒馆可招募
    var avail_lbl = Label.new()
    avail_lbl.text = "酒馆中的人物:"
    avail_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
    content.add_child(avail_lbl)
    
    var companions = _load_available_companions()
    for comp in companions:
        var row = HBoxContainer.new()
        
        var icon_lbl = Label.new()
        icon_lbl.text = "👤"
        icon_lbl.custom_minimum_size.x = 40
        row.add_child(icon_lbl)
        
        var name_lbl = Label.new()
        name_lbl.text = "%s [%s]" % [comp.name, comp.species]
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name_lbl)
        
        var desc_lbl = Label.new()
        desc_lbl.text = comp.personality if "personality" in comp else ""
        desc_lbl.modulate = Color(0.6, 0.6, 0.6)
        desc_lbl.custom_minimum_size.x = 200
        row.add_child(desc_lbl)
        
        var recruit_btn = Button.new()
        var is_recruited = comp.get("is_recruited", false)
        if is_recruited:
            recruit_btn.text = "已招募"
            recruit_btn.disabled = true
        else:
            recruit_btn.text = "招募"
            recruit_btn.pressed.connect(_on_recruit_companion.bind(comp))
        row.add_child(recruit_btn)
        
        content.add_child(row)
    
    return panel


func _get_recruited_companions() -> Array:
    # 从 GameManager 获取已招募伙伴
    if _game_manager and _game_manager.has_method("get_recruited_companions"):
        return _game_manager.get_recruited_companions()
    return []


func _load_available_companions() -> Array:
    var list = []
    var companions_path = "res://resources/companions/"
    var dir = DirAccess.open(companions_path)
    if not dir:
        print("[PortScene] Warning: Cannot open companions dir")
        # 返回内置演示数据
        return _get_demo_companions()
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res = load(companions_path + file_name)
            if res:
                list.append(res)
        file_name = dir.get_next()
    dir.list_dir_end()
    
    if list.is_empty():
        return _get_demo_companions()
    return list


func _get_demo_companions() -> Array:
    return [
        {"name": "珂尔莉", "species": "鸟族", "personality": "傲娇但怕雷声", "is_recruited": false},
        {"name": "铁砧", "species": "机械改造人", "personality": "沉默寡言，嗜喝机油", "is_recruited": false},
        {"name": "深蓝", "species": "鱼人", "personality": "内向，能与鱼群对话", "is_recruited": false}
    ]


func _on_recruit_companion(comp) -> void:
    print("[PortScene] Recruiting: ", comp.name if "name" in comp else comp.get("name"))
    if comp.has("is_recruited"):
        comp.set("is_recruited", true)
    if _game_manager and _game_manager.has_method("recruit_companion"):
        _game_manager.recruit_companion(comp)
    # 刷新面板
    _close_active_panel()


# === 赏金公告板面板创建 ===

func _create_bounty_panel() -> Control:
    var panel = Control.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.name = "BountyPanel"
    
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.1, 0.15, 0.97)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(bg)
    
    var title = Label.new()
    title.text = "📋 赏金公会"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 30)
    title.size = Vector2(900, 50)
    title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
    panel.add_child(title)
    
    var back_btn = Button.new()
    back_btn.text = "← 返回港口"
    back_btn.position = Vector2(30, 30)
    back_btn.pressed.connect(_close_active_panel)
    panel.add_child(back_btn)
    
    var content = VBoxContainer.new()
    content.position = Vector2(100, 100)
    content.size = Vector2(700, 450)
    panel.add_child(content)
    
    var region_lbl = Label.new()
    region_lbl.text = "—— 当前海域「锈海湾」悬赏 ——"
    region_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
    content.add_child(region_lbl)
    
        var bounties = _load_available_bounties()
    for bounty in bounties:
        var card = _create_bounty_card(bounty)
        content.add_child(card)
    
    return panel


func _create_bounty_card(bounty) -> Control:
    var card = PanelContainer.new()
    card.custom_minimum_size.y = 110
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.35, 0.4, 0.6)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    card.add_theme_stylebox_override("panel", style)
    
    var vbox = VBoxContainer.new()
    card.add_child(vbox)
    
    # 第一行：名称+赏金
    var top = HBoxContainer.new()
    var name_lbl = Label.new()
    name_lbl.text = bounty.get("name", "?")
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
    top.add_child(name_lbl)
    
    var reward_lbl = Label.new()
    reward_lbl.text = "%d 金克朗" % bounty.get("reward_gold", 0)
    reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
    top.add_child(reward_lbl)
    vbox.add_child(top)
    
    # 等级
    var rank_lbl = Label.new()
    rank_lbl.text = "[%s]" % bounty.get("rank", "普通")
    rank_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    vbox.add_child(rank_lbl)
    
    # 描述
    var desc_lbl = Label.new()
    desc_lbl.text = bounty.get("desc", bounty.dialogue.pre_battle if "dialogue" in bounty else "")
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
    vbox.add_child(desc_lbl)
    
    # 条件
    var cond_lbl = Label.new()
    cond_lbl.text = "出现: %s" % bounty.get("conditions", "任意")
    cond_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
    vbox.add_child(cond_lbl)
    
    # 按钮
    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    
    var is_defeated = bounty.get("is_defeated", false)
    if is_defeated:
        var ok_lbl = Label.new()
        ok_lbl.text = "已击败 ✓"
        ok_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
        btn_row.add_child(ok_lbl)
    else:
        var accept_btn = Button.new()
        accept_btn.text = "接取"
        accept_btn.pressed.connect(_on_accept_bounty.bind(bounty))
        btn_row.add_child(accept_btn)
    
    vbox.add_child(btn_row)
    return card


func _load_available_bounties() -> Array:
    var list = []
    var bounties_path = "res://resources/bounties/"
    var dir = DirAccess.open(bounties_path)
    if not dir:
        return _get_demo_bounties()
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res = load(bounties_path + file_name)
            if res:
                list.append(res)
        file_name = dir.get_next()
    dir.list_dir_end()
    
    if list.is_empty():
        return _get_demo_bounties()
    return list


func _get_demo_bounties() -> Array:
    return [
        {"name": "「铁牙」独眼鲨", "rank": "海域级", "reward_gold": 3000, "desc": "装备铁制下颚的巨大鲨鱼，咬碎过无数船只。", "conditions": "风暴中出现", "is_defeated": false},
        {"name": "幽灵船「悔恨女王」", "rank": "海域级", "reward_gold": 8000, "desc": "神秘的幽灵船，击毁桅杆幽灵灯可造成伤害。", "conditions": "雾气弥漫", "is_defeated": false},
        {"name": "帝国叛将「黑炉」", "rank": "史诗级", "reward_gold": 20000, "desc": "驾驶雷钢战列舰的旧帝国将军。", "conditions": "主线剧情解锁", "is_defeated": false}
    ]


func _on_accept_bounty(bounty) -> void:
    print("[PortScene] Accepted bounty: ", bounty.get("name", "?"))
    if _game_manager and _game_manager.has_method("accept_bounty"):
        _game_manager.accept_bounty(bounty)


# === 商店面板创建 ===

func _create_shop_panel() -> Control:
    var panel = Control.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.name = "ShopPanel"
    
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.1, 0.15, 0.97)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(bg)
    
    var title = Label.new()
    title.text = "🛒 杂货商店"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 30)
    title.size = Vector2(900, 50)
    title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
    panel.add_child(title)
    
    var back_btn = Button.new()
    back_btn.text = "← 返回港口"
    back_btn.position = Vector2(30, 30)
    back_btn.pressed.connect(_close_active_panel)
    panel.add_child(back_btn)
    
    # 玩家金币显示
    var gold_lbl = Label.new()
    gold_lbl.text = "持有金币: %d 金克朗" % _get_player_gold()
    gold_lbl.position = Vector2(600, 30)
    gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    panel.add_child(gold_lbl)
    
    var content = VBoxContainer.new()
    content.position = Vector2(100, 100)
    content.size = Vector2(700, 450)
    panel.add_child(content)
    
    var shop_lbl = Label.new()
    shop_lbl.text = "—— 商品列表 ——"
    shop_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    content.add_child(shop_lbl)
    
    var items = [
        {"name": "木板修复包", "price": 100, "desc": "恢复200耐久", "icon": "🔧"},
        {"name": "锅炉清洁剂", "price": 80, "desc": "降低30过热值", "icon": "🧴"},
        {"name": "烟雾弹", "price": 150, "desc": "紧急回避+50%", "icon": "💨"},
        {"name": "声呐浮标", "price": 200, "desc": "显示周围敌舰", "icon": "📡"},
        {"name": "陈年朗姆", "price": 50, "desc": "贝索船长喜好", "icon": "🍾"},
        {"name": "铁皮装甲", "price": 300, "desc": "防御+3回合", "icon": "🛡️"},
        {"name": "穿甲弹", "price": 250, "desc": "无视30%护甲", "icon": "💥"},
        {"name": "燃烧弹", "price": 180, "desc": "持续火焰伤害", "icon": "🔥"}
    ]
    
    for item in items:
        var row = HBoxContainer.new()
        row.custom_minimum_size.y = 36
        
        var icon_lbl = Label.new()
        icon_lbl.text = item["icon"]
        icon_lbl.custom_minimum_size.x = 40
        row.add_child(icon_lbl)
        
        var name_lbl = Label.new()
        name_lbl.text = item["name"]
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name_lbl)
        
        var desc_lbl = Label.new()
        desc_lbl.text = item["desc"]
        desc_lbl.modulate = Color(0.5, 0.5, 0.5)
        desc_lbl.custom_minimum_size.x = 160
        row.add_child(desc_lbl)
        
        var price_lbl = Label.new()
        price_lbl.text = "%d金" % item["price"]
        price_lbl.modulate = Color(1.0, 0.85, 0.3)
        price_lbl.custom_minimum_size.x = 80
        row.add_child(price_lbl)
        
        var buy_btn = Button.new()
        buy_btn.text = "购买"
        buy_btn.pressed.connect(_on_buy_item.bind(item))
        row.add_child(buy_btn)
        
        content.add_child(row)
    
    return panel


func _get_player_gold() -> int:
    return GameState.gold


func _on_buy_item(item: Dictionary) -> void:
    var price = item["price"]
    if not GameState.spend_gold(price):
        print("[PortScene] Not enough gold for: ", item["name"])
        return
    
    print("[PortScene] Bought: ", item["name"])
    
    # 刷新商店UI
    _close_active_panel()


# === 信号和返回处理 ===

func _connect_signals() -> void:
    if _back_btn:
        _back_btn.pressed.connect(_on_back_pressed)
    # 连接离港信号到 GameManager
    exit_port.connect(_on_exit_port_requested)

func _on_exit_port_requested() -> void:
    print("[PortScene] Exit port requested, departing...")
    if _game_manager and _game_manager.has_method("depart_from_port"):
        _game_manager.depart_from_port()
    else:
        print("[PortScene] GameManager not found for departure")


func _on_back_pressed() -> void:
    if _active_panel:
        _close_active_panel()
    else:
        print("[PortScene] Exit port")
        exit_port.emit()


func _setup_interact_points() -> void:
    print("[PortScene] Interact points configured")
    for key in INTERACT_POINTS:
        print("  ", key, ": ", INTERACT_POINTS[key]["position"], " ", INTERACT_POINTS[key]["icon"])


func _make_spacer(height: int) -> Control:
    var spacer = Control.new()
    spacer.custom_minimum_size.y = height
    return spacer