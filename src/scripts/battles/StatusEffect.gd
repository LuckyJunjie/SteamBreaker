class_name StatusEffect
extends Resource

## 状态效果数据类

enum StatusType {
    NONE,
    OVERHEAT,
    PARALYSIS,
    FLOOD,
    FIRE,
    STEALTH,
    SLOW,
    DISORIENT
}

var type: StatusType = StatusType.NONE
var duration_remaining: int = 0
var severity: int = 1
var can_stack: bool = false
var source_part: String = ""

func _init(
    p_type: StatusType = StatusType.NONE,
    p_duration: int = 0,
    p_severity: int = 1,
    p_can_stack: bool = false
) -> void:
    type = p_type
    duration_remaining = p_duration
    severity = p_severity
    can_stack = p_can_stack

func tick() -> bool:
    duration_remaining -= 1
    return duration_remaining <= 0

func get_display_name() -> String:
    match type:
        StatusType.OVERHEAT:  return "过热 (Overheat)"
        StatusType.PARALYSIS: return "瘫痪 (Paralysis)"
        StatusType.FLOOD:     return "漏水 (Flood)"
        StatusType.FIRE:      return "火灾 (Fire)"
        StatusType.STEALTH:   return "隐形 (Stealth)"
        StatusType.SLOW:      return "减速 (Slow)"
        StatusType.DISORIENT:  return "混乱 (Disorient)"
    return "无"

## 预设工厂方法
static func make_overheat(duration: int = 2, severity: int = 1) -> StatusEffect:
    var e := StatusEffect.new(StatusEffect.StatusType.OVERHEAT, duration, severity, false)
    e.source_part = "boiler"
    return e

static func make_paralysis() -> StatusEffect:
    var e := StatusEffect.new(StatusEffect.StatusType.PARALYSIS, 999, 1, false)
    e.source_part = "helm"
    return e

static func make_flood(duration: int = 3, severity: int = 1) -> StatusEffect:
    return StatusEffect.new(StatusEffect.StatusType.FLOOD, duration, severity, true)

static func make_fire(duration: int = 2, severity: int = 1) -> StatusEffect:
    var e := StatusEffect.new(StatusEffect.StatusType.FIRE, duration, severity, true)
    e.source_part = "boiler"
    return e

static func make_stealth(duration: int = 2, severity: int = 1) -> StatusEffect:
    return StatusEffect.new(StatusEffect.StatusType.STEALTH, duration, severity, false)

static func make_slow(duration: int = 3, severity: int = 1) -> StatusEffect:
    var e := StatusEffect.new(StatusEffect.StatusType.SLOW, duration, severity, false)
    e.source_part = "boiler"
    return e

static func make_disorient(duration: int = 2, severity: int = 1) -> StatusEffect:
    var e := StatusEffect.new(StatusEffect.StatusType.DISORIENT, duration, severity, false)
    e.source_part = "helm"
    return e
