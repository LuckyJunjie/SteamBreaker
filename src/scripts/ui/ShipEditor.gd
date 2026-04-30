extends Control

# === ShipEditor.gd ===
# 船只改装界面控制器
# 职责：显示船只配置、槽位选择、属性预览、安装/卸下部件、购买确认

const SLOT_TYPE_ORDER = ["hull", "boiler", "helm", "weapon", "secondary", "special"]
const SLOT_TYPE_LABELS = {
    "hull": "船体",
    "boiler": "锅炉",
    "helm": "操舵室",
    "weapon": "主炮",
    "secondary": "副炮",
    "special": "特殊装置",
}

# 拖拽预览尺寸
const DRAG_PREVIEW_SIZE = 64

signal loadout_changed(loadout: ShipLoadout)
signal editor_confirmed(loadout: ShipLoadout)
signal editor_cancelled()
signal preview_updated(preview: ShipLoadout, diff: Dictionary)

var _current_loadout: ShipLoadout = null
var _preview_loadout: ShipLoadout = null
var _all_parts: Dictionary = {
    "hull": [],
    "boiler": [],
    "helm": [],
    "weapon": [],
    "secondary": [],
    "special": [],
}

# 拖拽状态
var _dragged_part: Resource = null
var _drag_preview: Control = null
var _drag_slot_type: String = ""
var _drag_ghost: Label = null
var _drop_target_slot: String = ""

# 差价计算（当前 vs 预览）
var _cost_diff: int = 0
var _player_gold: int = 0

# UI节点引用
var _slots_vbox: VBoxContainer = null
var _ship_name_label: Label = null
var _ship_icon_label: Label = null
var _weight_bar_fill: Panel = null
var _weight_values_label: Label = null
var _hp_preview: Label = null
var _speed_preview: Label = null
var _turn_preview: Label = null
var _firepower_preview: Label = null
var _load_preview: Label = null
var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _gold_label: Label = null
var _cost_label: Label = null
var _cost_diff_label: Label = null
var _message_label: Label = null

# 属性差值显示节点
var _diff_hp: Label = null
var _diff_speed: Label = null
var _diff_turn: Label = null
var _diff_firepower: Label = null
var _diff_load: Label = null

# 商店/装备列表（内联面板）
var _shop_vbox: VBoxContainer = null


# ============================================================
# Godot Native Drag — 装备列表拖拽
# ============================================================

func _get_drag_data(pos: Vector2) -> Dictionary:
    var control = _find_control_at_pos(pos)
    if not control:
        return {}

    var part = control.get_meta("part")
    var slot_type = control.get_meta("slot_type")

    if part:
        # 跳过当前已安装的装备（不允许拖拽自身）
        var current = _get_current_part_for_slot(slot_type)
        if current == part:
            return {}

        _dragged_part = part
        _drag_slot_type = slot_type

        # 创建拖拽预览
        var preview = Control.new()
        preview.custom_minimum_size = Vector2(DRAG_PREVIEW_SIZE, 30)
        var bg = ColorRect.new()
        bg.color = Color(0.2, 0.6, 1.0, 0.85)
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        preview.add_child(bg)
        var lbl = Label.new()
        lbl.text = part.part_name
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.set_anchors_preset(Control.PRESET_CENTER)
        preview.add_child(lbl)
        set_drag_preview(preview)

        return {"part": part, "slot_type": slot_type}

    return {}


func _find_control_at_pos(pos: Vector2) -> Control:
    # pos 是 local to self
    if not _slots_vbox:
        return null
    for row in _slots_vbox.get_children():
        if row is Control and row.get_global_rect().has_point(get_global_transform().xform(pos)):
            var found = _find_part_meta_in_children(row)
            if found:
                return found
    # 也检查商店面板
    if _shop_vbox:
        for child in _shop_vbox.get_children():
            if child is Control and child.has_meta("part"):
                if child.get_global_rect().has_point(get_global_transform().xform(pos)):
                    return child
    return null


func _find_part_meta_in_children(node: Node) -> Control:
    for child in node.get_children():
        if child is Control:
            if child.has_meta("part"):
                return child
            var recursive = _find_part_meta_in_children(child)
            if recursive:
                return recursive
    return null


func _can_drop_data(pos: Vector2, data: Dictionary) -> bool:
    if not data.has("part") or not data.has("slot_type"):
        return false
    var target_slot = _get_slot_at_pos(pos)
    if target_slot == "":
        return false
    return target_slot == data["slot_type"]


func _drop_data(pos: Vector2, data: Dictionary) -> void:
    if not data.has("part"):
        return

    var slot_type = _get_slot_at_pos(pos)
    if slot_type == "" or slot_type != data["slot_type"]:
        _play_reject_feedback()
        return

    _install_part_to_slot(data["part"], slot_type)
    _refresh_ui()
    _update_cost_diff()
    preview_updated.emit(_preview_loadout, _calc_diff())


func _get_slot_at_pos(pos: Vector2) -> String:
    # pos 是 local to self
    if not _slots_vbox:
        return ""
    var global_pos = get_global_transform().xform(pos)
    for row in _slots_vbox.get_children():
        if row is Control and row.has_meta("slot_type") and row.get_global_rect().has_point(global_pos):
            return row.get_meta("slot_type")
    return ""


# ============================================================
# 右键菜单 — 卸下装备
# ============================================================

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            var local_pos = event.position
            var slot_type = _get_slot_at_pos(local_pos)
            if slot_type != "":
                var current = _get_current_part_for_slot(slot_type)
                if current:
                    _show_slot_context_menu(slot_type, current, get_global_mouse_position())


func _show_slot_context_menu(slot_type: String, current_part: Resource, screen_pos: Vector2) -> void:
    var menu = PopupMenu.new()
    menu.add_item("卸下 %s" % current_part.part_name, SLOT_ACTION_REMOVE)
    menu.add_item("替换 %s" % current_part.part_name, SLOT_ACTION_REPLACE)
    menu.id_pressed.connect(_on_slot_menu_id_pressed.bind(slot_type))
    add_child(menu)
    menu.position = screen_pos
    menu.popup()


enum SLOT_ACTION { SLOT_ACTION_REMOVE = 1, SLOT_ACTION_REPLACE = 2 }


func _on_slot_menu_id_pressed(id: int, slot_type: String) -> void:
    match id:
        SLOT_ACTION.SLOT_ACTION_REMOVE:
            _remove_part_from_slot(slot_type)
            _refresh_ui()
            _update_cost_diff()
            preview_updated.emit(_preview_loadout, _calc_diff())
        SLOT_ACTION.SLOT_ACTION_REPLACE:
            _show_part_picker(slot_type)


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
    print("[ShipEditor] Ready")
    _find_nodes()
    _connect_signals()
    _scan_available_parts()
    _load_player_gold()
    if _current_loadout:
        _preview_loadout = _current_loadout.duplicate_loadout()
        _refresh_ui()
        _update_cost_diff()


func _find_nodes() -> void:
    _slots_vbox = $HSplit/RightPanel/SlotsMargin/SlotsList/SlotsScroll/SlotsVBox
    _ship_name_label = $HSplit/LeftPanel/PreviewArea/ShipPreview/ShipNameLabel
    _ship_icon_label = $HSplit/LeftPanel/PreviewArea/ShipPreview/ShipIconLabel
    _weight_bar_fill = $BottomPanel/StatsMargin/StatsHBox/WeightSection/WeightBarFill
    _weight_values_label = $BottomPanel/StatsMargin/StatsHBox/WeightSection/WeightValues
    _hp_preview = $BottomPanel/StatsMargin/StatsHBox/StatsSection/HPPreview
    _speed_preview = $BottomPanel/StatsMargin/StatsHBox/StatsSection/SpeedPreview
    _turn_preview = $BottomPanel/StatsMargin/StatsHBox/StatsSection/TurnPreview
    _confirm_btn = $BottomPanel/StatsMargin/StatsHBox/ButtonsSection/ConfirmBtn
    _cancel_btn = $BottomPanel/StatsMargin/StatsHBox/ButtonsSection/CancelBtn

    # 新增节点（通过路径或递归查找）
    _gold_label = $BottomPanel/StatsMargin/StatsHBox/GoldSection/GoldLabel
    _cost_label = $BottomPanel/StatsMargin/StatsHBox/GoldSection/CostLabel
    _cost_diff_label = $BottomPanel/StatsMargin/StatsHBox/GoldSection/CostDiffLabel
    _message_label = $BottomPanel/StatsMargin/StatsHBox/GoldSection/MessageLabel

    _diff_hp = _find_child_recursive($HSplit, "DiffHP")
    _diff_speed = _find_child_recursive($HSplit, "DiffSpeed")
    _diff_turn = _find_child_recursive($HSplit, "DiffTurn")
    _diff_firepower = _find_child_recursive($HSplit, "DiffFirepower")
    _diff_load = _find_child_recursive($HSplit, "DiffLoad")
    _firepower_preview = _find_child_recursive($BottomPanel, "FirepowerPreview")
    _load_preview = _find_child_recursive($BottomPanel, "LoadPreview")
    _shop_vbox = _find_child_recursive($HSplit, "ShopVBox")

    print("[ShipEditor] Nodes found: slots=%s confirm=%s gold=%s" % [_slots_vbox, _confirm_btn, _gold_label])


func _find_child_recursive(node: Node, name: String) -> Node:
    if not node:
        return null
    if node.name == name:
        return node
    for child in node.get_children():
        var found = _find_child_recursive(child, name)
        if found:
            return found
    return null


func _connect_signals() -> void:
    if _confirm_btn:
        _confirm_btn.pressed.connect(_on_confirm_pressed)
    if _cancel_btn:
        _cancel_btn.pressed.connect(_on_cancel_pressed)


func _load_player_gold() -> void:
    _player_gold = GameState.gold if GameState else 0


# ============================================================
# 公开 API
# ============================================================

func set_loadout(loadout: ShipLoadout) -> void:
    _current_loadout = loadout
    if loadout:
        _preview_loadout = loadout.duplicate_loadout()
    else:
        _preview_loadout = ShipLoadout.new()
    _refresh_ui()
    _update_cost_diff()


func get_loadout() -> ShipLoadout:
    return _preview_loadout


# ============================================================
# 部件扫描
# ============================================================

func _scan_available_parts() -> void:
    var parts_dir = "res://resources/parts/"
    var dir = DirAccess.open(parts_dir)
    if not dir:
        print("[ShipEditor] Warning: Cannot open parts directory: ", parts_dir)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res = load(parts_dir + file_name)
            if res and res.get("part_type"):
                var pt: String = res.part_type
                if pt in _all_parts:
                    _all_parts[pt].append(res)
                    print("[ShipEditor] Loaded part: ", res.part_name, " (", pt, ") price=", res.price)
        file_name = dir.get_next()
    dir.list_dir_end()


# ============================================================
# UI 刷新
# ============================================================

func _refresh_ui() -> void:
    if not _preview_loadout:
        return
    _update_ship_preview()
    _update_slots_list()
    _update_stats()
    _update_shop_list()
    _update_diff_display()
    loadout_changed.emit(_preview_loadout)


func _update_ship_preview() -> void:
    if _ship_name_label:
        _ship_name_label.text = _preview_loadout.ship_name
    var icon = "⚓"
    if _preview_loadout.hull:
        var ht = _preview_loadout.hull.hull_type.to_lower() if "hull_type" in _preview_loadout.hull else ""
        if "scout" in ht or "侦察" in _preview_loadout.hull.part_name:
            icon = "🚤"
        elif "ironclad" in ht or "铁甲" in _preview_loadout.hull.part_name:
            icon = "⚔️"
        elif "battleship" in ht or "战列" in _preview_loadout.hull.part_name:
            icon = "🏴‍☠️"
    if _ship_icon_label:
        _ship_icon_label.text = icon


func _update_slots_list() -> void:
    if not _slots_vbox:
        return

    for child in _slots_vbox.get_children():
        child.queue_free()

    for slot_type in SLOT_TYPE_LABELS:
        var parts_for_slot = _get_parts_for_slot(slot_type)
        var current_part = _get_current_part_for_slot(slot_type)
        _create_slot_row(slot_type, SLOT_TYPE_LABELS[slot_type], current_part, parts_for_slot)


func _get_parts_for_slot(slot_type: String) -> Array:
    return _all_parts.get(slot_type, [])


func _get_current_part_for_slot(slot_type: String) -> Resource:
    if not _preview_loadout:
        return null
    match slot_type:
        "hull":
            return _preview_loadout.hull
        "boiler":
            return _preview_loadout.boiler
        "helm":
            return _preview_loadout.helm
        "weapon":
            return _preview_loadout.main_weapons[0] if _preview_loadout.main_weapons.size() > 0 else null
        "secondary":
            return _preview_loadout.secondary_weapons[0] if _preview_loadout.secondary_weapons.size() > 0 else null
        "special":
            return _preview_loadout.special_devices[0] if _preview_loadout.special_devices.size() > 0 else null
    return null


func _create_slot_row(slot_type: String, label: String, current_part: Resource, available_parts: Array) -> void:
    var row = HBoxContainer.new()
    row.custom_minimum_size.y = 44
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.set_meta("slot_type", slot_type)
    row.gui_drag_highlight = true

    # 槽位标签
    var lbl = Label.new()
    lbl.text = label
    lbl.custom_minimum_size.x = 80
    lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    row.add_child(lbl)

    # 当前部件（可拖拽）
    var current_lbl = Label.new()
    if current_part:
        current_lbl.text = current_part.part_name + " [%.0fkg]" % current_part.weight
        current_lbl.set_meta("part", current_part)
        current_lbl.set_meta("slot_type", slot_type)
    else:
        current_lbl.text = "(空)"
        current_lbl.modulate = Color(0.6, 0.6, 0.6)
        current_lbl.set_meta("slot_type", slot_type)
    current_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    current_lbl.draggable = true
    current_lbl.gui_event.connect(_on_current_part_gui_event.bind(slot_type, current_lbl))
    row.add_child(current_lbl)

    # 选择按钮
    var select_btn = Button.new()
    select_btn.text = "选择"
    select_btn.pressed.connect(_on_slot_select_pressed.bind(slot_type, current_part))
    row.add_child(select_btn)

    # 卸下按钮（仅当有部件时）
    if current_part:
        var remove_btn = Button.new()
        remove_btn.text = "卸下"
        remove_btn.pressed.connect(_on_slot_remove_pressed.bind(slot_type))
        row.add_child(remove_btn)

    _slots_vbox.add_child(row)


func _on_current_part_gui_event(event: InputEvent, slot_type: String, label: Label) -> void:
    # 右键点击当前装备打开菜单
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            var part = label.get_meta("part") if label.has_meta("part") else null
            if part:
                _show_slot_context_menu(slot_type, part, get_global_mouse_position())


# ============================================================
# 商店/装备列表（内联面板）
# ============================================================

func _update_shop_list() -> void:
    if not _shop_vbox:
        return

    for child in _shop_vbox.get_children():
        child.queue_free()

    var title = Label.new()
    title.text = "可用装备"
    title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
    _shop_vbox.add_child(title)

    for slot_type in SLOT_TYPE_LABELS:
        var parts = _get_parts_for_slot(slot_type)
        if parts.is_empty():
            continue

        var slot_header = Label.new()
        slot_header.text = "—— %s ——" % SLOT_TYPE_LABELS[slot_type]
        slot_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
        slot_header.custom_minimum_size.y = 20
        _shop_vbox.add_child(slot_header)

        for part in parts:
            var row = _create_shop_part_row(part, slot_type)
            _shop_vbox.add_child(row)


func _create_shop_part_row(part: Resource, slot_type: String) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.custom_minimum_size.y = 36
    row.set_meta("part", part)
    row.set_meta("slot_type", slot_type)
    row.draggable = true

    var name_lbl = Label.new()
    name_lbl.text = part.part_name
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.draggable = true
    name_lbl.set_meta("part", part)
    name_lbl.set_meta("slot_type", slot_type)
    row.add_child(name_lbl)

    var weight_lbl = Label.new()
    weight_lbl.text = "%.0fkg" % part.weight
    weight_lbl.custom_minimum_size.x = 60
    weight_lbl.modulate = Color(0.6, 0.6, 0.6)
    row.add_child(weight_lbl)

    var price_lbl = Label.new()
    var price: int = part.price if "price" in part else 0
    price_lbl.text = "%d金" % price
    price_lbl.custom_minimum_size.x = 80
    price_lbl.modulate = Color(1.0, 0.85, 0.3)
    row.add_child(price_lbl)

    var install_btn = Button.new()
    install_btn.text = "装上"
    install_btn.pressed.connect(_on_shop_install_pressed.bind(part, slot_type))
    row.add_child(install_btn)

    return row


func _on_shop_install_pressed(part: Resource, slot_type: String) -> void:
    _install_part_to_slot(part, slot_type)
    _refresh_ui()
    _update_cost_diff()
    preview_updated.emit(_preview_loadout, _calc_diff())


# ============================================================
# 部件安装 / 卸下
# ============================================================

func _on_slot_select_pressed(slot_type: String, current_part: Resource) -> void:
    print("[ShipEditor] Select slot: ", slot_type)
    _show_part_picker(slot_type)


func _on_slot_remove_pressed(slot_type: String) -> void:
    print("[ShipEditor] Remove from slot: ", slot_type)
    _remove_part_from_slot(slot_type)
    _refresh_ui()
    _update_cost_diff()
    preview_updated.emit(_preview_loadout, _calc_diff())


func _show_part_picker(slot_type: String) -> void:
    var picker = PartPickerPopup.new()
    picker.part_type = slot_type
    picker.available_parts = _all_parts.get(slot_type, [])
    picker.part_selected.connect(_on_part_selected.bind(slot_type))
    get_tree().root.add_child(picker)
    picker.popup_centered(Vector2(400, 320))


func _on_part_selected(part: Resource, slot_type: String) -> void:
    print("[ShipEditor] Part selected: ", part.part_name, " for slot: ", slot_type)
    _install_part_to_slot(part, slot_type)
    _refresh_ui()
    _update_cost_diff()
    preview_updated.emit(_preview_loadout, _calc_diff())


func _install_part_to_slot(part: Resource, slot_type: String) -> void:
    if not _preview_loadout:
        return

    match slot_type:
        "hull":
            _preview_loadout.hull = part as ShipHull
        "boiler":
            _preview_loadout.boiler = part as ShipBoiler
        "helm":
            _preview_loadout.helm = part as ShipHelm
        "weapon":
            if _preview_loadout.main_weapons.is_empty():
                _preview_loadout.main_weapons.append(part as ShipWeapon)
            else:
                _preview_loadout.main_weapons[0] = part as ShipWeapon
        "secondary":
            if _preview_loadout.secondary_weapons.is_empty():
                _preview_loadout.secondary_weapons.append(part as ShipSecondary)
            else:
                _preview_loadout.secondary_weapons[0] = part as ShipSecondary
        "special":
            if _preview_loadout.special_devices.is_empty():
                _preview_loadout.special_devices.append(part as ShipSpecial)
            else:
                _preview_loadout.special_devices[0] = part as ShipSpecial

    if _preview_loadout.is_overloaded():
        print("[ShipEditor] WARNING: Ship is overloaded! ratio=%.2f" % _preview_loadout.get_weight_ratio())


func _remove_part_from_slot(slot_type: String) -> void:
    if not _preview_loadout:
        return

    match slot_type:
        "hull":
            _preview_loadout.hull = null
        "boiler":
            _preview_loadout.boiler = null
        "helm":
            _preview_loadout.helm = null
        "weapon":
            if not _preview_loadout.main_weapons.is_empty():
                _preview_loadout.main_weapons[0] = null
        "secondary":
            if not _preview_loadout.secondary_weapons.is_empty():
                _preview_loadout.secondary_weapons[0] = null
        "special":
            if not _preview_loadout.special_devices.is_empty():
                _preview_loadout.special_devices[0] = null


# ============================================================
# 属性统计 & 差值高亮
# ============================================================

func _update_stats() -> void:
    if not _preview_loadout:
        return

    var total_weight = _preview_loadout.get_total_weight()
    var cargo_cap = _preview_loadout.get_cargo_capacity()

    if _weight_values_label:
        _weight_values_label.text = "%.0f / %.0f kg" % [total_weight, cargo_cap]

    if _weight_bar_fill:
        var fill_ratio = mini(total_weight / max(cargo_cap, 1.0), 1.5)
        _weight_bar_fill.anchor_right = clamp(fill_ratio, 0.0, 1.0)
        if _preview_loadout.is_overloaded():
            _weight_bar_fill.modulate = Color(1.0, 0.2, 0.2)
        else:
            _weight_bar_fill.modulate = Color(0.3, 0.8, 0.3)

    # HP
    var max_hp = _preview_loadout.get_max_hp()
    if _hp_preview:
        _hp_preview.text = "耐久: %d" % max_hp

    # 航速
    var speed_bonus = _preview_loadout.get_speed_bonus()
    var speed_str = "航速: +%d" % speed_bonus
    if _preview_loadout.is_overloaded():
        speed_str += " ⚠️超载！"
    if _speed_preview:
        _speed_preview.text = speed_str

    # 转向
    var turn_bonus = _preview_loadout.get_turn_bonus()
    if _turn_preview:
        _turn_preview.text = "转向: +%d" % turn_bonus

    # 火力
    var firepower = _calc_firepower(_preview_loadout)
    if _firepower_preview:
        _firepower_preview.text = "火力: %d" % firepower

    # 载重
    if _load_preview:
        _load_preview.text = "载重: %.0f/%.0f" % [total_weight, cargo_cap]


func _update_diff_display() -> void:
    if not _current_loadout:
        return

    var diff = _calc_diff()

    _set_diff_label(_diff_hp, diff.get("hp", 0))
    _set_diff_label(_diff_speed, diff.get("speed", 0))
    _set_diff_label(_diff_turn, diff.get("turn", 0))
    _set_diff_label(_diff_firepower, diff.get("firepower", 0))
    _set_diff_label(_diff_load, diff.get("load", 0.0))


func _set_diff_label(lbl: Label, delta: Variant) -> void:
    if not lbl:
        return
    if delta is float:
        var d: float = delta as float
        if absf(d) < 0.01:
            lbl.text = ""
            lbl.modulate = Color(1, 1, 1)
        elif d > 0:
            lbl.text = "+%.0fkg" % d
            lbl.modulate = Color(1.0, 0.3, 0.3)  # 红色：更重
        else:
            lbl.text = "%.0fkg" % d
            lbl.modulate = Color(0.3, 1.0, 0.4)  # 绿色：更轻
    else:
        var d: int = delta as int
        if d == 0:
            lbl.text = ""
            lbl.modulate = Color(1, 1, 1)
        elif d > 0:
            lbl.text = "+%d" % d
            lbl.modulate = Color(0.3, 1.0, 0.4)  # 绿色：提升
        else:
            lbl.text = "%d" % d
            lbl.modulate = Color(1.0, 0.3, 0.3)  # 红色：下降


# ============================================================
# 差价计算
# ============================================================

func _calc_diff() -> Dictionary:
    if not _current_loadout:
        return {"hp": 0, "speed": 0, "turn": 0, "firepower": 0, "load": 0.0}

    return {
        "hp": _preview_loadout.get_max_hp() - _current_loadout.get_max_hp(),
        "speed": _preview_loadout.get_speed_bonus() - _current_loadout.get_speed_bonus(),
        "turn": _preview_loadout.get_turn_bonus() - _current_loadout.get_turn_bonus(),
        "firepower": _calc_firepower(_preview_loadout) - _calc_firepower(_current_loadout),
        "load": _preview_loadout.get_total_weight() - _current_loadout.get_total_weight(),
    }


func _calc_firepower(loadout: ShipLoadout) -> int:
    var total: int = 0
    for w in loadout.main_weapons:
        if w and "firepower" in w:
            total += w.firepower as int
    for s in loadout.secondary_weapons:
        if s and "firepower" in s:
            total += (s.firepower as int) / 2
    return total


func _update_cost_diff() -> void:
    _cost_diff = calculate_cost_diff()

    if _cost_label:
        if _cost_diff > 0:
            _cost_label.text = "需支付: %d 金" % _cost_diff
            _cost_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
        elif _cost_diff < 0:
            _cost_label.text = "可回收: %d 金" % (-_cost_diff)
            _cost_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
        else:
            _cost_label.text = "无需费用"
            _cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

    if _gold_label:
        _gold_label.text = "持有: %d 金" % _player_gold

    # 检查金币是否足够
    var can_afford = _cost_diff <= _player_gold
    if _message_label:
        if _cost_diff > _player_gold:
            _message_label.text = "⚠️ 金币不足！"
            _message_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
        else:
            _message_label.text = ""
    if _confirm_btn:
        _confirm_btn.disabled = not can_afford

    # 差值颜色
    if _cost_diff_label:
        if _cost_diff > 0:
            _cost_diff_label.text = "+%d" % _cost_diff
            _cost_diff_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
        elif _cost_diff < 0:
            _cost_diff_label.text = "%d" % _cost_diff
            _cost_diff_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
        else:
            _cost_diff_label.text = "±0"


func calculate_cost_diff() -> int:
    if not _current_loadout:
        return 0
    return _calc_total_parts_cost(_preview_loadout) - _calc_total_parts_cost(_current_loadout)


func _calc_total_parts_cost(loadout: ShipLoadout) -> int:
    var total: int = 0
    if loadout.hull and "price" in loadout.hull:
        total += loadout.hull.price as int
    if loadout.boiler and "price" in loadout.boiler:
        total += loadout.boiler.price as int
    if loadout.helm and "price" in loadout.helm:
        total += loadout.helm.price as int
    for w in loadout.main_weapons:
        if w and "price" in w:
            total += w.price as int
    for s in loadout.secondary_weapons:
        if s and "price" in s:
            total += s.price as int
    for sp in loadout.special_devices:
        if sp and "price" in sp:
            total += sp.price as int
    return total


# ============================================================
# 确认 / 取消
# ============================================================

func _on_confirm_pressed() -> void:
    # 最终金币检查
    if _cost_diff > _player_gold:
        _show_message("金币不足，无法完成改装！")
        return

    # 扣除金币
    if _cost_diff > 0:
        if not GameState.spend_gold(_cost_diff):
            _show_message("金币扣除失败！")
            return
        _player_gold = GameState.gold

    # 应用改装到 GameState.player_ship
    if GameState and GameState.player_ship:
        GameState.player_ship.apply_loadout(_preview_loadout)
    elif _current_loadout:
        _current_loadout = _preview_loadout.duplicate_loadout()

    # 同时通知 ShipFactory（使用autoload）
    ShipFactory.apply_loadout(_preview_loadout)

    print("[ShipEditor] Confirmed! Cost diff: %d, remaining gold: %d" % [_cost_diff, _player_gold])
    editor_confirmed.emit(_preview_loadout)
    loadout_changed.emit(_preview_loadout)
    _show_message("改装完成！")


func _on_cancel_pressed() -> void:
    print("[ShipEditor] Cancelled")
    editor_cancelled.emit()


func _show_message(msg: String) -> void:
    if _message_label:
        _message_label.text = msg
    else:
        print("[ShipEditor] Message: ", msg)


# ============================================================
# 拒绝反馈
# ============================================================

func _play_reject_feedback() -> void:
    if _slots_vbox:
        var tween = create_tween()
        var flash = Color(1, 0, 0, 0.4)
        var normal = Color(1, 1, 1, 1)
        for i in range(3):
            tween.tween_property(_slots_vbox, "modulate", flash, 0.1)
            tween.tween_property(_slots_vbox, "modulate", normal, 0.1)
        tween.play()


# ============================================================
# 内嵌弹窗：部件选择器
# ============================================================

class PartPickerPopup extends PopupPanel:
    var part_type: String = ""
    var available_parts: Array = []
    signal part_selected(part: Resource)

    func _ready() -> void:
        var margin = MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 12)
        margin.add_theme_constant_override("margin_top", 12)
        margin.add_theme_constant_override("margin_right", 12)
        margin.add_theme_constant_override("margin_bottom", 12)
        add_child(margin)

        var vbox = VBoxContainer.new()
        margin.add_child(vbox)

        var title = Label.new()
        title.text = "选择部件"
        vbox.add_child(title)

        var scroll = ScrollContainer.new()
        scroll.custom_minimum_size.y = 200
        vbox.add_child(scroll)

        var list = VBoxContainer.new()
        scroll.add_child(list)

        for part in available_parts:
            var btn = Button.new()
            var price: int = part.price if "price" in part else 0
            btn.text = "%s [%.0fkg] - %d金" % [part.part_name, part.weight, price]
            btn.pressed.connect(_on_part_btn_pressed.bind(part))
            list.add_child(btn)

        var close_btn = Button.new()
        close_btn.text = "关闭"
        close_btn.pressed.connect(_hide)
        vbox.add_child(close_btn)

    func _on_part_btn_pressed(part: Resource) -> void:
        part_selected.emit(part)
        _hide()

    func _hide() -> void:
        hide()
        queue_free()
