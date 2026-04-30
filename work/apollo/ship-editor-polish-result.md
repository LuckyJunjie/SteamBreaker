# ShipEditor 拖拽交互完善 - 结果报告

**执行者**: Apollo
**日期**: 2026-04-30
**修改文件**: `src/scripts/ui/ShipEditor.gd`, `src/scenes/ui/ShipEditor.tscn`

---

## 1. 装备列表拖拽 (`_get_drag_data` 完善)

- `_all_parts` 字典从 `res://resources/parts/` 扫描可用装备，按 slot_type 分类
- 商店/装备列表 (`ShopVBox`) 每行控件携带 `part` 和 `slot_type` meta
- `_get_drag_data` 检测拖拽源：槽位当前装备 或 商店装备列表
- 跳过自身装备（不允许把已装装备拖到同槽位）
- 拖拽返回 `{"part": part, "slot_type": slot_type}` 字典

---

## 2. 槽位放置目标 (`_can_drop_data` / `_drop_data` 实现)

- `_can_drop_data`: 检查 data 含 part/slot_type，且目标槽位类型匹配
- `_drop_data`:
  - 更新 `_preview_loadout` 而非直接修改
  - 调用 `_refresh_ui()` 刷新全量UI
  - 调用 `_update_cost_diff()` 更新差价显示
  - 触发 `preview_updated` 信号

---

## 3. 购买确认流程

- `_cost_diff = calculate_cost_diff()`: 预览配置总价 - 当前配置总价
  - `calculate_cost_diff()`: 公开方法，外部可调用
  - `_calc_total_parts_cost()`: 遍历所有槽位部件累加 price 字段
- `_update_cost_diff()`:
  - 显示"需支付/可回收/无需费用"
  - `_player_gold < _cost_diff` 时：消息提示"金币不足"，`ConfirmBtn` 置灰
- `_on_confirm_pressed()`:
  - 二次金币检查
  - `GameState.spend_gold(_cost_diff)` 扣除（退款场景不触发）
  - `GameState.player_ship.apply_loadout(_preview_loadout)` 应用配置
  - `ShipFactory.apply_loadout(_preview_loadout)` 同步
  - 触发 `editor_confirmed` 和 `loadout_changed` 信号

---

## 4. 右键卸下装备

- `_gui_input`: 右键点击槽位区域触发 `_show_slot_context_menu`
- `_show_slot_context_menu`: PopupMenu 显示"卸下 [装备名]" / "替换 [装备名]"
- `SLOT_ACTION_REMOVE`: `_remove_part_from_slot` → `_refresh_ui` → `_update_cost_diff`
- `SLOT_ACTION_REPLACE`: 打开 PartPickerPopup
- 当前装备标签 `current_lbl.gui_event` 也接收右键事件

---

## 5. 属性预览面板 & 差值高亮

- 底部 `StatsSection` 新增:
  - `FirepowerPreview`: 火力（主炮 + 副炮/2）
  - `LoadPreview`: 载重绝对值
- 左侧 `DiffPanel` 新增差值标签:
  - `DiffHP`, `DiffSpeed`, `DiffTurn`, `DiffFirepower`, `DiffLoad`
- `_calc_diff()`: 返回 `{hp, speed, turn, firepower, load}` 各属性差值
- `_set_diff_label()`:
  - `+N` 绿色（提升 / 载重减少）
  - `-N` 红色（下降 / 载重增加）
  - 空字符串（无变化）
- `_update_diff_display()` 在每次 `_refresh_ui` 时调用

---

## 6. 商店/装备列表内联面板

- `ShopVBox` 节点：显示所有可用装备，按槽位类型分组
- 每行: `[装备名] [重量] [价格] [装上按钮]`
- 行控件携带 `part` meta，支持直接拖拽到槽位
- "装上"按钮直接调用 `_install_part_to_slot`

---

## 新增信号

- `preview_updated(preview: ShipLoadout, diff: Dictionary)`: 每次预览配置变化时触发

---

## 代码规范遵守

- GDScript 缩进 4 空格 ✓
- 节点命名：大驼峰 `PartPickerPopup`, `ShopVBox`, `DiffHP` ✓
- 变量命名：小写下划线 `current_loadout`, `preview_loadout`, `cost_diff` ✓
- 常量：全大写 `SLOT_TYPE_ORDER`, `SLOT_TYPE_LABELS` ✓
