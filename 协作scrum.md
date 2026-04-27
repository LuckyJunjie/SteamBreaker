# 协作scrum.md — Steam Breaker 开发

> 最后更新: 2026-04-25
> 模式: 独立团队模式（CEO 直接指派）
> Sprint 1-3 完成，Sprint 4 启动

## 角色与会话
- Team Manager: `jarvis`
- Godot 开发: `apollo`
- 战斗系统: `einstein`
- 系统架构: `athena`
- DevOps: `hermes`

## Spawn Enforcement
- 每个 subagent 只分配 1 个任务
- 只有 executor_spawned=true 时才能分配任务
- 禁止匿名 subagent

## Sprint 1 完成（14:08）

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| godot-init | apollo | ✅ 完成 | 14个文件（场景/脚本/资源） |
| battle-system-design | einstein | ✅ 完成 | docs/SUBSYSTEMS_BATTLE.md |
| tech-architecture | athena | ✅ 完成 | docs/TECH_ARCHITECTURE.md + 19个.tres |

---

## Sprint 2 — 原型完善（2026-04-25 14:26 启动）

**目标**: 改装界面 + 战斗系统实现 + 港口场景

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| ship-editor-ui | apollo | ✅ 完成 | ShipEditor.gd + 8个resource脚本 |
| battle-implementation | einstein | ✅ 完成 | 10状态类 + CombatCalculator + WeaponData + ShipCombatData |
| port-scene | apollo | 🔄 待执行 | 港口场景交互（酒馆/船坞/公会/商店） |
| git-sync | hermes | ✅ 完成 | GitHub 已同步，SHA: 32e0b02 |

---

## Sprint 3 — 原型可玩（2026-04-25 14:40 启动）

**目标**: 港口场景 + 赏金系统UI + 存档系统 + 基础导航

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| port-scene-ui | apollo | ✅ 完成 | PortScene.gd + ShopUI.gd + BountyBoardUI.gd |
| bounty-board-ui | einstein | ✅ 完成 | BountyManager.gd + 赏金AI机制 |
| save-system | athena | ✅ 完成 | SaveData.gd + SaveManager.gd + SaveLoadUI.gd |
| world-navigation | apollo | 🔴 未完成 | World场景 + 港口切换 + 海域漫游 |

---

## Sprint 4 — 系统集成（2026-04-25 15:02 完成）

**目标**: 完善缺失系统 + 系统集成

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| world-navigation | apollo | ✅ 完成 | GameManager + WorldMapUI |
| autoload-setup | athena | ✅ 完成 | GameState + ResourceCache + CompanionManager |
| companion-system | einstein | ✅ 完成 | CompanionSkill + BondEvent + DialogueManager |
| integration-test | chiron | ✅ 完成 | 57个测试用例，6个critical bug发现 |

---

## Sprint 5 — 问题修复与缺失实现（2026-04-25 15:50 启动）

**基于代码审查发现的6个Critical + 4个Medium问题**

### Critical 问题（阻塞）

| # | 问题 | 原因 | 修复方案 | Agent |
|---|------|------|----------|-------|
| C1 | .tres资源脚本路径错误 | script path 不一致 | 更新所有.tres的script path | apollo |
| C2 | BattleManager缺少接口 | 状态机依赖的方法缺失 | 补充get_player_ship/get_enemy_by_id等 | einstein |
| C3 | CompanionManager不存在 | Sprint4发现时已实现 | 验证对接正确性 | athena |
| C4 | BountyManager赏金结算断裂 | 缺kill判定和奖励发放对接 | 修复BattleManager↔BountyManager | einstein |
| C5 | SaveManager存档接口缺失 | 跨系统调用方法不存在 | 完善SaveData序列化 | athena |
| C6 | 小游戏系统未实现 | 完全没有代码 | 实现锅炉骰子/海鸟赛跑/炮术射击/齿轮拼图 | athena |

### Medium 问题

| # | 问题 | 修复方案 | Agent |
|---|------|----------|-------|
| M1 | ShipFactory路径不一致 | 统一Resource路径引用 | apollo |
| M2 | .tres的script path不一致 | 统一为res://src/scripts/resources/ | apollo |
| M3 | 拖拽交互不完整 | ShipEditor完善拖拽 | apollo |
| M4 | 测试Gut框架依赖 | 确认Gut安装或使用替代方案 | chiron |

### Sprint 5 任务分配

| Agent | Session | 任务 |
|-------|---------|------|
| apollo | 381e81bb | 修复资源路径 + 拖拽交互 |
| einstein | ea16b40a | 修复战斗系统 + 赏金对接 |
| athena | 06aa5ade | 修复存档 + 实现小游戏 |
| chiron | db0b1495 | 验证修复 + 剧情系统 |

---
