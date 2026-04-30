extends CanvasLayer
## WorldMapUI.gd - 世界地图界面控制器
## 职责：管理世界地图的交互、港口节点、海域漫游、船只位置显示

# === 信号 ===
signal port_clicked(port_id: String)
signal sea_area_clicked(area_id: String)
signal return_to_port_requested()

# === 引用 ===
var _game_manager = null

# === 节点引用 ===
var _map_container: Node = null
var _ship_marker: Node = null
var _port_markers: Dictionary = {}
var _sea_area_shapes: Dictionary = {}
var _hovered_port: String = ""
var _hovered_area: String = ""
var _tooltip_label: Label = null
var _info_panel: Panel = null
var _fade_overlay: ColorRect = null
var _current_location_label: Label = null

# === 港口节点定义 ===
const PORT_DEFS := {
	"rusty_bay":     {"name": "铁锈湾",     "pos": Vector2(180, 280), "emoji": "⚓", "explored": true},
	"industrial_port":{"name": "工业港",    "pos": Vector2(820, 120), "emoji": "🏭", "explored": false},
	"pirate_cove":   {"name": "海盗港",     "pos": Vector2(1050, 420),"emoji": "☠️", "explored": false},
	"storm_ridge":   {"name": "风暴岭",     "pos": Vector2(560, 80),  "emoji": "⛈️", "explored": false},
	"abyssal_trench": {"name": "深渊海沟",  "pos": Vector2(920, 580), "emoji": "🌀", "explored": false}
}

# === 海域区域定义 ===
const SEA_AREA_DEFS := {
	"rusty_bay":      {"name": "锈海湾",    "polygon": [Vector2(80,180),Vector2(320,180),Vector2(320,400),Vector2(80,400)],      "explored": true},
	"industrial_port":{"name": "工业海峡",  "polygon": [Vector2(700,60),Vector2(960,60),Vector2(960,240),Vector2(700,240)],     "explored": false},
	"pirate_cove":    {"name": "海盗湾",    "polygon": [Vector2(900,360),Vector2(1140,360),Vector2(1140,620),Vector2(900,620)],  "explored": false},
	"storm_ridge":    {"name": "风暴岭",    "polygon": [Vector2(420,40),Vector2(680,40),Vector2(680,160),Vector2(420,160)],      "explored": false},
	"abyssal_trench": {"name": "深渊海沟",  "polygon": [Vector2(780,480),Vector2(1080,480),Vector2(1080,640),Vector2(780,640)], "explored": false}
}

func _draw_map() -> void:
	# Map drawing handled via _setup_ui() which creates polygons/markers
	pass

func _ready() -> void:
	print("[WorldMapUI] Ready")
	_setup_ui()
	_load_game_manager()
	_draw_map()
	_update_ship_position()
	_update_bounty_hints()

func _setup_ui() -> void:
	# 世界地图容器
	_map_container = Node2D.new()
	_map_container.name = "MapContainer"
	add_child(_map_container)

	# 海域背景（手绘风格）
	_draw_sea_areas()

	# 港口节点
	_draw_port_markers()

	# 船只位置标记
	_draw_ship_marker()

	# 提示标签（底部）
	_setup_tooltip()

	# 当前位置标签
	_setup_location_label()

	# 信息面板（右侧）
	_setup_info_panel()

	# 淡入淡出叠加层
	_setup_fade_overlay()

	# 顶部导航栏
	_setup_top_bar()

func _load_game_manager() -> void:
	_game_manager = GameManager  # Use autoload
	_sync_from_game_manager()
	print("[WorldMapUI] GameManager (autoload) connected")

func _sync_from_game_manager() -> void:
	if not _game_manager:
		return
	# 同步探索状态
	for port_id in PORT_DEFS:
		var is_unlocked = _game_manager.is_port_unlocked(port_id)
		if is_unlocked:
			_set_port_explored(port_id, true)

# === 绘制海域区域（手绘风格） ===

func _draw_sea_areas() -> void:
	# 海域背景底色
	var bg = ColorRect.new()
	bg.name = "SeaBackground"
	bg.color = Color(0.04, 0.07, 0.12, 1.0)  # 深蓝黑色海洋
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# 绘制各个海域多边形
	for area_id in SEA_AREA_DEFS:
		var area_def = SEA_AREA_DEFS[area_id]
		var polygon = _create_sea_area_polygon(area_id, area_def)
		_map_container.add_child(polygon)

func _create_sea_area_polygon(area_id: String, area_def: Dictionary) -> Node:
	var polygon_node = Polygon2D.new()
	polygon_node.name = "SeaArea_" + area_id
	var points = area_def.get("polygon", [])
	if not points.is_empty():
		polygon_node.polygon = PackedVector2Array(points)
	
	var is_explored = area_def.get("explored", false)
	if is_explored:
		polygon_node.color = Color(0.12, 0.18, 0.25, 0.6)
	else:
		polygon_node.color = Color(0.06, 0.08, 0.12, 0.4)
	
	polygon_node.z_index = -5
	
	# 边缘高亮 - Polygon2D在Godot 4中没有outline属性,用另一个Polygon2D实现
	var outline = Polygon2D.new()
	outline.name = "Outline_" + area_id
	outline.polygon = PackedVector2Array(points)
	outline.color = Color(0.3, 0.5, 0.7, 0.15)
	outline.z_index = -4
	
	var container = Node2D.new()
	container.name = "SeaAreaContainer_" + area_id
	container.add_child(polygon_node)
	container.add_child(outline)
	
	_sea_area_shapes[area_id] = container
	return container

# === 绘制港口标记 ===

func _draw_port_markers() -> void:
	for port_id in PORT_DEFS:
		var port_def = PORT_DEFS[port_id]
		_create_port_marker(port_id, port_def)

func _create_port_marker(port_id: String, port_def: Dictionary) -> void:
	var marker = Control.new()
	marker.name = "PortMarker_" + port_id
	marker.position = port_def.pos - Vector2(24, 24)
	marker.custom_minimum_size = Vector2(48, 48)
	
	# 港口图标（Emoji标签）
	var icon = Label.new()
	icon.name = "Icon"
	icon.text = port_def.get("emoji", "⚓")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 36)
	marker.add_child(icon)
	
	# 港口名称
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = port_def.get("name", "?")
	name_lbl.position = Vector2(-20, 40)
	name_lbl.size = Vector2(88, 24)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	name_lbl.add_theme_font_size_override("font_size", 13)
	marker.add_child(name_lbl)
	
	# 未解锁状态覆盖
	var lock_overlay = Control.new()
	lock_overlay.name = "LockOverlay"
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_overlay.visible = not port_def.get("explored", false)
	
	var lock_icon = Label.new()
	lock_icon.text = "🔒"
	lock_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_icon.add_theme_font_size_override("font_size", 28)
	lock_overlay.add_child(lock_icon)
	marker.add_child(lock_overlay)
	
	_port_markers[port_id] = marker
	_map_container.add_child(marker)

func _set_port_explored(port_id: String, explored: bool) -> void:
	if PORT_DEFS.has(port_id):
		_set_dict_value(PORT_DEFS[port_id], "explored", explored)
	
	if _port_markers.has(port_id):
		var marker = _port_markers[port_id]
		var lock_overlay = marker.find_child("LockOverlay", true, false)
		if lock_overlay:
			lock_overlay.visible = not explored
		
		# 未探索时降低透明度
		marker.modulate = Color(1.0, 1.0, 1.0, 0.6) if not explored else Color(1.0, 1.0, 1.0, 1.0)
	
	# 更新海域探索状态
	for area_id in SEA_AREA_DEFS:
		if SEA_AREA_DEFS[area_id].get("port_id", "") == port_id:
			_set_dict_value(SEA_AREA_DEFS[area_id], "explored", explored)
			_refresh_sea_area_appearance(area_id)

func _set_dict_value(dict: Dictionary, key: String, value) -> void:
	# Godot 4 的 Dictionary 是引用传递，不需要特殊处理
	pass

func _refresh_sea_area_appearance(area_id: String) -> void:
	if _sea_area_shapes.has(area_id):
		var container = _sea_area_shapes[area_id]
		var polygon = container.find_child(area_id, false, false)
		if polygon:
			var is_explored = SEA_AREA_DEFS[area_id].get("explored", false)
			polygon.color = Color(0.12, 0.18, 0.25, 0.6) if is_explored else Color(0.06, 0.08, 0.12, 0.4)

# === 绘制船只标记 ===

func _draw_ship_marker() -> void:
	_ship_marker = Node2D.new()
	_ship_marker.name = "ShipMarker"
	_ship_marker.z_index = 10
	
	var ship_icon = Label.new()
	ship_icon.name = "Icon"
	ship_icon.text = "⛵"
	ship_icon.add_theme_font_size_override("font_size", 32)
	_ship_marker.add_child(ship_icon)
	
	_map_container.add_child(_ship_marker)

func _update_ship_position() -> void:
	if not _ship_marker:
		return
	
	var current_port_id = "rusty_bay"
	if _game_manager:
		current_port_id = _game_manager.current_port_id
	
	if PORT_DEFS.has(current_port_id):
		var target_pos = PORT_DEFS[current_port_id].pos - Vector2(16, 16)
		_ship_marker.position = target_pos
		_ship_marker.z_index = 10
		
		# 平滑动画
		var tween = create_tween()
		tween.tween_property(_ship_marker, "position", target_pos, 0.5)
	else:
		_ship_marker.position = Vector2(180, 280)

# === 顶部导航栏 ===

func _setup_top_bar() -> void:
	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 400
	top_bar.offset_bottom = 50
	top_bar.custom_minimum_size = Vector2(0, 50)
	add_child(top_bar)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	style.set_corner_radius_all(0)
	style.set_border_width_all(0)
	style.set_content_margin_all(12)
	top_bar.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(hbox)
	
	# 船只名称
	var ship_lbl = Label.new()
	ship_lbl.text = "⛵ 蒸汽破浪号"
	ship_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	ship_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(ship_lbl)
	
	hbox.add_child(_make_spacer())
	
	# 金币显示
	var gold_lbl = Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.text = "💰 %d 金克朗" % (_game_manager.player_gold if _game_manager else 5000)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(gold_lbl)

# === 当前位置标签 ===

func _setup_location_label() -> void:
	var lbl = Label.new()
	lbl.name = "CurrentLocationLabel"
	lbl.text = "📍 当前位置: 铁锈湾"
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_left = 20
	lbl.offset_bottom = -20
	lbl.offset_top = lbl.offset_bottom - 30
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	lbl.add_theme_font_size_override("font_size", 14)
	add_child(lbl)
	_current_location_label = lbl

func _update_location_label() -> void:
	if not _current_location_label or not _game_manager:
		return
	var port_data = _game_manager.get_current_port()
	var port_name = port_data.get("name", "未知")
	_current_location_label.text = "📍 当前位置: " + port_name

# === 提示标签 ===

func _setup_tooltip() -> void:
	_tooltip_label = Label.new()
	_tooltip_label.name = "TooltipLabel"
	_tooltip_label.text = "点击港口进入，或点击海域开始探索"
	_tooltip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tooltip_label.offset_left = 20
	_tooltip_label.offset_right = -20
	_tooltip_label.offset_bottom = -60
	_tooltip_label.offset_top = _tooltip_label.offset_bottom - 28
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	add_child(_tooltip_label)

# === 信息面板 ===

func _setup_info_panel() -> void:
	_info_panel = Panel.new()
	_info_panel.name = "InfoPanel"
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.offset_left = -260
	_info_panel.offset_top = 70
	_info_panel.offset_right = -20
	_info_panel.offset_bottom = 380
	_info_panel.custom_minimum_size = Vector2(240, 310)
	_info_panel.visible = false
	add_child(_info_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.15, 0.92)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.45, 0.6, 0.5)
	style.set_content_margin_all(12)
	_info_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	_info_panel.add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.name = "PanelTitle"
	title.text = "📋 航行信息"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
	
	# 悬赏追踪提示区域
	var bounty_hints_label = Label.new()
	bounty_hints_label.name = "BountyHints"
	bounty_hints_label.text = "（无悬赏追踪）"
	bounty_hints_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	bounty_hints_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.55))
	bounty_hints_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(bounty_hints_label)
	
	vbox.add_child(_make_spacer_node(8))
	
	# 操作按钮
	var sail_btn = Button.new()
	sail_btn.name = "SailButton"
	sail_btn.text = "⚓ 起航返回港口"
	sail_btn.pressed.connect(_on_sail_return_pressed)
	vbox.add_child(sail_btn)
	
	var explore_btn = Button.new()
	explore_btn.name = "ExploreButton"
	explore_btn.text = "🔍 探索海域"
	explore_btn.pressed.connect(_on_explore_pressed)
	vbox.add_child(explore_btn)

# === 淡入淡出叠加层 ===

func _setup_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.z_index = 100
	add_child(_fade_overlay)

func fade_to_black(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, duration)

func fade_from_black(duration: float = 0.5) -> void:
	_fade_overlay.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, duration)

# === 赏金追踪提示 ===

func _update_bounty_hints() -> void:
	if not _info_panel:
		return
	
	var hints_label = _info_panel.find_child("BountyHints", true, false)
	if hints_label and _game_manager:
		var hints = _game_manager.get_bounty_tracker_hints()
		if hints.is_empty():
			hints_label.text = "（无悬赏追踪）"
		else:
			var lines: Array[String] = []
			for hint in hints:
				var area_name = hint.get("location", "?")
				var name = hint.get("name", "?")
				var diff = hint.get("difficulty", "?")
				lines.append("📍 %s: %s [%s]" % [area_name, name, diff])
			hints_label.text = "\n".join(lines)

# === 输入处理 ===

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)
	elif event is InputEventKey and event.pressed:
		_handle_key(event)

func _handle_mouse_motion(pos: Vector2) -> void:
	var hovered_port = _get_port_at_position(pos)
	var hovered_area = _get_sea_area_at_position(pos)
	
	if hovered_port != _hovered_port or hovered_area != _hovered_area:
		_hovered_port = hovered_port
		_hovered_area = hovered_area
		_update_hover_visual()
		_update_tooltip()

func _handle_click(pos: Vector2) -> void:
	var port_id = _get_port_at_position(pos)
	var area_id = _get_sea_area_at_position(pos)
	
	if port_id != "":
		_on_port_clicked(port_id)
	elif area_id != "":
		_on_sea_area_clicked(area_id)

func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_show_info_panel(false)
	elif event.keycode == KEY_TAB or event.keycode == KEY_M:
		_toggle_info_panel()

# === 碰撞检测 ===

func _get_port_at_position(pos: Vector2) -> String:
	# Port collision detection using global coordinates
	for port_id in _port_markers:
		var marker = _port_markers[port_id]
		var marker_rect = Rect2(marker.global_position, marker.size)
		if marker_rect.has_point(pos):
			return port_id
	return ""

func _get_sea_area_at_position(pos: Vector2) -> String:
	# 简单多边形碰撞检测
	for area_id in SEA_AREA_DEFS:
		var area_def = SEA_AREA_DEFS[area_id]
		var poly = area_def.get("polygon", [])
		if _point_in_polygon(pos, poly):
			return area_id
	return ""

func _point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if polygon.size() < 3:
		return false
	var inside = false
	var j = polygon.size() - 1
	for i in range(polygon.size()):
		var pi = polygon[i]
		var pj = polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
		   (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 0.001) + pi.x):
			inside = not inside
		j = i
	return inside

# === 高亮更新 ===

func _update_hover_visual() -> void:
	# 港口高亮
	for port_id in _port_markers:
		var marker = _port_markers[port_id]
		var is_hovered = (port_id == _hovered_port)
		var icon = marker.find_child("Icon", true, false)
		if icon:
			icon.modulate = Color(1.0, 0.85, 0.3, 1.0) if is_hovered else Color(1.0, 1.0, 1.0, 1.0)
		
		var name_lbl = marker.find_child("NameLabel", true, false)
		if name_lbl:
			name_lbl.add_theme_color_override("font_color", 
				Color(1.0, 0.9, 0.5) if is_hovered else Color(0.7, 0.65, 0.5))
		
		# 缩放动画
		var target_scale = 1.25 if is_hovered else 1.0
		var tween = create_tween()
		tween.tween_property(marker, "scale", Vector2(target_scale, target_scale), 0.12)

func _update_tooltip() -> void:
	if _hovered_port != "":
		var port_def = PORT_DEFS.get(_hovered_port, {})
		var name = port_def.get("name", "?")
		var emoji = port_def.get("emoji", "⚓")
		var explored = port_def.get("explored", false)
		if explored:
			_tooltip_label.text = "%s %s — 点击进入港口" % [emoji, name]
		else:
			_tooltip_label.text = "%s %s — 🔒 未探索" % [emoji, name]
	elif _hovered_area != "":
		var area_def = SEA_AREA_DEFS.get(_hovered_area, {})
		var name = area_def.get("name", "?")
		_tooltip_label.text = "🌊 %s — 点击在此海域探索" % name
	else:
		_tooltip_label.text = "点击港口进入，或点击海域开始探索"

# === 点击处理 ===

func _on_port_clicked(port_id: String) -> void:
	print("[WorldMapUI] Port clicked: ", port_id)
	
	if not _game_manager:
		push_error("[WorldMapUI] GameManager not available")
		return
	
	# 检查港口是否已解锁
	if not _game_manager.is_port_unlocked(port_id):
		_show_toast("该港口尚未解锁")
		return
	
	# 当前港口则直接进入
	if _game_manager.current_port_id == port_id:
		_game_manager.change_scene_to_port(port_id)
		return
	
	# 淡出并切换场景
	fade_to_black(0.4)
	await get_tree().create_timer(0.5).timeout
	_game_manager.sail_to_port(port_id)

func _on_sea_area_clicked(area_id: String) -> void:
	print("[WorldMapUI] Sea area clicked: ", area_id)
	
	if not _game_manager:
		return
	
	if not _game_manager.is_area_explored(area_id):
		_show_toast("该海域尚未探索")
		return
	
	# 执行海域探索（随机遭遇）
	_show_exploration_dialog(area_id)

func _show_exploration_dialog(area_id: String) -> void:
	var area_def = SEA_AREA_DEFS.get(area_id, {})
	var area_name = area_def.get("name", "?")
	
	# 简单处理：直接触发遭遇判定
	fade_to_black(0.3)
	await get_tree().create_timer(0.4).timeout
	
	var encounter = _game_manager.roll_sea_encounter()
	if encounter.get("type") == "none":
		_show_toast("海面平静无事...")
		_game_manager.set_sea_area(area_id)
		fade_from_black(0.3)
	else:
		# 触发战斗或特殊事件
		_game_manager.set_sea_area(area_id)
		_game_manager.change_scene_to_battle(encounter)

# === 按钮响应 ===

func _on_sail_return_pressed() -> void:
	if _game_manager:
		fade_to_black(0.4)
		await get_tree().create_timer(0.5).timeout
		_game_manager.depart_from_port()

func _on_explore_pressed() -> void:
	_show_toast("选择一片海域进行探索")
	_show_info_panel(false)

# === 信息面板 ===

func _toggle_info_panel() -> void:
	_show_info_panel(not _info_panel.visible)

func _show_info_panel(show: bool) -> void:
	_info_panel.visible = show
	if show:
		_update_bounty_hints()

# === Toast 提示 ===

var _toast_timer: Timer = null
var _toast_label: Label = null

func _show_toast(msg: String) -> void:
	if not _toast_label:
		_toast_label = Label.new()
		_toast_label.name = "ToastLabel"
		_toast_label.set_anchors_preset(Control.PRESET_CENTER)
		_toast_label.custom_minimum_size = Vector2(400, 40)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		_toast_label.add_theme_font_size_override("font_size", 15)
		_toast_label.z_index = 200
		add_child(_toast_label)
	
	_toast_label.text = msg
	_toast_label.modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property(_toast_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	
	if _toast_timer:
		_toast_timer.queue_free()
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func(): _toast_label.modulate.a = 0)
	add_child(_toast_timer)
	_toast_timer.start(2.2)

# === 辅助函数 ===

func _make_spacer() -> Control:
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _make_spacer_node(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
