# AGENTS.md — Steam Breaker 开发团队

> 本项目采用独立团队开发模式（CEO 直接指派）。
> 所有 Agent 通过 OpenClaw spawn，汇报至「福渊研发部」飞书群。

---

## 团队角色

| Agent | 角色 | 职责范围 |
|-------|------|----------|
| **Hermes** | DevOps / Git 管理 | 代码同步、仓库管理、CI/CD |
| **Athena** | 系统架构 / 需求 | 技术设计、API 规范、需求分析 |
| **Apollo** | Godot 主开发 | 游戏核心玩法、场景、UI |
| **Einstein** | 战斗系统 / AI | 回合战斗、AI 敌人、状态机 |
| **Chiron** | 工具 / 验证 | 内部工具、测试、验证脚本 |

---

## 每人同时最多 1 个任务

- 每个 subagent 只分配 **1 个任务**
- 只有 `executor_spawned=true` 时才能分配新任务
- 禁止匿名 subagent

---

## 开发流程

1. **需求确认** → Athena 分析 GDD，提炼技术方案
2. **任务分配** → Jarvis 根据 Agent 专长分配任务
3. **开发执行** → Agent 在 `work/<agent>/` 下产出
4. **审查合并** → Hermes 同步到 Git，主线代码由 Apollo 整合
5. **进度汇报** → Jarvis 向「福渊研发部」飞书群汇报

---

## DoD（完成定义）

- ✅ 代码完成
- ✅ 通过单元测试（存在测试用例）
- ✅ 文档更新（API / 设计文档）
- ✅ `work/<agent>/<task>-result.md` 产出

---

## 项目根目录

```
/Users/jay/.openclaw/workspace/smart-factory/SteamBreaker/
```

## Git 仓库

- **远程**: `https://github.com/LuckyJunjie/SteamBreaker.git`
- **分支**: `main`

---

## 技术栈

- **引擎**: Godot 4.x
- **语言**: GDScript / C#
- **版本控制**: Git
- **文档**: Markdown
