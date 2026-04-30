extends Control

## 背包面板UI

signal closed()
signal item_selected(item_id: String)
signal item_used(item_id: String)

var _inventory_manager: Node = null
var _inventory_snapshot: Array[Dictionary] = []
var _selected_slot: int = -1

# UI节点
var _title_lbl: Label = null
var _close_btn: Button = null
var _items_container: VBoxContainer = null
var _detail_panel: PanelContainer = null
var _detail_name_lbl: Label = null
var _detail_desc_lbl: Label = null
var _detail_effect_lbl: Label = null
var _use_btn: Button = null
var _empty_lbl: Label = null

func _ready() -> void:
    print("[InventoryPanel] Ready")
    _find_nodes()
    _setup_ui()

func _find_nodes() -> void:
    _title_lbl = _find_child("TitleLabel") or _find_child("Title")
    _close_btn = _find_child("CloseBtn") as Button
    _items_container = _find_child("ItemsContainer") as VBoxContainer
    _detail_panel = _find_child("DetailPanel") as PanelContainer
    _detail_name_lbl = _find_child("DetailName") as Label
    _detail_desc_lbl = _find_child("DetailDesc") as Label
    _detail_effect_lbl = _find_child("DetailEffect") as Label
    _use_btn = _find_child("UseBtn") as Button
    _empty_lbl = _find_child("EmptyLabel") as Label

    if _close_btn:
        _close_btn.pressed.connect(_on_close_pressed)
    if _use_btn:
        _use_btn.pressed.connect(_on_use_pressed)

    # Detail panel initially hidden
    if _detail_panel:
        _detail_panel.visible = false

func _find_child(name: String) -> Node:
    var result = get_node_or_null(name)
    if result:
        return result
    # Search recursively
    return _recursive_find(self, name)

func _recursive_find(node: Node, name: String) -> Node:
    if node.name == name:
        return node
    for child in node.get_children():
        var found = _recursive_find(child, name)
        if found:
            return found
    return null

func _setup_ui() -> void:
    # 创建默认布局（如果场景中没有预设）
    if not _items_container:
        _create_default_layout()
    _refresh()

func _create_default_layout() -> void:
    # 整体使用HBoxContainer：左侧物品列表，右侧详情
    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.add_theme_constant_override("separation", 10)
    add_child(hbox)

    # 左侧：物品列表区域
    var left_panel = PanelContainer.new()
    left_panel.custom_minimum_size.x = 350
    var left_style = StyleBoxFlat.new()
    left_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
    left_style.border_width_left = 2
    left_style.border_width_right = 2
    left_style.border_width_top = 2
    left_style.border_width_bottom = 2
    left_style.border_color = Color(0.3, 0.35, 0.4, 0.5)
    left_panel.add_theme_stylebox_override("panel", left_style)
    hbox.add_child(left_panel)

    var left_vbox = VBoxContainer.new()
    left_vbox.add_theme_constant_override("separation", 5)
    left_panel.add_child(left_vbox)

    # 标题
    var title_lbl = Label.new()
    title_lbl.text = "🎒 背包"
    title_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
    title_lbl.custom_minimum_size.y = 40
    left_vbox.add_child(title_lbl)

    # 滚动容器
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size.y = 350
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_vbox.add_child(scroll)

    _items_container = VBoxContainer.new()
    _items_container.add_theme_constant_override("separation", 3)
    scroll.add_child(_items_container)

    # 关闭按钮
    _close_btn = Button.new()
    _close_btn.text = "关闭"
    _close_btn.pressed.connect(_on_close_pressed)
    left_vbox.add_child(_close_btn)

    # 右侧：详情面板
    var right_panel = PanelContainer.new()
    right_panel.custom_minimum_size.x = 300
    var right_style = StyleBoxFlat.new()
    right_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
    right_style.border_width_left = 2
    right_style.border_width_right = 2
    right_style.border_width_top = 2
    right_style.border_width_bottom = 2
    right_style.border_color = Color(0.25, 0.3, 0.35, 0.5)
    right_style.content_margin_left = 15
    right_style.content_margin_right = 15
    right_style.content_margin_top = 15
    right_style.content_margin_bottom = 15
    right_panel.add_theme_stylebox_override("panel", right_style)
    hbox.add_child(right_panel)

    var right_vbox = VBoxContainer.new()
    right_vbox.add_theme_constant_override("separation", 10)
    right_panel.add_child(right_vbox)

    _detail_panel = right_panel

    _detail_name_lbl = Label.new()
    _detail_name_lbl.text = "选择物品"
    _detail_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
    _detail_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    right_vbox.add_child(_detail_name_lbl)

    var type_lbl = Label.new()
    type_lbl.text = "类型: -"
    type_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    type_lbl.name = "DetailType"
    right_vbox.add_child(type_lbl)

    var sep = Label.new()
    sep.text = "───────────"
    sep.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
    right_vbox.add_child(sep)

    _detail_desc_lbl = Label.new()
    _detail_desc_lbl.text = "选择一个物品查看详情"
    _detail_desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    _detail_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    _detail_desc_lbl.custom_minimum_size.y = 60
    right_vbox.add_child(_detail_desc_lbl)

    _detail_effect_lbl = Label.new()
    _detail_effect_lbl.text = ""
    _detail_effect_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.6))
    _detail_effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    right_vbox.add_child(_detail_effect_lbl)

    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_vbox.add_child(spacer)

    _use_btn = Button.new()
    _use_btn.text = "使用"
    _use_btn.custom_minimum_size.y = 40
    _use_btn.disabled = true
    _use_btn.pressed.connect(_on_use_pressed)
    right_vbox.add_child(_use_btn)

func set_inventory_manager(manager: Node) -> void:
    _inventory_manager = manager
    if _inventory_manager and _inventory_manager.has_signal("inventory_changed"):
        _inventory_manager.inventory_changed.connect(_on_inventory_changed)
    _refresh()

func _on_inventory_changed() -> void:
    _refresh()

func _refresh() -> void:
    if not _inventory_manager:
        return

    _inventory_snapshot = _inventory_manager.get_inventory_snapshot()

    # Clear existing items
    if _items_container:
        foreach_child(_items_container, func(c): c.queue_free())

        if _inventory_snapshot.is_empty():
            var empty = Label.new()
            empty.text = "（背包空空如也）"
            empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
            _items_container.add_child(empty)
        else:
            for i in range(_inventory_snapshot.size()):
                var slot_data = _inventory_snapshot[i]
                var row = _create_slot_row(slot_data, i)
                _items_container.add_child(row)

    # Update empty state
    if _empty_lbl:
        _empty_lbl.visible = _inventory_snapshot.is_empty()

func _create_slot_row(slot_data: Dictionary, index: int) -> Control:
    var row = PanelContainer.new()
    row.custom_minimum_size.y = 50
    row.name = "Slot_%d" % index

    var is_selected = (index == _selected_slot)
    var style = StyleBoxFlat.new()
    if is_selected:
        style.bg_color = Color(0.2, 0.25, 0.35, 0.9)
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_color = Color(0.6, 0.5, 0.2, 0.8)
    else:
        style.bg_color = Color(0.1, 0.12, 0.18, 0.8)
        style.border_width_left = 1
        style.border_width_right = 1
        style.border_width_top = 1
        style.border_width_bottom = 1
        style.border_color = Color(0.2, 0.22, 0.28, 0.4)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    row.add_theme_stylebox_override("panel", style)

    var hbox = HBoxContainer.new()
    row.add_child(hbox)

    # Icon
    var icon_lbl = Label.new()
    icon_lbl.text = slot_data.get("icon", "📦")
    icon_lbl.custom_minimum_size.x = 40
    hbox.add_child(icon_lbl)

    # Name
    var name_lbl = Label.new()
    name_lbl.text = slot_data.get("name", "?")
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if is_selected:
        name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
    else:
        name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
    hbox.add_child(name_lbl)

    # Quantity
    var qty_lbl = Label.new()
    var qty = slot_data.get("quantity", 1)
    qty_lbl.text = "x%d" % qty if qty > 1 else ""
    qty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    qty_lbl.custom_minimum_size.x = 30
    hbox.add_child(qty_lbl)

    # Click handler
    var btn = Button.new()
    btn.flat = true
    btn.set_anchors_preset(Control.PRESET_FULL_RECT)
    btn.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _select_slot(index)
    )
    row.add_child(btn)

    return row

func _select_slot(index: int) -> void:
    _selected_slot = index
    _refresh()
    _update_detail()

func _update_detail() -> void:
    if _selected_slot < 0 or _selected_slot >= _inventory_snapshot.size():
        _clear_detail()
        return

    var slot_data = _inventory_snapshot[_selected_slot]

    if _detail_name_lbl:
        _detail_name_lbl.text = "%s %s" % [slot_data.get("icon", "📦"), slot_data.get("name", "?")]

    if _detail_desc_lbl:
        _detail_desc_lbl.text = slot_data.get("description", "")

    if _detail_effect_lbl:
        var effect = slot_data.get("effect_desc", "")
        _detail_effect_lbl.text = "效果: %s" % effect if effect else ""

    if _use_btn:
        # All items can potentially be used
        _use_btn.disabled = false

    if _detail_panel:
        _detail_panel.visible = true

    # Update type label
    var type_lbl = _detail_panel.find_child("DetailType", false, false) if _detail_panel else null
    if type_lbl is Label:
        type_lbl.text = "类型: %s" % slot_data.get("type_name", "未知")

func _clear_detail() -> void:
    if _detail_name_lbl:
        _detail_name_lbl.text = "选择物品"
    if _detail_desc_lbl:
        _detail_desc_lbl.text = "选择一个物品查看详情"
    if _detail_effect_lbl:
        _detail_effect_lbl.text = ""
    if _use_btn:
        _use_btn.disabled = true

func _on_use_pressed() -> void:
    if _selected_slot < 0 or _selected_slot >= _inventory_snapshot.size():
        return

    var slot_data = _inventory_snapshot[_selected_slot]
    var item_id = slot_data.get("item_id", "")

    if not _inventory_manager:
        return

    var success = _inventory_manager.use_item(item_id)
    if success:
        print("[InventoryPanel] Used item: %s" % item_id)
        item_used.emit(item_id)
        # After use, refresh to update quantity
        _selected_slot = -1
        _refresh()
        _clear_detail()
    else:
        print("[InventoryPanel] Failed to use item: %s" % item_id)

func _on_close_pressed() -> void:
    print("[InventoryPanel] Closed")
    closed.emit()
    queue_free()

func foreach_child(node: Node, fn: Callable) -> void:
    for child in node.get_children():
        fn.call(child)
        foreach_child(child, fn)
