class_name Skill
extends Resource

## 技能数据资源

@export var skill_id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var mp_cost: int = 0        # 士气消耗
@export var cooldown: int = 0      # 冷却回合数
@export var current_cooldown: int = 0
@export var effect_type: String = ""  # targeted_attack / heal / utility / buff / debuff
@export var effect_params: Dictionary = {}  # 各效果的具体参数

## 冷却管理
func tick_cooldown() -> void:
    if current_cooldown > 0:
        current_cooldown -= 1

func is_ready() -> bool:
    return current_cooldown <= 0

func trigger_cooldown() -> void:
    current_cooldown = cooldown

## 获取士气消耗
func get_mp_cost() -> int:
    return mp_cost

## 效果类型枚举（便于扩展）
enum EffectType {
    TARGETED_ATTACK,
    HEAL,
    UTILITY,
    BUFF,
    DEBUFF
}

func get_effect_type_enum() -> EffectType:
    match effect_type:
        "targeted_attack": return EffectType.TARGETED_ATTACK
        "heal": return EffectType.HEAL
        "utility": return EffectType.UTILITY
        "buff": return EffectType.BUFF
        "debuff": return EffectType.DEBUFF
    return EffectType.UTILITY
