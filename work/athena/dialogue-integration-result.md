# 对话系统与伙伴羁绊集成结果

**执行者**: Athena (系统架构)
**日期**: 2026-04-30
**状态**: ✅ 完成

## 1. DialogueBox 场景创建

### `src/scenes/ui/DialogueBox.tscn`
- 底部对话框面板（anchors_preset = 15，固定在屏幕底部）
- 头像（TextureRect，根据伙伴着色）
- 名字标签（带背景装饰）
- 情绪标签（emoji 显示）
- RichTextLabel 对话文本
- VBoxContainer 选项按钮容器

### `src/scenes/ui/DialogueBox.gd`
- **打字机效果**: `_process()` 中实现，可跳过
- **选项按钮**: `_build_option_buttons()` 创建，点击触发 `option_selected` 信号
- **输入处理**: 空格/回车/ESC/点击 推进对话；打字过程中跳过打字机
- **信号**: `dialogue_ended`、`option_selected(option_index, option_text)`
- **公开API**: `show_dialogue(speaker, text, mood, options, portrait_color)`

## 2. CompanionPanel 对话集成

### 更新 `src/scripts/ui/CompanionPanel.gd`

新增方法：
- `set_dialogue_manager(dm)` — 注入 DialogueManager 引用
- `set_dialogue_box(box)` — 注入 DialogueBox UI 引用
- `set_bond_event_manager(bem)` — 注入 BondEventManager 引用

信号连接：
- `DialogueManager.dialogue_started` → `_on_dialogue_started()`
- `DialogueManager.dialogue_option_selected` → `_on_dialogue_option_selected()`
- `DialogueManager.dialogue_ended` → `_on_dialogue_finished()`
- `DialogueBox.option_selected` → `_on_dialogue_option_selected_ui()`
- `DialogueBox.dialogue_ended` → `_on_dialogue_ui_ended()`

对话流程：
1. `_on_dialogue_pressed()` → `DialogueManager.start_dialogue(companion_state, "bond_talk_" + id)`
2. `_on_dialogue_started()` → `DialogueBox.show_dialogue(...)`
3. 用户选择选项 → `DialogueBox.option_selected` → `_on_dialogue_option_selected_ui()`
4. `_on_dialogue_finished()` → `BondEventManager.trigger_bond_event(..., "dialogue_option", ...)`

## 3. DialogueManager 完善

### 参数类型改为 `Variant`
`start_dialogue()` 现在接受 `Companion` 或 `CompanionManager.CompanionState`，内部统一通过 `has_method("get_companion_id")` 判断。

### 新增 `_load_dialogue_tree()` & `_load_dialogue_trees_from_files()`
- `_load_dialogue_trees_from_files()` 在 `_ready()` 中尝试加载 `res://resources/dialogues/companion_*.json`
- `_load_dialogue_tree(dialogue_id, tree_data)` 注册单个对话树
- `_merge_dialogue_tree(data)` 批量合并（会覆盖硬编码数据）

### JSON 格式（`res://resources/dialogues/`）
```json
{
  "bond_talk_keerli_sample": [
    {
      "speaker": "珂尔莉",
      "text": "……有事？",
      "options": [
        {"text": "想找你聊聊。", "next": "bond_talk_keerli_1", "affection": 1}
      ]
    }
  ]
}
```

## 4. 基础对话内容

为 3 个伙伴各添加 3 段基础对话 + 1 个入口节点：

| 对话ID | 伙伴 | 选项数 | 备注 |
|--------|------|--------|------|
| `bond_talk_keerli` | 珂尔莉 | 3入口→分支 | 傲娇鸟族 |
| `bond_talk_keerli_1/2/3` | 珂尔莉 | 2-3 | 关于飞行/天空/羽毛 |
| `bond_talk_tiechan` | 铁砧 | 3入口→分支 | 机械改造人 |
| `bond_talk_tiechan_1/2/3` | 铁砧 | 2-3 | 关于保养/钢铁/齿轮礼物 |
| `bond_talk_shenlan` | 深蓝 | 3入口→分支 | 鱼人 |
| `bond_talk_shenlan_1/2/3` | 深蓝 | 2-3 | 关于海/云/深海的梦 |

## 5. BondEvent 触发

对话结束后，`_on_dialogue_finished()` 调用：
```gdscript
BondEventManager.trigger_bond_event(
    companion_state,
    "dialogue_option",
    {"affection_delta": affection_delta}
)
```
自动触发好感度更新、等级检测和羁绊支线任务检查。

## 文件清单

| 文件 | 变更 |
|------|------|
| `src/scenes/ui/DialogueBox.tscn` | 新增 |
| `src/scenes/ui/DialogueBox.gd` | 新增 |
| `src/scripts/systems/DialogueManager.gd` | 修改：Variant参数、bond_talk、JSON加载 |
| `src/scripts/ui/CompanionPanel.gd` | 修改：对话集成、BondEvent触发 |
| `src/resources/dialogues/companion_keerli_dialogues.json` | 新增（示例格式）|
| `work/athena/dialogue-integration-result.md` | 新增 |

## 待办 / 后续

1. **DialogueBox 实例化**: HUD 或游戏主场景需要在合适时机 `add_child(dialogue_box_instance)` 并调用 `CompanionPanel.set_dialogue_box()`
2. **CompanionState 访问**: `CompanionPanel._get_companion_state()` 依赖 `CompanionManager.get_companion_state()` 方法，如不存在需在 CompanionManager 中添加
3. **更多对话内容**: JSON 文件可扩展更多分支，无需修改代码
4. **打字机音效**: 可在 `DialogueBox._process()` 中加入字符播放音效
