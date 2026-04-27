extends Node
class_name CannonPractice

## 炮术射击练习 / Cannon Practice
## 限时瞄准移动靶的小游戏
## 30秒内击中尽可能多的靶子，根据环数计分
## 得分可兑换炮弹图纸或副炮蓝图碎片

signal practice_started()
signal target_hit(target_pos: Vector2, ring: int, score: int)
signal target_missed()
signal tick_remaining(seconds: int)
signal practice_ended(result: Dictionary)

const TIME_LIMIT: int = 30  # 秒
const ARENA_WIDTH: int = 800
const ARENA_HEIGHT: int = 600
const RING_SCORES: Array[int] = [100, 75, 50, 25, 10]  # 圆心到边缘的分数

var _is_active: bool = false
var _time_remaining: int = TIME_LIMIT
var _total_score: int = 0
var _targets_hit: int = 0
var _shots_taken: int = 0
var _current_target_pos: Vector2 = Vector2.ZERO
var _target_radius: float = 40.0
var _last_tick_time: int = 0

# ============================================
# Public API / 公开接口
# ============================================

## 开始练习
func start_practice() -> void:
    _is_active = true
    _time_remaining = TIME_LIMIT
    _total_score = 0
    _targets_hit = 0
    _shots_taken = 0
    _spawn_target()
    _last_tick_time = Time.get_unix_time_from_system()
    practice_started.emit()
    print("[CannonPractice] Practice started: %d seconds" % TIME_LIMIT)

## 在指定坐标射击
## pos: 鼠标/点击位置（相对于靶场）
## 返回: Dictionary { hit, ring, points, target_pos }
func shoot(pos: Vector2) -> Dictionary:
    if not _is_active:
        return {}
    
    _shots_taken += 1
    var distance: float = pos.distance_to(_current_target_pos)
    var ring: int = _get_ring(distance)
    
    var hit: bool = ring >= 0
    var points: int = 0
    
    if hit:
        points = RING_SCORES[ring]
        _total_score += points
        _targets_hit += 1
        target_hit.emit(_current_target_pos, ring, points)
        print("[CannonPractice] Hit! ring=%d, dist=%.1f, +%d pts (total=%d)" % [
            ring, distance, points, _total_score])
        # 击中后刷新靶子
        _spawn_target()
    else:
        target_missed.emit()
        print("[CannonPractice] Missed! dist=%.1f" % distance)
    
    return {
        "hit": hit,
        "ring": ring,
        "points": points,
        "target_pos": _current_target_pos,
        "shoot_pos": pos,
        "total_score": _total_score,
    }

## 更新练习状态（每帧或每计时调用）
## 返回: 当前是否仍在进行中
func update() -> bool:
    if not _is_active:
        return false
    
    var now: int = Time.get_unix_time_from_system()
    if now > _last_tick_time:
        _time_remaining -= 1
        _last_tick_time = now
        tick_remaining.emit(_time_remaining)
        
        if _time_remaining <= 0:
            end_practice()
            return false
    
    return _is_active

## 结束练习并返回结果
func end_practice() -> Dictionary:
    if not _is_active:
        return {}
    
    _is_active = false
    
    # 计算奖励
    var accuracy: float = 0.0
    if _shots_taken > 0:
        accuracy = float(_targets_hit) / float(_shots_taken) * 100.0
    
    var reward_tier: int = _calculate_reward_tier(_total_score)
    var reward_name: String = _get_reward_name(reward_tier)
    var gold_bonus: int = _calculate_gold_bonus(reward_tier)
    
    # 发放金币奖励
    if gold_bonus > 0:
        var game_state := _get_game_state()
        if game_state:
            game_state.add_gold(gold_bonus)
    
    var result: Dictionary = {
        "total_score": _total_score,
        "targets_hit": _targets_hit,
        "shots_taken": _shots_taken,
        "accuracy": accuracy,
        "reward_tier": reward_tier,
        "reward_name": reward_name,
        "gold_bonus": gold_bonus,
        "time_limit": TIME_LIMIT,
    }
    
    practice_ended.emit(result)
    print("[CannonPractice] Practice ended: score=%d, hit=%d/%d, acc=%.1f%%, reward=%s" % [
        _total_score, _targets_hit, _shots_taken, accuracy, reward_name])
    
    return result

## 获取当前靶子位置
func get_target_pos() -> Vector2:
    return _current_target_pos

## 获取靶子半径
func get_target_radius() -> float:
    return _target_radius

## 获取剩余时间
func get_time_remaining() -> int:
    return _time_remaining

## 获取当前总分
func get_total_score() -> int:
    return _total_score

## 是否在练习中
func is_active() -> bool:
    return _is_active

## 获取靶场的尺寸
func get_arena_size() -> Vector2:
    return Vector2(ARENA_WIDTH, ARENA_HEIGHT)

# ============================================
# Private Methods / 私有方法
# ============================================

func _spawn_target() -> void:
    # 靶子以一定速度移动
    var margin: float = 60.0
    _current_target_pos = Vector2(
        randf_range(margin, ARENA_WIDTH - margin),
        randf_range(margin, ARENA_HEIGHT - margin)
    )
    _target_radius = randf_range(30.0, 50.0)
    print("[CannonPractice] Target spawned at %s (r=%.1f)" % [_current_target_pos, _target_radius])

## 根据距离计算环数（0=中心，4=最外）
func _get_ring(distance: float) -> int:
    # 环宽 = 靶半径 / 5
    var ring_width: float = _target_radius / 5.0
    if distance < ring_width:
        return 0  # 中心（100分）
    for i in range(1, 5):
        if distance < ring_width * (i + 1):
            return i
    return -1  # 未命中

func _calculate_reward_tier(score: int) -> int:
    if score >= 2000:  return 4  # 卓越
    if score >= 1200:  return 3  # 优秀
    if score >= 600:   return 2  # 良好
    if score >= 200:   return 1  # 参与奖
    return 0

func _get_reward_name(tier: int) -> String:
    var names: Array[String] = ["参与奖", "炮弹碎片 x1", "燃烧弹图纸", "连射炮蓝图", "精密炮架设计图"]
    return names[clampi(tier, 0, names.size() - 1)]

func _calculate_gold_bonus(tier: int) -> int:
    var bonuses: Array[int] = [0, 20, 50, 100, 200]
    return bonuses[clampi(tier, 0, bonuses.size() - 1)]

func _get_game_state() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs
