extends Control

# === ShipEditor.gd ===
# 船只改装界面控制器
# 职责：显示船只配置、槽位选择、属性预览、安装/卸下部件

const SLOT_TYPE_ORDER = ["hull", "boiler", "helm", "weapon", "secondary", "special"]
const SLOT_TYPE_LABELS = {
    "hull": "船体",
    "boiler": "锅炉",
    "helm": "操舵室",
    "weapon": "主炮",
    "secondary": "副炮",
    "special": "特殊装置",
}

signal loadout_changed(loadout: ShipLoadout)
signal editor_confirmed(loadout: ShipLoadout)
signal editor_cancelled()

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

# 槽位UI引用
var _slots_vbox: VBoxContainer = null
var _ship_name_label: Label = null
var _ship_icon_label: Label = null
var _weight_bar_fill: Panel = null
var _weight_values_label: Label = null
var _hp_preview: Label = null
var _speed_preview: Label = null
var _turn_preview: Label = null
var _confirm_btn: Button = null
var _cancel_btn: Button = null


func _ready() -> void:
    print("[ShipEditor] Ready")
    _find_nodes()
    _connect_signals()
    _scan_available_parts()
    if _current_loadout:
        _preview_loadout = _current_loadout.duplicate()
        _refresh_ui()


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


func _connect_signals() -> void:
    if _confirm_btn:
        _confirm_btn.pressed.connect(_on_confirm_pressed)
    if _cancel_btn:
        _cancel_btn.pressed.connect(_on_cancel_pressed)


# 公开方法：设置当前船只配置
func set_loadout(loadout: ShipLoadout) -> void:
    _current_loadout = loadout
    if loadout:
        _preview_loadout = loadout.duplicate()
    else:
        _preview_loadout = ShipLoadout.new()
    _refresh_ui()


func get_loadout() -> ShipLoadout:
    return _preview_loadout


# 扫描所有可用部件
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
                    print("[ShipEditor] Loaded part: ", res.part_name, " (", pt, ")")
        file_name = dir.get_next()
    dir.list_dir_end()


# 刷新整个UI
func _refresh_ui() -> void:
    if not _preview_loadout:
        return
    _update_ship_preview()
    _update_slots_list()
    _update_stats()
    loadout_changed.emit(_preview_loadout)


# 更新船只预览区
func _update_ship_preview() -> void:
    if _ship_name_label:
        _ship_name_label.text = _preview_loadout.ship_name
    # 根据船体类型显示不同图标
    var icon = "⚓"
    if _preview_loadout.hull:
        var ht = _preview_loadout.hull.hull_type.to_lower()
        if "scout" in ht or "侦察" in _preview_loadout.hull.part_name:
            icon = "🚤"
        elif "ironclad" in ht or "铁甲" in _preview_loadout.hull.part_name:
            icon = "⚔️"
        elif "battleship" in ht or "战列" in _preview_loadout.hull.part_name:
            icon = "🏴‍☠️"
    if _ship_icon_label:
        _ship_icon_label.text = icon


# 更新槽位列表
func _update_slots_list() -> void:
    if not _slots_vbox:
        return

    # 清除旧槽位
    for child in _slots_vbox.get_children():
        child.queue_free()

    # 生成槽位行
    for slot_type in SLOT_TYPE_LABELS:
        var parts_for_slot = _get_parts_for_slot(slot_type)
        var current_part = _get_current_part_for_slot(slot_type)
        _create_slot_row(slot_type, SLOT_TYPE_LABELS[slot_type], current_part, parts_for_slot)


func _get_parts_for_slot(slot_type: String) -> Array:
    if slot_type in ["weapon", "secondary", "special"]:
        return _all_parts.get(slot_type, [])
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

    # 槽位名称
    var lbl = Label.new()
    lbl.text = label
    lbl.custom_minimum_size.x = 80
    lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    row.add_child(lbl)

    # 当前部件显示
    var current_lbl = Label.new()
    if current_part:
        current_lbl.text = current_part.part_name + " [%.0fkg]" % current_part.weight
    else:
        current_lbl.text = "(空)"
        current_lbl.modulate = Color(0.6, 0.6, 0.6)
    current_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(current_lbl)

    # 选择按钮
    var select_btn = Button.new()
    select_btn.text = "选择"
    select_btn.pressed.connect(_on_slot_select_pressed.bind(slot_type, current_part))
    row.add_child(select_btn)

    # 卸下按钮（如果有部件）
    if current_part:
        var remove_btn = Button.new()
        remove_btn.text = "卸下"
        remove_btn.pressed.connect(_on_slot_remove_pressed.bind(slot_type))
        row.add_child(remove_btn)

    _slots_vbox.add_child(row)


func _on_slot_select_pressed(slot_type: String, current_part: Resource) -> void:
    print("[ShipEditor] Select slot: ", slot_type, " current: ", current_part)
    _show_part_picker(slot_type)


func _on_slot_remove_pressed(slot_type: String) -> void:
    print("[ShipEditor] Remove from slot: ", slot_type)
    _remove_part_from_slot(slot_type)
    _refresh_ui()


# 部件选择面板（内联实现，弹出式）
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

    # 验证重量超载警告
    if _preview_loadout.is_overloaded():
        print("[ShipEditor] WARNING: Ship is overloaded! ", _preview_loadout.get_weight_ratio())


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


# 更新属性统计显示
func _update_stats() -> void:
    if not _preview_loadout:
        return

    var total_weight = _preview_loadout.get_total_weight()
    var cargo_cap = _preview_loadout.get_cargo_capacity()
    var ratio = cargo_cap / max(cargo_cap, 1.0)  # avoid div0

    # 重量进度条
    if _weight_values_label:
        _weight_values_label.text = "%.0f / %.0f kg" % [total_weight, cargo_cap]

    if _weight_bar_fill:
        var fill_ratio = mini(total_weight / max(cargo_cap, 1.0), 1.5)
        # 用anchor_right控制填充宽度
        _weight_bar_fill.anchor_right = clamp(fill_ratio, 0.0, 1.0)
        # 超载时变红
        if _preview_loadout.is_overloaded():
            _weight_bar_fill.modulate = Color(1.0, 0.2, 0.2)
        else:
            _weight_bar_fill.modulate = Color(0.3, 0.8, 0.3)

    # HP预览
    var max_hp = _preview_loadout.get_max_hp()
    var hp_str = "耐久: %d" % max_hp
    if _preview_loadout.current_hp > 0:
        hp_str += " (当前: %d)" % _preview_loadout.current_hp
    if _hp_preview:
        _hp_preview.text = hp_str

    # 航速预览
    var speed_bonus = _preview_loadout.get_speed_bonus()
    var speed_str = "航速: +%d" % speed_bonus
    if _preview_loadout.is_overloaded():
        speed_str += " ⚠️超载！"
    if _speed_preview:
        _speed_preview.text = speed_str

    # 转向预览
    var turn_bonus = _preview_loadout.get_turn_bonus()
    if _turn_preview:
        _turn_preview.text = "转向: +%d" % turn_bonus


# === 按钮回调 ===
func _on_confirm_pressed() -> void:
    print("[ShipEditor] Confirmed. Loadout: ", _preview_loadout)
    editor_confirmed.emit(_preview_loadout)


func _on_cancel_pressed() -> void:
    print("[ShipEditor] Cancelled")
    editor_cancelled.emit()


# === 内嵌弹窗：部件选择器 ===
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
            btn.text = "%s [%.0fkg] - %d金" % [part.part_name, part.weight, part.price]
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
