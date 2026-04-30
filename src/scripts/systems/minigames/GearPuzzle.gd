extends Control
class_name GearPuzzle

## 齿轮拼图 / Gear Puzzle
## 酒馆小游戏：旋转齿轮使所有齿轮联动
## 玩家通过点击旋转特定齿轮，目标是让所有齿轮都转动起来

signal puzzle_started(grid_size: Vector2i)
signal gear_rotated(gear_index: int, direction: int)
signal puzzle_solved(moves_used: int, reward_item: String)
signal puzzle_failed(reason: String)
signal tick_update(moves_remaining: int)
signal minigame_finished(result: Dictionary)

const GRID_WIDTH: int = 3
const GRID_HEIGHT: int = 3
const MAX_MOVES: int = 15

var _gears: Array[Dictionary] = []
var _moves_used: int = 0
var _moves_remaining: int = MAX_MOVES
var _is_solved: bool = false
var _is_active: bool = false

# Gear emoji states
const _gear_faces := ["⚙️", "⚙️", "⚙️", "⚙️"]

# UI references
var _gear_buttons: Array[Button] = []
var _start_btn: Button = null
var _finish_btn: Button = null
var _moves_lbl: Label = null
var _status_lbl: Label = null
var _result_panel: PanelContainer = null

# ============================================
# Lifecycle / 生命周期
# ============================================

func _ready() -> void:
    print("[GearPuzzle] _ready")
    _find_ui_nodes()
    _connect_ui_signals()
    _set_gear_buttons_enabled(false)
    _finish_btn.disabled = true

func _find_ui_nodes() -> void:
    var grid = find_child("GearGrid", false, false) as GridContainer
    if grid:
        for child in grid.get_children():
            if child is Button:
                _gear_buttons.append(child)
    
    var controls = find_child("ControlsRow", false, false)
    if controls:
        var btns = controls.get_children()
        if btns.size() >= 2:
            _start_btn = btns[0] as Button
            _finish_btn = btns[1] as Button
    
    _moves_lbl = find_child("MovesLabel", false, false) as Label
    _status_lbl = find_child("StatusLabel", false, false) as Label
    _result_panel = find_child("ResultPanel", false, false) as PanelContainer
    
    print("[GearPuzzle] UI: gear_btns=%d, start=%s, finish=%s" % [
        _gear_buttons.size(), _start_btn != null, _finish_btn != null])

func _connect_ui_signals() -> void:
    var back_btn = find_child("BackBtn", false, false) as Button
    if back_btn:
        back_btn.pressed.connect(_on_back_pressed)
    
    for i in range(_gear_buttons.size()):
        if _gear_buttons[i]:
            _gear_buttons[i].pressed.connect(_on_gear_clicked.bind(i))
    
    if _start_btn:
        _start_btn.pressed.connect(_on_start_pressed)
    
    if _finish_btn:
        _finish_btn.pressed.connect(_on_finish_pressed)

func _on_back_pressed() -> void:
    print("[GearPuzzle] Back pressed")
    var result := {"gold_change": 0, "cancelled": true}
    minigame_finished.emit(result)
    queue_free()

# ============================================
# Game Flow / 游戏流程
# ============================================

func _on_start_pressed() -> void:
    print("[GearPuzzle] Start pressed")
    start_puzzle()
    _set_gear_buttons_enabled(true)
    _finish_btn.disabled = false
    _start_btn.disabled = true
    _update_moves_display()
    _update_status("点击齿轮旋转，让所有齿轮归位！")

func _on_finish_pressed() -> void:
    print("[GearPuzzle] Finish pressed")
    _finish_puzzle()

func _on_gear_clicked(index: int) -> void:
    if not _is_active or _is_solved:
        return
    if _moves_remaining <= 0:
        _update_status("步数用尽！")
        return
    
    # 顺时针旋转
    rotate_cw(index)
    _animate_gear(index)
    _update_gear_display()
    _update_moves_display()
    
    if check_solved():
        _is_solved = true
        _set_gear_buttons_enabled(false)
        _finish_btn.disabled = true
        _update_status("🎉 解谜成功！")
        await get_tree().create_timer(1.0).timeout
        _finish_puzzle()

func _finish_puzzle() -> void:
    _set_gear_buttons_enabled(false)
    _finish_btn.disabled = true
    
    var result = finish()
    _show_result(result)

func _show_result(result: Dictionary) -> void:
    if _result_panel:
        _result_panel.visible = true
    
    var result_lbl = _result_panel.get_node_or_null("ResultLabel") as Label
    var gold_lbl = _result_panel.get_node_or_null("GoldChangeLabel") as Label
    
    var solved: bool = result.get("solved", false)
    if result_lbl:
        if solved:
            result_lbl.text = "✅ 解谜成功！\n用了 %d 步" % result.get("moves_used", 0)
        else:
            result_lbl.text = "❌ 未解开谜题\n齿轮未完全归位"
    
    if gold_lbl:
        var gold_change: int = result.get("gold_change", 0)
        if gold_change > 0:
            gold_lbl.text = "🎉 +%d 金！" % gold_change
            gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
        else:
            gold_lbl.text = "💸 没有奖励"
            gold_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    
    await get_tree().create_timer(3.0).timeout
    minigame_finished.emit(result)
    queue_free()

# ============================================
# Puzzle Logic / 拼图逻辑（保持 API 兼容）
# ============================================

func start_puzzle(cols: int = GRID_WIDTH, rows: int = GRID_HEIGHT) -> void:
    _is_active = true
    _is_solved = false
    _moves_used = 0
    _moves_remaining = MAX_MOVES
    
    _gears.clear()
    for y in range(rows):
        for x in range(cols):
            _gears.append({
                "pos": Vector2i(x, y),
                "rotation": randi() % 4 * 90.0,
                "is_active": false,
                "index": _gears.size(),
            })
    
    var center_idx: int = (rows * cols) / 2
    if center_idx < _gears.size():
        _gears[center_idx]["is_active"] = true
    
    var extra_active: int = randi() % 2 + 1
    for i in range(extra_active):
        var idx: int = randi() % _gears.size()
        _gears[idx]["is_active"] = true
    
    puzzle_started.emit(Vector2i(cols, rows))
    print("[GearPuzzle] Puzzle started: %dx%d grid" % [cols, rows])
    _update_gear_display()

func rotate_cw(gear_index: int) -> bool:
    return _rotate_gear(gear_index, 1)

func rotate_ccw(gear_index: int) -> bool:
    return _rotate_gear(gear_index, -1)

func rotate_gear(gear_index: int, direction: int) -> bool:
    return _rotate_gear(gear_index, direction)

func _rotate_gear(gear_index: int, direction: int) -> bool:
    if not _is_active or _is_solved:
        return false
    if gear_index < 0 or gear_index >= _gears.size():
        return false
    if _moves_remaining <= 0:
        puzzle_failed.emit("No moves remaining")
        _is_active = false
        return false
    
    var gear: Dictionary = _gears[gear_index]
    gear["rotation"] += direction * 90.0
    _moves_used += 1
    _moves_remaining -= 1
    
    _update_adjacent_gears(gear_index)
    
    gear_rotated.emit(gear_index, direction)
    tick_update.emit(_moves_remaining)
    
    if _moves_remaining <= 0 and not check_solved():
        _is_active = false
        puzzle_failed.emit("Out of moves")
        print("[GearPuzzle] Out of moves!")
    
    return true

func _update_adjacent_gears(gear_index: int) -> void:
    var gear: Dictionary = _gears[gear_index]
    var pos: Vector2i = gear["pos"]
    var dirs: Array[Vector2i] = [
        Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
    ]
    
    for dir in dirs:
        var neighbor_pos: Vector2i = pos + dir
        for i in range(_gears.size()):
            if _gears[i]["pos"] == neighbor_pos:
                if not _gears[i]["is_active"]:
                    _gears[i]["is_active"] = true

func get_gears() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for g in _gears:
        result.append({
            "pos": g["pos"],
            "rotation": g["rotation"],
            "is_active": g["is_active"],
            "index": g["index"],
        })
    return result

func get_grid_size() -> Vector2i:
    if _gears.is_empty():
        return Vector2i(GRID_WIDTH, GRID_HEIGHT)
    var max_x: int = 0
    var max_y: int = 0
    for g in _gears:
        max_x = maxi(max_x, g["pos"].x)
        max_y = maxi(max_y, g["pos"].y)
    return Vector2i(max_x + 1, max_y + 1)

func get_moves_remaining() -> int:
    return _moves_remaining

func get_moves_used() -> int:
    return _moves_used

func check_solved() -> bool:
    if _gears.is_empty():
        return false
    for g in _gears:
        var normalized: float = fmod(g["rotation"], 360.0)
        if normalized < 0:
            normalized += 360.0
        if not g["is_active"] or normalized != 0.0:
            return false
    return true

func finish() -> Dictionary:
    var solved: bool = check_solved()
    var reward_item: String = ""
    var gold_change: int = 0
    
    if solved:
        _is_solved = true
        _is_active = false
        reward_item = "ancient_gear_part"
        gold_change = 50
        
        var game_state := _get_game_state()
        if game_state:
            game_state.add_gold(gold_change)
        
        puzzle_solved.emit(_moves_used, reward_item)
        print("[GearPuzzle] Solved in %d moves! Reward: %s" % [_moves_used, reward_item])
    else:
        puzzle_failed.emit("Not all gears are aligned")
        print("[GearPuzzle] Failed: gears not all aligned after %d moves" % _moves_used)
    
    return {
        "solved": solved,
        "moves_used": _moves_used,
        "moves_remaining": _moves_remaining,
        "reward_item": reward_item,
        "gold_change": gold_change,
    }

func is_active() -> bool:
    return _is_active

func get_gear(index: int) -> Dictionary:
    if index < 0 or index >= _gears.size():
        return {}
    return {
        "pos": _gears[index]["pos"],
        "rotation": _gears[index]["rotation"],
        "is_active": _gears[index]["is_active"],
        "index": index,
    }

# ============================================
# UI Updates / UI 更新
# ============================================

func _update_gear_display() -> void:
    var faces := ["⚙️", "🔩", "⚡", "⚙️"]
    for i in range(mini(_gear_buttons.size(), _gears.size())):
        var gear = _gears[i]
        var normalized = fmod(gear["rotation"], 360.0)
        if normalized < 0:
            normalized += 360.0
        
        var face_idx = int(normalized / 90.0) % 4
        _gear_buttons[i].text = faces[face_idx]
        
        # 高亮活跃齿轮
        if gear["is_active"]:
            _gear_buttons[i].add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
        else:
            _gear_buttons[i].remove_theme_color_override("font_color")

func _animate_gear(index: int) -> void:
    var tween = create_tween()
    tween.tween_property(_gear_buttons[index], "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(_gear_buttons[index], "scale", Vector2(1.0, 1.0), 0.1)

func _update_moves_display() -> void:
    if _moves_lbl:
        _moves_lbl.text = "剩余步数: %d" % _moves_remaining

func _update_status(text: String) -> void:
    if _status_lbl:
        _status_lbl.text = text

func _set_gear_buttons_enabled(enabled: bool) -> void:
    for btn in _gear_buttons:
        if btn:
            btn.disabled = not enabled

# ============================================
# Utility / 工具
# ============================================

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs