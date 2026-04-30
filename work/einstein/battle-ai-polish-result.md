# Battle AI Polish Report

> **Agent:** Einstein  
> **Date:** 2026-04-30  
> **Status:** ✅ Completed  
> **Sprint:** Steam Breaker Sprint 3 — Battle AI Polish

---

## 1. Overview

完善敌方AI决策逻辑 + 添加行动延迟动画，让战斗更有节奏感。

---

## 2. Changes

### Enhanced `EnemyTurnState.gd`

| Feature | Implementation |
|---------|---------------|
| **普通敌人AI** | 基于射程环决策（近距攻击/远距接近/中距判断血量） |
| **状态效果视觉** | 回合开始时图标闪烁提示（烧伤🔥/减速❄️/混乱🌀等） |
| **行动延迟动画** | 决策0.5~0.8s / 移动0.7~1.1s / 攻击0.8~1.2s |
| **伤害数字显示** | FloatingText 浮动文字，普通伤害淡黄/暴击红色 |
| **Miss提示** | 显示"MISS"文字 |
| **部位选择优化** | 优先攻击锅炉/操舵室（降低敌人机动/闪避） |

### New `FloatingText.gd`

| Method | Description |
|--------|-------------|
| `show_damage(dmg, is_crit, pos)` | 伤害数字，暴击时字体放大+红色+更长存活 |
| `show_miss(pos)` | Miss灰色文字 |
| `show_status(name, color, pos)` | 状态效果图标+名称 |
| `show_message(msg, color, pos, lifetime)` | 通用提示消息 |

---

## 3. AI Decision Logic

### 普通敌人射程环决策

```
_ai_choose_ring():
  - 减速/过热 → 撤退远距(3)
  - 近距(1): 有武器→攻击, 无→退中距
  - 中距(2): 
    · 己方HP<30% → 撤退(3)
    · 敌方HP<30% → 冲近距(1)
    · 有远程武器 → 保持(2)
    · 否则随机(40%近/40%中/20%远)
  - 远距(3): 尝试接近中距(优先)
```

### 武器选择

```gdscript
# 综合评分 = 伤害 / max(1, 冷却时间)
# 优先高伤害+低冷却
```

### 部位攻击权重

```
锅炉25% > 船体40% > 操舵室15% > 特殊装置10% > 其他10%
（优先破坏敌人机动和闪避）
```

---

## 4. Animation Delays

| Action | Duration |
|--------|----------|
| 决策思考 | 0.5~0.8s (随机) |
| 移动 | 0.7~1.1s |
| 攻击 | 0.8~1.2s |
| 召唤/特殊 | 0.5~0.8s |

使用 `await get_tree().create_timer(delay).timeout` 实现，无需额外Timer节点。

---

## 5. FloatingText Usage

```gdscript
# 伤害
_create_floating_text().show_damage(dmg, is_crit, screen_pos)

# Miss
_create_floating_text().show_miss(screen_pos)

# 状态效果
_create_floating_text().show_status("火灾", Color.RED, screen_pos)
```

场景路径: `res://src/scripts/ui/FloatingText.gd`  
父节点: `get_tree().root`（保证在最上层渲染）

---

## 6. Status Effect Visual Hints

回合开始时 `enemy.refresh_for_turn()` 后，遍历 `status_effects` 字典：

| StatusType | Icon | Color |
|------------|------|-------|
| FIRE | 🔥 | `Color(1.0, 0.4, 0.1)` |
| FLOOD | 💧 | `Color(0.3, 0.6, 1.0)` |
| SLOW | ❄️ | `Color(0.5, 0.8, 1.0)` |
| DISORIENT | 🌀 | `Color(0.7, 0.5, 1.0)` |
| PARALYSIS | ⚡ | `Color(1.0, 0.9, 0.2)` |
| OVERHEAT | 🌡️ | `Color(1.0, 0.3, 0.0)` |
| STEALTH | 👻 | `Color(0.6, 0.6, 0.8)` |

---

## 7. Files Changed

| File | Change |
|------|--------|
| `src/scripts/battles/states/EnemyTurnState.gd` | ~600行重写，增强AI+动画 |
| `src/scripts/ui/FloatingText.gd` | 新建，浮动文字系统 |

---

## 8. Compliance

- [x] GDScript缩进4空格
- [x] 节点命名：大驼峰
- [x] 变量命名：小写下划线
- [x] 行动延迟0.5~1.2s范围
- [x] 伤害颜色区分：普通淡黄/暴击红色
- [x] 状态效果图标+颜色对应