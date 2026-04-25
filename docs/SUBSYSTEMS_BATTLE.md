# 战斗系统详细设计

> 文档版本: 1.0
> 最后更新: 2026-04-25
> 负责 Agent: Einstein
> 参考: GDD.md / SUBSYSTEMS.md

---

## 1. 战斗状态机

### 1.1 状态列表

| 状态名 | 说明 | 可执行动作 |
|--------|------|------------|
| `TURN_START` | 回合开始，初始化回合数据 | 自动进入 `PLAYER_MOVE` |
| `PLAYER_MOVE` | 玩家选择移动至目标射程环 | 移动 / 跳过 |
| `PLAYER_ACTION` | 玩家选择武器攻击/使用道具/特殊装置 | 攻击 / 道具 / 修理 / 防御 / 跳过 |
| `PARTY_SKILL` | 伙伴技能释放 | 伙伴技能列表 |
| `ENEMY_TURN` | 敌方回合（移动+攻击） | 自动结算 |
| `INTERCEPT` | 迎击阶段（副炮自动拦截） | 自动结算 |
| `DAMAGE_RESOLVE` | 伤害结算，更新状态效果 | 自动结算 |
| `STATUS_EFFECT` | 状态效果处理（过热门火等） | 自动结算 |
| `CHECK_END` | 胜负判定 | 自动跳转 |
| `BATTLE_END` | 战斗结束，弹出结果 | 显示战利品 |

### 1.2 状态转换图

```
[TURN_START]
     │
     ▼
[PLAYER_MOVE] ──(跳过)──► [PLAYER_ACTION]
     │                          │
     │(移动)                    ├──(攻击)──► [INTERCEPT]
     │                          ├──(道具)──► [DAMAGE_RESOLVE]
     │                          ├──(修理)──► [DAMAGE_RESOLVE]
     │                          ├──(防御)──► [ENEMY_TURN]
     │                          ├──(伙伴技能)──► [PARTY_SKILL]
     │                          └──(跳过)──► [ENEMY_TURN]
     │
     ▼
[PARTY_SKILL] ──────────────────► [DAMAGE_RESOLVE]
                                          │
                                          ▼
[INTERCEPT] ◄──(敌方攻击)── [ENEMY_TURN] ──► [STATUS_EFFECT]
     │                                                │
     ▼                                                ▼
[DAMAGE_RESOLVE] ◄─────────────────────────────────► [CHECK_END]
     │                                                  │
     │                                                  ├──(双方HP>0)──► [TURN_START]
     │                                                  │
     └──► [BATTLE_END] ◄──(一方HP≤0) ──────────────────┘
```

### 1.3 转换条件

| 当前状态 | 目标状态 | 触发条件 |
|----------|----------|----------|
| `TURN_START` | `PLAYER_MOVE` | 自动 |
| `PLAYER_MOVE` | `PLAYER_ACTION` | 玩家确认移动或跳过 |
| `PLAYER_MOVE` | `PARTY_SKILL` | 玩家选择伙伴技能 |
| `PLAYER_ACTION` | `INTERCEPT` | 玩家发起攻击 |
| `PLAYER_ACTION` | `ENEMY_TURN` | 玩家跳过或无有效行动 |
| `PARTY_SKILL` | `DAMAGE_RESOLVE` | 伙伴技能释放完毕 |
| `ENEMY_TURN` | `INTERCEPT` | 敌方发起攻击 |
| `ENEMY_TURN` | `DAMAGE_RESOLVE` | 敌方攻击结束 |
| `INTERCEPT` | `DAMAGE_RESOLVE` | 迎击结算完毕 |
| `DAMAGE_RESOLVE` | `STATUS_EFFECT` | 伤害应用完毕 |
| `STATUS_EFFECT` | `CHECK_END` | 状态效果应用完毕 |
| `CHECK_END` | `TURN_START` | 双方HP均>0 |
| `CHECK_END` | `BATTLE_END` | 任意一方HP≤0 |

### 1.4 回合流程（参考《重装机兵》节奏）

```
每回合执行顺序:
1. [TURN_START]        → 刷新机动值、专注值、解除临时状态
2. [PLAYER_MOVE]       → 玩家决定是否移动射程环（可跳过）
3. [PLAYER_ACTION]     → 玩家选择：武器攻击 / 道具 / 修理 / 防御 / 伙伴技能
4. [PARTY_SKILL]       → 伙伴技能演出（若触发）
5. [INTERCEPT]         → 副炮迎击判定（双方均执行）
6. [ENEMY_TURN]        → 敌方行动（移动+攻击，自动AI）
7. [DAMAGE_RESOLVE]    → 伤害与状态应用
8. [STATUS_EFFECT]     → 持续性效果处理（过热门火漏水）
9. [CHECK_END]         → 胜负判定 → 下一回合或结束
```

---

## 2. 射程环系统

### 2.1 环定义

| 环 | 距离区间 | 距离格数 | 效果定位 |
|----|----------|----------|----------|
| **远距 (FAR)** | 30-50 链 | 环3 | 先手优势区，狙击 |
| **中距 (MID)** | 10-30 链 | 环2 | 标准交战区 |
| **近距 (NEAR)** | 0-10 链 | 环1 | 高风险高回报，接舷战 |

### 2.2 移动消耗计算

```
基础机动值: 10 点（由锅炉决定每回合回复量）

从环A移动到环B的消耗 = |环差| × 基础消耗比例

消耗表:
┌──────────┬────────┬────────┬────────┐
│ 起点\终点 │ → 远距 │ → 中距 │ → 近距 │
├──────────┼────────┼────────┼────────┤
│ 远距     │   0    │  40%   │  80%   │
│ 中距     │  40%   │   0    │  20%   │
│ 近距     │  80%   │  20%   │   0    │
└──────────┴────────┴────────┴────────┘
即: 跨1环 = 20% 机动值, 跨2环 = 40% 机动值
```

**特殊规则**:
- 过热状态下移动消耗 **×2**
- 瘫痪状态下 **无法移动**
- 部分技能可强制位移（推远/拉近），不消耗机动值

### 2.3 武器限制

| 武器类型 | 远距 | 中距 | 近距 | 说明 |
|----------|------|------|------|------|
| 主炮 | ✅ | ✅ | ⚠️ 命中-20% | 可用但不推荐 |
| 副炮 | ❌ | ✅ | ✅ +50%伤害 | 远距无法使用 |
| 鱼雷 | ✅ | ✅ | ❌ | 需目标在己方半场 |
| 撞角 | ❌ | ❌ | ✅ | 仅近距可用 |
| 接舷战 | ❌ | ❌ | ✅ | 特殊装置触发 |
| SE(部分) | ✅ | ✅ | ✅/❌ | 视具体技能而定 |

### 2.4 射程环效果汇总

| 环 | 命中加成（攻方） | 闪避加成（守方） | 机动消耗 | 主炮 | 副炮 | 特殊 |
|----|-----------------|-----------------|----------|------|------|------|
| 远距 | -20% | +30% | 高 | ✅ | ❌ | 可撤退 |
| 中距 | 0% | 0% | 中 | ✅ | ✅ | 标准区 |
| 近距 | +30%(近战) | -15% | 低 | ⚠️-20% | ✅+50% | 接舷/撞角 |

---

## 3. 命中与伤害计算

### 3.1 基础命中率公式

```
最终命中率 = 基础命中率 - 距离修正 - 速度差修正 + 技能加成

组成因子:
  基础命中率: 75%（可装备调整）
  距离修正: 远距-20%, 中距0%, 近距(近战武器)+30%
  速度差修正: (自身航速 - 敌方航速) × 1%，上限±15%
  技能加成: 取决于伙伴技能或装备（如"精确射击"+15%）
```

### 3.2 部位命中修正

| 目标部位 | 命中率 | 效果 | 反制 |
|----------|--------|------|------|
| **船体** | 100% | 正常伤害 | 无 |
| **锅炉** | 70% | 强制过热+30值，速度降低50% | 装甲升级 |
| **操舵室** | 60% | 下回合无法移动，转向归零 | 装甲升级 |
| **炮位（指定）** | 65% | 该武器被摧毁，战斗中不可用 | 装甲升级 |
| **特殊装置** | 55% | SE技能禁用X回合 | 装甲升级 |

**部位装甲**：每个部位可有独立装甲值，公式：
```
实际命中率 = 基础命中率 × (1 - 部位装甲值 / 100)
部位装甲值上限: 40（硬上限，防止必不中）
```

### 3.3 伤害计算公式

```
最终伤害 = 武器基础伤害 × 距离伤害系数 × 弹种系数 × (1 - 护甲减免) × 暴击倍率

组成因子:
  武器基础伤害: 由武器 Resource 定义
  距离伤害系数: 远距1.0, 中距1.0, 近距(主炮)0.8/(副炮)1.5
  弹种系数: 标准弹1.0, 穿甲弹1.5(无视50%护甲), 高爆弹2.0(范围), 圣水弹1.3(对亡灵)
  护甲减免: 护甲值 / (护甲值 + 100)，即100护甲≈50%减免
  暴击倍率: 暴击率10% × 暴击伤害2.0倍

伤害浮动: ±10%（随机）
```

### 3.4 伤害类型

| 伤害类型 | 说明 | 克制 |
|----------|------|------|
| 物理 | 常规炮弹伤害，受护甲减免 | 重装甲 |
| 穿甲 | 无视50%护甲 | 重装甲目标 |
| 高爆 | 范围伤害（对相邻目标50%溅射），无视护甲 | 群体 |
| 火焰 | 含持续伤害（火灾状态） | 灭火装置 |
| 圣水 | 对亡灵系敌人额外100%伤害 | 亡灵单位 |

---

## 4. 迎击系统

### 4.1 拦截判定

```
迎击判定流程（每次敌方攻击）:
1. 敌方发射弹药 → 进入飞行轨迹
2. 对每个可迎击的副炮计算: 迎击率 = 副炮拦截基础值 + 操舵室加成
3. 副炮拦截基础值: 15%（可升级）
4. 操舵室加成: 手动舵0% / 陀螺仪+5% / AI参谋+10%
5. 专注值消耗: 每迎击1次消耗1点专注值
6. 迎击成功: 弹药被摧毁，不造成伤害
7. 迎击失败: 弹药继续飞向目标，进入伤害结算
```

### 4.2 专注值机制

```
专注值 (Focus):
  每个副炮独立专注值上限: 3点
  每回合回复: +1点（回合开始时）
  全力迎击指令: 消耗所有专注值，拦截率提升至 (基础率 × 专注剩余倍数)
    - 3点时: 拦截率×2.0
    - 2点时: 拦截率×1.5
    - 1点时: 拦截率×1.0
```

### 4.3 迎击优先级

当多发弹药同时来袭时，按副炮**从外到内**（远距优先）依次分配拦截目标，每门副炮同一回合最多迎击2次。

---

## 5. 状态效果

### 5.1 状态效果列表

| 状态 | 触发条件 | 效果 | 持续 | 解除方式 |
|------|----------|------|------|----------|
| **过热 (Overheat)** | 累积热值≥阈值 / 攻击锅炉 | 无法使用武器/加速，移动消耗×2 | 2回合 | 自然冷却 / 道具"海水注入" |
| **瘫痪 (Paralysis)** | 操舵室被毁 | 完全无法行动 | 修理前 | 修理操舵室 |
| **漏水 (Flood)** | 攻击船体时20%概率 / 水雷 | 每回合-5%最大耐久 | 持续 | 修理 / 堵漏毯 |
| **火灾 (Fire)** | 燃烧弹攻击 / 攻击锅炉 | 每回合-10%最大耐久，锅炉过热累积+20/回合 | 持续 | 灭火器 / 灭火装置 |
| **隐形 (Stealth)** | 烟幕发生器 / 特殊装置 | 无法被瞄准，无部位命中 | 2回合 | 被攻击 / 持续时间结束 |
| **减速 (Slow)** | 攻击锅炉成功 | 航速降低50% | 3回合 | 自然解除 |
| **混乱 (Disorient)** | 攻击操舵室 | 命中率-15% | 2回合 | 自然解除 |

### 5.2 效果叠加规则

```
叠加原则（层级压制）:
  同类状态不叠加，取最强效果
  过热 + 火灾 → 过热时间延长50%（火灾加热效应）
  漏水 + 火灾 → 漏水速率×1.5（蒸汽加剧）
  隐形 + 被攻击 → 解除隐形状态

优先级（从高到低）:
  瘫痪 > 隐形 > 过热 > 减速 > 混乱 > 火灾 > 漏水
```

### 5.3 状态效果数据结构

```gdscript
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

class StatusEffect:
    StatusType type
    int duration_remaining   # 剩余持续回合
    int severity             # 强度等级(1-3)
    bool can_stack = false  # 是否可叠加
```

---

## 6. 数据结构

### 6.1 ShipCombatData

```gdscript
class_name ShipCombatData
extends Resource

## 战斗中的船只动态数据（与静态 ShipResource 分离）

# 基础属性
var ship_id: String
var current_hp: int              # 当前耐久
var max_hp: int                  # 最大耐久
var mobility: int                # 当前机动值
var max_mobility: int            # 最大机动值
var focus: Array[int]            # 每门副炮的专注值数组

# 位置与状态
var current_ring: int            # 当前射程环 (1=近/2=中/3=远)
var position_2d: Vector2          # 战斗场景中的2D坐标
var facing: float                 # 朝向角度（度）

# 状态效果
var status_effects: Dictionary    # StatusType -> StatusEffect
var overheating_value: int         # 当前过热值 (0-100)
var is_paralyzed: bool             # 操舵室被毁

# 部件状态
var part_hp: Dictionary = {
    "hull": 100,     # 船体HP百分比
    "boiler": 100,   # 锅炉HP百分比
    "helm": 100,     # 操舵室HP百分比
    "weapon_slots": [],  # 每门武器的HP百分比数组
    "special_device": 100
}
var destroyed_parts: Array[String]  # 已摧毁的部件列表

# 战斗计数
var turn_in_combat: int
var damage_dealt: int
var damage_taken: int

func take_damage(damage: float, part_target: String = "hull") -> void:
    # 命中判定已在外层完成，这里只处理伤害应用
    # 包含护甲减免、部位特殊效果
    pass

func apply_status(effect: StatusType, duration: int, severity: int = 1) -> void:
    # 状态效果应用，含叠加规则判定
    pass

func check_destruction() -> bool:
    # 船体HP≤0 或 操舵室+锅炉同时被毁 → 船只沉没
    return current_hp <= 0
```

### 6.2 WeaponData

```gdscript
class_name WeaponData
extends Resource

## 武器定义数据（Resource，可配置）

# 基础属性
var weapon_id: String
var display_name: String
var weapon_type: WeaponType  # enum: MAIN_GUN, SUB_GUN, TORPEDO, RAM, BOARDING
var damage: int
var accuracy: int            # 基础命中率加成
var heat_cost: int           # 过热消耗
var range_min: int           # 最小射程（链）
var range_max: int            # 最大射程（链）
var cooldown: int            # 冷却回合数
var ammo_type: String         # 消耗弹药类型（可选）
var ammo_cost: int            # 每次射击消耗弹药数

# 特殊属性
var can_target_parts: bool    # 是否可部位攻击
var part_accuracy_mod: Dictionary  # 各部位命中率修正
var intercept_rate: float    # 迎击基础率（仅副炮）
var special_effects: Array[String]  # 特殊效果标签

# 状态
var is_loaded: bool = true
var current_cooldown: int = 0

## 枚举
enum WeaponType {
    MAIN_GUN,
    SUB_GUN,
    TORPEDO,
    RAM,
    BOARDING,
    SPECIAL
}
```

### 6.3 TurnManager

```gdscript
class_name TurnManager
extends Node

## 回合控制中心

signal turn_changed(current_turn: int, phase: String)
signal phase_changed(from: String, to: String)
signal battle_ended(winner: int, loot: Dictionary)

# 状态
var current_turn: int = 0
var current_phase: String = ""
var battle_state_machine: BattleStateMachine
var is_player_turn: bool = true
var is_battle_active: bool = false

# 参战单位
var player_ship: ShipCombatData
var enemy_ships: Array[ShipCombatData]

# 战斗配置
var max_turns: int = 50
var turn_timeout: bool = false

func start_battle(player: ShipCombatData, enemies: Array[ShipCombatData]) -> void:
    is_battle_active = true
    current_turn = 1
    player_ship = player
    enemy_ships = enemies
    _change_phase("TURN_START")

func next_phase() -> void:
    match current_phase:
        "TURN_START":   _change_phase("PLAYER_MOVE")
        "PLAYER_MOVE":  _change_phase("PLAYER_ACTION")
        "PLAYER_ACTION": _change_phase("PARTY_SKILL")
        "PARTY_SKILL":  _change_phase("INTERCEPT")
        "INTERCEPT":    _change_phase("ENEMY_TURN")
        "ENEMY_TURN":   _change_phase("DAMAGE_RESOLVE")
        "DAMAGE_RESOLVE": _change_phase("STATUS_EFFECT")
        "STATUS_EFFECT":  _change_phase("CHECK_END")
        "CHECK_END":
            if _check_battle_end():
                _change_phase("BATTLE_END")
            else:
                current_turn += 1
                _change_phase("TURN_START")

func _change_phase(new_phase: String) -> void:
    var old_phase = current_phase
    current_phase = new_phase
    phase_changed.emit(old_phase, new_phase)
    battle_state_machine.set_state(new_phase)

func _check_battle_end() -> bool:
    if player_ship.current_hp <= 0:
        battle_ended.emit(1, {})
        return true
    for enemy in enemy_ships:
        if enemy.current_hp > 0:
            return false
    var loot = _generate_loot()
    battle_ended.emit(0, loot)
    return true

func _generate_loot() -> Dictionary:
    return {"gold": 100, "items": []}
```

---

## 7. GDScript 代码框架

### 7.1 StateMachine 架构

```gdscript
class_name BattleStateMachine
extends Node

## 战斗状态机 — Godot 4 实现

signal state_changed(from_state: String, to_state: String)

var current_state: BattleState
var states: Dictionary = {}

func _ready() -> void:
    states = {
        "TURN_START":      TurnStartState.new(self),
        "PLAYER_MOVE":     PlayerMoveState.new(self),
        "PLAYER_ACTION":   PlayerActionState.new(self),
        "PARTY_SKILL":     PartySkillState.new(self),
        "INTERCEPT":       InterceptState.new(self),
        "ENEMY_TURN":      EnemyTurnState.new(self),
        "DAMAGE_RESOLVE":  DamageResolveState.new(self),
        "STATUS_EFFECT":   StatusEffectState.new(self),
        "CHECK_END":       CheckEndState.new(self),
        "BATTLE_END":      BattleEndState.new(self),
    }
    current_state = states["TURN_START"]
    current_state.enter()

func set_state(state_name: String) -> void:
    if states.has(state_name):
        var prev = current_state
        current_state.exit()
        current_state = states[state_name]
        current_state.enter()
        state_changed.emit(prev.name, current_state.name)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

## 状态基类
class BattleState:
    var state_machine: BattleStateMachine
    var name: String = "Base"
    
    func _init(sm: BattleStateMachine) -> void:
        state_machine = sm
    
    func enter() -> void: pass
    func exit() -> void: pass
    func update(delta: float) -> void: pass
    func handle_input(event: InputEvent) -> void: pass
```

### 7.2 核心状态实现

```gdscript
## TurnStartState
class TurnStartState:
    extends BattleState
    var name = "TURN_START"
    
    func enter() -> void:
        var ship = state_machine.turn_manager.player_ship
        ship.mobility = ship.max_mobility
        for i in range(ship.focus.size()):
            ship.focus[i] = mini(ship.focus[i] + 1, 3)
        _tick_status_effects(ship)
        await get_tree().create_timer(0.5).timeout
        state_machine.turn_manager.next_phase()
    
    func _tick_status_effects(ship: ShipCombatData) -> void:
        for status in ship.status_effects.values():
            status.duration_remaining -= 1
        # 移除已结束的状态...

## PlayerMoveState
class PlayerMoveState:
    extends BattleState
    var name = "PLAYER_MOVE"
    var selected_ring: int = -1
    
    func enter() -> void:
        # 显示射程环UI
        pass
    
    func handle_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
            if event.button_index == MOUSE_BUTTON_LEFT:
                selected_ring = _get_ring_from_click(event.position)
                _execute_move(selected_ring)
    
    func _execute_move(target_ring: int) -> void:
        var ship = state_machine.turn_manager.player_ship
        if target_ring == ship.current_ring:
            state_machine.turn_manager.next_phase()
            return
        var cost = _calc_mobility_cost(ship.current_ring, target_ring)
        if ship.mobility >= cost:
            ship.mobility -= cost
            ship.current_ring = target_ring
            # 播放移动动画
        state_machine.turn_manager.next_phase()
    
    func _calc_mobility_cost(from: int, to: int) -> int:
        var diff = abs(to - from)
        return [0, 20, 40][diff]

## PlayerActionState
class PlayerActionState:
    extends BattleState
    var name = "PLAYER_ACTION"
    
    func enter() -> void:
        # 显示行动面板：武器列表/道具/修理/防御
        pass
    
    func execute_attack(weapon_index: int, target: ShipCombatData, part: String = "hull") -> void:
        var weapon: WeaponData = state_machine.player_loadout[weapon_index]
        if not _can_use_weapon(weapon):
            return
        var hit_roll = randf()
        var final_accuracy = _calc_accuracy(weapon, target, part)
        if hit_roll <= final_accuracy:
            var damage = _calc_damage(weapon, target, part)
            target.take_damage(damage, part)
            _consume_weapon_cost(weapon_index)
        else:
            _play_miss_effect(target)
        state_machine.turn_manager.next_phase()
    
    func _can_use_weapon(weapon: WeaponData) -> bool:
        var ship = state_machine.turn_manager.player_ship
        if ship.status_effects.has("OVERHEAT"):
            return false
        if weapon.current_cooldown > 0:
            return false
        if not weapon.is_loaded:
            return false
        return _is_in_range(weapon)
    
    func _calc_accuracy(weapon: WeaponData, target: ShipCombatData, part: String) -> float:
        var base = 0.75
        var distance_mod = [0.0, 0.0, -0.2][target.current_ring - 1]
        if part != "hull":
            base = [1.0, 0.7, 0.6, 0.65, 0.55][_part_to_index(part)]
        return clampf(base + distance_mod + weapon.accuracy * 0.01, 0.05, 0.95)
    
    func _calc_damage(weapon: WeaponData, target: ShipCombatData, part: String) -> float:
        var base_dmg = weapon.damage
        var range_mult = [1.0, 1.0, 0.8][target.current_ring - 1]
        var armor = target.part_hp.get(part, 0) * 0.5
        var armor_reduction = armor / (armor + 100.0)
        return base_dmg * range_mult * (1.0 - armor_reduction)
    
    func _is_in_range(weapon: WeaponData) -> bool:
        var ring = state_machine.turn_manager.player_ship.current_ring
        match weapon.weapon_type:
            WeaponData.WeaponType.MAIN_GUN: return ring >= 1
            WeaponData.WeaponType.SUB_GUN: return ring <= 2
            WeaponData.WeaponType.TORPEDO: return ring == 3
            WeaponData.WeaponType.RAM: return ring == 1
        return true

## EnemyTurnState
class EnemyTurnState:
    extends BattleState
    var name = "ENEMY_TURN"
    
    func enter() -> void:
        var enemy = state_machine.turn_manager.enemy_ships[0]
        _enemy_ai_decision(enemy)
        await get_tree().create_timer(1.0).timeout
        state_machine.turn_manager.next_phase()
    
    func _enemy_ai_decision(enemy: ShipCombatData) -> void:
        # 简单AI：评估距离→选择武器→决定是否部位攻击→执行
        pass

## InterceptState
class InterceptState:
    extends BattleState
    var name = "INTERCEPT"
    
    func enter() -> void:
        var pending_projectiles = state_machine.turn_manager.pending_projectiles
        for proj in pending_projectiles:
            _resolve_intercept(proj)
        await get_tree().create_timer(0.5).timeout
        state_machine.turn_manager.next_phase()
    
    func _resolve_intercept(proj: Dictionary) -> void:
        var ship = state_machine.turn_manager.player_ship
        for i in range(ship.focus.size()):
            if ship.focus[i] <= 0:
                continue
            var intercept_rate = 0.15
            intercept_rate += ship.intercept_bonus
            intercept_rate *= [1.0, 1.5, 2.0][ship.focus[i] - 1]
            if randf() <= intercept_rate:
                proj.destroyed = true
                ship.focus[i] -= 1
                return
```

### 7.3 核心类接口总览

```gdscript
# ShipCombatData — 战斗中船只动态数据
class ShipCombatData:
    func take_damage(damage: float, part: String = "hull") -> void
    func apply_status(effect: StatusType, duration: int, severity: int = 1) -> void
    func heal(amount: int) -> void
    func repair_part(part: String, amount: int) -> void
    func check_destruction() -> bool

# WeaponData — 武器定义 Resource
class_name WeaponData extends Resource:
    enum WeaponType { MAIN_GUN, SUB_GUN, TORPEDO, RAM, BOARDING, SPECIAL }
    func can_fire_at_ring(ring: int) -> bool
    func get_damage_vs(target: ShipCombatData, part: String) -> float

# TurnManager — 回合控制
class TurnManager:
    func start_battle(player: ShipCombatData, enemies: Array[ShipCombatData]) -> void
    func next_phase() -> void
    func end_battle(winner: int) -> void

# BattleStateMachine — 状态机
class BattleStateMachine:
    func set_state(state_name: String) -> void
    func get_current_state() -> BattleState

# CombatCalculator — 命中/伤害计算工具
class CombatCalculator:
    static func calc_hit_chance(weapon: WeaponData, target: ShipCombatData, part: String) -> float
    static func calc_damage(weapon: WeaponData, target: ShipCombatData, part: String) -> float
    static func calc_intercept_rate(interceptor: ShipCombatData, sub_turret_index: int) -> float
```

---

## 8. 模块依赖图

```
┌─────────────────────────────────────────────────────┐
│                    BattleManager                     │
│              (场景根节点，单例化)                     │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌───────────────┐ ┌──────────┐ ┌─────────────┐
│ TurnManager   │ │ State    │ │ Combat      │
│ (回合控制)    │ │ Machine  │ │ Calculator  │
│               │ │          │ │ (命中/伤害)  │
└───────┬───────┘ └──────────┘ └─────────────┘
        │                                      │
        ▼                                      ▼
┌───────────────┐                    ┌─────────────────┐
│ ShipCombatData│◄───────────────────│  WeaponData     │
│ (船只战斗数据) │                    │  (WeaponResource)│
└───────┬───────┘                    └─────────────────┘
        │
        ▼
┌───────────────┐
│ StatusEffect  │
│ (状态效果)     │
└───────────────┘
```

---

## 9. 扩展性设计

### 9.1 新增状态效果

在 `StatusType` 枚举中添加新类型，并在 `StatusEffectState` 中增加对应处理函数：

```gdscript
# 示例：新增"触电"状态
enum StatusType {
    NONE, OVERHEAT, PARALYSIS, FLOOD, FIRE, STEALTH, SLOW, DISORIENT,
    SHOCK  # 新增
}
```

### 9.2 新增武器类型

在 `WeaponData.WeaponType` 中添加新枚举值：

```gdscript
# 示例：新增"电磁炮"
WeaponData.WeaponType.MAGNUM
    # 高伤害，低命中，高穿甲，附带SHOCK状态
```

### 9.3 新增射程环

将 `int current_ring` 扩展为 `float distance`，环系统退化为距离分段：

```gdscript
func get_ring_from_distance(dist: float) -> int:
    if dist <= 10: return 1   # 近距
    elif dist <= 30: return 2  # 中距
    else: return 3              # 远距
```

---

## 10. 数据驱动配置示例

```json
// combat_config.json
{
  "mobility": {
    "base_points": 10,
    "far_to_mid_cost": 40,
    "far_to_near_cost": 80,
    "mid_to_near_cost": 20
  },
  "accuracy": {
    "base_hit_rate": 0.75,
    "far_modifier": -0.20,
    "near_melee_modifier": 0.30
  },
  "part_hit_rates": {
    "hull": 1.0,
    "boiler": 0.7,
    "helm": 0.6,
    "weapon_slot": 0.65,
    "special_device": 0.55
  },
  "intercept": {
    "base_rate": 0.15,
    "helm_bonus": [0.0, 0.05, 0.10]
  },
  "status_effects": {
    "overheat_duration": 2,
    "flood_damage_per_turn": 0.05,
    "fire_damage_per_turn": 0.10,
    "stealth_duration": 2
  }
}
```

---

## 11. 参考引用

| 文档 | 章节 | 关键内容 |
|------|------|----------|
| GDD.md | 六、战斗系统 | 射程环机制、部位攻击、战术技能 |
| SUBSYSTEMS.md | 2. 战斗系统 | 射程环数值、迎击系统、状态效果详细参数 |
