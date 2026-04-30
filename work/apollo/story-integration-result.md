# 剧情进度追踪系统接入赏金 - 执行结果

**执行者**: Apollo (Godot 开发)
**日期**: 2026-04-30
**状态**: ✅ 完成

## 任务概述
将 StoryManager 接入 BountyManager，使赏金解锁受剧情进度控制。

## 变更内容

### 1. StoryManager.gd
- **状态**: 已存在且完整，无需创建
- 已有方法: `get_flag()`, `set_flag()`, `trigger_event()`, `advance_chapter()`, `get_save_data()`, `apply_save_data()`

### 2. project.godot Autoload
- **新增**: `StoryManager="*res://scripts/systems/StoryManager.gd"`
- 位置: 排在 BountyManager 之后

### 3. BountyManager.gd - _check_story_flag()
**修改前**:
```gdscript
func _check_story_flag(flag: String) -> bool:
    # TODO: 接入StoryManager检查剧情进度
    return true
```

**修改后**:
```gdscript
func _check_story_flag(flag: String) -> bool:
    if flag.is_empty():
        return true
    if not has_node("/root/StoryManager"):
        push_warning("[BountyManager] StoryManager not found, allowing bounty unlock")
        return true
    var sm = get_node("/root/StoryManager")
    return sm.get_flag(flag, false)
```

## Git
- Commit: `8f17cad`
- Branch: `main`
- 已推送到远程

## 使用方式
赏金数据中设置 `required_story_flag` 字段即可锁定剧情进度：
```gdscript
var bounty = {
    "bounty_id": "bounty_ghost_queen",
    "required_story_flag": "chapter_2_unlocked",  # 需先触发此flag
    ...
}
```
