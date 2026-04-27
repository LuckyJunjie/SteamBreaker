extends Control
# === BountyBoardUI.gd ===
# 赏金公告板界面控制器
# 职责：显示悬赏列表、接取赏金任务、追踪赏金进度

signal bounty_accepted(bounty_id: String)
signal bounty_viewed(bounty_id: String)
signal board_closed()

const BOARD_NAME = "赏金公会"

var _available_bounties: Array = []
var _active_bounties: Array = []  # 已接取的赏金
var _current_region: String = "rusty_gulf"  # 当前海域

# UI节点
var _title_lbl: Label = null
var _region_lbl: Label = null
var _bounties_container: VBoxContainer = null
var _close_btn: Button = null


func _ready() -> void:
    print("[BountyBoardUI] Ready")
    _find_nodes()
    _load_bounties()
    _populate_bounties()


func _find_nodes() -> void:
    _title_lbl = get_node_or_null(["TitleLabel", "BountyTitle", "VBox/Title"])
    _region_lbl = get_node_or_null(["RegionLabel"])
    _bounties_container = get_node_or_null(["BountiesList", "BountiesContainer", "ScrollContainer/ListVBox"])
    _close_btn = get_node_or_null(["CloseBtn", "CloseButton"])
    
    if _close_btn:
        _close_btn.pressed.connect(_on_close_pressed)


func _load_bounties() -> void:
    # 从资源配置加载悬赏
    _available_bounties.clear()
    
    var bounties_path = "res://src/resources/bounties/"
    var dir = DirAccess.open(bounties_path)
    if not dir:
        print("[BountyBoardUI] Warning: Cannot open bounties directory")
        _load_demo_bounties()
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res = load(bounties_path + file_name)
            if res:
                _available_bounties.append(res)
                print("[BountyBoardUI] Loaded bounty: ", res.name)
        file_name = dir.get_next()
    dir.list_dir_end()
    
    if _available_bounties.is_empty():
        _load_demo_bounties()


func _load_demo_bounties() -> void:
    # 无配置文件时的演示数据
    _available_bounties = [
        {
            "bounty_id": "bounty_irontooth_shark",
            "name": "「铁牙」独眼鲨",
            "rank": "海域级",
            "reward_gold": 3000,
            "desc": "一条装备铁制下颚的巨大鲨鱼，咬碎过无数船只。",
            "conditions": "风暴中出现",
            "is_defeated": false
        },
        {
            "bounty_id": "bounty_ghost_queen",
            "name": "幽灵船「悔恨女王」",
            "rank": "海域级",
            "reward_gold": 8000,
            "desc": "一艘神秘的幽灵船，吸收船员生命力。击毁桅杆上的幽灵灯可造成伤害。",
            "conditions": "雾气弥漫的夜晚",
            "is_defeated": false
        },
        {
            "bounty_id": "bounty_black_furnace",
            "name": "帝国叛将「黑炉」",
            "rank": "史诗级",
            "reward_gold": 20000,
            "desc": "驾驶雷钢战列舰的旧帝国将军，拥有压倒性的火力和装甲。",
            "conditions": "主线剧情解锁",
            "is_defeated": false
        }
    ]


func _populate_bounties() -> void:
    if not _bounties_container:
        print("[BountyBoardUI] Warning: BountiesContainer not found, creating dynamically")
        _create_board_layout()
        return
    
    # 清除旧列表
    foreach_child(_bounties_container, func(c): c.queue_free())
    
    # 标题
    var header = Label.new()
    header.text = "—— 当前海域「%s」悬赏 ——" % _current_region
    header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
    _bounties_container.add_child(header)
    
    for bounty in _available_bounties:
        _add_bounty_row(bounty)


func _add_bounty_row(bounty) -> void:
    var card = PanelContainer.new()
    card.custom_minimum_size.y = 120
    card.add_theme_stylebox_override("panel", _get_card_style())
    
    var vbox = VBoxContainer.new()
    card.add_child(vbox)
    
    # 第一行：名称+悬赏金
    var top_row = HBoxContainer.new()
    
    var name_lbl = Label.new()
    name_lbl.text = bounty.get("name", bounty.name if "name" in bounty else "?")
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
    top_row.add_child(name_lbl)
    
    var reward_lbl = Label.new()
    reward_lbl.text = "赏金: %d 金克朗" % bounty.get("reward_gold", 0)
    reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    top_row.add_child(reward_lbl)
    
    vbox.add_child(top_row)
    
    # 等级标签
    var rank_row = HBoxContainer.new()
    var rank_lbl = Label.new()
    rank_lbl.text = "[%s]" % bounty.get("rank", "普通")
    rank_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
    rank_row.add_child(rank_lbl)
    vbox.add_child(rank_row)
    
    # 描述
    var desc_lbl = Label.new()
    desc_lbl.text = bounty.get("desc", bounty.dialogue.pre_battle if "dialogue" in bounty else "")
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_lbl.custom_minimum_size.y = 30
    desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    vbox.add_child(desc_lbl)
    
    # 条件
    var cond_lbl = Label.new()
    cond_lbl.text = "出现条件: %s" % bounty.get("conditions", "任意")
    cond_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    vbox.add_child(cond_lbl)
    
    # 按钮行
    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    
    if bounty.get("is_defeated", false):
        var defeated_lbl = Label.new()
        defeated_lbl.text = "已击败 ✓"
        defeated_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
        btn_row.add_child(defeated_lbl)
    else:
        var accept_btn = Button.new()
        accept_btn.text = "接取任务"
        accept_btn.pressed.connect(_on_accept_bounty.bind(bounty))
        btn_row.add_child(accept_btn)
        
        var view_btn = Button.new()
        view_btn.text = "详情"
        view_btn.pressed.connect(_on_view_bounty.bind(bounty))
        btn_row.add_child(view_btn)
    
    vbox.add_child(btn_row)
    _bounties_container.add_child(card)


func _get_card_style() -> StyleBox:
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.15, 0.18, 0.22, 0.9)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.35, 0.4, 0.8)
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style


func _create_board_layout() -> void:
    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 10)
    add_child(vbox)
    _bounties_container = vbox
    
    _populate_bounties()


func _on_accept_bounty(bounty) -> void:
    var bounty_id = bounty.get("bounty_id", "")
    print("[BountyBoardUI] Accepting bounty: ", bounty_id or bounty.bounty_id)
    
    if bounty_id != "":
        bounty_accepted.emit(bounty_id)
    
    # 标记为已接取
    if "is_defeated" in bounty:
        bounty["is_accepted"] = true
    
    # 通知 GameManager
    if has_node("/root/GameManager"):
        var gm = get_node("/root/GameManager")
        if gm.has_method("accept_bounty"):
            gm.accept_bounty(bounty)
    
    # 刷新显示
    _populate_bounties()


func _on_view_bounty(bounty) -> void:
    var bounty_id = bounty.get("bounty_id", "")
    print("[BountyBoardUI] Viewing bounty details: ", bounty_id or bounty.bounty_id)
    bounty_viewed.emit(bounty_id)


func _on_close_pressed() -> void:
    print("[BountyBoardUI] Closed")
    board_closed.emit()
    get_tree().quit()


# 辅助函数
func foreach_child(node: Node, fn: Callable) -> void:
    for child in node.get_children():
        fn.call(child)