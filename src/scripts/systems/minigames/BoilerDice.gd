extends Control
class_name BoilerDice

## 锅炉骰子 / Boiler Dice
## 酒馆小游戏：掷3颗骰子，根据组合计算得分
## 规则：
##   - 三个相同：10 × 点数之和
##   - 顺子 (1-2-3 到 4-5-6)：固定 20 金
##   - 对子 + 单张：对子点数 × 2 + 单张点数
##   - 散牌：点数之和
## 可"再次掷出"两次，每次可选择保留哪些骰子

signal game_started(bet: int)
signal game_ended(result: Dictionary)
signal dice_rolled(dice_values: Array[int])
signal minigame_finished(result: Dictionary)

var _current_bet: int = 0
var _dice_values: Array[int] = [0, 0, 0]
var _kept_indices: Array[int] = []  # 保留的骰子索引
var _rolls_remaining: int = 2        # 剩余再掷次数

# UI节点引用
var _dice_labels: Array[Label] = []
var _roll_btn: Button = null
var _finish_btn: Button = null
var _status_lbl: Label = null
var _result_panel: PanelContainer = null
var _result_lbl: Label = null
var _gold_change_lbl: Label = null
var _bet_buttons: Array[Button] = []

# ============================================
# Lifecycle / 生命周期
# ============================================

func _ready() -> void:
    print("[BoilerDice] _ready")
    _find_ui_nodes()
    _connect_ui_signals()
    _update_dice_display([0, 0, 0], true)
    _set_buttons_enabled(false, false)
    _status_lbl.text = "选择押注金额开始"

func _find_ui_nodes() -> void:
    # 骰子标签
    var dice_area = find_child("DiceArea", false, false)
    if dice_area:
        for i in range(3):
            var dice_node = dice_area.get_child(i)
            if dice_node:
                var lbl = dice_node.get_node_or_null("DiceLabel")
                if lbl:
                    _dice_labels.append(lbl)
    
    # 骰子也可以直接从根节点查找
    if _dice_labels.is_empty():
        for path in ["DiceArea/Dice1/DiceLabel", "DiceArea/Dice2/DiceLabel", "DiceArea/Dice3/DiceLabel"]:
            var lbl = find_child(path, false, false) as Label
            if lbl:
                _dice_labels.append(lbl)
    
    # 按钮
    _roll_btn = find_child("RollBtn", false, false) as Button
    _finish_btn = find_child("FinishBtn", false, false) as Button
    
    # 状态标签
    _status_lbl = find_child("StatusLabel", false, false) as Label
    
    # 结果面板
    _result_panel = find_child("ResultPanel", false, false) as PanelContainer
    if _result_panel:
        _result_lbl = _result_panel.get_node_or_null("ResultLabel") as Label
        _gold_change_lbl = _result_panel.get_node_or_null("GoldChangeLabel") as Label
    
    # 押注按钮
    var bet_row = find_child("BetRow", false, false)
    if bet_row:
        for child in bet_row.get_children():
            if child is Button:
                _bet_buttons.append(child)
    
    print("[BoilerDice] UI nodes found: dice_labels=%d, roll_btn=%s, finish_btn=%s" % [
        _dice_labels.size(), _roll_btn != null, _finish_btn != null])

func _connect_ui_signals() -> void:
    # 返回按钮
    var back_btn = find_child("BackBtn", false, false) as Button
    if back_btn:
        back_btn.pressed.connect(_on_back_pressed)
    
    # 押注按钮
    var bet_amounts: Array[int] = [10, 30, 50, 100]
    for i in range(mini(_bet_buttons.size(), bet_amounts.size())):
        if _bet_buttons[i]:
            _bet_buttons[i].pressed.connect(_on_bet_selected.bind(bet_amounts[i]))
    
    # 投掷按钮
    if _roll_btn:
        _roll_btn.pressed.connect(_on_roll_pressed)
    
    # 确认结果按钮
    if _finish_btn:
        _finish_btn.pressed.connect(_on_finish_pressed)
    
    # 骰子点击（选择保留）
    _connect_dice_clicks()

func _connect_dice_clicks() -> void:
    var dice_area = find_child("DiceArea", false, false)
    if dice_area:
        for i in range(dice_area.get_child_count()):
            var dice_node = dice_area.get_child(i)
            if dice_node is PanelContainer:
                var btn = Button.new()
                btn.set_anchors_preset(Control.PRESET_FULL_RECT)
                btn.flat = true
                btn.theme_type_variation = ""
                var idx = i  # capture
                btn.pressed.connect(_on_dice_clicked.bind(idx))
                dice_node.add_child(btn)

func _on_back_pressed() -> void:
    print("[BoilerDice] Back pressed")
    var result := {"gold_change": 0, "cancelled": true}
    minigame_finished.emit(result)
    queue_free()

# ============================================
# Public API / 公开接口
# ============================================

## 开始游戏，设置押注金额
## bet: 押注金币，最小10
## 返回: 是否开始成功
func start_game(bet: int) -> bool:
    if bet < 10:
        print("[BoilerDice] Bet too small: %d (min 10)" % bet)
        return false
    
    var game_state := _get_game_state()
    if not game_state or game_state.gold < bet:
        print("[BoilerDice] Not enough gold: have %d, need %d" % [game_state.gold if game_state else 0, bet])
        return false
    
    # 扣除押注金币
    if game_state and game_state.has_method("spend_gold"):
        game_state.spend_gold(bet)
    
    _current_bet = bet
    _rolls_remaining = 2
    _kept_indices.clear()
    game_started.emit(bet)
    print("[BoilerDice] Game started with bet: %d" % bet)
    return true

## 掷骰子（保留指定的骰子索引）
## kept_indices: 要保留的骰子索引数组，如 [0, 2] 保留第1和第3颗
## 返回: 当前三颗骰子的值
func roll(kept_indices: Array[int] = []) -> Array[int]:
    _kept_indices = kept_indices
    
    for i in range(3):
        if not (i in _kept_indices):
            _dice_values[i] = randi() % 6 + 1
    
    _rolls_remaining -= 1
    dice_rolled.emit(_dice_values)
    print("[BoilerDice] Rolled: %s (kept: %s), %d rolls left" % [_dice_values, _kept_indices, _rolls_remaining])
    return _dice_values.duplicate()

## 完成游戏并返回结果
## 返回: Dictionary { gold_change, total_win, score, combo_name }
func finish() -> Dictionary:
    var score: int = _calculate_score()
    var combo_name: String = _get_combo_name()
    var total_win: int = score * _current_bet / 10  # 得分转化为金币奖励
    
    var game_state := _get_game_state()
    if game_state:
        game_state.add_gold(total_win)
    
    var result: Dictionary = {
        "gold_change": total_win,
        "total_win": total_win,
        "score": score,
        "combo_name": combo_name,
        "dice_values": _dice_values.duplicate(),
        "bet": _current_bet,
    }
    
    game_ended.emit(result)
    print("[BoilerDice] Game ended: %s → win %d gold" % [combo_name, total_win])
    
    # Reset
    _current_bet = 0
    _dice_values = [0, 0, 0]
    _kept_indices.clear()
    _rolls_remaining = 2
    
    return result

## 获取当前骰子值
func get_dice_values() -> Array[int]:
    return _dice_values.duplicate()

## 获取剩余再掷次数
func get_rolls_remaining() -> int:
    return _rolls_remaining

## 是否仍在游戏中
func is_game_active() -> bool:
    return _current_bet > 0

# ============================================
# UI 交互处理
# ============================================

func _on_bet_selected(bet: int) -> void:
    print("[BoilerDice] Bet selected: %d" % bet)
    if start_game(bet):
        _update_status("押注 %d 金，开始投掷！" % bet)
        _set_bet_buttons_enabled(false)
        _roll_btn.disabled = false
        _roll_btn.text = "🎲 投掷骰子 (剩余2次)"
        _kept_indices.clear()
        # 自动投掷
        _do_roll([])

func _on_roll_pressed() -> void:
    if _rolls_remaining <= 0:
        return
    _do_roll(_kept_indices)

func _do_roll(kept: Array[int]) -> void:
    roll(kept)
    _animate_dice_roll()
    _update_dice_display(_dice_values, false)
    
    if _rolls_remaining > 0:
        _roll_btn.text = "🎲 再投一次 (剩余%d次)" % _rolls_remaining
        _finish_btn.disabled = false
    else:
        _roll_btn.disabled = true
        _roll_btn.text = "无剩余投掷次数"
        _finish_btn.disabled = false

func _on_dice_clicked(index: int) -> void:
    """点击骰子切换保留状态"""
    if index in _kept_indices:
        _kept_indices.erase(index)
    else:
        _kept_indices.append(index)
    _update_dice_highlight()

func _on_finish_pressed() -> void:
    print("[BoilerDice] Finish pressed")
    _finish_btn.disabled = true
    _roll_btn.disabled = true
    
    var result = finish()
    
    # 显示结果
    _show_result(result)

func _show_result(result: Dictionary) -> void:
    if _result_panel:
        _result_panel.visible = true
    
    if _result_lbl:
        var combo = result.get("combo_name", "?")
        var score = result.get("score", 0)
        _result_lbl.text = "%s\n得分: %d" % [combo, score]
    
    if _gold_change_lbl:
        var change = result.get("gold_change", 0)
        if change > 0:
            _gold_change_lbl.text = "🎉 +%d 金！" % change
            _gold_change_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
        else:
            _gold_change_lbl.text = "💸 失去 %d 金" % _current_bet
            _gold_change_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
    
    _update_status("游戏结束！")
    
    # 3秒后自动关闭（或等待点击返回）
    await get_tree().create_timer(3.0).timeout
    minigame_finished.emit(result)
    queue_free()

# ============================================
# UI 更新方法
# ============================================

func _update_dice_display(values: Array[int], reset: bool) -> void:
    var dice_faces := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
    for i in range(mini(_dice_labels.size(), 3)):
        if i < values.size():
            if reset or values[i] == 0:
                _dice_labels[i].text = "?"
            else:
                _dice_labels[i].text = dice_faces[values[i] - 1]
        else:
            _dice_labels[i].text = "?"

func _animate_dice_roll() -> void:
    """骰子滚动动画"""
    var tween = create_tween()
    var faces := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
    
    for i in range(_dice_labels.size()):
        if not (i in _kept_indices):
            # 快速切换动画
            var steps = 8
            for s in range(steps):
                var delay = s * 0.05
                var face_idx = randi() % 6
                tween.tween_callback(func():
                    if i < _dice_labels.size():
                        _dice_labels[i].text = faces[face_idx]
                ).with_delay(delay)

func _update_dice_highlight() -> void:
    """更新骰子保留高亮"""
    var dice_area = find_child("DiceArea", false, false)
    if dice_area:
        for i in range(dice_area.get_child_count()):
            var dice_node = dice_area.get_child(i)
            if dice_node is PanelContainer:
                var is_kept = (i in _kept_indices)
                var style = StyleBoxFlat.new()
                style.bg_color = Color(0.3, 0.25, 0.15, 0.8) if is_kept else Color(0.12, 0.1, 0.08, 0.8)
                style.border_width_left = 3 if is_kept else 0
                style.border_color = Color(1.0, 0.8, 0.2) if is_kept else Color(0, 0, 0, 0)
                dice_node.add_theme_stylebox_override("panel", style)

func _update_status(text: String) -> void:
    if _status_lbl:
        _status_lbl.text = text

func _set_buttons_enabled(roll_enabled: bool, finish_enabled: bool) -> void:
    if _roll_btn:
        _roll_btn.disabled = not roll_enabled
    if _finish_btn:
        _finish_btn.disabled = not finish_enabled

func _set_bet_buttons_enabled(enabled: bool) -> void:
    for btn in _bet_buttons:
        if btn:
            btn.disabled = not enabled

# ============================================
# Scoring Logic / 计分逻辑
# ============================================

func _calculate_score() -> int:
    var d := _dice_values.duplicate()
    d.sort()
    
    # 三个相同
    if d[0] == d[1] and d[1] == d[2]:
        return 10 * d[0]  # 10倍点数
    
    # 顺子
    if d[0] + 1 == d[1] and d[1] + 1 == d[2]:
        return 20  # 固定20分
    
    # 对子
    if d[0] == d[1] or d[1] == d[2] or d[0] == d[2]:
        var pair_val: int = 0
        var single_val: int = 0
        if d[0] == d[1]:
            pair_val = d[0]
            single_val = d[2]
        elif d[1] == d[2]:
            pair_val = d[1]
            single_val = d[0]
        else:
            pair_val = d[0]
            single_val = d[1]
        return pair_val * 2 + single_val
    
    # 散牌：点数之和
    return d[0] + d[1] + d[2]

func _get_combo_name() -> String:
    var d := _dice_values.duplicate()
    d.sort()
    
    if d[0] == d[1] and d[1] == d[2]:
        return "三同！[%d%d%d]" % [d[0], d[1], d[2]]
    if d[0] + 1 == d[1] and d[1] + 1 == d[2]:
        return "顺子！[%d-%d-%d]" % [d[0], d[1], d[2]]
    if d[0] == d[1] or d[1] == d[2] or d[0] == d[2]:
        return "对子！[%d%d%ds]" % [d[0], d[1], d[2]]
    return "散牌 (%d点)" % (d[0] + d[1] + d[2])

# ============================================
# Utility / 工具
# ============================================

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs