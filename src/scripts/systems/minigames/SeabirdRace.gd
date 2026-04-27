extends Node
class_name SeabirdRace

## 海鸟赛跑 / Seabird Race
## 酒馆小游戏：押注海鸟竞速比赛
## 每只鸟有速度/耐力/运气属性，赛道有随机障碍
## 玩家可消耗"哨子"道具让鸟短暂加速

signal race_started(selected_bird_id: String, bet: int)
signal race_tick(progress: Array[Dictionary])  # 每只鸟的进度
signal race_finished(winner_id: String, results: Array[Dictionary])
signal bird_accelerated(bird_id: String)

const NUM_BIRDS: int = 4
const TRACK_LENGTH: int = 100  # 赛道总长度（格）
const OBSTACLE_CHANCE: float = 0.15

var _birds: Array[Dictionary] = []
var _selected_bird_id: String = ""
var _current_bet: int = 0
var _progress: Array[int] = [0, 0, 0, 0]  # 每只鸟的当前位置
var _is_racing: bool = false
var _race_odds: Array[float] = [2.0, 2.5, 3.0, 4.0]  # 默认赔率

# ============================================
# Public API / 公开接口
# ============================================

## 开始比赛，选择海鸟和押注
## bird_id: 选择的鸟ID (0-3)
## bet: 押注金币
## 返回: 是否开始成功
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
    _current_bet = bet
    _init_birds()
    _progress = [0, 0, 0, 0]
    _is_racing = true
    
    race_started.emit(_selected_bird_id, bet)
    print("[SeabirdRace] Race started: bird=%s, bet=%d" % [_selected_bird_id, bet])
    return true

## 执行一个比赛 tick（模拟一步）
## delta_progress: 随机种子偏移
## 返回: 当前排名信息 Array[Dictionary]
func tick(delta_progress: float = 0.0) -> Array[Dictionary]:
    if not _is_racing:
        return []
    
    for i in range(NUM_BIRDS):
        var speed: float = _birds[i]["speed"]
        var luck: float = _birds[i]["luck"]
        var pos: int = _progress[i]
        
        # 基础移动
        var roll: float = randf() + luck * 0.1 + delta_progress
        var move: int = int(speed * roll * 0.15)
        
        # 障碍影响
        if randf() < OBSTACLE_CHANCE:
            move = maxi(0, move - randi() % 5)
        
        # 加速效果
        if _birds[i]["is_accelerating"]:
            move += randi() % 4 + 2
            _birds[i]["is_accelerating"] = false
        
        _progress[i] = mini(pos + move, TRACK_LENGTH)
    
    # 排序
    var ranking: Array[Dictionary] = _build_ranking()
    race_tick.emit(ranking)
    return ranking

## 检查比赛是否结束
func check_race_end() -> bool:
    for p in _progress:
        if p >= TRACK_LENGTH:
            return true
    return false

## 完成比赛，返回结果
## 返回: Dictionary { gold_change, is_winner, payout, results }
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
        var odds_idx: int = int(winner_id.replace("bird_", "")) - 1
        odds_idx = clampi(odds_idx, 0, _race_odds.size() - 1)
        payout = int(_current_bet * _race_odds[odds_idx])
        gold_change = payout
        
        var game_state := _get_game_state()
        if game_state:
            game_state.add_gold(payout)
    
    var result: Dictionary = {
        "gold_change": gold_change,
        "payout": payout,
        "is_winner": is_winner,
        "winner_id": winner_id,
        "results": ranking,
        "bet": _current_bet,
    }
    
    race_finished.emit(winner_id, ranking)
    print("[SeabirdRace] Race finished: winner=%s, player_won=%s, payout=%d" % [
        winner_id, is_winner, payout])
    
    _selected_bird_id = ""
    _current_bet = 0
    
    return result

## 使用哨子为选择的鸟加速
## 需要玩家背包中有"seabird_whistle"道具
func use_whistle() -> bool:
    if _selected_bird_id.is_empty():
        return false
    
    var game_state := _get_game_state()
    if not game_state:
        return false
    
    # 检查是否有哨子道具（通过物品ID检查）
    if game_state.has("player_inventory"):
        var inv: Array = game_state.player_inventory
        if "seabird_whistle" in inv:
            inv.erase("seabird_whistle")
            var bird_idx: int = int(_selected_bird_id.replace("bird_", "")) - 1
            if bird_idx >= 0 and bird_idx < NUM_BIRDS:
                _birds[bird_idx]["is_accelerating"] = true
                bird_accelerated.emit(_selected_bird_id)
                print("[SeabirdRace] Whistle used: %s accelerated" % _selected_bird_id)
                return true
    
    # 如果没有背包系统，直接给指定鸟加速
    var bird_idx: int = int(_selected_bird_id.replace("bird_", "")) - 1
    if bird_idx >= 0 and bird_idx < NUM_BIRDS:
        _birds[bird_idx]["is_accelerating"] = true
        bird_accelerated.emit(_selected_bird_id)
        print("[SeabirdRace] Bird accelerated (no inventory check)")
        return true
    
    return false

## 获取赔率表
func get_odds() -> Array[float]:
    return _race_odds.duplicate()

## 获取当前比赛状态
func get_current_progress() -> Array[int]:
    return _progress.duplicate()

## 是否在比赛中
func is_racing() -> bool:
    return _is_racing

# ============================================
# Private Methods / 私有方法
# ============================================

func _init_birds() -> void:
    _birds = []
    _race_odds = []
    
    # 鸟的属性定义
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

func _build_ranking() -> Array[Dictionary]:
    var ranking: Array[Dictionary] = []
    for i in range(NUM_BIRDS):
        ranking.append({
            "bird_id": _birds[i]["bird_id"],
            "name": _birds[i]["name"],
            "progress": _progress[i],
            "odds": _birds[i]["odds"],
        })
    # 按进度降序排序
    ranking.sort_custom(func(a, b): return a["progress"] > b["progress"])
    return ranking

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs
