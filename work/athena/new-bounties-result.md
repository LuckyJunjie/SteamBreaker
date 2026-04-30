# 新增赏金敌人 + 帝国债券商店 - 实施报告

**执行者**: Athena (系统架构)
**日期**: 2026-04-30
**状态**: ✅ 完成

---

## 1. 赏金敌人资源创建

### 巡逻铁甲舰 (`bounty_patrol_ironclad.tres`)
- **路径**: `src/resources/bounties/bounty_patrol_ironclad.tres`
- **类型**: enemy_ship (patrol)
- **HP**: 400
- **武器**: 24磅卡隆炮
- **护甲**: 60 (高护甲)
- **特殊机制**: `high_armor`, `medium_range_cannon`, `armor_24lb`
- **出现区域**: 工业海峡 (`industrial_port`)
- **难度**: ⭐⭐ (2星)
- **奖励**: 5000金 + 钢板 + 24磅炮图纸

### 雷电龙 (`bounty_thunder_dragon.tres`)
- **路径**: `src/resources/bounties/bounty_thunder_dragon.tres`
- **类型**: bounty_target
- **HP**: 600
- **特殊机制**: `thunder_attack` (降低敌方机动), `storm_aura`
- **出现区域**: 风暴岭 (`storm_ridge`)
- **难度**: ⭐⭐⭐ (3星)
- **奖励**: 12000金 + 龙鳞 + 雷火炮图纸

### 深渊者 (`bounty_deep_one.tres`)
- **路径**: `src/resources/bounties/bounty_deep_one.tres`
- **类型**: bounty_target
- **HP**: 500
- **特殊机制**: `deep_slow_aura` (降低玩家回避率), `abyssal_darkness`
- **出现区域**: 深渊海沟 (`abyssal_trench`)
- **难度**: ⭐⭐⭐⭐ (4星)
- **奖励**: 15000金 + 深海之眼 + 深渊核心碎片

---

## 2. 海域赏金提示

`SEA_AREAS` 中的 `bounty_hints` 已配置：

| 海域 | bounty_hints | 难度 |
|------|-------------|------|
| 工业海峡 | `["patrol_ironclad"]` | 2 |
| 风暴岭 | `["thunder_dragon"]` | 3 |
| 深渊海沟 | `["deep_one"]` | 4 |

---

## 3. 帝国债券系统

**已存在**: `GameState.gd` 中已有完整实现：
- `empire_bonds` 字段
- `add_bonds(amount)` / `spend_bonds(amount)` 
- `empire_bonds_changed` 信号
- SaveManager/SaveData 集成

**无需新建** `EmpireBondManager.gd` — 现有系统已完整。

---

## 4. Autoload 注册

无需额外注册 — `empire_bonds` 已在 `GameState.gd` (已注册 autoload) 中管理。

---

## 5. 帝国商店 Tab

**文件**: `src/scripts/ui/ShopUI.gd`

更新内容：
- 新增 `_empire_shop_items` 数组（帝国债券专属商品）
- 新增 `_add_empire_item_row()` 方法
- 新增 `_on_empire_buy_pressed()` 方法（使用 `GameState.spend_bonds()`）
- 新增 `_bonds_lbl` 节点显示债券余额
- `_populate_items()` 同时填充两个列表

**帝国商店商品**：
| 商品 | 价格(债券) | 效果 |
|------|-----------|------|
| 雷火炮图纸 | 200 | 风暴岭特殊武器 |
| 深渊甲图纸 | 300 | 深渊海沟特殊护甲 |
| 铁甲舰船体图纸 | 250 | 帝国巡逻舰技术 |
| 帝国罗盘 | 150 | 永久显示赏金位置 |
| 皇室勋章 | 100 | 所有商人9折 |

---

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `src/resources/bounties/bounty_patrol_ironclad.tres` | 新增 |
| `src/resources/bounties/bounty_thunder_dragon.tres` | 新增 |
| `src/resources/bounties/bounty_deep_one.tres` | 新增 |
| `src/scripts/ui/ShopUI.gd` | 修改 |

---

## 注意事项

1. UI 场景中需要添加 `BondsLabel` 节点以显示帝国债券余额
2. 帝国商店 Tab 页面需要添加 `EmpireItemsList` 节点
3. 赏金敌人对应的战斗 AI 机制（雷属性降低机动、深海减速光环）需在 BattleManager 中实现具体逻辑
