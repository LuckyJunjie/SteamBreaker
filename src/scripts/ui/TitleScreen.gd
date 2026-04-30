extends CanvasLayer

## TitleScreen.gd - 游戏标题画面控制器
## 职责：显示标题画面，处理新游戏/继续游戏/退出逻辑

# === 节点引用 ===
var _title_label: Label = null
var _subtitle_label: Label = null
var _new_game_btn: Button = null
var _continue_btn: Button = null
var _version_label: Label = null
var _fade_overlay: ColorRect = null
var _buttons_container: VBoxContainer = null

const GAME_VERSION := "v0.1.0 Alpha"

func _ready() -> void:
	print("[TitleScreen] Ready")
	_setup_ui()
	_check_save_exists()

func _setup_ui() -> void:
	# 全屏深色背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.04, 0.06, 0.10, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)

	# 装饰性边框
	_draw_decorative_frame()

	# 淡入叠加层
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 1.0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.z_index = 100
	add_child(_fade_overlay)

	# 中央容器
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "蒸汽破浪号\nSteam Breaker"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	_title_label.add_theme_font_size_override("font_size", 56)
	vbox.add_child(_title_label)

	# 副标题
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = "蒸汽朋克航海RPG"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80))
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_subtitle_label)

	# 按钮间隔
	vbox.add_child(_make_spacer_node(60))

	# 按钮容器
	_buttons_container = VBoxContainer.new()
	_buttons_container.name = "ButtonsContainer"
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_buttons_container)

	# 新游戏按钮
	_new_game_btn = _make_steam_button("⚓ 新游戏")
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_buttons_container.add_child(_new_game_btn)

	# 继续游戏按钮
	_continue_btn = _make_steam_button("📜 继续游戏")
	_continue_btn.pressed.connect(_on_continue_pressed)
	_buttons_container.add_child(_continue_btn)

	# 底部版本信息
	vbox.add_child(_make_spacer_node(80))

	var version_lbl = Label.new()
	version_lbl.name = "VersionLabel"
	version_lbl.text = "%s  |  Made with Godot 4" % GAME_VERSION
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_lbl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50))
	version_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(version_lbl)

	# 淡入动画
	_fade_overlay.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, 1.2)

func _draw_decorative_frame() -> void:
	# 顶部装饰线
	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.color = Color(0.40, 0.55, 0.70, 0.3)
	top_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_top = 0
	top_line.offset_bottom = 2
	top_line.z_index = 5
	add_child(top_line)

	# 底部装饰线
	var bottom_line = ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.color = Color(0.40, 0.55, 0.70, 0.3)
	bottom_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_line.offset_top = -2
	bottom_line.offset_bottom = 0
	bottom_line.z_index = 5
	add_child(bottom_line)

func _make_steam_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	normal_style.set_corner_radius_all(6)
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color(0.35, 0.50, 0.65, 0.7)
	normal_style.set_content_margin_all(16)
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.12, 0.18, 0.26, 0.95)
	hover_style.set_corner_radius_all(6)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0.60, 0.80, 1.0, 0.9)
	hover_style.set_content_margin_all(16)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	pressed_style.set_corner_radius_all(6)
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = Color(0.50, 0.70, 0.90, 0.8)
	pressed_style.set_content_margin_all(16)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.04, 0.06, 0.10, 0.7)
	disabled_style.set_corner_radius_all(6)
	disabled_style.set_border_width_all(1)
	disabled_style.border_color = Color(0.20, 0.25, 0.35, 0.5)
	disabled_style.set_content_margin_all(16)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	btn.add_theme_color_override("font_pressed_color", Color(0.70, 0.75, 0.90))
	btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.45, 0.55))
	btn.add_theme_font_size_override("font_size", 18)
	
	return btn

func _check_save_exists() -> void:
	# 检查是否存在存档
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.has_method("has_save") and save_mgr.has_save(0):
			_continue_btn.disabled = false
			return
	_continue_btn.disabled = true
	print("[TitleScreen] No save found — continue disabled")

# === 按钮响应 ===

func _on_new_game_pressed() -> void:
	print("[TitleScreen] New Game pressed")
	_set_buttons_enabled(false)
	_fade_to_black(0.6)
	await get_tree().create_timer(0.7).timeout
	_start_new_game()

func _on_continue_pressed() -> void:
	if _continue_btn.disabled:
		_show_toast("暂无存档")
		return
	print("[TitleScreen] Continue pressed")
	_set_buttons_enabled(false)
	_fade_to_black(0.6)
	await get_tree().create_timer(0.7).timeout
	_load_and_continue()

func _start_new_game() -> void:
	# 重置 GameState
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		gs.reset()
		gs.gold = 5000
		gs.player_name = "船长"
		gs.current_zone = gs.ZoneType.PORT
		gs.current_port_id = "rusty_bay"
		print("[TitleScreen] GameState reset for new game")

	# 重置 GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.current_port_id = "rusty_bay"
		gm.current_sea_area_id = "rusty_bay"
		gm.player_gold = 5000
		gm.explored_areas = ["rusty_bay"]
		gm.unlocked_ports = ["rusty_bay"]
		gm.current_state = gm.PlayState.WORLD_MAP
		print("[TitleScreen] GameManager reset for new game")

	# 初始化剧情节点标志
	_init_story_flags()

	# 切换到 World 场景
	_change_to_world()

func _init_story_flags() -> void:
	if has_node("/root/StoryManager"):
		var sm = get_node("/root/StoryManager")
		sm.reset_progress()
		sm.set_flag("prologue_complete", false)
		sm.set_flag("chapter_1_complete", false)
		sm.set_flag("first_bounty_complete", false)
		sm.set_flag("companion_keerli_bond_2", false)
		sm.set_flag("companion_tiechan_bond_2", false)
		sm.set_flag("companion_shenlan_bond_2", false)
		sm.set_flag("companion_beisuo_bond_2", false)
		sm.set_flag("companion_linhuo_bond_2", false)
		print("[TitleScreen] Story flags initialized")

func _load_and_continue() -> void:
	if not has_node("/root/SaveManager"):
		_show_toast("存档系统不可用")
		_change_to_world()
		return
	
	var save_mgr = get_node("/root/SaveManager")
	if not save_mgr.has_method("get_current_save"):
		_show_toast("存档加载失败")
		_change_to_world()
		return
	
	var save_data = save_mgr.get_current_save()
	if save_data == null or save_data == {}:
		_show_toast("存档数据无效")
		_change_to_world()
		return
	
	# 应用存档数据到 GameState
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if save_data.has("game_state"):
			gs.apply_save_data(save_data.get("game_state", {}))
			print("[TitleScreen] GameState loaded from save")
	
	# 应用存档数据到 GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if save_data.has("game_manager"):
			gm._apply_save_data(save_data.get("game_manager", {}))
			print("[TitleScreen] GameManager loaded from save")
	
	_change_to_world()

func _change_to_world() -> void:
	var tree = get_tree()
	if tree:
		var err = tree.change_scene_to_file("res://scenes/worlds/World.tscn")
		if err != OK:
			push_error("[TitleScreen] Failed to load World scene: " + str(err))
		else:
			print("[TitleScreen] Loaded World.tscn")

# === 辅助 ===

func _fade_to_black(duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, duration)

func _set_buttons_enabled(enabled: bool) -> void:
	_new_game_btn.disabled = not enabled
	_continue_btn.disabled = not enabled

var _toast_label: Label = null

func _show_toast(msg: String) -> void:
	if not _toast_label:
		_toast_label = Label.new()
		_toast_label.name = "ToastLabel"
		_toast_label.set_anchors_preset(Control.PRESET_CENTER)
		_toast_label.custom_minimum_size = Vector2(400, 40)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		_toast_label.add_theme_font_size_override("font_size", 16)
		_toast_label.z_index = 200
		add_child(_toast_label)
	
	_toast_label.text = msg
	_toast_label.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_toast_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)

func _make_spacer_node(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
