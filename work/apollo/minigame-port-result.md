# 小游戏系统接入港口场景 - 结果报告

**执行者**: Apollo (Godot 开发)
**日期**: 2026-04-30
**状态**: ✅ 完成

## 变更概述

将4个已实现的小游戏系统接入港口酒馆场景，玩家可在酒馆中直接进入小游戏。

## 变更内容

### 1. 新增小游戏场景文件

创建 `src/scenes/minigames/` 目录，包含4个场景占位符：

- `BoilerDice.tscn` — 锅炉骰子场景
- `CannonPractice.tscn` — 炮术射击场景
- `GearPuzzle.tscn` — 齿轮拼图场景
- `SeabirdRace.tscn` — 海鸟赛跑场景

每个场景：
- Control 根节点 + 对应 `.gd` 脚本
- 内置「← 返回港口」按钮

### 2. 修改 PortScene.gd

**酒馆面板添加小游戏入口** (`_create_tavern_panel`)：
- 新增「小游戏」分区
- 4个按钮：🎲骰子挑战 / 💣炮术挑战 / ⚙️齿轮挑战 / 🐦海鸟竞猜

**新增 `_on_minigame_pressed(game_id: String)`**：
- 根据 game_id 加载对应 `.tscn`
- 实例化并添加到根节点
- 连接返回按钮和 `minigame_finished` 信号

**新增 `_on_minigame_finished(game_id: String, result: Dictionary)`**：
- BoilerDice: 发放 `gold_change` 金币
- CannonPractice: 发放 `gold_bonus` 金币
- GearPuzzle: 解锁成功则发放 `gold_change`
- SeabirdRace: 发放 `gold_change`（赢家）

**新增 `_return_to_port()`**：
- 清理小游戏节点
- 恢复港口概览

### 3. 小游戏完成奖励逻辑

| 小游戏 | 成功条件 | 奖励 |
|--------|---------|------|
| BoilerDice | 任意完成 | score × bet / 10 金币 |
| CannonPractice | 任意完成 | 命中率 tier 对应 gold_bonus |
| GearPuzzle | 15步内解谜 | 50 金币 |
| SeabirdRace | 押注正确 | bet × odds 金币 |

## 文件变更

```
src/scenes/minigames/BoilerDice.tscn    [新建]
src/scenes/minigames/CannonPractice.tscn [新建]
src/scenes/minigames/GearPuzzle.tscn     [新建]
src/scenes/minigames/SeabirdRace.tscn    [新建]
src/scripts/ui/PortScene.gd             [修改]
```

## 待办 / 备注

- [ ] 小游戏场景 UI 填充（当前为占位符）
- [ ] BoilerDice 需要押注 UI（目前通过 start_game API 手动调用）
- [ ] CannonPractice 计时器 UI
- [ ] GearPuzzle 齿轮可视化
- [ ] SeabirdRace 赛道和鸟的动画
- [ ] `minigame_finished` 信号需在小游戏 UI 完成后由场景自行 emit
