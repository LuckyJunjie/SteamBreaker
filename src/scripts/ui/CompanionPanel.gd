class_name CompanionPanel
extends Control

## 伙伴羁绊面板
## 显示已招募伙伴列表、羁绊等级、已解锁技能，提供赠送礼物和对话入口

signal gift_sent(companion_id: String, item_id: String, affection_delta: int)
signal dialogue_requested(companion_id: String)
signal panel_closed()

# 伙伴羁绊等级名称
const BOND_LEVEL_NAMES: Array[String] = ["陌生", "相识", "信任", "亲密", "灵魂"]

# 种族图标映射
const SPECIES_ICONS: Dictionary = {
    "鸟族": "🐦",
    "机械改造人": "⚙️",
    "鱼人": "🐟",
    "人族": "👤"
}

# 礼物定义（ID -> {name, icon, affection_base}）
const GIFT_DEFINITIONS: Dictionary = {
    "item_flower_bouquet":  {"name": "花束",       "icon": "💐", "base": 8},
    "item_old_book":        {"name": "旧书籍",     "icon": "📖", "base": 6},
    "item_ship_model":      {"name": "船模",       "icon": "⛵", "base": 10},
    "item_rum":             {"name": "朗姆酒",     "icon": "🍾", "base": 7},
    "item_feather_fan":     {"name": "羽毛扇",     "icon": "🪶", "base": 9},
    "item_seafood_platter": {"name": "海鲜拼盘",   "icon": "🦐", "base": 7},
    "item_engine_oil":      {"name": "机械油",     "icon": "🛢️", "base": 6},
    "item_pearl":           {"name": "珍珠",       "icon": "💎", "base": 12}
}

var _companion_manager = null
var _selected_companion_id: String = ""
var _companion_buttons: Array[Button] = []

# UI节点引用
var _list_container: VBoxContainer = null
var _details_container: Control = null
var _details_name: Label = null
var _details_species: Label = null
var _details_bond_level: Label = null
var _details_affection_bar: ProgressBar = null
var _details_affection_label: Label = null
var _details_skills_container: VBoxContainer = null
var _gift_btn: Button = null
var _dialogue_btn: Button = null
var _close_btn: Button = null

# 音效
var _sfx_gift: AudioStream = null
var _sfx_select: AudioStream = null


func _ready() -> void:
    print("[CompanionPanel] Ready")
    _find_nodes()
    _connect_signals()
    _load_sounds()


func _find_nodes() -> void:
    _list_container = _find_child_by_name("CompanionListContainer")
    _details_container = _find_child_by_name("DetailsContainer")
    if _details_container:
        _details_name = _details_container.find_child("NameLabel", false, false)
        _details_species = _details_container.find_child("SpeciesLabel", false, false)
        _details_bond_level = _details_container.find_child("BondLevelLabel", false, false)
        _details_affection_bar = _details_container.find_child("AffectionBar", false, false)
        _details_affection_label = _details_container.find_child("AffectionLabel", false, false)
        _details_skills_container = _details_container.find_child("SkillsContainer", false, false)
        _gift_btn = _details_container.find_child("GiftButton", false, false)
        _dialogue_btn = _details_container.find_child("DialogueButton", false, false)
    _close_btn = _find_child_by_name("CloseButton")
    print("[CompanionPanel] Nodes found: list=", _list_container, " details=", _details_container)


func _find_child_by_name(name: String) -> Node:
    return _recursive_find(self, name)


func _recursive_find(node: Node, name: String) -> Node:
    if node.name == name:
        return node
    for child in node.get_children():
        var found = _recursive_find(child, name)
        if found:
            return found
    return null


func _connect_signals() -> void:
    if _close_btn:
        _close_btn.pressed.connect(_on_close_pressed)
    if _gift_btn:
        _gift_btn.pressed.connect(_on_gift_pressed)
    if _dialogue_btn:
        _dialogue_btn.pressed.connect(_on_dialogue_pressed)
    if _companion_manager:
        _companion_manager.companion_affection_changed.connect(_on_affection_changed)
        _companion_manager.companion_bond_level_up.connect(_on_bond_level_up)


func _load_sounds() -> void:
    # 尝试加载音效资源（可选）
    pass


## 设置伙伴管理器引用
func set_companion_manager(manager: CompanionManager) -> void:
    if _companion_manager:
        _companion_manager.companion_affection_changed.disconnect(_on_affection_changed)
        _companion_manager.companion_bond_level_up.disconnect(_on_bond_level_up)
    _companion_manager = manager
    if _companion_manager:
        _companion_manager.companion_affection_changed.connect(_on_affection_changed)
        _companion_manager.companion_bond_level_up.connect(_on_bond_level_up)
    refresh()


## 刷新伙伴列表显示
func refresh() -> void:
    if not _list_container:
        return
    # 清空现有列表
    for child in _list_container.get_children():
        child.queue_free()
    _companion_buttons.clear()

    if not _companion_manager:
        return

    var recruited_ids: Array[String] = _companion_manager.get_recruited_ids()

    if recruited_ids.is_empty():
        var empty_lbl = Label.new()
        empty_lbl.text = "（尚无已招募伙伴）"
        empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
        _list_container.add_child(empty_lbl)
        _hide_details()
        return

    for cid in recruited_ids:
        var info: Dictionary = _companion_manager.get_companion_display_info(cid)
        var btn = _create_companion_row(info)
        _list_container.add_child(btn)
        _companion_buttons.append(btn)

    # 如果有选中的伙伴，更新详情
    if _selected_companion_id != "" and _selected_companion_id in recruited_ids:
        _show_details(_selected_companion_id)
    elif not recruited_ids.is_empty():
        _select_companion(recruited_ids[0])


func _create_companion_row(info: Dictionary) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size.y = 60
    btn.pressed.connect(_on_companion_row_pressed.bind(info["companion_id"]))

    var hbox = HBoxContainer.new()
    btn.add_child(hbox)

    # 种族图标
    var icon_lbl = Label.new()
    var species = info.get("species", "")
    icon_lbl.text = SPECIES_ICONS.get(species, "👤")
    icon_lbl.custom_minimum_size.x = 40
    hbox.add_child(icon_lbl)

    # 名字 + 羁绊等级
    var name_lbl = Label.new()
    name_lbl.text = "%s [%s]" % [info.get("name", "?"), info.get("bond_level_name", "陌生")]
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(name_lbl)

    # 好感度条
    var bar = ProgressBar.new()
    bar.max_value = 100
    bar.value = info.get("affection", 0)
    bar.custom_minimum_size.x = 100
    bar.show_percentage = false
    # 颜色随好感度变化
    var affection = info.get("affection", 0)
    if affection < 30:
        bar.add_theme_color_override("fill_color", Color(0.6, 0.4, 0.4))
    elif affection < 60:
        bar.add_theme_color_override("fill_color", Color(0.9, 0.7, 0.3))
    else:
        bar.add_theme_color_override("fill_color", Color(0.4, 0.8, 0.5))
    hbox.add_child(bar)

    # 选中高亮
    if info["companion_id"] == _selected_companion_id:
        btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.3, 0.25, 0.1, 0.8)
        btn.add_theme_stylebox_override("normal", style)

    return btn


func _on_companion_row_pressed(companion_id: String) -> void:
    _select_companion(companion_id)
    _play_select_sound()


func _select_companion(companion_id: String) -> void:
    _selected_companion_id = companion_id
    # 刷新列表以更新选中高亮
    refresh()


func _show_details(companion_id: String) -> void:
    if not _details_container:
        return

    _details_container.visible = true

    var info: Dictionary = {}
    if _companion_manager:
        info = _companion_manager.get_companion_display_info(companion_id)

    if _details_name:
        _details_name.text = info.get("name", "?")
    if _details_species:
        var species = info.get("species", "")
        _details_species.text = SPECIES_ICONS.get(species, "👤") + " " + species
    if _details_bond_level:
        var level = info.get("bond_level", 0)
        var level_name = info.get("bond_level_name", "陌生")
        _details_bond_level.text = "羁绊等级: %s (%d/4)" % [level_name, level]

    if _details_affection_bar:
        _details_affection_bar.value = info.get("affection", 0)
    if _details_affection_label:
        _details_affection_label.text = "好感度: %d/100" % info.get("affection", 0)

    # 刷新技能列表
    _refresh_skills_list(companion_id)

    # 按钮状态
    if _gift_btn:
        _gift_btn.disabled = false
    if _dialogue_btn:
        _dialogue_btn.disabled = false


func _hide_details() -> void:
    if _details_container:
        _details_container.visible = false


func _refresh_skills_list(companion_id: String) -> void:
    if not _details_skills_container:
        return

    for child in _details_skills_container.get_children():
        child.queue_free()

    if not _companion_manager:
        return

    var unlocked_ids: Array[String] = _companion_manager.get_unlocked_skill_ids(companion_id)

    if unlocked_ids.is_empty():
        var empty_lbl = Label.new()
        empty_lbl.text = "（羁绊等级不足，尚未解锁技能）"
        empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
        _details_skills_container.add_child(empty_lbl)
        return

    for skill_id in unlocked_ids:
        var skill_row = HBoxContainer.new()
        var skill_lbl = Label.new()
        skill_lbl.text = "⚔ %s" % skill_id
        skill_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
        skill_row.add_child(skill_lbl)
        _details_skills_container.add_child(skill_row)


## 赠送礼物按钮
func _on_gift_pressed() -> void:
    if _selected_companion_id == "":
        return
    var gift_panel = _create_gift_selection_panel()
    _show_gift_overlay(gift_panel)


func _create_gift_selection_panel() -> Control:
    var panel = Control.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)

    var bg = ColorRect.new()
    bg.color = Color(0.0, 0.0, 0.0, 0.6)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.add_child(bg)

    var card = PanelContainer.new()
    card.position = Vector2(300, 200)
    card.custom_minimum_size = Vector2(400, 350)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.12, 0.18, 0.98)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.4, 0.35, 0.2)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    card.add_theme_stylebox_override("panel", style)
    panel.add_child(card)

    var vbox = VBoxContainer.new()
    card.add_child(vbox)

    var title = Label.new()
    title.text = "💝 选择礼物"
    title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
    vbox.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "×"
    close_btn.pressed.connect(func(): panel.queue_free())
    vbox.add_child(close_btn)

    for gift_id in GIFT_DEFINITIONS.keys():
        var gift = GIFT_DEFINITIONS[gift_id]
        var row = HBoxContainer.new()

        var icon_lbl = Label.new()
        icon_lbl.text = gift["icon"]
        icon_lbl.custom_minimum_size.x = 40
        row.add_child(icon_lbl)

        var name_lbl = Label.new()
        name_lbl.text = gift["name"]
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name_lbl)

        # 喜好标记
        if _companion_manager and _companion_manager.is_item_liked(_selected_companion_id, gift_id):
            var heart = Label.new()
            heart.text = "❤️"
            row.add_child(heart)
        elif _companion_manager and _companion_manager.is_item_disliked(_selected_companion_id, gift_id):
            var hate = Label.new()
            hate.text = "💔"
            row.add_child(hate)

        var send_btn = Button.new()
        send_btn.text = "赠送"
        send_btn.pressed.connect(_on_send_gift.bind(gift_id, panel))
        row.add_child(send_btn)

        vbox.add_child(row)

    return panel


func _show_gift_overlay(gift_panel: Control) -> void:
    if not has_node("GiftOverlay"):
        var overlay = Node.new()
        overlay.name = "GiftOverlay"
        add_child(overlay)
    get_node("GiftOverlay").add_child(gift_panel)


func _on_send_gift(gift_id: String, gift_panel: Control) -> void:
    if not _companion_manager:
        gift_panel.queue_free()
        return

    var delta = _companion_manager.give_gift(_selected_companion_id, gift_id)
    gift_sent.emit(_selected_companion_id, gift_id, delta)
    _play_gift_sound()
    gift_panel.queue_free()

    # 显示反馈
    _show_affection_feedback(delta)
    refresh()


func _show_affection_feedback(delta: int) -> void:
    if not _companion_manager:
        return
    var info = _companion_manager.get_companion_display_info(_selected_companion_id)
    var name = info.get("name", "?")
    print("[CompanionPanel] %s 好感度 %+d → %d" % [name, delta, info.get("affection", 0)])


## 对话按钮
func _on_dialogue_pressed() -> void:
    if _selected_companion_id == "":
        return
    dialogue_requested.emit(_selected_companion_id)
    print("[CompanionPanel] Dialogue requested for: ", _selected_companion_id)


## 信号回调
func _on_affection_changed(companion_id: String, old_val: int, new_val: int) -> void:
    if companion_id == _selected_companion_id:
        refresh()


func _on_bond_level_up(companion_id: String, new_level: int) -> void:
    if companion_id == _selected_companion_id:
        refresh()
    # 全屏提示羁绊等级提升
    _show_bond_level_up_notification(companion_id, new_level)


func _show_bond_level_up_notification(companion_id: String, new_level: int) -> void:
    if not _companion_manager:
        return
    var info = _companion_manager.get_companion_display_info(companion_id)
    var name = info.get("name", "?")
    var level_name = BOND_LEVEL_NAMES[new_level] if new_level < BOND_LEVEL_NAMES.size() else "?"
    print("[CompanionPanel] ★ 羁绊等级提升！%s → %s" % [name, level_name])


func _on_close_pressed() -> void:
    panel_closed.emit()
    queue_free()


func _play_select_sound() -> void:
    # 简单的选择音效（可通过 AudioStreamPlayer 实现）
    pass


func _play_gift_sound() -> void:
    pass


## 被动触发：战斗外伙伴技能（航行/港口中触发）
func try_trigger_out_of_battle_skill(skill_id: String, context: String = "sailing") -> Dictionary:
    """
    尝试在战斗外触发伙伴技能。
    context: "sailing" | "port" | "exploration"
    返回技能触发结果。
    """
    if not _companion_manager:
        return {"triggered": false, "reason": "no_companion_manager"}

    var result: Dictionary = {"triggered": false, "skill_id": skill_id, "context": context}

    # 查找拥有该技能的伙伴
    var owner_id: String = ""
    var recruited_ids: Array[String] = _companion_manager.get_recruited_ids()
    for cid in recruited_ids:
        var unlocked: Array[String] = _companion_manager.get_unlocked_skill_ids(cid)
        if skill_id in unlocked:
            owner_id = cid
            break

    if owner_id == "":
        result["reason"] = "skill_not_unlocked"
        return result

    # 根据技能类型和场景触发效果
    var skill_effects: Dictionary = _get_out_of_battle_skill_effects(skill_id)
    if skill_effects.is_empty():
        result["reason"] = "no_out_of_battle_effect"
        return result

    var context_effects: Dictionary = skill_effects.get(context, {})
    if context_effects.is_empty():
        result["reason"] = "no_effect_for_context"
        return result

    result["triggered"] = true
    result["owner_id"] = owner_id
    result["effect"] = context_effects
    result["message"] = context_effects.get("message", "")

    print("[CompanionPanel] Out-of-battle skill triggered: %s (%s) by %s → %s" % [
        skill_id, context, owner_id, result["message"]
    ])

    return result


func _get_out_of_battle_skill_effects(skill_id: String) -> Dictionary:
    # 定义每个技能的战斗外效果
    match skill_id:
        "skill_snipe_helm":
            return {
                "sailing": {
                    "message": "珂尔莉发现前方有隐蔽暗礁，及时调整航线！",
                    "effect_type": "avoid_damage",
                    "value": 50
                },
                "port": {
                    "message": "珂尔莉在港口打听消息，获得情报折扣。",
                    "effect_type": "shop_discount",
                    "value": 10
                }
            }
        "skill_eagle_eye":
            return {
                "sailing": {
                    "message": "珂尔莉的锐眼发现了隐藏的漂浮物！",
                    "effect_type": "discover_hidden",
                    "value": 1
                },
                "exploration": {
                    "message": "珂尔莉发现了一处隐蔽的洞穴入口！",
                    "effect_type": "reveal_area",
                    "value": 1
                }
            }
        "skill_overdrive":
            return {
                "port": {
                    "message": "铁砧改造了引擎，航行速度提升！",
                    "effect_type": "speed_boost",
                    "value": 20
                },
                "sailing": {
                    "message": "铁砧紧急修复了受损管道！",
                    "effect_type": "durability_restore",
                    "value": 30
                }
            }
        "skill_whale_call":
            return {
                "sailing": {
                    "message": "深蓝引导鲸群护航，减少了遭遇海盗的概率！",
                    "effect_type": "reduce_pirate_encounter",
                    "value": 30
                },
                "exploration": {
                    "message": "深蓝感知到深海中有古老的沉船残骸！",
                    "effect_type": "treasure_hunt",
                    "value": 1
                }
            }
        "skill_deepsonar":
            return {
                "sailing": {
                    "message": "深蓝的声呐探测到附近的洋流变化。",
                    "effect_type": "current_warning",
                    "value": 1
                }
            }
    return {}
