extends BattleState

## BATTLE_END — 战斗结束，弹出结果

var winner: int = -1
var loot: Dictionary = {}
var _battle_end_timer: Timer = null
var _waiting_for_click: bool = false

func _init(sm: BattleStateMachine) -> void:
	super._init(sm)
	name = "BATTLE_END"

func enter() -> void:
	print("[BattleEnd] 战斗结束")

	var tm: Node = get_turn_manager()
	if tm and tm.has_method("get_battle_result"):
		var result: Dictionary = tm.get_battle_result()
		winner = result.get("winner", -1)
		loot = result.get("loot", {})

	# 播放结束动画
	_play_battle_end_animation()

	# 显示结算UI（胜利/失败不同显示）
	_show_battle_end_ui()

	# 通知战斗管理器
	if tm and tm.has_method("on_battle_end"):
		tm.on_battle_end(winner == 1)
	if tm and tm.has_method("show_battle_end_ui"):
		tm.show_battle_end_ui(winner, loot)

	# 关键节点自动存档：战斗胜利时触发
	if winner == 1 and SaveManager and SaveManager.has_method("trigger_auto_save"):
		SaveManager.trigger_auto_save("battle_victory")

func _play_battle_end_animation() -> void:
	var tm: Node = get_turn_manager()
	if tm and tm.has_method("play_battle_end_animation"):
		tm.play_battle_end_animation(winner)

## 显示战斗结算UI（区分胜利/失败）
func _show_battle_end_ui() -> void:
	var tm: Node = get_turn_manager()

	if winner == 1:
		# ── 胜利：显示获得的奖励 ──
		var gold: int = loot.get("gold", 0)
		var items: Array = loot.get("items", [])
		_show_victory_panel(gold, items)
		# 5秒后自动返回，或等待点击
		_setup_return_timer(5.0)
	elif winner == 0:
		# ── 失败：显示 Game Over 选项 ──
		_show_game_over_panel()
		# 等待玩家点击「重新开始」或「返回港口」
		_waiting_for_click = true

func _show_victory_panel(gold: int, items: Array) -> void:
	var hud: Node = _find_hud()
	if not hud:
		return

	var panel: Panel = Panel.new()
	panel.name = "VictoryPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 220)
	panel.z_index = 200
	hud.add_child(panel)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.1, 0.05, 0.97)
	bg.set_corner_radius_all(10)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.9, 0.8, 0.2, 0.9)
	bg.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "🎉 战斗胜利！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title)

	var gold_lbl: Label = Label.new()
	gold_lbl.text = "💰 金币 +%d" % gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 18)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(gold_lbl)

	if not items.is_empty():
		var items_lbl: Label = Label.new()
		items_lbl.text = "📦 获得物品: " + ", ".join(items)
		items_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		items_lbl.add_theme_font_size_override("font_size", 14)
		items_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(items_lbl)

	var hint: Label = Label.new()
	hint.text = "（点击任意处继续，5秒后自动返回）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

	# 点击关闭
	panel.gui_input.connect(_on_victory_panel_clicked.bind(panel))

func _show_game_over_panel() -> void:
	var hud: Node = _find_hud()
	if not hud:
		return

	var panel: Panel = Panel.new()
	panel.name = "GameOverPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 200)
	panel.z_index = 200
	hud.add_child(panel)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.02, 0.02, 0.97)
	bg.set_corner_radius_all(10)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.8, 0.1, 0.1, 0.9)
	bg.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "💀 战斗失败"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "你的船在战斗中沉没了..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(subtitle)

	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var restart_btn: Button = Button.new()
	restart_btn.text = "🔄 重新挑战"
	restart_btn.custom_minimum_size = Vector2(140, 40)
	restart_btn.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(restart_btn)

	var return_btn: Button = Button.new()
	return_btn.text = "⚓ 返回港口"
	return_btn.custom_minimum_size = Vector2(140, 40)
	return_btn.pressed.connect(_on_return_to_port_pressed)
	btn_hbox.add_child(return_btn)

func _on_victory_panel_clicked(_event: InputEvent, panel: Panel) -> void:
	panel.queue_free()
	_return_to_world_map()

func _on_restart_pressed() -> void:
	print("[BattleEnd] Restart battle")
	var tree := get_tree()
	if tree and tree.change_scene_to_file("res://scenes/battles/Battle.tscn") != OK:
		push_error("[BattleEnd] Failed to restart battle")

func _on_return_to_port_pressed() -> void:
	_return_to_world_map()

func _setup_return_timer(delay: float) -> void:
	_waiting_for_click = false
	if _battle_end_timer:
		_battle_end_timer.timeout.disconnect(_return_to_world_map)
		_battle_end_timer.queue_free()
	_battle_end_timer = Timer.new()
	_battle_end_timer.one_shot = true
	_battle_end_timer.wait_time = delay
	_battle_end_timer.timeout.connect(_return_to_world_map)
	var tm: Node = get_turn_manager()
	if tm:
		tm.get_tree().root.add_child(_battle_end_timer)
		_battle_end_timer.start()

func _find_hud() -> Node:
	var tree := get_tree()
	if not tree or not tree.root:
		return null
	return tree.root.find_child("HUD", false, false)

func _return_to_world_map() -> void:
	if _battle_end_timer:
		_battle_end_timer.queue_free()
		_battle_end_timer = null
	print("[BattleEnd] 返回世界地图")
	# 清理结算面板
	var hud: Node = _find_hud()
	if hud:
		var vp = hud.find_child("VictoryPanel", false, false)
		if vp:
			vp.queue_free()
		var gp = hud.find_child("GameOverPanel", false, false)
		if gp:
			gp.queue_free()

	var tree := get_tree()
	if tree:
		var gs = tree.root.find_child("GameState", false, false)
		if gs and gs.has("ZoneType"):
			gs.current_zone = gs.ZoneType.SEA
		if tree.change_scene_to_file("res://scenes/worlds/WorldMap.tscn") != OK:
			push_error("[BattleEnd] Failed to return to WorldMap")

func update(delta: float) -> void:
	pass

func exit() -> void:
	winner = -1
	loot.clear()
	_waiting_for_click = false
	if _battle_end_timer:
		_battle_end_timer.queue_free()
		_battle_end_timer = null
