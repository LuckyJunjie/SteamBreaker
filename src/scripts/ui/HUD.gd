extends CanvasLayer

@onready var HealthLabel: Label = null
@onready var PhaseLabel: Label = null
@onready var ActionPanel: Panel = null

# Bounty tracking
@onready var BountyTrackerPanel: Panel = null
@onready var ActiveBountyLabel: Label = null
@onready var BountyTrackerHints: VBoxContainer = null

# ---- 伙伴系统 UI ----
# 伙伴面板（战斗界面右下角）
var CompanionPanel: Panel = null
var CompanionSkillButtons: Array[Button] = []   # 伙伴技能按钮
var MoraleLabels: Dictionary = {}               # 士气值 Label per companion
var CompanionAvatars: Dictionary = {}           # 伙伴头像 + 情绪图标
var CurrentCompanions: Array[Companion] = []    # 当前参战伙伴

# Reference to systems
var companion_skill_system: Node = null
var dialogue_manager: Node = null
var bond_event_manager: Node = null

var current_health: int = 100
var max_health: int = 100

# Reference to BountyManager
var bounty_manager_ref: Node = null

# ---- 战斗模式 UI ----
var BattleActionPanel: Panel = null
var BattleActionButtons: VBoxContainer = null
var DamagePopupLayer: Node2D = null
var is_in_battle_mode: bool = false
var battle_manager_ref: Node = null
var selected_weapon_index: int = -1
var selected_target_ship: ShipCombatData = null
var current_weapons: Array[WeaponData] = []
var current_items: Array[Dictionary] = []

## 战斗速度选项
var animation_speed_multiplier: float = 1.0
var BattleSpeedBtn: Button = null
var _status_effect_icons: Dictionary = {}  # ship_id -> {effect_type -> icon_container}

func _ready():
    print("[HUD] Initialized")
    _setup_ui()
    _setup_bounty_tracker()
    _setup_companion_panel()
    _setup_battle_action_panel()
    _setup_damage_popup_layer()
    _connect_bounty_signals()
    _connect_companion_signals()
    _connect_battle_signals()
    _detect_battle_mode()

func _setup_ui():
    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
    vbox.offset_left = 20.0
    vbox.offset_top = 20.0
    vbox.offset_right = 300.0
    vbox.offset_bottom = 200.0
    add_child(vbox)

    PhaseLabel = Label.new()
    PhaseLabel.text = "Phase: Player Turn"
    PhaseLabel.add_theme_font_size_override("font_size", 18)
    vbox.add_child(PhaseLabel)

    HealthLabel = Label.new()
    HealthLabel.text = "HP: %d / %d" % [current_health, max_health]
    HealthLabel.add_theme_font_size_override("font_size", 16)
    vbox.add_child(HealthLabel)

    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND
    vbox.add_child(spacer)

    var bottom_bar = HBoxContainer.new()
    vbox.add_child(bottom_bar)

    var inventory_btn = Button.new()
    inventory_btn.text = "🎒 背包"
    inventory_btn.pressed.connect(_open_inventory)
    bottom_bar.add_child(inventory_btn)

func _setup_bounty_tracker() -> void:
    BountyTrackerPanel = Panel.new()
    BountyTrackerPanel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    BountyTrackerPanel.offset_left = -220.0
    BountyTrackerPanel.offset_top = 20.0
    BountyTrackerPanel.offset_right = -20.0
    BountyTrackerPanel.offset_bottom = 180.0
    BountyTrackerPanel.custom_minimum_size = Vector2(200, 160)
    add_child(BountyTrackerPanel)
    
    var tracker_style := StyleBoxFlat.new()
    tracker_style.bg_color = Color(0.1, 0.15, 0.2, 0.9)
    tracker_style.set_corner_radius_all(6)
    tracker_style.set_border_width_all(1)
    tracker_style.border_color = Color(0.4, 0.6, 0.8, 0.6)
    tracker_style.set_content_margin_all(8)
    BountyTrackerPanel.add_theme_stylebox_override("panel", tracker_style)
    
    var tracker_vbox: VBoxContainer = VBoxContainer.new()
    BountyTrackerPanel.add_child(tracker_vbox)
    
    var tracker_header: Label = Label.new()
    tracker_header.text = "⚔️ 赏金追踪"
    tracker_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tracker_header.add_theme_font_size_override("font_size", 14)
    tracker_header.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
    tracker_vbox.add_child(tracker_header)
    
    ActiveBountyLabel = Label.new()
    ActiveBountyLabel.text = "（无进行中的赏金）"
    ActiveBountyLabel.add_theme_font_size_override("font_size", 12)
    ActiveBountyLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    ActiveBountyLabel.autowrap_mode = TextServer.AUTOWRAP_WORD
    tracker_vbox.add_child(ActiveBountyLabel)
    
    BountyTrackerHints = VBoxContainer.new()
    tracker_vbox.add_child(BountyTrackerHints)

## ============================================================
## 伙伴技能面板（战斗界面右下角）
## ============================================================
func _setup_companion_panel() -> void:
    CompanionPanel = Panel.new()
    CompanionPanel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    CompanionPanel.offset_left = -240.0
    CompanionPanel.offset_top = -260.0
    CompanionPanel.offset_right = -20.0
    CompanionPanel.offset_bottom = -20.0
    CompanionPanel.custom_minimum_size = Vector2(220, 240)
    CompanionPanel.z_index = 10
    add_child(CompanionPanel)

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.92)
    panel_style.set_corner_radius_all(8)
    panel_style.set_border_width_all(1)
    panel_style.border_color = Color(0.3, 0.5, 0.7, 0.7)
    panel_style.set_content_margin_all(10)
    CompanionPanel.add_theme_stylebox_override("panel", panel_style)

    var main_vbox: VBoxContainer = VBoxContainer.new()
    CompanionPanel.add_child(main_vbox)

    # 标题
    var title: Label = Label.new()
    title.text = "👥 伙伴技能"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
    main_vbox.add_child(title)

    # 士气显示区（每个伙伴一行）
    var morale_container: VBoxContainer = VBoxContainer.new()
    morale_container.custom_minimum_size.y = 60.0
    main_vbox.add_child(morale_container)

    # 分隔线
    var sep: HSeparator = HSeparator.new()
    sep.custom_minimum_size.y = 1.0
    main_vbox.add_child(sep)

    # 技能按钮区
    var skill_scroll: ScrollContainer = ScrollContainer.new()
    skill_scroll.custom_minimum_size.y = 140.0
    main_vbox.add_child(skill_scroll)

    var skill_vbox: VBoxContainer = VBoxContainer.new()
    skill_scroll.add_child(skill_vbox)

    # 初始化空的技能按钮（后续由 set_companions 填充）
    CompanionPanel.visible = false

func _connect_companion_signals() -> void:
    # 查找 CompanionSkill 系统
    companion_skill_system = _find_autoload("CompanionSkill")
    if companion_skill_system and companion_skill_system.has_signal("morale_changed"):
        companion_skill_system.morale_changed.connect(_on_morale_changed)
        companion_skill_system.skill_used.connect(_on_skill_used)
        companion_skill_system.skill_cooldown_ready.connect(_on_skill_cooldown_ready)

    dialogue_manager = _find_autoload("DialogueSystem")
    bond_event_manager = _find_autoload("BondEventSystem")

func _find_autoload(name: String) -> Node:
    var tree := get_tree()
    if tree and tree.root:
        return tree.root.find_node(name, true, false)
    return get_node_or_null("/root/" + name)

## 设置当前参战伙伴
func set_companions(companions: Array[Companion]) -> void:
    CurrentCompanions = companions
    if companions.is_empty():
        CompanionPanel.visible = false
        return

    CompanionPanel.visible = true
    _rebuild_companion_ui(companions)

func _rebuild_companion_ui(companions: Array[Companion]) -> void:
    # 清除旧UI
    for btn in CompanionSkillButtons:
        if is_instance_valid(btn):
            btn.queue_free()
    CompanionSkillButtons.clear()
    MoraleLabels.clear()
    CompanionAvatars.clear()

    # 重新构建
    var main_vbox: VBoxContainer = CompanionPanel.get_child(0) as VBoxContainer
    if not main_vbox:
        return

    var morale_container: VBoxContainer = main_vbox.get_child(1) as VBoxContainer

    for c in companions:
        _add_companion_header(morale_container, c)
        _add_companion_skills(main_vbox, c)

    # 刷新士气显示
    _refresh_morale_display()

func _add_companion_header(parent: VBoxContainer, companion: Companion) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    parent.add_child(row)

    # 伙伴头像占位（彩色方块+名字）
    var avatar: Panel = Panel.new()
    avatar.custom_minimum_size = Vector2(32, 32)
    var color: Color = _get_companion_color(companion.companion_id)
    var avatar_style := StyleBoxFlat.new()
    avatar_style.bg_color = color.darkened(0.3)
    avatar_style.set_corner_radius_all(4)
    avatar_style.set_border_width_all(1)
    avatar_style.border_color = color
    avatar.add_theme_stylebox_override("panel", avatar_style)
    row.add_child(avatar)

    # 情绪图标（基于好感度）
    var mood_icon: Label = Label.new()
    mood_icon.text = _get_mood_emoji(companion)
    mood_icon.add_theme_font_size_override("font_size", 16)
    mood_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    avatar.add_child(mood_icon)
    CompanionAvatars[companion.companion_id] = {"avatar": avatar, "mood": mood_icon}

    # 伙伴名字
    var name_label: Label = Label.new()
    name_label.text = companion.name
    name_label.add_theme_font_size_override("font_size", 11)
    name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    row.add_child(name_label)

    # 士气值
    var morale_lbl: Label = Label.new()
    morale_lbl.add_theme_font_size_override("font_size", 10)
    morale_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
    morale_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(morale_lbl)
    MoraleLabels[companion.companion_id] = morale_lbl

func _add_companion_skills(parent_vbox: VBoxContainer, companion: Companion) -> void:
    var skill_vbox: VBoxContainer = parent_vbox.get_child(3) as VBoxContainer
    if not skill_vbox:
        return

    # 添加技能按钮（最多3个，按羁绊等级解锁）
    var unlocked_ids: Array[String] = companion.get_unlocked_skill_ids()
    for i in range(mini(unlocked_ids.size(), 3)):
        var sid: String = unlocked_ids[i]
        var skill: Skill = _load_skill(sid)
        if skill == null:
            continue

        var btn: Button = Button.new()
        btn.custom_minimum_size.y = 28.0
        btn.text = "⬡ %s (💥%d)" % [skill.name, skill.mp_cost]
        btn.add_theme_font_size_override("font_size", 11)
        btn.tooltip_text = skill.description
        btn.pressed.connect(_on_companion_skill_button_pressed.bind(companion, skill))
        skill_vbox.add_child(btn)
        CompanionSkillButtons.append(btn)

func _load_skill(skill_id: String) -> Skill:
    var paths: Array[String] = [
        "res://resources/skills/%s.tres" % skill_id,
        "res://resources/skills/%s.tres" % skill_id
    ]
    for p in paths:
        if ResourceLoader.exists(p):
            return load(p)
    return null

func _refresh_morale_display() -> void:
    for c in CurrentCompanions:
        if not MoraleLabels.has(c.companion_id):
            continue
        var lbl: Label = MoraleLabels[c.companion_id]
        var morale: int = 0
        var max_m: int = c.base_stats.get("morale_max", 3)
        if companion_skill_system:
            morale = companion_skill_system.get_current_morale(c.companion_id)
        lbl.text = "💪 %d/%d" % [morale, max_m]

func _get_companion_color(companion_id: String) -> Color:
    match companion_id:
        "companion_keerli": return Color(0.9, 0.5, 0.2)  # 橙褐色
        "companion_tiechan": return Color(0.7, 0.7, 0.8) # 铁灰色
        "companion_shenlan": return Color(0.2, 0.5, 0.9) # 深蓝色
    return Color(0.5, 0.5, 0.5)

func _get_mood_emoji(companion: Companion) -> String:
    var level: int = companion.get_bond_level()
    match level:
        0: return "😶"
        1: return "🙂"
        2: return "😊"
        3: return "😄"
        4: return "🥰"
    return "😐"

## ---- 伙伴技能按钮点击 ----
func _on_companion_skill_button_pressed(companion: Companion, skill: Skill) -> void:
    if companion_skill_system == null:
        print("[HUD] CompanionSkill system not found!")
        return

    if not companion_skill_system.can_use_skill(companion, skill):
        _show_skill_error("士气不足或技能冷却中！")
        return

    # 获取玩家船只和敌人数据（从 BattleManager）
    var player_ship: ShipCombatData = _get_player_ship()
    var enemy_ships: Array[ShipCombatData] = _get_enemy_ships()

    var result: Dictionary = companion_skill_system.execute_skill(companion, skill, player_ship, enemy_ships)
    if result.get("success", false):
        _show_skill_feedback(companion, skill, result)
    else:
        _show_skill_error(result.get("message", "技能释放失败"))

func _get_player_ship() -> ShipCombatData:
    var bm: Node = _find_autoload("BattleManager")
    if bm and bm.has_method("get_player_ship"):
        return bm.get_player_ship()
    return null

func _get_enemy_ships() -> Array[ShipCombatData]:
    var bm: Node = _find_autoload("BattleManager")
    if bm and bm.has_method("get_enemy_ships"):
        return bm.get_enemy_ships()
    return []

func _show_skill_feedback(companion: Companion, skill: Skill, result: Dictionary) -> void:
    var msg: String = result.get("message", "%s 释放了「%s」！" % [companion.name, skill.name])
    _show_floating_text(msg, Color(0.3, 0.9, 0.3))
    # 更新士气显示
    _refresh_morale_display()

func _show_skill_error(msg: String) -> void:
    _show_floating_text(msg, Color(0.9, 0.3, 0.3))

func _show_floating_text(text: String, color: Color) -> void:
    var lbl: Label = Label.new()
    lbl.text = text
    lbl.add_theme_color_override("font_color", color)
    lbl.add_theme_font_size_override("font_size", 14)
    lbl.z_index = 50
    lbl.set_anchors_preset(Control.PRESET_CENTER)
    add_child(lbl)
    # 简单动画：向上飘动
    var tween: Tween = create_tween()
    lbl.position.y = 0
    tween.tween_property(lbl, "position:y", -60.0, 1.5)
    tween.tween_callback(lbl.queue_free)

func _on_morale_changed(companion_id: String, current: int, maximum: int) -> void:
    _refresh_morale_display()
    # 士气变化时高亮一下
    if MoraleLabels.has(companion_id):
        var lbl: Label = MoraleLabels[companion_id]
        var tween: Tween = create_tween()
        tween.tween_property(lbl, "modulate", Color(1.2, 1.0, 0.5), 0.2)
        tween.tween_property(lbl, "modulate", Color.WHITE, 0.3)

func _on_skill_used(companion_id: String, skill_id: String, effect_data: Dictionary) -> void:
    print("[HUD] Skill used: %s by %s | Result: %s" % [skill_id, companion_id, str(effect_data)])

func _on_skill_cooldown_ready(companion_id: String, skill_id: String) -> void:
    print("[HUD] Skill cooldown ready: %s for %s" % [skill_id, companion_id])
    # 更新按钮状态
    for btn in CompanionSkillButtons:
        if btn.tooltip_text.find(skill_id) >= 0:
            btn.disabled = false

## ============================================================
## 对话系统 UI（可由 DialogueManager 触发）
## ============================================================

## 显示对话气泡（伙伴对话时调用）
func show_dialogue_box(companion: Companion, dialogue_id: String) -> void:
    if dialogue_manager == null:
        dialogue_manager = _find_autoload("DialogueSystem")
    if dialogue_manager == null:
        return

    var data: Dictionary = dialogue_manager.start_dialogue(companion, dialogue_id)
    _display_dialogue_content(data)

func _display_dialogue_content(data: Dictionary) -> void:
    # 创建对话气泡
    var box: Panel = Panel.new()
    box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    box.offset_left = 20.0
    box.offset_top = -160.0
    box.offset_right = -20.0
    box.offset_bottom = -20.0
    box.custom_minimum_size.y = 140.0
    box.z_index = 20
    add_child(box)

    var box_style := StyleBoxFlat.new()
    box_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
    box_style.set_corner_radius_all(10)
    box_style.set_border_width_all(2)
    box_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
    box_style.set_content_margin_all(12)
    box.add_theme_stylebox_override("panel", box_style)

    var vbox: VBoxContainer = VBoxContainer.new()
    box.add_child(vbox)

    # 说话者名
    var name_lbl: Label = Label.new()
    name_lbl.text = "【%s】" % data.get("speaker_name", "?")
    name_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
    name_lbl.add_theme_font_size_override("font_size", 12)
    vbox.add_child(name_lbl)

    # 对话文本
    var text_lbl: Label = Label.new()
    text_lbl.text = data.get("text", "")
    text_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
    text_lbl.add_theme_font_size_override("font_size", 14)
    text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    vbox.add_child(text_lbl)

    # 选项按钮（如果存在）
    if data.get("has_options", false):
        var options: Array = data.get("options", [])
        for i in range(options.size()):
            var opt: Dictionary = options[i]
            var btn: Button = Button.new()
            btn.text = "[%d] %s" % [i + 1, opt.get("text", "...")]
            btn.custom_minimum_size.y = 26.0
            btn.add_theme_font_size_override("font_size", 12)
            btn.pressed.connect(_on_dialogue_option_pressed.bind(box, i))
            vbox.add_child(btn)

    # 持续显示，等待玩家操作
    # (外部可调用 skip_dialogue() 关闭)

func _on_dialogue_option_pressed(dialogue_box: Panel, option_index: int) -> void:
    if dialogue_manager == null:
        return
    var result: Dictionary = dialogue_manager.select_option(option_index)
    dialogue_box.queue_free()
    if result.get("next", {}).get("has_options", false):
        await get_tree().create_timer(0.3).timeout
        _display_dialogue_content(result["next"])

## ============================================================
## 原有 HUD 功能
## ============================================================

func _connect_bounty_signals() -> void:
    var tree := get_tree()
    if tree and tree.root:
        bounty_manager_ref = tree.root.find_node("BountyManager", true, false)
        if bounty_manager_ref and bounty_manager_ref.has_signal("bounty_updated"):
            bounty_manager_ref.bounty_updated.connect(_on_bounty_updated)
            bounty_manager_ref.bounty_accepted.connect(_on_bounty_accepted)
            bounty_manager_ref.bounty_completed.connect(_on_bounty_completed)
            _refresh_bounty_tracker()
    
    if not bounty_manager_ref:
        var sm: Node = get_node_or_null("/root/BattleManager")
        if sm and sm.has_method("get_bounty_manager"):
            bounty_manager_ref = sm.get_bounty_manager()
            if bounty_manager_ref:
                bounty_manager_ref.bounty_updated.connect(_on_bounty_updated)
                _refresh_bounty_tracker()

func _on_bounty_updated() -> void:
    _refresh_bounty_tracker()

func _on_bounty_accepted(bounty_id: String) -> void:
    print("[HUD] Bounty accepted: " + bounty_id)
    _refresh_bounty_tracker()

func _on_bounty_completed(bounty_id: String, rewards: Dictionary) -> void:
    print("[HUD] Bounty completed: " + bounty_id + " | Rewards: " + str(rewards))
    _show_bounty_reward_popup(rewards)
    _refresh_bounty_tracker()

func _refresh_bounty_tracker() -> void:
    if not bounty_manager_ref:
        return
    
    var active_bounties = bounty_manager_ref.get_active_bounties()
    var hints = bounty_manager_ref.get_bounty_tracker_hints()
    
    for child in BountyTrackerHints.get_children():
        child.queue_free()
    
    if active_bounties.is_empty():
        ActiveBountyLabel.text = "（无进行中的赏金）"
        ActiveBountyLabel.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    else:
        var first_bounty = active_bounties[0]
        ActiveBountyLabel.text = "🔱 " + first_bounty.get("name", "Unknown")
        ActiveBountyLabel.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
        
        for hint in hints:
            var hint_label: Label = Label.new()
            hint_label.text = "📍 %s (%s)" % [hint.get("location", "?"), hint.get("difficulty", "?")]
            hint_label.add_theme_font_size_override("font_size", 10)
            hint_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
            BountyTrackerHints.add_child(hint_label)

func _show_bounty_reward_popup(rewards: Dictionary) -> void:
    var gold: int = rewards.get("gold", 0)
    var items: Array = rewards.get("items", [])
    
    var popup: Panel = Panel.new()
    popup.set_anchors_preset(Control.PRESET_CENTER)
    popup.custom_minimum_size = Vector2(300, 150)
    popup.z_index = 100
    
    var popup_style := StyleBoxFlat.new()
    popup_style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
    popup_style.set_corner_radius_all(8)
    popup_style.set_border_width_all(2)
    popup_style.border_color = Color(0.9, 0.7, 0.2)
    popup.add_theme_stylebox_override("panel", popup_style)
    add_child(popup)
    
    var popup_vbox: VBoxContainer = VBoxContainer.new()
    popup.add_child(popup_vbox)
    
    var title: Label = Label.new()
    title.text = "🎉 赏金完成！"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    popup_vbox.add_child(title)
    
    var gold_label: Label = Label.new()
    gold_label.text = "💰 金币 +%d" % gold
    gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gold_label.add_theme_font_size_override("font_size", 16)
    popup_vbox.add_child(gold_label)
    
    if not items.is_empty():
        var items_label: Label = Label.new()
        items_label.text = "📦 获得: " + ", ".join(items)
        items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        items_label.add_theme_font_size_override("font_size", 14)
        items_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        popup_vbox.add_child(items_label)
    
    await get_tree().create_timer(3.0).timeout
    popup.queue_free()

func UpdateHealth(current: int, maximum: int):
    current_health = current
    max_health = maximum
    if HealthLabel:
        HealthLabel.text = "HP: %d / %d" % [current, maximum]

func UpdatePhase(phase_name: String):
    if PhaseLabel:
        PhaseLabel.text = "Phase: " + phase_name

func ShowActionPanel(actions: Array[String]):
    if ActionPanel:
        ActionPanel.visible = true

func HideActionPanel():
    if ActionPanel:
        ActionPanel.visible = false

func open_bounty_board() -> void:
    var board_ui: Node = get_tree().root.find_node("BountyBoardUI", true, false)
    if board_ui and board_ui.has_method("show_board"):
        board_ui.show_board()
    else:
        print("[HUD] BountyBoardUI not found")

func _open_inventory() -> void:
    var inv_path = "/root/InventoryPanel"
    if has_node(inv_path):
        var panel = get_node(inv_path)
        panel.visible = true
    else:
        print("[HUD] InventoryPanel not found in scene tree")

# ============================================================
# World Navigation / 世界导航控件
# ============================================================

func _load_game_manager() -> void:
    # 延迟一帧查找，确保 World 节点已初始化
    await get_tree().process_frame
    if has_node("/root/GameManager"):
        _game_manager_ref = get_node("/root/GameManager")
        print("[HUD] GameManager found for navigation")
    elif has_node("/root/GameState"):
        _game_manager_ref = get_node("/root/GameState")
        print("[HUD] Using GameState as fallback")

## 设置港口/世界地图导航按钮
func _setup_navigation_controls() -> void:
    _nav_panel = Panel.new()
    _nav_panel.name = "NavigationPanel"
    _nav_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _nav_panel.offset_left = 0
    _nav_panel.offset_right = 0
    _nav_panel.offset_top = 0
    _nav_panel.offset_bottom = 0
    _nav_panel.custom_minimum_size = Vector2(0, 60)
    _nav_panel.size.y = 60
    _nav_panel.z_index = 50
    add_child(_nav_panel)
    
    var nav_style := StyleBoxFlat.new()
    nav_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
    nav_style.set_corner_radius_all(0)
    nav_style.set_border_width_all(0)
    nav_style.set_content_margin_all(10)
    _nav_panel.add_theme_stylebox_override("panel", nav_style)
    
    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.add_theme_constant_override("separation", 12)
    _nav_panel.add_child(hbox)
    
    # 左侧：返回世界地图按钮
    var world_map_btn = Button.new()
    world_map_btn.name = "WorldMapBtn"
    world_map_btn.text = "🗺️ 世界地图"
    world_map_btn.pressed.connect(_on_world_map_pressed)
    hbox.add_child(world_map_btn)
    
    # 中间：当前港口/位置显示
    var location_lbl = Label.new()
    location_lbl.name = "LocationLabel"
    location_lbl.text = "📍 铁锈湾"
    location_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    location_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
    location_lbl.add_theme_font_size_override("font_size", 14)
    hbox.add_child(location_lbl)
    
    # 右侧：起航按钮
    var sail_btn = Button.new()
    sail_btn.name = "SailBtn"
    sail_btn.text = "⚓ 起航"
    sail_btn.pressed.connect(_on_sail_pressed)
    hbox.add_child(sail_btn)
    
    # 刷新导航状态
    _refresh_navigation_state()

## 刷新导航状态
func _refresh_navigation_state() -> void:
    if not _nav_panel:
        return
    var location_lbl = _nav_panel.find_child("LocationLabel", true, false) as Label
    if location_lbl and _game_manager_ref:
        var port_data = _game_manager_ref.get_current_port()
        var port_name = port_data.get("name", "未知港口")
        location_lbl.text = "📍 " + port_name

## 世界地图按钮点击
func _on_world_map_pressed() -> void:
    print("[HUD] World Map button pressed")
    if _game_manager_ref and _game_manager_ref.has_method("change_scene_to_world_map"):
        _game_manager_ref.change_scene_to_world_map()
    else:
        print("[HUD] GameManager not available for scene change")

## 起航按钮点击
func _on_sail_pressed() -> void:
    print("[HUD] Sail button pressed")
    if _game_manager_ref and _game_manager_ref.has_method("depart_from_port"):
        _game_manager_ref.depart_from_port()
    else:
        print("[HUD] GameManager not available for departure")

## 显示/隐藏导航面板
func show_navigation_panel(visible: bool) -> void:
    if _nav_panel:
        _nav_panel.visible = visible

## ============================================
## 战斗模式 UI（新增）
## ============================================

func _detect_battle_mode() -> void:
	# Use deferred lookup to handle BattleManager loading after HUD ready
	await get_tree().process_frame
	var tree = get_tree()
	if not tree:
		return
	var root = tree.root
	if not root:
		return
	var battle = root.find_child("BattleManager", true, false)
	if battle:
		is_in_battle_mode = true
		battle_manager_ref = battle
		_connect_battle_signals()
		setup_battle_speed_button()
		print("[HUD] BattleManager resolved via deferred lookup")
	else:
		# Fallback to scene-based detection
		var scene_battle = root.find_child("Battle", false, false)
		if scene_battle:
			is_in_battle_mode = true
			battle_manager_ref = scene_battle
			setup_battle_speed_button()
			print("[HUD] Battle mode detected (scene fallback)")

func _setup_battle_action_panel() -> void:
	BattleActionPanel = Panel.new()
	BattleActionPanel.name = "BattleActionPanel"
	BattleActionPanel.set_anchors_preset(Control.PRESET_CENTER)
	BattleActionPanel.custom_minimum_size = Vector2(400, 300)
	BattleActionPanel.visible = false
	add_child(BattleActionPanel)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	BattleActionPanel.add_child(bg)

	var title = Label.new()
	title.text = "⚔️ 行动选择"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 40)
	BattleActionPanel.add_child(title)

	BattleActionButtons = VBoxContainer.new()
	BattleActionButtons.position = Vector2(50, 60)
	BattleActionButtons.size = Vector2(300, 220)
	BattleActionPanel.add_child(BattleActionButtons)

	_add_battle_action_button("🔫 攻击", Callable(self, "_on_battle_attack"))
	_add_battle_action_button("🔧 修理", Callable(self, "_on_battle_repair"))
	_add_battle_action_button("🛡️ 防御", Callable(self, "_on_battle_defend"))
	_add_battle_action_button("⏭️ 跳过", Callable(self, "_on_battle_skip"))

func _add_battle_action_button(label: String, callback: Callable) -> void:
	if not BattleActionButtons:
		return
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(300, 50)
	btn.pressed.connect(callback)
	BattleActionButtons.add_child(btn)

func _setup_damage_popup_layer() -> void:
	DamagePopupLayer = Node2D.new()
	DamagePopupLayer.name = "DamagePopupLayer"
	add_child(DamagePopupLayer)

func _connect_battle_signals() -> void:
	var tree = get_tree()
	if not tree:
		return
	var root = tree.root
	if not root:
		return
	var battle = root.find_child("Battle", false, false)
	if battle and battle.has_signal("show_battle_action_panel"):
		battle.connect("show_battle_action_panel", _on_show_battle_action_panel)
	if battle and battle.has_signal("show_damage_popup"):
		battle.connect("show_damage_popup", _on_show_damage_popup)

func _on_show_battle_action_panel(visible: bool) -> void:
	if BattleActionPanel:
		BattleActionPanel.visible = visible

func _on_show_damage_popup(ship_id: String, damage: float, is_crit: bool) -> void:
	if not DamagePopupLayer:
		return
	var ship_label = Label.new()
	ship_label.text = ("%.0f" % damage) + (" CRIT!" if is_crit else "")
	ship_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2) if is_crit else Color(1.0, 0.8, 0.2))
	ship_label.position = Vector2(400 + randf() * 100, 200 + randf() * 100)
	DamagePopupLayer.add_child(ship_label)
	var tween = create_tween()
	tween.tween_property(ship_label, "position:y", ship_label.position.y - 60, 1.0)
	tween.tween_callback(ship_label.queue_free)

func _on_battle_attack() -> void:
	print("[HUD] Battle: Attack selected")
	if BattleActionPanel:
		BattleActionPanel.visible = false
	if battle_manager_ref and battle_manager_ref.has_method("request_attack"):
		battle_manager_ref.request_attack(selected_weapon_index, "", "hull")

func _on_battle_repair() -> void:
	print("[HUD] Battle: Repair selected")
	if BattleActionPanel:
		BattleActionPanel.visible = false

func _on_battle_defend() -> void:
	print("[HUD] Battle: Defend selected")
	if BattleActionPanel:
		BattleActionPanel.visible = false

func _on_battle_skip() -> void:
	print("[HUD] Battle: Skip turn")
	if BattleActionPanel:
		BattleActionPanel.visible = false
	if battle_manager_ref and battle_manager_ref.has_method("advance_turn"):
		battle_manager_ref.advance_turn()

## ============================================
## 战斗速度选项
## ============================================

func _toggle_battle_speed() -> void:
	animation_speed_multiplier = 2.0 if animation_speed_multiplier == 1.0 else 1.0
	if BattleSpeedBtn:
		BattleSpeedBtn.text = "⏩ x%.0f" % animation_speed_multiplier
	print("[HUD] Battle speed: x%.0f" % animation_speed_multiplier)

func setup_battle_speed_button() -> void:
	if BattleSpeedBtn:
		return
	BattleSpeedBtn = Button.new()
	BattleSpeedBtn.name = "BattleSpeedBtn"
	BattleSpeedBtn.text = "⏩ x1"
	BattleSpeedBtn.custom_minimum_size = Vector2(70, 36)
	BattleSpeedBtn.pressed.connect(_toggle_battle_speed)
	BattleSpeedBtn.anchor_left = 1.0
	BattleSpeedBtn.anchor_right = 1.0
	BattleSpeedBtn.offset_left = -96.0
	BattleSpeedBtn.offset_top = 22.0
	BattleSpeedBtn.offset_right = -22.0
	BattleSpeedBtn.offset_bottom = 58.0
	add_child(BattleSpeedBtn)
	print("[HUD] Battle speed button created")

## ============================================
## 状态效果剩余回合显示
## ============================================

## 更新船只的状态效果图标（由BattleManager每回合调用）
func update_status_effects_ui(ship: ShipCombatData) -> void:
	if not is_in_battle_mode:
		return
	var ship_id: String = ship.ship_id
	# 清除旧图标
	if _status_effect_icons.has(ship_id):
		for container: Node in _status_effect_icons[ship_id].values():
			if is_instance_valid(container):
				container.queue_free()
		_status_effect_icons[ship_id].clear()

	var container_dict: Dictionary = {}
	for eff_type: int in ship.status_effects.keys():
		var eff: StatusEffect = ship.status_effects[eff_type]
		var icon: Panel = _create_status_icon(ship_id, eff)
		if icon:
			container_dict[eff_type] = icon
	_status_effect_icons[ship_id] = container_dict

func _create_status_icon(ship_id: String, eff: StatusEffect) -> Panel:
	var icon: Panel = Panel.new()
	icon.custom_minimum_size = Vector2(32, 32)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	icon_style.set_corner_radius_all(4)
	icon_style.set_border_width_all(1)
	icon_style.border_color = _get_status_color(eff.type)
	icon.add_theme_stylebox_override("panel", icon_style)
	add_child(icon)

	# 状态图标（emoji）
	var icon_lbl: Label = Label.new()
	icon_lbl.text = _get_status_emoji(eff.type)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(icon_lbl)

	# 剩余回合数小标签（右下角显示 "x3"）
	var turns_lbl: Label = Label.new()
	turns_lbl.text = "x%d" % eff.duration_remaining
	turns_lbl.add_theme_font_size_override("font_size", 9)
	turns_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	turns_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	turns_lbl.offset_left = 16.0
	turns_lbl.offset_top = 18.0
	icon.add_child(turns_lbl)

	# 悬浮提示
	icon.tooltip_text = "%s（剩余 %d 回合）" % [eff.get_display_name(), eff.duration_remaining]

	# 定位（放在屏幕下方中央，按索引排列）
	var ship_index: int = _get_ship_index(ship_id)
	var x_pos: int = 300 + ship_index * 80
	icon.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	icon.offset_left = x_pos
	icon.offset_top = -20
	icon.offset_right = x_pos + 32
	icon.offset_bottom = 20
	icon.z_index = 15
	return icon

func _get_status_emoji(type: StatusEffect.StatusType) -> String:
	match type:
		StatusEffect.StatusType.FIRE:      return "🔥"
		StatusEffect.StatusType.FLOOD:     return "💧"
		StatusEffect.StatusType.SLOW:      return "🐌"
		StatusEffect.StatusType.DISORIENT: return "🌀"
		StatusEffect.StatusType.STEALTH:   return "👻"
		StatusEffect.StatusType.OVERHEAT:  return "♨️"
		StatusEffect.StatusType.PARALYSIS: return "⚡"
	return "❓"

func _get_status_color(type: StatusEffect.StatusType) -> Color:
	match type:
		StatusEffect.StatusType.FIRE:      return Color(0.9, 0.3, 0.1)
		StatusEffect.StatusType.FLOOD:     return Color(0.2, 0.4, 0.9)
		StatusEffect.StatusType.SLOW:      return Color(0.4, 0.7, 0.2)
		StatusEffect.StatusType.DISORIENT: return Color(0.7, 0.3, 0.9)
		StatusEffect.StatusType.STEALTH:   return Color(0.5, 0.5, 0.7)
		StatusEffect.StatusType.OVERHEAT:  return Color(0.9, 0.6, 0.1)
		StatusEffect.StatusType.PARALYSIS: return Color(0.9, 0.9, 0.1)
	return Color(0.6, 0.6, 0.6)

var _ship_index_map: Dictionary = {}

func _get_ship_index(ship_id: String) -> int:
	if _ship_index_map.has(ship_id):
		return _ship_index_map[ship_id]
	var idx: int = _ship_index_map.size()
	_ship_index_map[ship_id] = idx
	return idx
