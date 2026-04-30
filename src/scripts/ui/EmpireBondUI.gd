extends Control
# === EmpireBondUI.gd ===
# 帝国债券交易界面
# 玩家可购买三种债券（工业/海军/探索），持有债券在特定事件触发时获得分红

signal bond_purchased(bond_type: int, cost: int)
signal bond_sold(bond_type: int, quantity: int, revenue: int)
signal panel_closed()

const BOND_TYPE_INDUSTRIAL = 0
const BOND_TYPE_NAVAL = 1
const BOND_TYPE_EXPLORATION = 2

const BOND_NAMES = {
    BOND_TYPE_INDUSTRIAL: "工业债券",
    BOND_TYPE_NAVAL: "海军债券",
    BOND_TYPE_EXPLORATION: "探索债券"
}

const BOND_PRICES: Dictionary = {
    BOND_TYPE_INDUSTRIAL: 100,
    BOND_TYPE_NAVAL: 200,
    BOND_TYPE_EXPLORATION: 150
}

const BOND_RETURNS: Dictionary = {
    BOND_TYPE_INDUSTRIAL: 120,  # 20% return
    BOND_TYPE_NAVAL: 250,       # 25% return
    BOND_TYPE_EXPLORATION: 180  # 20% return
}

const BOND_ICONS: Dictionary = {
    BOND_TYPE_INDUSTRIAL: "🏭",
    BOND_TYPE_NAVAL: "⚓",
    BOND_TYPE_EXPLORATION: "🧭"
}

const BOND_DESCS: Dictionary = {
    BOND_TYPE_INDUSTRIAL: "帝国工业债券，稳健分红 20%",
    BOND_TYPE_NAVAL: "帝国海军债券，高额分红 25%",
    BOND_TYPE_EXPLORATION: "帝国探索债券，分红 20%"
}

var owned_bonds: Dictionary = {
    BOND_TYPE_INDUSTRIAL: 0,
    BOND_TYPE_NAVAL: 0,
    BOND_TYPE_EXPLORATION: 0
}

var _main_vbox: VBoxContainer = null
var _gold_label: Label = null


func _ready() -> void:
    print("[EmpireBondUI] Ready")
    _load_saved_bonds()
    _build_ui()


func _load_saved_bonds() -> void:
    # 从 GameState 加载已保存的债券数据
    if GameState and GameState.has_method("get_bonds"):
        var saved: Dictionary = GameState.get_bonds()
        if not saved.is_empty():
            for key in saved.keys():
                var k = int(key) if key is String else key
                owned_bonds[k] = saved[key]
            print("[EmpireBondUI] Loaded bonds: ", owned_bonds)


func _save_bonds() -> void:
    # 保存债券数据到 GameState
    if GameState and GameState.has_method("set_bonds"):
        GameState.set_bonds(owned_bonds)


func _build_ui() -> void:
    # 背景
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.1, 0.15, 0.97)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # 主容器
    _main_vbox = VBoxContainer.new()
    _main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    _main_vbox.add_theme_constant_override("separation", 12)
    add_child(_main_vbox)

    # 标题栏
    var header = HBoxContainer.new()
    header.custom_minimum_size.y = 60
    _main_vbox.add_child(header)

    var title = Label.new()
    title.text = "📜 帝国债券交易所"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.custom_minimum_size = Vector2(40, 40)
    close_btn.pressed.connect(_on_close_pressed)
    header.add_child(close_btn)

    # 金币显示
    _gold_label = Label.new()
    _gold_label.text = "💰 持有金币: %d 金克朗" % GameState.gold
    _gold_label.add_theme_font_size_override("font_size", 14)
    _gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    _main_vbox.add_child(_gold_label)

    # 债券列表
    var bonds_label = Label.new()
    bonds_label.text = "—— 可购买债券 ——"
    bonds_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    _main_vbox.add_child(bonds_label)

    for bond_type in [BOND_TYPE_INDUSTRIAL, BOND_TYPE_NAVAL, BOND_TYPE_EXPLORATION]:
        var card = _create_bond_card(bond_type)
        _main_vbox.add_child(card)

    # 持有债券显示
    var held_label = Label.new()
    held_label.text = "—— 持有中的债券 ——"
    held_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    _main_vbox.add_child(held_label)

    for bond_type in [BOND_TYPE_INDUSTRIAL, BOND_TYPE_NAVAL, BOND_TYPE_EXPLORATION]:
        var held_row = _create_held_bond_row(bond_type)
        _main_vbox.add_child(held_row)

    # 分红按钮
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND
    _main_vbox.add_child(spacer)

    var action_row = HBoxContainer.new()
    _main_vbox.add_child(action_row)

    var collect_btn = Button.new()
    collect_btn.text = "💵 领取债券分红"
    collect_btn.custom_minimum_size = Vector2(200, 44)
    collect_btn.pressed.connect(_on_collect_returns_pressed)
    action_row.add_child(collect_btn)

    var info_lbl = Label.new()
    info_lbl.text = "债券在港口或特定事件触发时分红"
    info_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_row.add_child(info_lbl)


func _create_bond_card(bond_type: int) -> PanelContainer:
    var card = PanelContainer.new()
    card.custom_minimum_size.y = 80

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
    style.set_corner_radius_all(6)
    style.set_border_width_all(1)
    style.border_color = Color(0.4, 0.6, 0.8, 0.4)
    style.set_content_margin_all(12)
    card.add_theme_stylebox_override("panel", style)

    var row = HBoxContainer.new()
    card.add_child(row)

    # 图标
    var icon_lbl = Label.new()
    icon_lbl.text = BOND_ICONS[bond_type]
    icon_lbl.add_theme_font_size_override("font_size", 28)
    icon_lbl.custom_minimum_size.x = 50
    row.add_child(icon_lbl)

    # 信息
    var info_vbox = VBoxContainer.new()
    info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var name_lbl = Label.new()
    name_lbl.text = BOND_NAMES[bond_type]
    name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
    name_lbl.add_theme_font_size_override("font_size", 14)
    info_vbox.add_child(name_lbl)

    var desc_lbl = Label.new()
    desc_lbl.text = BOND_DESCS[bond_type]
    desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    desc_lbl.add_theme_font_size_override("font_size", 11)
    info_vbox.add_child(desc_lbl)

    var price_lbl = Label.new()
    price_lbl.text = "发行价: %d 金克朗 → 到期偿还: %d 金克朗" % [BOND_PRICES[bond_type], BOND_RETURNS[bond_type]]
    price_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
    price_lbl.add_theme_font_size_override("font_size", 11)
    info_vbox.add_child(price_lbl)

    row.add_child(info_vbox)

    # 购买按钮
    var buy_btn = Button.new()
    buy_btn.text = "购买"
    buy_btn.custom_minimum_size = Vector2(80, 36)
    buy_btn.pressed.connect(_on_buy_bond_pressed.bind(bond_type))
    row.add_child(buy_btn)

    return card


func _create_held_bond_row(bond_type: int) -> Control:
    var row = HBoxContainer.new()
    row.custom_minimum_size.y = 36

    var icon_lbl = Label.new()
    icon_lbl.text = BOND_ICONS[bond_type]
    icon_lbl.custom_minimum_size.x = 40
    row.add_child(icon_lbl)

    var name_lbl = Label.new()
    name_lbl.text = BOND_NAMES[bond_type]
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_lbl)

    var count_lbl = Label.new()
    count_lbl.name = "Count_%d" % bond_type
    count_lbl.text = "x%d" % owned_bonds[bond_type]
    count_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
    count_lbl.custom_minimum_size.x = 50
    row.add_child(count_lbl)

    var sell_btn = Button.new()
    sell_btn.text = "卖出"
    sell_btn.custom_minimum_size = Vector2(60, 28)
    sell_btn.pressed.connect(_on_sell_bond_pressed.bind(bond_type))
    row.add_child(sell_btn)

    return row


func _refresh_ui() -> void:
    if _gold_label:
        _gold_label.text = "💰 持有金币: %d 金克朗" % GameState.gold

    # 更新持有数量显示
    for bond_type in [BOND_TYPE_INDUSTRIAL, BOND_TYPE_NAVAL, BOND_TYPE_EXPLORATION]:
        var count_lbl = _main_vbox.find_child("Count_%d" % bond_type, true, false) as Label
        if count_lbl:
            count_lbl.text = "x%d" % owned_bonds[bond_type]


func purchase_bond(bond_type: int) -> bool:
    var cost = BOND_PRICES[bond_type]
    if GameState.gold < cost:
        print("[EmpireBondUI] Not enough gold for bond type %d: need %d, have %d" % [bond_type, cost, GameState.gold])
        return false

    if not GameState.spend_gold(cost):
        return false

    owned_bonds[bond_type] += 1
    _save_bonds()
    _refresh_ui()
    bond_purchased.emit(bond_type, cost)
    print("[EmpireBondUI] Purchased %s for %d gold. Owned: %d" % [BOND_NAMES[bond_type], cost, owned_bonds[bond_type]])
    return true


func sell_bond(bond_type: int) -> bool:
    if owned_bonds[bond_type] <= 0:
        print("[EmpireBondUI] No bonds of type %d to sell" % bond_type)
        return false

    var revenue = BOND_RETURNS[bond_type]
    owned_bonds[bond_type] -= 1
    GameState.add_gold(revenue)
    _save_bonds()
    _refresh_ui()
    bond_sold.emit(bond_type, 1, revenue)
    print("[EmpireBondUI] Sold %s for %d gold. Remaining: %d" % [BOND_NAMES[bond_type], revenue, owned_bonds[bond_type]])
    return true


func _calculate_total_returns() -> int:
    var total = 0
    for bond_type in owned_bonds:
        var count = owned_bonds[bond_type]
        if count > 0:
            total += BOND_RETURNS[bond_type] * count
    return total


func _collect_all_returns() -> int:
    """兑现所有债券（按到期价值），返回总收益"""
    var total = 0
    for bond_type in owned_bonds:
        var count = owned_bonds[bond_type]
        if count > 0:
            total += BOND_RETURNS[bond_type] * count
            owned_bonds[bond_type] = 0

    if total > 0:
        GameState.add_gold(total)
        _save_bonds()
        _refresh_ui()
        print("[EmpireBondUI] Collected all bond returns: +%d gold" % total)

    return total


# === 信号处理 ===

func _on_buy_bond_pressed(bond_type: int) -> void:
    if not purchase_bond(bond_type):
        _show_message("金币不足！")


func _on_sell_bond_pressed(bond_type: int) -> void:
    if not sell_bond(bond_type):
        _show_message("没有可卖出的债券！")


func _on_collect_returns_pressed() -> void:
    var total_returns = _calculate_total_returns()
    if total_returns == 0:
        _show_message("没有持有任何债券！")
        return

    var collected = _collect_all_returns()
    if collected > 0:
        _show_message("债券兑现！+%d 金克朗" % collected)


func _on_close_pressed() -> void:
    panel_closed.emit()
    queue_free()


func _show_message(msg: String) -> void:
    print("[EmpireBondUI] %s" % msg)
    # 简单弹出提示（复用人造浮文字）
    var popup = Panel.new()
    popup.custom_minimum_size = Vector2(300, 60)
    popup.set_anchors_preset(Control.PRESET_CENTER)
    popup.z_index = 100

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
    style.set_corner_radius_all(8)
    style.set_border_width_all(2)
    style.border_color = Color(0.9, 0.7, 0.2)
    popup.add_theme_stylebox_override("panel", style)
    add_child(popup)

    var lbl = Label.new()
    lbl.text = msg
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
    popup.add_child(lbl)

    await get_tree().create_timer(1.5).timeout
    popup.queue_free()


# === 供外部调用的接口 ===

func get_owned_count(bond_type: int) -> int:
    return owned_bonds.get(bond_type, 0)


func get_total_returns() -> int:
    return _calculate_total_returns()
