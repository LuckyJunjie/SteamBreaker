# Bug Fix: 初始金币 + HUD BattleManager 修复

**执行者**: Apollo  
**日期**: 2026-04-30  
**状态**: ✅ 完成

## Bug #7: TitleScreen 新游戏初始金币不一致

### 问题
TitleScreen._start_new_game() 设置 `gs.gold = 5000`，但调用 `gs.reset()` 后金币被覆盖为 1000。

### 修复
修改 `GameState.reset()` 默认金币值：
- 文件: `src/scripts/autoload/GameState.gd`
- `gold = 1000` → `gold = 5000`

### 验证
TitleScreen 新游戏 → 港口 → 金币应显示为 5000

---

## Bug #11: HUD BattleManager 引用风险

### 问题
HUD._detect_battle_mode() 在 ready 时触发一次，如果 BattleManager 之后才加载，引用丢失。

### 修复
修改 `HUD._detect_battle_mode()` 使用延迟查找：
- 文件: `src/scripts/ui/HUD.gd`
- 在 `_ready` 后添加 `await get_tree().process_frame` 延迟一帧
- 通过 `find_child("BattleManager", true, false)` 动态查找
- 找不到时回退到 `find_child("Battle", false, false)` 场景检测

### 验证
战斗开始时 HUD 能正确显示操作面板

---

## 修改文件
1. `src/scripts/autoload/GameState.gd` - reset() gold: 1000 → 5000
2. `src/scripts/ui/HUD.gd` - _detect_battle_mode() 延迟查找逻辑
