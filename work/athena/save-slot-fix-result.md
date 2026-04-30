# Auto-save 槽位修复 + PartPickerPopup 验证报告

**执行者**: Athena (系统架构)  
**日期**: 2026-04-30  
**状态**: ✅ 完成

---

## Bug #10: Auto-save 槽位修复

### 问题
槽位 9 同时用于自动存档和手动存档列表中的可见槽位，导致用户可见存档数实际只有 9 个（0-8），且 auto-save 会覆盖用户的手动存档。

### 修复方案
使用槽位 `-1`（`AUTO_SAVE_SLOT`）表示自动存档（内部使用，不显示在存档列表中）。

### 修改文件
**`src/scripts/systems/SaveManager.gd`**

1. 新增常量 `AUTO_SAVE_SLOT := -1`
2. `auto_save()` 方法改用 `AUTO_SAVE_SLOT` 而非槽位 9
3. `save()` 方法放宽校验：`slot != AUTO_SAVE_SLOT and (slot < 0 or slot >= MAX_SAVE_SLOTS)`
4. `load()` 方法同样支持 `AUTO_SAVE_SLOT`
5. `list_saves()` 跳过 `AUTO_SAVE_SLOT`：
   ```gdscript
   if slot == AUTO_SAVE_SLOT:
       continue
   ```
6. 新增 `_ensure_auto_save_path()` 确保 `user://saves/auto/` 目录存在
7. `_get_save_path()` 为 `AUTO_SAVE_SLOT` 返回 `user://saves/auto/auto_save.json`
8. `_get_file_name()` 为 `AUTO_SAVE_SLOT` 返回 `auto_save.json`

### 结果
- 手动存档槽位 0-9 共 10 个全部保留给用户
- 自动存档写入独立路径 `user://saves/auto/auto_save.json`，不占用任何用户可见槽位
- `list_saves()` 正确跳过内部 auto-save

---

## Bug #9: PartPickerPopup 内部类验证

### 检查结果
`PartPickerPopup` 是 `ShipEditor.gd` 的**内部类**（嵌套类），通过以下方式使用：

```gdscript
func _show_part_picker(slot_type: String) -> void:
    var picker = PartPickerPopup.new()
    picker.part_type = slot_type
    picker.available_parts = _all_parts.get(slot_type, [])
    picker.part_selected.connect(_on_part_selected.bind(slot_type))
    get_tree().root.add_child(picker)
    picker.popup_centered(Vector2(400, 320))
```

**信号连接正确**：`picker.part_selected.connect(_on_part_selected.bind(slot_type))`

### Godot 4 内部类行为分析
Godot 4 的嵌套类（inner class）行为：
- ✅ `PartPickerPopup.new()` 可正常实例化
- ✅ 信号 `part_selected` 定义为 `signal part_selected(part: Resource)`
- ✅ `connect()` 绑定 lambda 可以正常工作
- ✅ 无需拆分为独立场景

### 结论
**PartPickerPopup 内部类实现无问题**，无需拆分为独立场景。信号连接正确，内部类实例化在 Godot 4 中正常工作。

---

## 提交
```
fix: use hidden auto-save slot + validate PartPickerPopup
```

修改文件：
- `src/scripts/systems/SaveManager.gd`
