extends Node
class_name GearPuzzle

## 齿轮拼图 / Gear Puzzle
## 机械师公会小游戏：旋转齿轮使所有齿轮联动
## 玩家通过点击旋转特定齿轮，目标是让所有齿轮都转动起来
## 步数限制内完成可获得"古代零件"（兑换部件蓝图碎片）

signal puzzle_started(grid_size: Vector2i)
signal gear_rotated(gear_index: int, direction: int)  # direction: 1=顺时针, -1=逆时针
signal puzzle_solved(moves_used: int, reward_item: String)
signal puzzle_failed(reason: String)
signal tick_update(moves_remaining: int)

const GRID_WIDTH: int = 3
const GRID_HEIGHT: int = 3
const MAX_MOVES: int = 15
const TOOTH_COUNT: int = 8  # 每个齿轮的齿数

# 齿轮位置（2D网格索引）
var _gears: Array[Dictionary] = []  # [{pos: Vector2i, rotation: float, is_active: bool}, ...]
var _moves_used: int = 0
var _moves_remaining: int = MAX_MOVES
var _is_solved: bool = false
var _is_active: bool = false

# ============================================
# Public API / 公开接口
# ============================================

## 开始拼图（可指定网格大小）
## cols: 列数，rows: 行数，默认 3x3
func start_puzzle(cols: int = GRID_WIDTH, rows: int = GRID_HEIGHT) -> void:
    _is_active = true
    _is_solved = false
    _moves_used = 0
    _moves_remaining = MAX_MOVES
    
    # 初始化齿轮
    _gears.clear()
    for y in range(rows):
        for x in range(cols):
            _gears.append({
                "pos": Vector2i(x, y),
                "rotation": randi() % 4 * 90.0,  # 随机初始旋转角度（0/90/180/270）
                "is_active": false,
                "index": _gears.size(),
            })
    
    # 设置中心齿轮为初始活跃齿轮
    var center_idx: int = (rows * cols) / 2
    if center_idx < _gears.size():
        _gears[center_idx]["is_active"] = true
    
    # 随机激活几个齿轮
    var extra_active: int = randi() % 2 + 1
    for i in range(extra_active):
        var idx: int = randi() % _gears.size()
        _gears[idx]["is_active"] = true
    
    puzzle_started.emit(Vector2i(cols, rows))
    print("[GearPuzzle] Puzzle started: %dx%d grid, %d gears" % [cols, rows, _gears.size()])

## 点击指定齿轮，使其顺时针旋转90°
## gear_index: 齿轮索引
## 返回: 是否成功旋转
func rotate_cw(gear_index: int) -> bool:
    return _rotate_gear(gear_index, 1)

## 点击指定齿轮，使其逆时针旋转90°
## gear_index: 齿轮索引
## 返回: 是否成功旋转
func rotate_ccw(gear_index: int) -> bool:
    return _rotate_gear(gear_index, -1)

## 旋转齿轮（统一入口）
## gear_index: 齿轮索引
## direction: 1=顺时针, -1=逆时针
## 返回: 是否成功旋转
func rotate_gear(gear_index: int, direction: int) -> bool:
    return _rotate_gear(gear_index, direction)

## 获取所有齿轮状态
## 返回: Array[Dictionary] 每个齿轮的 {pos, rotation, is_active, index}
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

## 获取网格尺寸
func get_grid_size() -> Vector2i:
    if _gears.is_empty():
        return Vector2i(GRID_WIDTH, GRID_HEIGHT)
    var max_x: int = 0
    var max_y: int = 0
    for g in _gears:
        max_x = maxi(max_x, g["pos"].x)
        max_y = maxi(max_y, g["pos"].y)
    return Vector2i(max_x + 1, max_y + 1)

## 获取剩余步数
func get_moves_remaining() -> int:
    return _moves_remaining

## 获取已用步数
func get_moves_used() -> int:
    return _moves_used

## 检查是否全部齿轮联动（全部 is_active = true 且 rotation % 360 == 0）
func check_solved() -> bool:
    if _gears.is_empty():
        return false
    for g in _gears:
        # 检查是否旋转到位（rotation 应该是 360 的整数倍，即 0, 360, 720...）
        # 这里简化为判断 rotation % 360 == 0
        var normalized: float = fmod(g["rotation"], 360.0)
        if normalized < 0:
            normalized += 360.0
        if not g["is_active"] or normalized != 0.0:
            return false
    return true

## 完成拼图并返回结果
## 返回: Dictionary { solved, moves_used, reward_item, gold_change }
func finish() -> Dictionary:
    var solved: bool = check_solved()
    var reward_item: String = ""
    var gold_change: int = 0
    
    if solved:
        _is_solved = true
        _is_active = false
        reward_item = "ancient_gear_part"
        gold_change = 50  # 谜题奖励金币
        
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

## 是否在谜题中
func is_active() -> bool:
    return _is_active

## 获取单个齿轮信息
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
# Private Methods / 私有方法
# ============================================

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
    
    # 更新相邻齿轮的联动状态
    _update_adjacent_gears(gear_index)
    
    gear_rotated.emit(gear_index, direction)
    tick_update.emit(_moves_remaining)
    print("[GearPuzzle] Gear %d rotated %s (moves left: %d)" % [
        gear_index, "CW" if direction > 0 else "CCW", _moves_remaining])
    
    # 检查是否用完步数
    if _moves_remaining <= 0 and not check_solved():
        _is_active = false
        puzzle_failed.emit("Out of moves")
        print("[GearPuzzle] Out of moves!")
    
    return true

## 当一个齿轮旋转时，更新相邻齿轮的活跃状态（模拟齿轮联动）
func _update_adjacent_gears(gear_index: int) -> void:
    var gear: Dictionary = _gears[gear_index]
    var pos: Vector2i = gear["pos"]
    var dirs: Array[Vector2i] = [
        Vector2i(0, -1),  # 上
        Vector2i(0, 1),  # 下
        Vector2i(-1, 0), # 左
        Vector2i(1, 0),  # 右
    ]
    
    for dir in dirs:
        var neighbor_pos: Vector2i = pos + dir
        # 找到相邻位置的齿轮
        for i in range(_gears.size()):
            if _gears[i]["pos"] == neighbor_pos:
                # 齿轮联动：相邻的齿轮也变活跃
                if not _gears[i]["is_active"]:
                    _gears[i]["is_active"] = true
                    print("[GearPuzzle] Gear %d activated by adjacency to %d" % [i, gear_index])

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs
