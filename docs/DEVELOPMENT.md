# 开发规范 — Steam Breaker

---

## 开发模式

**独立团队模式（CEO 直接指派）**

所有任务由 Master Jay（CEO）通过 Jarvis 分配，并发执行。

---

## 开发流程

### 1. 需求分析（Athena）
- 阅读 GDD.md
- 提炼技术方案
- 输出 `docs/TECH_DESIGN_<feature>.md`

### 2. 任务分配（Jarvis）
- 根据 Agent 专长分配任务
- 更新 `协作scrum.md`
- Spawn subagent 执行

### 3. 开发执行（各 Agent）
- 在 `work/<agent>/` 下创建任务目录
- 产出代码到 `src/`
- 完成后写 `work/<agent>/<task>-result.md`

### 4. 代码整合（Apollo）
- 审查并合并代码到 `src/`
- 确保无冲突

### 5. 同步推送（Hermes）
- Commit + Push 到 GitHub

---

## 代码规范

### Godot / GDScript
- 缩进：4空格
- 节点命名：大驼峰 `PlayerShip`
- 变量命名：小写下划线 `ship_health`
- 常量：全大写 `MAX_AMMO`

### 场景结构
```
res://
├── scenes/
│   ├── battles/
│   ├── worlds/
│   └── ui/
├── scripts/
│   ├── battles/
│   ├── systems/
│   └── ui/
├── resources/
│   ├── ships/
│   ├── items/
│   └── characters/
└── assets/
```

---

## Git 工作流

### 分支命名
- `feature/<功能名>`
- `fix/<问题名>`
- `hotfix/<紧急修复>`

### Commit 规范
```
<type>(<scope>): <描述>

type: feat | fix | docs | refactor | test
```

---

## 测试要求

- 每个功能模块需要有对应测试
- 使用 Godot 内置测试框架或 GUT
- 运行: `godot --headless --test`
