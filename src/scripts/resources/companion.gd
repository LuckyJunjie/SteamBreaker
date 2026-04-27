class_name Companion
extends Resource

## 伙伴基础数据资源

@export var companion_id: String = ""
@export var name: String = ""
@export var species: String = ""
@export var portrait: Texture = null
@export var base_stats: Dictionary = {}  # hp, attack, defense, speed, morale_max
@export var personality: String = ""
@export var likes: Array[String] = []     # 喜好物品ID
@export var dislikes: Array[String] = [] # 厌恶物品ID
@export var affection: int = 0           # 好感度 0-100
@export var story_flags: Dictionary = {} # 剧情标志
@export var is_recruited: bool = false
@export var skill_ids: Array[String] = [] # 拥有的技能ID列表

## 羁绊等级计算
func get_bond_level() -> int:
    if affection <= 20:  return 0  # 陌生
    elif affection <= 40: return 1 # 相识
    elif affection <= 60: return 2 # 信任
    elif affection <= 80: return 3 # 亲密
    else:                  return 4 # 灵魂

func get_bond_level_name() -> String:
    var levels: Array[String] = ["陌生", "相识", "信任", "亲密", "灵魂"]
    return levels[get_bond_level()]

## 好感度变化
func add_affection(amount: int) -> void:
    affection = clampi(affection + amount, 0, 100)

## 获取可解锁技能（按羁绊等级）
func get_unlocked_skill_ids() -> Array[String]:
    var unlocked: Array[String] = []
    var level: int = get_bond_level()
    # 羁绊等级0解锁第1个技能, 等级1解锁第2个, 等级3解锁第3个
    var thresholds: Array[int] = [0, 21, 41, 61, 81]
    for i in range(skill_ids.size()):
        if level >= int(i + 1):
            unlocked.append(skill_ids[i])
    return unlocked
