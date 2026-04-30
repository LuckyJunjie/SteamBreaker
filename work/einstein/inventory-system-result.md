# 物品/道具系统实现报告

**执行者**: Einstein (战斗系统)
**日期**: 2026-04-30
**状态**: ✅ 完成

## 任务概述

根据 GDD 中定义的物品系统需求，实现了完整的物品/道具系统，包括道具定义、玩家背包、物品使用、商店购买和存档支持。

## 完成内容

### 1. 物品资源类型 ✅
**文件**: `src/scripts/resources/game_item.gd`

创建了 `GameItem` Resource 类，包含：
- `ItemType` 枚举：`CONSUMABLE`、`EQUIPMENT`、`KEY_ITEM`、`GIFT`
- 基础属性：`item_id`、`name`、`description`、`icon_emoji`
- 价格属性：`buy_price`、`sell_price`
- 效果数据：`effect_data` Dictionary
- 辅助方法：`get_type_name()`、`can_sell()`、`can_buy()`、`get_effect_description()`

### 2. 物品数据库 ✅
**文件**: `src/resources/items/` 目录下的 .tres 文件

创建了 6 个物品资源：

| item_id | name | type | icon | effect |
|---------|------|------|------|--------|
| `return_port_smoke` | 归港烟玉 | KEY_ITEM | 🏠 | 瞬间返回铁锈湾 |
| `flower_bouquet` | 花束 | GIFT | 💐 | 好感度 +5~15 |
| `old_book` | 旧书 | GIFT | 📖 | 知识型伙伴好感 +5~10 |
| `ship_model` | 船模 | GIFT | ⛵ | 铁砧好感 +15~25 |
| `sea_chart` | 海图 | KEY_ITEM | 🗺️ | 揭示新海域 |
| `repair_kit` | 修理工具包 | CONSUMABLE | 🔧 | 恢复船只100HP |

**管理脚本**: `src/scripts/systems/ItemDatabase.gd`
- 单例模式，自动加载所有物品
- 提供 `get_item()`、`get_all_items()`、`get_buyable_items()`、`get_items_by_type()` 等查询接口

### 3. 玩家背包系统 ✅
**文件**: `src/scripts/systems/InventoryManager.gd`

核心功能：
- `add_item(item_id, quantity)` - 添加物品
- `remove_item(item_id, quantity)` - 移除物品
- `has_item(item_id)` - 检查是否拥有
- `use_item(item_id)` - 使用物品（根据类型执行效果）
- `get_inventory_snapshot()` - 获取背包快照（用于UI）
- 完整存档支持：`get_save_data()`、`apply_save_data()`

物品使用效果：
- **消耗品**: `repair_ship` 修复船只HP
- **关键道具**: `teleport` 传送、`reveal_area` 揭示区域
- **礼物**: `affection` 增加好感度

### 4. 背包面板 UI ✅
**文件**:
- `src/scenes/ui/InventoryPanel.tscn` - 场景文件
- `src/scripts/ui/InventoryPanel.gd` - 控制器

功能：
- 左侧物品列表（可点击选择）
- 右侧详情面板（显示名称、描述、效果）
- 使用按钮（对选中物品执行效果）
- 自动刷新（当背包变化时）
- 默认布局（场景无预设时的动态创建）

### 5. 商店集成 ✅
**修改**: `src/scripts/ui/PortScene.gd`

- 商店面板添加「🎒 背包」按钮
- 商店购买时自动添加物品到背包
- 优先使用 ItemDatabase 中的物品列表

### 6. 存档系统集成 ✅
**修改**:
- `src/scripts/systems/SaveData.gd` - 添加 `inventory_data` 字段
- `src/scripts/systems/SaveManager.gd` - 添加收集/应用背包数据方法

### 7. Autoload 注册 ✅
**文件**: `src/project.godot`

添加了以下 Autoload：
```
ItemDatabase="*res://scripts/systems/ItemDatabase.gd"
InventoryManager="*res://scripts/systems/InventoryManager.gd"
```

## 文件清单

| 文件 | 类型 | 说明 |
|------|------|------|
| `src/scripts/resources/game_item.gd` | GDScript | 物品资源类 |
| `src/scripts/systems/ItemDatabase.gd` | GDScript | 物品数据库 |
| `src/scripts/systems/InventoryManager.gd` | GDScript | 背包管理器 |
| `src/scripts/ui/InventoryPanel.gd` | GDScript | 背包面板控制器 |
| `src/scenes/ui/InventoryPanel.tscn` | TSCN | 背包面板场景 |
| `src/resources/items/item_return_port_smoke.tres` | TRES | 归港烟玉 |
| `src/resources/items/item_flower_bouquet.tres` | TRES | 花束 |
| `src/resources/items/item_old_book.tres` | TRES | 旧书 |
| `src/resources/items/item_ship_model.tres` | TRES | 船模 |
| `src/resources/items/item_sea_chart.tres` | TRES | 海图 |
| `src/resources/items/item_repair_kit.tres` | TRES | 修理工具包 |

## 代码规范

- GDScript 缩进使用 4 空格
- 物品ID使用 snake_case
- 类名使用 PascalCase
- 信号命名使用 snake_case

## 待后续完善

1. **装备系统**: `EQUIPMENT` 类型物品尚未实现装备/穿戴逻辑
2. **礼物赠送UI**: 目前礼物直接增加好感，没有伙伴选择界面
3. **物品图标**: 当前使用 emoji，后续需要替换为实际美术资源
4. **HUD集成**: 背包入口目前仅在商店内，后续可在主HUD添加快捷入口
