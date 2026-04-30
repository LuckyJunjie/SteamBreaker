extends Control
class_name SeabirdRace

## 海鸟赛跑 / Seabird Race
## 酒馆小游戏：押注海鸟竞速比赛
## 每只鸟有速度/耐力/运气属性，赛道有随机障碍

signal race_started(selected_bird_id: String, bet: int)
signal race_tick(progress: Array[Dictionary])  # 每只鸟的进度
signal race_finished(winner_id: String, results: Array[Dictionary])
signal bird_accelerated(bird_id: String)
signal minigame_finished(result: Dictionary)

const NUM_BIRDS: int = 4
const TRACK_LENGTH: int = 100  # 赛道总长度（格）
const OBSTACLE_CHANCE: float = 0.15

var _birds: Array[Dictionary] = []
var _selected_bird_id: String = ""
var _selected_bird_idx: int = -1
var _current_bet: int = 0
var _progress: Array[int] = [0, 0, 0, 0]
var _is_racing: bool = false
var _race_odds: Array[float] = [2.0, 2.5, 3.0, 4.0]
var _race_timer: float = 0.0
var _race_ticking: bool = false

# UI references
var _bet_buttons: Array[Button] = []
var _bird_buttons: Array[Button] = []
var _start_btn: Button = null
var _status_lbl: Label = null
var _progress_bars: Array[ProgressBar] = []
var _track_lbl: Label = null
var _result_panel: PanelContainer = null

# ============================================
# Lifecycle / 生命周期
# ============================================

func _ready() -> void:
    print("[SeabirdRace] _ready")
    _find_ui_nodes()
    _connect_ui_signals()
    _init_bird_display()

func _find_ui_nodes() -> void:
    # 押注按钮
    var bet_row = find_child("BetRow", false, false)
    if bet_row:
        for child in bet_row.get_children():
            if child is Button:
                _bet_buttons.append(child)
    
    # 海鸟选择按钮
    var select_row = find_child("BirdSelectRow", false, false)
    if select_row:
        for child in select_row.get_children():
            if child is Button:
                _bird_buttons.append(child)
    
    # 开始按钮
    _start_btn = find_child("StartRaceBtn", false, false) as Button
    
    # 状态标签
    _status_lbl = find_child("StatusLabel", false, false) as Label
    
    # 轨道区域标签
    _track_lbl = find_child("TrackLabel", false, false) as Label
    
    # 结果面板
    _result_panel = find_child("ResultPanel", false, false) as PanelContainer
    
    # Progress bars
    var track_area = find_child("TrackArea", false, false)
    if track_area:
        var race_track = track_area.find_child("RaceTrack", false, false)
        if race_track:
            var progress_container = race_track.find_child("BirdProgressBars", false, false)
            if progress_container:
                for child in progress_container.get_children():
                    if child is ProgressBar:
                        _progress_bars.append(child)
    
    print("[SeabirdRace] UI nodes: bet_btns=%d, bird_btns=%d, progress_bars=%d" % [
        _bet_buttons.size(), _bird_buttons.size(), _progress_bars.size()])

func _connect_ui_signals() -> void:
    var back_btn = find_child("BackBtn", false, false) as Button
    if back_btn:
        back_btn.pressed.connect(_on_back_pressed)
    
    # 押注按钮 (10, 30, 50)
    var bet_amounts: Array[int] = [10, 30, 50]
    for i in range(mini(_bet_buttons.size(), bet_amounts.size())):
        if _bet_buttons[i]:
            _bet_buttons[i].pressed.connect(_on_bet_selected.bind(bet_amounts[i]))
    
    # 海鸟选择按钮
    for i in range(_bird_buttons.size()):
        if _bird_buttons[i]:
            _bird_buttons[i].pressed.connect(_on_bird_selected.bind(i))
    
    # 开始竞猜按钮
    if _start_btn:
        _start_btn.pressed.connect(_on_start_race_pressed)

func _init_bird_display() -> void:
    _init_birds()
    _highlight_selected_bird()
    _set_bet_buttons_enabled(true)
    _start_btn.disabled = true

# ============================================
# UI 交互处理
# ============================================

func _on_back_pressed() -> void:
    print("[SeabirdRace] Back pressed")
    var result := {"gold_change": 0, "cancelled": true}
    minigame_finished.emit(result)
    queue_free()

func _on_bet_selected(bet: int) -> void:
    print("[SeabirdRace] Bet selected: %d" % bet)
    _current_bet = bet
    _update_status("已选择押注 %d 金" % bet)
    _update_start_button_state()

func _on_bird_selected(idx: int) -> void:
    print("[SeabirdRace] Bird selected: %d" % idx)
    _selected_bird_idx = idx
    _selected_bird_id = _get_bird_id_str(idx)
    _highlight_selected_bird()
    _update_start_button_state()

func _on_start_race_pressed() -> void:
    if _selected_bird_idx < 0 or _current_bet <= 0:
        return
    
    var game_state := _get_game_state()
    if not game_state or game_state.gold < _current_bet:
        _update_status("金币不足！")
        return
    
    # 扣除押注
    if game_state.has_method("spend_gold"):
        game_state.spend_gold(_current_bet)
    
    _start_race(_selected_bird_idx, _current_bet)

func _highlight_selected_bird() -> void:
    for i in range(_bird_buttons.size()):
        if _bird_buttons[i]:
            if i == _selected_bird_idx:
                _bird_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
            else:
                _bird_buttons[i].remove_theme_color_override("font_color")

func _update_start_button_state() -> void:
    if _start_btn:
        _start_btn.disabled = (_selected_bird_idx < 0 or _current_bet <= 0)
        if _selected_bird_idx >= 0 and _current_bet > 0:
            var bird_name = _get_bird_name(_selected_bird_idx)
            _start_btn.text = "🏃 开始押注 %d 金于 %s" % [_current_bet, bird_name]

func _update_status(text: String) -> void:
    if _status_lbl:
        _status_lbl.text = text

func _set_bet_buttons_enabled(enabled: bool) -> void:
    for btn in _bet_buttons:
        if btn:
            btn.disabled = not enabled

# ============================================
# Race Logic / 竞猜逻辑
# ============================================

func start_race(bird_id: int, bet: int) -> bool:
    if bird_id < 0 or bird_id >= NUM_BIRDS:
        print("[SeabirdRace] Invalid bird_id: %d" % bird_id)
        return false
    if bet < 5:
        print("[SeabirdRace] Bet too small: %d (min 5)" % bet)
        return false
    
    var game_state := _get_game_state()
    if not game_state or game_state.gold < bet:
        print("[SeabirdRace] Not enough gold")
        return false
    
    _selected_bird_id = _get_bird_id_str(bird_id)
    _selected_bird_idx = bird_id
    _current_bet = bet
    _init_birds()
    _progress = [0, 0, 0, 0]
    _is_racing = true
    
    race_started.emit(_selected_bird_id, bet)
    print("[SeabirdRace] Race started: bird=%s, bet=%d" % [_selected_bird_id, bet])
    return true

func _start_race(bird_idx: int, bet: int) -> void:
    if not start_race(bird_idx, bet):
        _update_status("无法开始竞猜，金币不足")
        return
    
    _update_status("竞猜开始！")
    _set_bet_buttons_enabled(false)
    _start_btn.disabled = true
    _set_bird_buttons_enabled(false)
    
    if _track_lbl:
        _track_lbl.text = "🐦 比赛进行中..."
    
    _race_ticking = true
    _race_timer = 0.0

func _process(delta: float) -> void:
    if not _race_ticking:
        return
    
    _race_timer += delta
    
    # 每隔一小段时间tick一次
    if _race_timer >= 0.3:
        _race_timer = 0.0
        var ranking = tick(0.1)
        _update_progress_bars()
        race_tick.emit(ranking)
        
        if check_race_end():
            _race_ticking = false
            _finish_race_and_show_result()

func _finish_race_and_show_result() -> void:
    var result = finish_race()
    _show_result(result)

func _show_result(result: Dictionary) -> void:
    if _result_panel:
        _result_panel.visible = true
    
    var is_winner: bool = result.get("is_winner", false)
    var gold_change: int = result.get("gold_change", 0)
    var winner_name: String = result.get("winner_id", "?")
    
    var result_lbl = _result_panel.get_node_or_null("ResultLabel") as Label
    var gold_lbl = _result_panel.get_node_or_null("GoldChangeLabel") as Label
    
    if result_lbl:
        result_lbl.text = "🏁 %s 获胜！" % winner_name
    
    if gold_lbl:
        if is_winner:
            gold_lbl.text = "🎉 +%d 金！" % gold_change
            gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
        else:
            gold_lbl.text = "💸 你输了，押注 %d 金" % _current_bet
            gold_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
    
    _update_status("竞猜结束！")
    
    await get_tree().create_timer(3.0).timeout
    minigame_finished.emit(result)
    queue_free()

func _set_bird_buttons_enabled(enabled: bool) -> void:
    for btn in _bird_buttons:
        if btn:
            btn.disabled = not enabled

func _update_progress_bars() -> void:
    for i in range(mini(_progress_bars.size(), 4)):
        if i < _progress.size():
            _progress_bars[i].value = _progress[i]

# ============================================
# Public API / 公开接口（保持与原 API 兼容）
# ============================================

func tick(delta_progress: float = 0.0) -> Array[Dictionary]:
    if not _is_racing:
        return []
    
    for i in range(NUM_BIRDS):
        var speed: float = _birds[i]["speed"]
        var luck: float = _birds[i]["luck"]
        var pos: int = _progress[i]
        
        var roll: float = randf() + luck * 0.1 + delta_progress
        var move: int = int(speed * roll * 0.15)
        
        if randf() < OBSTACLE_CHANCE:
            move = maxi(0, move - randi() % 5)
        
        if _birds[i]["is_accelerating"]:
            move += randi() % 4 + 2
            _birds[i]["is_accelerating"] = false
        
        _progress[i] = mini(pos + move, TRACK_LENGTH)
    
    var ranking: Array[Dictionary] = _build_ranking()
    return ranking

func check_race_end() -> bool:
    for p in _progress:
        if p >= TRACK_LENGTH:
            return true
    return false

func finish_race() -> Dictionary:
    if not _is_racing:
        return {}
    
    _is_racing = false
    var ranking: Array[Dictionary] = _build_ranking()
    var winner_id: String = ranking[0]["bird_id"]
    var is_winner: bool = (winner_id == _selected_bird_id)
    
    var payout: int = 0
    var gold_change: int = 0
    
    if is_winner:
        var odds_idx: int = clampi(_selected_bird_idx, 0, _race_odds.size() - 1)
        payout = int(_current_bet * _race_odds[odds_idx])
        gold_change = payout
        
        var game_state := _get_game_state()
        if game_state:
            game_state.add_gold(payout)
    
    var result: Dictionary = {
        "gold_change": gold_change,
        "payout": payout,
        "is_winner": is_winner,
        "winner_id": _get_bird_name_by_id(winner_id),
        "results": ranking,
        "bet": _current_bet,
    }
    
    race_finished.emit(winner_id, ranking)
    print("[SeabirdRace] Race finished: winner=%s, player_won=%s, payout=%d" % [
        winner_id, is_winner, payout])
    
    _selected_bird_id = ""
    _selected_bird_idx = -1
    _current_bet = 0
    
    return result

func use_whistle() -> bool:
    if _selected_bird_id.is_empty():
        return false
    var game_state := _get_game_state()
    if not game_state:
        return false
    var bird_idx = _selected_bird_idx
    if bird_idx >= 0 and bird_idx < NUM_BIRDS:
        _birds[bird_idx]["is_accelerating"] = true
        bird_accelerated.emit(_selected_bird_id)
        return true
    return false

func get_odds() -> Array[float]:
    return _race_odds.duplicate()

func get_current_progress() -> Array[int]:
    return _progress.duplicate()

func is_racing() -> bool:
    return _is_racing

# ============================================
# Private Methods / 私有方法
# ============================================

func _init_birds() -> void:
    _birds = []
    _race_odds = []
    
    var bird_defs: Array[Dictionary] = [
        {"name": "银翼", "speed": 8.0, "stamina": 6.0, "luck": 0.3, "odds": 2.0},
        {"name": "灰羽", "speed": 6.0, "stamina": 8.0, "luck": 0.5, "odds": 2.5},
        {"name": "金喙", "speed": 7.0, "stamina": 7.0, "luck": 0.7, "odds": 3.0},
        {"name": "黑羽", "speed": 9.0, "stamina": 4.0, "luck": 0.2, "odds": 4.0},
    ]
    
    for i in range(NUM_BIRDS):
        var def: Dictionary = bird_defs[i] if i < bird_defs.size() else bird_defs[0]
        _birds.append({
            "bird_id": _get_bird_id_str(i),
            "name": def["name"],
            "speed": def["speed"],
            "stamina": def["stamina"],
            "luck": def["luck"],
            "odds": def["odds"],
            "is_accelerating": false,
        })
        _race_odds.append(def["odds"])

func _get_bird_id_str(idx: int) -> String:
    return "bird_%d" % (idx + 1)

func _get_bird_name(idx: int) -> String:
    if idx >= 0 and idx < _birds.size():
        return _birds[idx]["name"]
    return "bird_%d" % (idx + 1)

func _get_bird_name_by_id(bird_id: String) -> String:
    for b in _birds:
        if b["bird_id"] == bird_id:
            return b["name"]
    return bird_id

func _build_ranking() -> Array[Dictionary]:
    var ranking: Array[Dictionary] = []
    for i in range(NUM_BIRDS):
        ranking.append({
            "bird_id": _birds[i]["bird_id"],
            "name": _birds[i]["name"],
            "progress": _progress[i],
            "odds": _birds[i]["odds"],
        })
    ranking.sort_custom(func(a, b): return a["progress"] > b["progress"])
    return ranking

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs