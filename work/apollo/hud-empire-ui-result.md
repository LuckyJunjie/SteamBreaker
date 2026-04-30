# Sprint 15 - HUD完善 + 帝国债券UI 交付报告

**执行者:** Apollo (Apollo, Godot Developer)
**日期:** 2026-04-30
**状态:** ✅ 完成并推送

---

## 1. ShopUI 帝国商店Tab完善 ✅

### 创建 `src/scenes/ui/ShopUI.tscn`
场景节点结构完整：
- `VBox/TitleArea/TitleLabel` — 标题
- `VBox/CurrencyBar/GoldLabel` — 金币显示
- `VBox/CurrencyBar/BondsSection/BondsLabel` — 帝国债券显示
- `VBox/TabContainer` — Tab切换
  - `GeneralShop` (杂货商店) — 普通商品列表
  - `EmpireShop` (帝国商店) — 帝国债券专属商品
- `VBox/BottomBar/CloseBtn` — 关闭按钮

### 更新 `src/scripts/ui/ShopUI.gd`
- `_find_node_robust()` — 健壮节点查找（兼容多种路径）
- `_open_empire_shop()` — 帝国商店Tab入口方法
- `_show_empire_items_list()` — 切换到帝国Tab并刷新列表
- `_update_bonds_display(bonds)` — 更新债券显示
- `_on_empire_buy_pressed(item)` — 帝国债券消费逻辑
- `spend_bonds()` 调用 GameState
- 修复 `_on_close_pressed()` 不再调用 `get_tree().quit()`（只隐藏面板）

---

## 2. HUD 界面完善 ✅

### 更新 `src/scripts/ui/HUD.gd`
- `_setup_ui()` 添加背包按钮 `🎒 背包`
- `_open_inventory()` 方法实现：
  ```gdscript
  func _open_inventory() -> void:
      var inv_path = "/root/InventoryPanel"
      if has_node(inv_path):
          var panel = get_node(inv_path)
          panel.visible = true
      else:
          print("[HUD] InventoryPanel not found in scene tree")
  ```
- `show_dialogue_box()` 中 DialogueManager 查找改为 `DialogueSystem`
- `_connect_companion_signals()` 中 autoload 查找更新为 DialogueSystem/BondEventSystem

---

## 3. DialogueManager 和 BondEventManager 接入 ✅

### 更新 `src/project.godot`
注册为 autoload：
```
DialogueSystem="*res://scripts/systems/DialogueManager.gd"
BondEventSystem="*res://scripts/systems/BondEventManager.gd"
```

### 修改 `src/scripts/systems/DialogueManager.gd`
- 移除 `class_name DialogueManager`（已作为autoload，避免名称冲突）

### 修改 `src/scripts/systems/BondEventManager.gd`
- 移除 `class_name BondEventManager`（已作为autoload，避免名称冲突）

### 修改 `src/scripts/ui/CompanionPanel.gd`
- `set_dialogue_manager(dm: Node)` 参数类型从 `DialogueManager` 改为 `Node`（消除编译冲突）

---

## 4. 验证新伙伴资源 ✅

所有5个伙伴资源存在于 `src/resources/companions/` 并包含正确的 `companion_id` 字段：

| 文件 | companion_id | 状态 |
|------|-------------|------|
| companion_keerli.tres | companion_keerli | ✅ |
| companion_tiechan.tres | companion_tiechan | ✅ |
| companion_shenlan.tres | companion_shenlan | ✅ |
| companion_beisuo.tres | companion_beisuo | ✅ |
| companion_linhuo.tres | companion_linhuo | ✅ |

`ResourceCache.gd` 的 `_preload_companions()` 已能正确扫描加载这些资源。

---

## Git 提交

```
[main 91619bc] Sprint 15: HUD完善 + 帝国债券UI
 7 files changed, 189 insertions(+), 40 deletions(-)
 create mode 100644 src/scenes/ui/ShopUI.tscn
 pushed to: main
```

---

## 待后续处理

- HUD.tscn 仍是空场景，内容全部通过 HUD.gd 动态生成（设计如此，符合现有架构）
- 帝国债券获取途径需后续在游戏内实现（如完成赏金任务奖励发放）
- InventoryPanel 需要确保在场景树中存在（`/root/InventoryPanel`），当前作为独立面板存在