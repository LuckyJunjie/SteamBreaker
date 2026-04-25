# 协作scrum.md — Steam Breaker 开发

> 最后更新: 2026-04-25
> 模式: 独立团队模式（CEO 直接指派）
> Sprint 0 启动

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

## 当前 Sprint

### Sprint 0 — 项目初始化（2026-04-25）
- [x] 创建项目结构
- [x] 添加 GDD.md
- [x] 添加 AGENTS.md
- [x] 添加 README.md
- [ ] 创建 GitHub 仓库
- [ ] 推送初始代码

---

## 阶段一：原型开发

### 目标
核心船只移动、DIY基础界面、简单回合战斗

### 任务池
| Task | Agent | 状态 | 依赖 |
|------|-------|------|------|
| 项目初始化 | hermes | 待分配 | - |
| Godot 项目配置 | apollo | 待分配 | - |
| 船只基础场景 | apollo | 待分配 | Godot项目 |
| 战斗系统框架 | einstein | 待分配 | - |
| 射程环UI | apollo | 待分配 | 战斗系统 |
