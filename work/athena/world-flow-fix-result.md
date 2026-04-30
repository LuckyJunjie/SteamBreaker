# WorldMap → Port 流程 + 对话JSON格式统一 结果报告

**执行者**: Athena (系统架构)
**日期**: 2026-04-30
**项目**: SteamBreaker

---

## 1. WorldMapUI → PortScene 流程验证 ✅

### 流程链路
```
WorldMapUI._on_port_clicked(port_id)
  → GameManager.sail_to_port(port_id)
    → set_current_port(port_id)
    → roll_sea_encounter()
    → change_scene_to_port(port_id)     ← 正确
      → _change_to_scene("res://scenes/worlds/PortScene.tscn")
```

### 验证结果
- `sail_to_port()` 正确调用 `change_scene_to_port(port_id)` ✅
- `change_scene_to_port()` 使用正确路径 `res://scenes/worlds/PortScene.tscn` ✅
- 流程包含随机遭遇判定（敌舰/悬赏/风暴触发战斗，其他直接进港）✅
- 港口解锁检查正确（未解锁时提前 return）✅

**结论**: 流程实现正确，无需修改。

---

## 2. 场景路径修复 ✅

### 检查结果
- `project.godot` 位于 `src/` 目录下
- 所有 `change_scene_to_file()` 调用均使用 `res://scenes/...` 格式 ✅
- 没有发现 `res://src/scenes/` 路径 ✅

### 具体路径（GameManager.gd）
| 方法 | 路径 | 状态 |
|------|------|------|
| `change_scene_to_port()` | `res://scenes/worlds/PortScene.tscn` | ✅ |
| `change_scene_to_world_map()` | `res://scenes/worlds/WorldMap.tscn` | ✅ |
| `change_scene_to_battle()` | `res://scenes/battles/Battle.tscn` | ✅ |

**结论**: 路径已统一正确，无须修复。

---

## 3. 对话JSON格式统一 ✅

### 问题诊断
现有 JSON 文件格式：
```json
{
  "bond_talk_tiechan_0": [
    {
      "speaker": "铁砧",
      "text": "……船上的零件检查完了。",
      "options": [
        {"text": "辛苦了", "next": "tiechan_rest", "affection": 2}
      ]
    }
  ]
}
```

DialogueManager 内部格式期望：
```json
{
  "companion_id": "companion_tiechan",
  "speaker_name": "铁砧",
  "mood": "neutral",
  "text": "……船上的零件检查完了。",
  "options": [
    {"text": "辛苦了", "next_dialogue": "tiechan_rest", "affection_delta": 2}
  ]
}
```

### 字段映射问题
| JSON 字段 | DialogueManager 字段 | 状态 |
|-----------|---------------------|------|
| `speaker` | `speaker_name` | ❌ 需映射 |
| `next` | `next_dialogue` | ❌ 需映射 |
| `affection` | `affection_delta` | ❌ 需映射 |
| `mood` | `mood` | ⚠️ JSON 缺少，默认 neutral |
| 数组格式 | 字典格式 | ❌ 需展平 |

### 修复方案
在 `DialogueManager.gd` 中新增：
- `_load_json_dialogue_tree(data, companion_id)` — 处理 JSON 树加载
- `_normalize_dialogue_entry(entry, companion_id, default_id)` — 字段名转换 + 格式标准化

支持两种 JSON 结构：
1. **数组格式**（当前使用）: `"bond_talk_xxx": [{...}]` — 每个 key 对应一个对话数组，展平为独立条目
2. **字典格式**（兼容）: `"bond_talk_xxx": {...}` — 直接合并

### 额外字段透传
JSON 中的 `unlock_bond`、`is_correct`、`is_special`、`dislike_triggered`、`reward` 等可选字段均正确透传到选项字典。

### 修改文件
- `src/scripts/systems/DialogueManager.gd` (`_load_dialogue_trees_from_files` → `_load_json_dialogue_tree`)

---

## 总结

| 检查项 | 状态 | 说明 |
|--------|------|------|
| WorldMap → Port 流程 | ✅ | 流程正确，`sail_to_port()` 正确调用 |
| 场景路径 | ✅ | 全部使用 `res://scenes/`，无 `res://src/scenes/` |
| DialogueManager JSON 加载 | ✅ 已修复 | 新增格式转换函数，支持现有 JSON 格式 |

---

## 下一步建议
1. 验证 JSON 对话加载：运行时检查日志 `[DialogueManager] Loaded dialogue tree from: ...`
2. 测试 `CompanionPanel` 触发 `bond_talk_*` 对话，确认选项和好感度正确
3. 可选：统一 JSON 文件 key 命名（去掉 `_0`、`_sample` 后缀），与代码期望的 `bond_talk_{companion}` 入口 key 对齐
