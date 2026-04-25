# ShipEditor 实现报告

**负责人**: Apollo  
**日期**: 2026-04-25  
**任务**: 船只改装界面（ShipEditor）  
**状态**: ✅ 完成

---

## 实现内容

### 1. 资源脚本（`src/scripts/resources/`）

| 文件 | 说明 |
|------|------|
| `ship_part.gd` | 部件基类 `ShipPart` |
| `ship_boiler.gd` | 锅炉部件，含 `speed_bonus`、`overheat_threshold`、`maneuver_power` |
| `ship_helm.gd` | 操舵室部件，含 `turn_bonus`、`intercept_bonus`、`skill_slots` |
| `ship_weapon.gd` | 主炮，含 `damage`、`range`、`overheat_cost`、`armor_pierce` |
| `ship_secondary.gd` | 副炮，含 `intercept_power`、`focus_max` |
| `ship_special.gd` | 特殊装置，含 `skill_id`、`cooldown`、`effect_value` |
| `ship_loadout.gd` | 船只配置，含总重量/载重/超载检查、属性预览计算 |

### 2. ShipHull.gd 扩展（`src/scripts/systems/ShipHull.gd`）

原有脚本新增了改装系统所需字段：
- `part_id`、`part_name`、`part_type`、`weight`、`price`、`description`
- `cargo_capacity`、`weapon_slot_main`、`weapon_slot_sub`、`defense_bonus`、`special_tags`

### 3. 部件 .tres 路径修复

所有部件资源文件从错误的 `res://src/scripts/resources/` 修正为 `res://scripts/resources/`：

| 文件 | 修复前 | 修复后 |
|------|--------|--------|
| `hull_scout.tres` | `res://src/scripts/resources/ship_hull.gd` | `res://scripts/resources/ship_hull.gd` |
| `hull_ironclad.tres` | 同上 | 同上 |
| `boiler_*.tres` (×2) | `ship_boiler.gd` 路径修正 | 同上 |
| `helm_*.tres` (×2) | `ship_helm.gd` 路径修正 | 同上 |
| `weapon_*.tres` (×2) | `ship_weapon.gd` 路径修正 | 同上 |
| `secondary_gatling.tres` | `ship_secondary.gd` 路径修正 | 同上 |
| `special_ramming.tres` | `ship_special.gd` 路径修正 | 同上 |
| `ship_loadout_starter.tres` | `ship_loadout.gd` 路径修正 | 同上 |

### 4. ShipEditor.tscn（`src/scenes/ui/ShipEditor.tscn`）

界面布局：
- **左侧**（HSplit左侧，480px）：船只预览区，含船名Label + 大型图标Label（⚓/🚤/⚔️）
- **右侧**（HSplit右侧）：可滚动槽位列表，每个槽位含名称、当前部件、选择按钮、卸下按钮
- **下方**：重量进度条 + 耐久/航速/转向预览 + 确认/取消按钮

槽位顺序：船体 → 锅炉 → 操舵室 → 主炮 → 副炮 → 特殊装置

### 5. ShipEditor.gd（`src/scripts/ui/ShipEditor.gd`）

主要功能：
- `set_loadout(loadout)` — 外部设置当前船只配置
- `_scan_available_parts()` — 启动时扫描 `res://resources/parts/` 下所有部件
- `_show_part_picker(slot_type)` — 弹出 `PartPickerPopup`（内嵌类）选择部件
- `_install_part_to_slot(part, slot_type)` — 安装部件到对应槽位
- `_remove_part_from_slot(slot_type)` — 卸下槽位部件
- `_update_stats()` — 实时更新重量条、耐久、航速、转向预览
- 超载时进度条变红，航速显示⚠️警告

**信号**：
- `loadout_changed(loadout)` — 配置变化时发出
- `editor_confirmed(loadout)` — 确认改装
- `editor_cancelled()` — 取消

**内嵌 `PartPickerPopup`**：弹窗式部件选择器，显示所有可用部件的名称/重量/价格。

### 6. 数据联动

- `ShipLoadout.get_total_weight()` — 累加所有槽位部件重量
- `ShipLoadout.get_cargo_capacity()` — 读取船体 `cargo_capacity`
- `ShipLoadout.is_overloaded()` — 重量 > 载重时触发超载惩罚
- `ShipLoadout.get_speed_bonus()` — 超载时航速降至30%
- `ShipLoadout.duplicate()` — 用于预览（不污染原配置）

---

## 文件清单

```
src/scripts/resources/ship_part.gd       [新建]
src/scripts/resources/ship_boiler.gd     [新建]
src/scripts/resources/ship_helm.gd        [新建]
src/scripts/resources/ship_weapon.gd      [新建]
src/scripts/resources/ship_secondary.gd  [新建]
src/scripts/resources/ship_special.gd     [新建]
src/scripts/resources/ship_loadout.gd     [新建]
src/scripts/resources/ship_hull.gd        [新建，resources/专用脚本]
src/scripts/systems/ShipHull.gd           [更新，新增改装字段]
src/scenes/ui/ShipEditor.tscn             [更新，重写布局]
src/scripts/ui/ShipEditor.gd              [新建]
work/apollo/ship-editor-result.md         [本报告]
```

---

## 使用方式

```gdscript
# 在其他场景中打开改装界面
var editor = preload("res://scenes/ui/ShipEditor.tscn").instantiate()
get_tree().root.add_child(editor)
editor.set_loadout(current_ship_loadout)
editor.editor_confirmed.connect(_on_editor_confirmed)
editor.editor_cancelled.connect(_on_editor_cancelled)

func _on_editor_confirmed(loadout: ShipLoadout):
    current_ship_loadout = loadout
    # 调用 ShipFactory 更新船只属性
```

---

## 后续建议

1. **ShipFactory 集成**：创建 `ShipFactory.update_from_loadout(ship_entity, loadout)` 方法
2. **拖拽支持**：当前为点击选择，可扩展 `DragDrop` 区支持拖拽
3. **预览开关**（试航模拟）：`ShipLoadout` 已有 `duplicate()`，可追加模拟战斗UI
4. **武器槽位数量限制**：按 `hull.weapon_slot_main` 动态生成多行武器槽
5. **存档联动**：ShipLoadout 已有完整字段，可直接通过 `ResourceSaver` 序列化
