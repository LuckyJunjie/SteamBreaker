# 协作scrum.md — Steam Breaker 开发

> 最后更新: 2026-04-30 13:50
> 模式: 独立团队模式（CEO 直接指派）
> Sprint 1-15 完成，Sprint 16 启动

## 角色与会话
- Team Manager: `jarvis`
- Godot 开发: `apollo`
- 战斗系统: `einstein`
- 系统架构: `athena`
- DevOps: `hermes`
- 工具/验证: `chiron`

## Spawn Enforcement
- 每个 subagent 只分配 1 个任务
- 只有 executor_spawned=true 时才能分配任务
- 禁止匿名 subagent
- ⚠️ 注意：Godot 4 禁止 class_name 与 autoload 同名，会导致冲突

---

## Sprint 16 — UI完善与存档验证（2026-04-30 13:50 完成）

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| hud-empire-ui | apollo | ✅ | HUD背包按钮+DialogueSystem+帝国债券UI |
| dialogue-json | chiron | ✅ | DialogueManager路径修复+铁砧/深蓝对话树 |
| save-flow | athena | ✅ | ShipEditor auto_save+存档字段验证 |

---

## Sprint 17 — 收尾与整合（2026-04-30 14:10 启动）

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| companion-skill-autoload | apollo | 🔄 执行中 | CompanionSkill注册+DialogueBox连接 |
| world-flow-fix | athena | 🔄 执行中 | WorldMap→Port路径+JSON格式统一 |
| project-audit | hermes | 🔄 执行中 | 项目统计+README更新 |

---

## Sprint 15 — 内容扩充（2026-04-30 11:03 完成）

| Task | Agent | 状态 | 产出 |
|------|-------|------|------|
| new-companions | apollo | ✅ | 贝索船长+磷火+对话树（commit 9293688） |
| inventory-system | einstein | ✅ | InventoryManager+ItemDatabase+6物品 |
| new-bounties | athena | ✅ | 巡逻舰+雷电龙+深渊者+帝国商店Tab（commit 267165d） |

**修复**: class_name冲突(GameItem/ItemDatabase/InventoryManager) → commit c58de40

---

## Sprint 11-14 完成汇总

| Sprint | 主要内容 |
|--------|---------|
| Sprint 11 | ShipEditor重写+战斗AI+存档+伙伴羁绊 |
| Sprint 12 | Critical bug修复（autoload缺失/战斗返回/ShipEditor） |
| Sprint 13 | Medium bug修复（初始金币/测试文件/auto-save槽位） |
| Sprint 14 | StoryManager+导出脚本+存档接口 |

**Godot 编译错误修复汇总**:
- class_name与autoload冲突（GameManager/CompanionManager/BountyManager/StoryManager/ItemDatabase/InventoryManager）
- ShipLoadout.duplicate() → duplicate_loadout()
- Resource.get()不接受default参数
- bounty.has() → 属性直接访问
- GameItem类型 → Resource类型

**Godot 验证**: 全部10个autoload初始化成功，0错误 ✅

---

## Sprint 6-10 历史

| Sprint | 内容 |
|--------|------|
| Sprint 10 | 战斗初始化链路修复 |
| Sprint 9 | 标题画面+港口面板 |
| Sprint 8 | 战斗流程打通 |
| Sprint 7 | 残留路径修复 |
| Sprint 6 | 路径修复与集成验证 |
