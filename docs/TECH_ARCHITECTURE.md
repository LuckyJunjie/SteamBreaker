# Steam Breaker 技术架构

> 版本：v0.1 | 状态：初稿 | 制定：Athena

---

## 1. 数据模型设计（Resource 层）

所有数据对象均定义为 Godot 4 `Resource` 子类，支持 `ResourceSaver` 序列化存档。

### 1.1 船只部件（ShipPart）

```
ShipPart (abstract Resource)
├── ShipHull          — 船体（底盘）
├── ShipBoiler        — 锅炉（引擎）
├── ShipHelm          — 操舵室（C装置）
├── ShipWeapon        — 主炮
├── ShipSecondary     — 副炮
└── ShipSpecial       — 特殊装置（SE）
```

**基础字段：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `part_id` | String | 唯一标识，如 `"hull_scout"` |
| `part_name` | String | 显示名称 |
| `part_type` | String | hull/boiler/helm/weapon/secondary/special |
| `weight` | float | 重量（影响载重） |
| `price` | int | 购买价格 |
| `icon` | Resource | Texture 引用 |
| `description` | String | 策划描述文本 |

**各子类扩展字段（示例）：**

- `ShipHull`: `max_hp`, `cargo_capacity`, `weapon_slot_main`, `weapon_slot_sub`, `defense_bonus`
- `ShipBoiler`: `speed_bonus`, `overheat_threshold`, `heat_recovery`, `maneuver_power`
- `ShipHelm`: `turn_bonus`, `intercept_bonus`, `skill_slots`
- `ShipWeapon`: `damage`, `range_min`, `range_max`, `overheat_cost`, `ammo_type`, `armor_pierce`
- `ShipSecondary`: `damage`, `intercept_power`, `focus_max`, `range_type` (anti-missile/torpedo)
- `ShipSpecial`: `skill_id`, `cooldown`, `target_type`, `effect_value`

---

### 1.2 船只配置（ShipLoadout）

```
ShipLoadout (Resource)
├── ship_name: String
├── hull: ShipHull
├── boiler: ShipBoiler
├── helm: ShipHelm
├── main_weapons: Array[ShipWeapon]        # 长度由 hull.weapon_slot_main 决定
├── secondary_weapons: Array[ShipSecondary] # 长度由 hull.weapon_slot_sub 决定
├── special_devices: Array[ShipSpecial]    # 长度由 helm.skill_slots 决定
├── current_hp: int
├── current_overheat: float
└── status_effects: Array[StatusEffect]
```

---

### 1.3 伙伴数据（Companion）

```
Companion (Resource)
├── companion_id: String
├── name: String
├── species: String              # 鸟族/鱼人/机械改造人/珊瑚精/人类
├── portrait: Resource           # Texture
├── base_stats: Dictionary       # {hp, attack, defense, speed, ...}
├── skills: Array[Skill]         # 战斗技能列表
├── personality: String
├── likes: Array[String]         # 物品ID列表（礼物）
├── dislikes: Array[String]
├── affection: int               # 好感度 0-100
├── story_flags: Dictionary      # 记录已解锁的羁绊剧情节点
└── is_recruited: bool
```

```
Skill (Resource)
├── skill_id: String
├── name: String
├── description: String
├── mp_cost: int
├── cooldown: int
├── effect_type: String          # damage/heal/buff/debuff/utility
└── effect_params: Dictionary    # 具体数值参数
```

---

### 1.4 赏金数据（Bounty）

```
Bounty (Resource)
├── bounty_id: String
├── name: String
├── rank: String                 # sea/epic
├── reward_gold: int
├── reward_items: Array[String]  # 物品ID
├── required_story_flag: String  # 前置剧情flag
├── spawn_location: String       # 海域名或 "random"
├── encounter_conditions: Dictionary
├── dialogue: Dictionary         # {pre_battle, in_battle, post_battle}
├── special_mechanics: Dictionary
├── enemy_ship_data: ShipLoadout # 敌方船只数据
└── is_defeated: bool
```

---

### 1.5 存档结构（SaveData）

```
SaveData (Resource)
├── save_version: String
├── timestamp: int
├── player_name: String
├── ship: ShipLoadout
├── party: Array[Companion]      # 当前伙伴列表
├── gold: int
├── empire_bonds: int            # 帝国债券
├── junk: int                     # 废料
├── inventory: Array[Item]
├── completed_bounties: Array[String]
├── story_flags: Dictionary     # 所有剧情flag
├── world_position: Vector2     # 当前海域坐标
├── visited_ports: Array[String]
└── game_statistics: Dictionary # 战斗次数、击破数等统计
```

---

## 2. Godot Resource vs Node 职责划分

| 类型 | 用途 | 示例 |
|------|------|------|
| **Resource** | 纯数据、跨场景引用、存档序列化 | ShipPart, Companion, Bounty, SaveData |
| **Node** | 场景实例化、逻辑控制、UI | ShipEntity（持有ShipLoadout的Node）, CombatArena, UIShipEditor |

### Resource 使用原则
- 所有可在编辑器中编辑、存档中序列化的对象 → `Resource`
- `Resource` 不持有 `_ready()`/`_process()` 等生命周期方法
- 引用关系通过 `Resource` 字段（而非硬编码路径）

### Node 使用原则
- 场景根节点必须是 `Node`（或 `Node2D`/`Node3D`）
- 逻辑控制器（如 `CombatManager`）挂载为 `Node`，持有 `Resource` 数据
- UI 节点直接操作 `Resource`，通过 `setget` 或信号同步

---

## 3. Autoload 方案

| Autoload | 类型 | 职责 |
|----------|------|------|
| **GameState** | Node | 全局状态：当前存档、玩家金币、章节进度、系统配置 |
| **SaveManager** | Node | 存档写入/读取（`ResourceSaver`/`ResourceLoader`），自动存档触发点 |
| **ResourceCache** | Node | 启动时预加载所有 `*.tres` 到内存，避免运行时 IO |
| **EventBus** | Node | 全局信号总线（战斗开始、伙伴升级、赏金完成），解耦模块 |
| **CombatState** | Node | 战斗中状态：当前回合、射程环、双方状态、行动队列 |

### Autoload 初始化顺序
```
1. ResourceCache  — 预加载数据资源
2. GameState      — 初始化全局状态
3. EventBus       — 信号总线就绪
4. SaveManager    — 可接受存档请求
5. CombatState    — 战斗状态机（战斗时激活）
```

---

## 4. 场景结构

```
res://
├── resources/              # 所有 .tres 资源文件
│   ├── parts/              # 部件资源（hull_*, boiler_*, ...）
│   ├── companions/         # 伙伴资源（companion_*.tres）
│   ├── bounties/           # 赏金资源（bounty_*.tres）
│   └── skills/             # 技能资源（skill_*.tres）
├── scripts/                # GDScript 源码
│   ├── resources/          # Resource 子类定义
│   ├── entities/           # 游戏实体 Node 脚本
│   ├── managers/           # 系统管理器
│   └── ui/                 # UI 脚本
├── scenes/                 # .tscn 场景文件
│   ├── main/               # 主场景（世界地图）
│   ├── combat/             # 战斗场景（隔离）
│   ├── ports/              # 港口场景
│   └── ui/                 # UI 场景（改装、伙伴、赏金等）
├── autoload/               # Autoload 脚本
│   ├── game_state.gd
│   ├── save_manager.gd
│   ├── resource_cache.gd
│   ├── event_bus.gd
│   └── combat_state.gd
└── project.godot

work/
├── design/                 # 策划文档、数值表格
└── prototypes/             # 玩法原型
```

### 主场景树

```
MainScene (Node)
├── WorldMap
│   ├── ShipEntity          # 玩家船只（含 ShipLoadout 引用）
│   ├── PartyPanel          # 伙伴状态面板
│   └── Minimap
├── NavigationLayer
├── PortDetector
└── UIOverlay
    ├── InventoryPanel
    ├── BountyBoard
    └── NotificationArea
```

### 战斗场景隔离

```
CombatScene (Node) — 独立于主场景树
├── CombatArena
│   ├── PlayerShip (Node)
│   │   └── ShipLoadout (Resource ref)
│   └── EnemyShip (Node)
├── CombatUI
│   ├── DistanceRingDisplay
│   ├── ActionPanel
│   ├── PartTargeting
│   └── DamagePopupLayer
└── CombatState (Autoload) — 管理所有战斗逻辑
```

---

## 5. 模块接口设计

### 5.1 ShipFactory

```gdscript
class_name ShipFactory
static func create_ship(loadout: ShipLoadout) -> ShipEntity
static func apply_damage(part_type: String, amount: int) -> void
static func repair_part(part_type: String, amount: int) -> void
static func get_part_status(part_type: String) -> Dictionary
```

### 5.2 CombatManager

```gdscript
class_name CombatManager
func start_combat(enemy_loadout: ShipLoadout) -> void
func execute_player_action(action: Dictionary) -> void  # {type, target_part, weapon_index}
func advance_turn() -> void
func calculate_damage(weapon: ShipWeapon, target_part: String, distance_ring: int) -> int
func check_victory() -> bool
func check_defeat() -> bool
```

### 5.3 CompanionManager

```gdscript
class_name CompanionManager
func recruit_companion(companion_id: String) -> bool
func modify_affection(companion_id: String, delta: int) -> void
func unlock_bond_story(companion_id: String, chapter: int) -> void
func get_companion_skill(companion_id: String, skill_index: int) -> Skill
```

### 5.4 BountyManager

```gdscript
class_name BountyManager
func get_available_bounties(port_id: String) -> Array[Bounty]
func accept_bounty(bounty_id: String) -> void
func mark_complete(bounty_id: String) -> void
func spawn_random_bounty(rank: String) -> Bounty
```

### 5.5 SaveManager

```gdscript
class_name SaveManager
func save_game(slot: int) -> bool
func load_game(slot: int) -> bool
func quick_save() -> bool
func quick_load() -> bool
func has_save(slot: int) -> bool
```

---

## 6. 存档序列化方案

### 格式选择
- **推荐**：`ResourceSaver` + `.tres`（Godot 原生格式，支持循环引用，自动处理类型）
- **备选**：`JSON`（便于外部工具查看/编辑）

### 关键 Resource 注册

```gdscript
# 注册所有自定义 Resource 类型（确保跨版本兼容）
ResourceLoader.add_resource_format_variants("*.tres", [MyCustomFormatLoader.new()])
```

### 自动存档触发点
- 进入港口时
- 完成赏金战斗后
- 章节剧情节点
- 伙伴好感度变化时（延迟写入）

---

## 7. 示例数据文件结构

```
src/resources/
├── parts/
│   ├── hull_scout.tres
│   ├── hull_ironclad.tres
│   ├── boiler_single_expansion.tres
│   ├── boiler_double_expansion.tres
│   ├── helm_manual.tres
│   ├── helm_gyroscope.tres
│   ├── weapon_24pounder.tres
│   ├── weapon_torpedo.tres
│   ├── secondary_gatling.tres
│   └── special_ramming.tres
├── companions/
│   ├── companion_keerli.tres
│   ├── companion_tiechan.tres
│   └── companion_shenlan.tres
├── bounties/
│   ├── bounty_irontooth_shark.tres
│   └── bounty_ghost_queen.tres
└── skills/
    ├── skill_snipe_helm.tres
    └── skill_emergency_repair.tres
```

---

## 8. 依赖关系图

```
SaveData (Resource)
  └── ShipLoadout (Resource)
        ├── ShipHull, ShipBoiler, ShipHelm (Resource)
        ├── Array[ShipWeapon] (Resource)
        ├── Array[ShipSecondary] (Resource)
        └── Array[ShipSpecial] (Resource)

SaveData
  └── Array[Companion] (Resource)
        └── Array[Skill] (Resource)

SaveData
  └── Array[Bounty] (Resource)
        └── ShipLoadout (enemy, Resource)

GameState (Autoload Node)
  └── save_data: SaveData (Resource reference)

ShipEntity (Node)
  └── loadout: ShipLoadout (Resource reference)
```

---

## 9. 待明确事项（需要策划确认）

- [ ] 存档最大槽位数（建议 3-5 个）
- [ ] 部件稀有度分级（白/绿/蓝/紫/金）
- [ ] 伙伴最大同时参战人数（建议 3 人）
- [ ] 战斗中伙伴技能消耗的是"士气"还是"MP"
- [ ] 雷钢部件是否作为独立稀有度还是剧情锁定
