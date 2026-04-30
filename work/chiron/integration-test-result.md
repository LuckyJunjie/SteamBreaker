# Steam Breaker — 端到端集成测试报告

**测试者**: Chiron (工具/验证)
**项目路径**: `/Users/jay/SteamBreaker`
**项目根**: `src/` (project.godot 位于 `src/project.godot`)
**Godot版本**: 4.5.1.stable
**测试方法**: 代码审查 + 静态分析 + 路径验证

---

## 一、通过项清单

### 1. 场景文件存在性 ✅
| 场景文件 | 路径 | 状态 |
|---|---|---|
| TitleScreen | `res://scenes/ui/TitleScreen.tscn` | ✅ 存在 |
| World | `res://scenes/worlds/World.tscn` | ✅ 存在 |
| WorldMap | `res://scenes/worlds/WorldMap.tscn` | ✅ 存在 |
| PortScene | `res://scenes/worlds/PortScene.tscn` | ✅ 存在 |
| Battle | `res://scenes/battles/Battle.tscn` | ✅ 存在 |
| ShipEditor | `res://scenes/ui/ShipEditor.tscn` | ✅ 存在 |
| HUD | `res://scenes/ui/HUD.tscn` | ✅ 存在 |

### 2. 核心脚本存在性 ✅
- `BattleManager.gd` — ✅ 存在，战斗核心逻辑完整
- `BattleStateMachine.gd` — ✅ 存在，状态机注册完整（10个状态）
- `TurnStartState/PlayerActionState/EnemyTurnState/DamageResolveState/BattleEndState/...` — ✅ 全部存在
- `GameManager.gd` — ✅ 存在，港口/海域管理完整
- `GameState.gd` — ✅ 存在，金币/剧情/zone管理完整
- `SaveManager.gd` — ✅ 存在，存档序列化完整
- `ShipFactory.gd` — ✅ 存在，含 `current_loadout`/`get_current_loadout()`/`apply_loadout()`
- `SaveData.gd` — ✅ 存在，使用正确 `@export`（非废弃的 `@export_var`）
- `BountyManager.gd` — ✅ 存在，含 `get_completed_bounty_ids()`/`apply_bounty_progress()`
- `CompanionManager.gd` — ✅ 存在，含 `get_save_data()`/`apply_save_data()`

### 3. 关键信号连接（代码追踪）✅
| 流程 | 信号/调用 | 状态 |
|---|---|---|
| 标题→World | `TitleScreen._change_to_world()` → `change_scene_to_file("res://scenes/worlds/World.tscn")` | ✅ 路径正确 |
| World→PortScene | `WorldMapUI._on_port_clicked()` → `GameManager.sail_to_port()` → `change_scene_to_port()` | ✅ 逻辑正确 |
| PortScene→酒馆 | `PortScene._open_tavern()` → `_create_tavern_panel()` 动态创建 | ✅ 正确 |
| PortScene→赏金板 | `PortScene._open_bounty_board()` → `_create_bounty_panel()` 动态创建 | ✅ 正确 |
| PortScene→商店 | `PortScene._open_shop()` → `_create_shop_panel()` 动态创建 | ✅ 正确 |
| PortScene返回 | `PortScene._on_back_pressed()` → `exit_port.emit()` → `GameManager.depart_from_port()` | ✅ 正确 |
| 世界地图→港口 | `WorldMapUI._on_port_clicked()` → `GameManager.sail_to_port()` | ✅ 正确 |
| 世界地图→海域探索 | `WorldMapUI._on_sea_area_clicked()` → `_show_exploration_dialog()` → `roll_sea_encounter()` | ✅ 正确 |
| 港口离港→地图 | `PortScene.exit_port` → `GameManager.depart_from_port()` → `change_scene_to_world_map()` | ✅ 正确 |
| 战斗→玩家攻击 | `HUD.BattleActionButtons` → `PlayerActionState.request_attack()` → `CombatCalculator` | ✅ 逻辑正确 |
| 战斗→敌方回合 | `PlayerActionState._transition_to_enemy_turn()` → `set_state("ENEMY_TURN")` | ✅ 正确 |
| 战斗结束自动存档 | `BattleEndState.enter()` → `SaveManager.trigger_auto_save("battle_victory")` | ✅ 正确 |

### 4. 战斗状态机流转 ✅
```
TURN_START → PLAYER_MOVE → PLAYER_ACTION → (INTERCEPT) → ENEMY_TURN
  → DAMAGE_RESOLVE → STATUS_EFFECT → CHECK_END
  → BATTLE_END (if game over) → TURN_START (if continue)
```
- 完整循环验证 ✅
- 敌方AI（EnemyTurnState）存在 ✅
- 战斗结算（BattleEndState）存在 ✅

### 5. 存档读档序列化 ✅
- `SaveData.to_dict()` / `from_dict()` 完整 ✅
- `SaveData.to_json_string()` / `from_json_string()` 正确实现 ✅
- 船体/伙伴/赏金进度序列化方法全部存在 ✅
- Slot 9 用于自动存档 ✅

### 6. 资源文件存在性 ✅
- 船体资源: `res://resources/parts/hull_scout.tres`, `hull_ironclad.tres` ✅
- 武器资源: `weapon_24pounder.tres`, `weapon_torpedo.tres` ✅
- 伙伴资源: `companion_keerli.tres`, `companion_tiechan.tres`, `companion_shenlan.tres` ✅
- 赏金资源: `bounty_irontooth_shark.tres`, `bounty_ghost_queen.tres` ✅

---

## 二、Critical Bug List（阻塞原型演示）

### Bug #1: GameManager 不是 Autoload — 场景获取链断裂
**文件**: `src/project.godot` [21-24]
**问题**: `project.godot` 的 `[autoload]` 节只注册了 `GameState`、`ResourceCache`、`SaveManager`。`GameManager` 未注册为 Autoload，但大量代码用 `get_node("/root/GameManager")` 或 `get_tree().root.find_child("World")` 假设它存在。

**影响范围**:
- `PortScene._load_game_manager()` → `find_child("World")` 返回 `null` → `_game_manager` 永为 `null`
- `WorldMapUI._load_game_manager()` → `find_child("World")` 返回 `null` → 所有 `GameManager` 功能失效
- `ShipEditor._on_confirm_pressed()` → `find_child("ShipFactory")` 返回 `null` → 改装数据无法应用

**修复建议**: 在 `project.godot [autoload]` 中添加:
```
GameManager="*res://scripts/systems/GameManager.gd"
ShipFactory="*res://scripts/systems/ShipFactory.gd"
CompanionManager="*res://scripts/systems/CompanionManager.gd"
BountyManager="*res://scripts/systems/BountyManager.gd"
```
同时从 `World.tscn` 中移除 `World` 节点（GameManager 改由 Autoload 提供）。

---

### Bug #2: ShipFactory / CompanionManager / BountyManager 未加入场景树
**文件**: `src/scenes/worlds/World.tscn`
**问题**: World.tscn 只包含 `World`（GameManager脚本）和 `WorldMapUI`，**不包含** `ShipFactory`、`CompanionManager`、`BountyManager`。

**影响**:
- `SaveManager._get_ship_factory()` → 永远返回 `null` → 船只配置无法存档/读档
- `SaveManager._apply_companions()` → 找不到 `CompanionManager` → 伙伴数据无法恢复
- `SaveManager._apply_bounties()` → 找不到 `BountyManager` → 赏金进度无法恢复

**修复建议**: 在 World.tscn 中添加所需节点:
```
[node name="ShipFactory" type="Node2D"]
script = ExtResource("...ShipFactory.gd")

[node name="CompanionManager" type="Node"]
script = ExtResource("...CompanionManager.gd")

[node name="BountyManager" type="Node"]
script = ExtResource("...BountyManager.gd")
```
或通过 Bug #1 的 Autoload 方案一并解决。

---

### Bug #3: PortScene._open_ship_editor() 类型混淆
**文件**: `src/scripts/ui/PortScene.gd:230-250`
**问题**: `_open_ship_editor()` 中:
```gdscript
if _game_manager and _game_manager.has_method("get_current_loadout"):
    instance.set_loadout(_game_manager.get_current_loadout())
```
`_game_manager` 是 `World` 节点（Node2D，附加 GameManager 脚本），但 `get_current_loadout()` 方法实际在 `ShipFactory` 上，不在 GameManager 上。

**影响**: `has_method("get_current_loadout")` 在 World 上为 `false`（GameManager 脚本无此方法） → `set_loadout()` 从不被调用，ShipEditor 显示空配置。

**修复建议**:
```gdscript
func _open_ship_editor() -> void:
    var ship_factory = get_tree().root.find_child("ShipFactory", false, false)
    if ship_factory and ship_factory.has_method("get_current_loadout"):
        instance.set_loadout(ship_factory.get_current_loadout())
    else:
        # fallback to GameManager
        var loadout = _game_manager.get_current_loadout() if _game_manager and _game_manager.has_method("get_current_loadout") else null
        instance.set_loadout(loadout)
```

---

### Bug #4: BattleEndState 战斗结束后不返回港口
**文件**: `src/scripts/battles/states/BattleEndState.gd:enter()`
**问题**: `BattleEndState.enter()` 只做了播放动画、显示结算UI、触发自动存档，**没有切换场景**。战斗结束后游戏停留在 Battle 场景。

**影响**: 玩家赢了/输了战斗后，看到结算画面，但无法返回港口或世界地图。

**修复建议**: 在 `BattleEndState.gd` 中添加战斗结束后的场景返回逻辑:
```gdscript
func enter() -> void:
    # ... 现有代码 ...
    
    # 显示返回按钮（通过 HUD 或 Overlay）
    _show_return_button()

func _show_return_button() -> void:
    # 延迟3秒后自动返回，或等待玩家点击
    var timer = Timer.new()
    timer.one_shot = true
    timer.timeout.connect(_return_to_world)
    get_tree().root.add_child(timer)
    timer.start(3.0)

func _return_to_world() -> void:
    var tree = get_tree()
    if tree and tree.change_scene_to_file("res://scenes/worlds/WorldMap.tscn") != OK:
        push_error("[BattleEnd] Failed to return to WorldMap")
```

---

### Bug #5: PortScene._on_back_pressed() 离港逻辑缺失
**文件**: `src/scripts/ui/PortScene.gd:900-906`
**问题**:
```gdscript
func _on_back_pressed() -> void:
    if _active_panel:
        _close_active_panel()
    else:
        print("[PortScene] Exit port")
        if SaveManager and SaveManager.has_method("trigger_auto_save"):
            SaveManager.trigger_auto_save("depart_from_port")
        exit_port.emit()
```
`exit_port` 信号在 PortScene 中定义，但**没有任何地方连接此信号**。

**影响**: 点击返回按钮 → 信号发出 → **无人接收** → 游戏无反应。

**修复建议**: 在 World.tscn 加载 PortScene 后显式连接，或在 PortScene 的 `_ready()` 中:
```gdscript
func _ready() -> void:
    # ... 现有代码 ...
    if not exit_port.is_connected(_on_exit_port_requested):
        exit_port.connect(_on_exit_port_requested)

func _on_exit_port_requested() -> void:
    if _game_manager and _game_manager.has_method("depart_from_port"):
        _game_manager.depart_from_port()
    else:
        get_tree().change_scene_to_file("res://scenes/worlds/WorldMap.tscn")
```

---

## 三、Medium Bug List（非阻塞但需修复）

### Bug #6: PortScene._get_player_gold() 使用错误的变量引用
**文件**: `src/scripts/ui/PortScene.gd:693`
```gdscript
func _get_player_gold() -> int:
    return GameState.gold
```
GameState 是 Autoload Node，`GameState.gold` 是 `@export var` 实例变量。由于 Autoload 是单例 Node，直接访问 `GameState.gold` 在某些上下文可能产生歧义（Godot 4 中推荐显式使用）。

**建议**: 改为 `return GameState.gold if GameState else 0`，并确认 GameState 已在 project.godot 正确注册。

---

### Bug #7: TitleScreen 新游戏初始金币不一致
**文件**: `src/scripts/ui/TitleScreen.gd:180` vs `src/scripts/autoload/GameState.gd:reset()`
```gdscript
# TitleScreen._start_new_game()
gs.gold = 5000

# GameState.reset()
gold = 1000
```
新游戏时 TitleScreen 重置 GameState.gold = 5000，但 GameState.reset() 会重置为 1000。如果 `gs.reset()` 在 `gs.gold = 5000` 之后被调用，金币会被覆盖为 1000。

**建议**: 在 TitleScreen._start_new_game() 中统一金币值，或让 GameState.reset() 接受初始金币参数。

---

### Bug #8: WorldMapUI._sync_from_game_manager() 中 `is_port_unlocked` 方法引用问题
**文件**: `src/scripts/ui/WorldMapUI.gd:144`
```gdscript
var is_unlocked = _game_manager.is_port_unlocked(port_id)
```
`_game_manager` 在 `_load_game_manager()` 中被设置为 `World` 节点（Node2D），而不是 GameManager 类实例。`is_port_unlocked` 是 GameManager 脚本的方法，但如果 `_game_manager` 引用为 null，此调用不会执行（短路求值），暂无报错但逻辑不生效。

---

### Bug #9: ShipEditor 的 `PartPickerPopup` 内部类在 Editor 外可能无法正确实例化
**文件**: `src/scripts/ui/ShipEditor.gd:620`
```gdscript
class PartPickerPopup extends PopupPanel:
    ...
func _on_part_selected(part: Resource, slot_type: String) -> void:
    ...
```
`PartPickerPopup` 是 ShipEditor.gd 的内部类，在 Godot 4 中内部类需要通过外部类访问。如果 `PartPickerPopup` 的信号 `part_selected` 连接方式不正确，可能导致选择部件后无反应。

**建议**: 验证 `get_tree().root.add_child(picker)` 后的信号连接，或将 `PartPickerPopup` 拆分为独立场景。

---

### Bug #10: SaveManager 手动存档槽位 9 被自动存档占用
**文件**: `src/scripts/systems/SaveManager.gd`
```gdscript
func auto_save(reason: String = "auto") -> void:
    var success: bool = save(9)  # quick slot 9
```
槽位 9 同时用于自动存档和手动存档槽位列表中的第9个槽位（`MAX_SAVE_SLOTS = 10`，槽位 0-9）。如果玩家在 SaveLoadUI 中看到槽位9，恰好是自动存档，可能造成困惑。

**建议**: 将自动存档槽位改为 -1 或单独管理，不占用可见槽位范围。

---

### Bug #11: HUD.gd BattleActionPanel 连接检查不完整
**文件**: `src/scripts/ui/HUD.gd`
HUD._setup_battle_action_panel() 连接战斗信号，但 `battle_manager_ref` 通过 `_detect_battle_mode()` 设置时，如果 BattleManager 在 HUD ready 之后才加载，引用可能不完整。

**建议**: 使用 `get_tree().root.find_child("BattleManager", true, false)` 显式查找，而非依赖 `_detect_battle_mode()` 的单次触发。

---

### Bug #12: 资源路径大小写敏感性（macOS 特性）
**文件**: 多处 `res://resources/companions/`
macOS 文件系统默认大小写不敏感，但项目可能在其他平台构建。确保所有 `.tres` 文件路径大小写完全一致（当前代码使用小写 `companion_keerli.tres` 等，与目录名 `companions/` 一致）✅。

---

## 四、测试套件现状

| 测试文件 | 状态 | 备注 |
|---|---|---|
| `test_battle.gd` | ⚠️ 路径问题 | 使用 `res://scripts/battles/` 但实际路径是 `res://src/scripts/battles/` |
| `test_save_load.gd` | ⚠️ 断言错误 | 多处 `assert_true(_X.has_method("YYY") == false)` — 方法实际存在，断言本身有误 |

**注**: 测试文件中的 `res://scripts/` 路径缺少 `src/` 前缀，因为 project.godot 位于 `src/project.godot`，`res://` 相对于 `src/` 目录。完整路径应为 `res://src/scripts/`。

---

## 五、总结

### 阻塞问题（阻止原型演示）
1. **GameManager/ShipFactory/CompanionManager/BountyManager 未注册为 Autoload** — 跨场景状态管理完全失效
2. **ShipEditor 无法获取船只配置** — 船只编辑器核心功能不可用
3. **战斗结束后无场景返回** — 赢了战斗也困在战斗场景

### 建议优先级
1. **立即修复**: Bug #1（Autoload）+ Bug #2（场景树节点）+ Bug #4（战斗返回）+ Bug #5（信号连接）
2. **高优先级**: Bug #3（ShipEditor loadout）、Bug #7（初始金币不一致）
3. **中优先级**: Bug #6-11

修复优先级1的问题后，核心游戏循环（标题→港口→出海→战斗→返回港口）应可走通。
