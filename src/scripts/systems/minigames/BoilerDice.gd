extends Node
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

var _current_bet: int = 0
var _dice_values: Array[int] = [0, 0, 0]
var _kept_indices: Array[int] = []  # 保留的骰子索引
var _rolls_remaining: int = 2        # 剩余再掷次数

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
# Scoring Logic / 计分逻辑
# ============================================

func _calculate_score() -> int:
    var d := _dice_values
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
