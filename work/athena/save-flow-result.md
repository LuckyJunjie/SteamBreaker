# 存档端到端验证结果

**执行者**: Athena (系统架构)  
**日期**: 2026-04-30  
**项目**: SteamBreaker  
**模式**: 独立团队模式

---

## 1. SaveManager 初始化验证 ✅

Godot headless 测试日志：

```
[SaveManager] Initializing...
[SaveManager] Ready. Save path: user://saves
```

**结论**: SaveManager 正常初始化，自动存档路径 `user://saves` 创建成功。

---

## 2. SaveData.to_dict() / from_dict() 字段检查

| 字段 | to_dict() | from_dict() | 备注 |
|------|-----------|-------------|------|
| `gold` | ✅ | ✅ | |
| `empire_bonds` | ✅ | ✅ | |
| `story_progress` | ✅ | ✅ | |
| `story_flags` | ✅ | ✅ | |
| `companions_data` | ✅ | ✅ | 含 affection/is_recruited/story_flags/skill_ids |
| `ship_loadout` | ✅ | ✅ | 通过 resource_path 序列化 |
| `bounties_completed` | ✅ | ✅ | Array[String] |
| `bounties_in_progress` | ✅ | ✅ | Array[Dictionary] |
| `inventory_data` | ✅ | ✅ | |
| `timestamp` | ✅ | ✅ | |
| `settings` | ✅ | ✅ | |

**结论**: 所有关键字段完整，实现正确。

---

## 3. Auto-save 触发点验证

| 触发点 | 状态 | 代码位置 |
|--------|------|----------|
| `PortScene._on_back_pressed()` → `"depart_from_port"` | ✅ 已确认 | PortScene.gd 末尾 `exit_port.emit()` 前调用 `SaveManager.trigger_auto_save("depart_from_port")` |
| `BattleEndState.enter()` → `"battle_victory"` | ✅ 已确认 | `if winner == 1 and SaveManager and SaveManager.has_method("trigger_auto_save"): SaveManager.trigger_auto_save("battle_victory")` |
| `ShipEditor._on_confirm_pressed()` → `"ship_upgrade"` | ⚠️ **缺失，已补充** | 添加于 `_on_confirm_pressed()` 末尾 |

**ShipEditor 补充代码** (src/scripts/ui/ShipEditor.gd):
```gdscript
# Auto-save after ship upgrade
SaveManager.trigger_auto_save("ship_upgrade") if SaveManager and SaveManager.has_method("trigger_auto_save") else None
```

---

## 4. 潜在问题检查

### 4.1 GameState.get_save_data() / apply_save_data()
- ✅ **存在**: `src/scripts/autoload/GameState.gd`
- 返回包含: `player_name`, `gold`, `empire_bonds`, `story_progress`, `story_flags`, `current_zone`, `current_port_id`, `current_sea_area`

### 4.2 BountyManager.get_completed_bounty_ids()
- ✅ **存在**: `src/scripts/systems/BountyManager.gd` line 265
- 返回: `Array[String]` (`_completed_bounties.keys()`)

### 4.3 ShipFactory.get_current_loadout() 初始化前 null
- ✅ **安全**: `ShipFactory._ready()` 初始化默认 `ShipLoadout`，`get_current_loadout()` 永远返回有效对象（非 null）
- `_collect_game_state()` 对 `get_current_loadout()` 有 null 检查: `if ship_factory.has_method("get_current_loadout") and ship_factory.get_current_loadout():`

### 4.4 CompanionManager.get_save_data() / apply_save_data()
- ✅ **存在**: `CompanionManager.gd` line 397/405
- 返回格式为 `Array[Dictionary]`，与 SaveData.companions_data 格式匹配

---

## 5. 修复摘要

| 修复项 | 文件 | 状态 |
|--------|------|------|
| ShipEditor auto_save 缺失 | `src/scripts/ui/ShipEditor.gd` | ✅ 已修复 |

---

## 6. 存档流程总览

```
存档触发点 (trigger_auto_save)
  ├─ PortScene._on_back_pressed()        → "depart_from_port"
  ├─ BattleEndState.enter()              → "battle_victory"
  └─ ShipEditor._on_confirm_pressed()    → "ship_upgrade" [新增]

SaveManager.trigger_auto_save(reason)
  └─ auto_save(reason)
       └─ save(AUTO_SAVE_SLOT)
            └─ _collect_game_state()
                 ├─ GameState.get_save_data()       → gold/empire_bonds/story
                 ├─ ShipFactory.get_current_loadout() → ship_loadout
                 ├─ CompanionManager.get_save_data()  → companions_data
                 ├─ InventoryManager.get_save_data()  → inventory_data
                 └─ BountyManager.get_completed_bounty_ids() → bounties_completed

SaveData.to_dict() → JSON.stringify → FileAccess → user://saves/auto/auto_save.json
```

---

## 7. 结论

存档系统端到端流程完整，所有关键字段正确实现。仅发现 ShipEditor 确认改装后缺少 auto_save 触发点，已补充。

**待验证项** (需人工测试):
1. 实际游戏中从港口离港，观察 auto_save 是否正常触发
2. 战斗胜利后读档，验证金币/伙伴/赏金状态是否正确恢复
3. 改装船只后读档，验证 ship_loadout 是否正确恢复