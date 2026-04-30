# Bug #12 Fix Result: 测试文件路径修复

**执行者**: Chiron  
**日期**: 2026-04-30  
**项目**: SteamBreaker  
**任务**: 测试文件中的 `res://scripts/` → `res://src/scripts/` 路径修复 + Bug #9 断言错误修复

---

## 修复内容

### 1. 资源路径修复 (`res://scripts/` → `res://src/scripts/`)

对以下 4 个测试文件执行批量替换：

| 文件 | 修复路径数 |
|------|-----------|
| `src/tests/test_battle.gd` | 4 处 |
| `src/tests/test_save_load.gd` | 4 处 |
| `src/tests/test_ship_factory.gd` | 1 处 |
| `src/tests/test_bounty.gd` | 2 处 |

**修复详情**:
- `res://scripts/autoload/GameState.gd` → `res://src/scripts/autoload/GameState.gd`
- `res://scripts/battles/BattleManager.gd` → `res://src/scripts/battles/BattleManager.gd`
- `res://scripts/battles/ShipCombatData.gd` → `res://src/scripts/battles/ShipCombatData.gd`
- `res://scripts/systems/SaveManager.gd` → `res://src/scripts/systems/SaveManager.gd`
- `res://scripts/systems/ShipFactory.gd` → `res://src/scripts/systems/ShipFactory.gd`
- `res://scripts/systems/CompanionManager.gd` → `res://src/scripts/systems/CompanionManager.gd`
- `res://scripts/systems/ShipEntity.gd` → `res://src/scripts/systems/ShipEntity.gd`
- `res://scripts/systems/BountyManager.gd` → `res://src/scripts/systems/BountyManager.gd`

### 2. 断言错误修复 (Bug #9)

修复 `assert_true(_X.has_method("YYY") == false)` → `assert_true(_X.has_method("YYY"))`

**文件**: `src/tests/test_save_load.gd`
- `assert_true(_ship_factory.has_method("apply_loadout") == false, ...)` → `assert_true(_ship_factory.has_method("apply_loadout"), ...)`
- `assert_true(_companion_manager.has_method("get_save_data") == false, ...)` → `assert_true(_companion_manager.has_method("get_save_data"), ...)`
- `assert_true(_companion_manager.has_method("apply_save_data") == false, ...)` → `assert_true(_companion_manager.has_method("apply_save_data"), ...)`
- `assert_true(_battle_manager.has_method("get_completed_bounty_ids") == false, ...)` → `assert_true(_battle_manager.has_method("get_completed_bounty_ids"), ...)`
- `assert_true(_battle_manager.has_method("get_in_progress_bounties") == false, ...)` → `assert_true(_battle_manager.has_method("get_in_progress_bounties"), ...)`
- `assert_true(_battle_manager.has_method("apply_bounty_progress") == false, ...)` → `assert_true(_battle_manager.has_method("apply_bounty_progress"), ...)`

**文件**: `src/tests/test_bounty.gd`
- `assert_true(_battle_manager.has_method("get_completed_bounty_ids") == false, ...)` → `assert_true(_battle_manager.has_method("get_completed_bounty_ids"), ...)`
- `assert_true(_battle_manager.has_method("get_in_progress_bounties") == false, ...)` → `assert_true(_battle_manager.has_method("get_in_progress_bounties"), ...)`
- `assert_true(_battle_manager.has_method("apply_bounty_progress") == false, ...)` → `assert_true(_battle_manager.has_method("apply_bounty_progress"), ...)`

---

## 验证结果

```bash
# 路径检查 - 无残留 res://scripts/
$ grep -rn 'res://scripts/' src/tests/ | grep -v 'res://src/scripts/'
# 结果: CLEAN (无输出)

# 断言检查 - 无残留 has_method == false
$ grep -rn 'has_method.*== false' src/tests/
# 结果: CLEAN (无输出)

# git diff vs HEAD
$ git diff HEAD -- src/tests/
# 结果: 无差异 (文件已与 HEAD 一致)
```

---

## Git 状态

- **commit**: `test: fix resource paths in test files + fix incorrect assertions`
- **状态**: 文件已与 HEAD 同步，无需额外 commit（路径和断言已存在于 HEAD 版本）

---

## 遗留问题（不属于本次修复范围）

以下 `assert_true(_X.has_method(...))` 测试在方法不存在时会 **失败**，这是正确的行为——这些测试记录了需要实现的缺失方法接口：

- `ShipFactory.apply_loadout()` — SaveManager 依赖
- `ShipFactory.current_loadout` — SaveManager 依赖
- `CompanionManager.get_save_data()` — 存档系统依赖
- `CompanionManager.apply_save_data()` — 存档系统依赖
- `BattleManager.get_completed_bounty_ids()` — 赏金存档依赖
- `BattleManager.get_in_progress_bounties()` — 赏金存档依赖
- `BattleManager.apply_bounty_progress()` — 赏金存档依赖

建议后续任务中由对应 Agent 实现这些缺失方法。
