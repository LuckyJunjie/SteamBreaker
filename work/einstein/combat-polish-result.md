# 战斗状态效果完善 + 追击系统 — 完成报告

**执行者**: Einstein (战斗系统)
**日期**: 2026-04-30
**项目**: SteamBreaker

---

## 1. 追击系统（Follow-up Attack）

### CombatCalculator.gd — 新增静态方法
- `check_follow_up_attack(damaged_part: String) -> bool`：命中锅炉/操舵室返回 true
- `calc_follow_up_damage(base_damage: float) -> float`：返回基础伤害的 50%

### DamageResolveState.gd — 接入追击逻辑
- `_check_follow_up()`：遍历伤害事件，检测弱点命中
- `_execute_follow_up(evt)`：追加追击伤害事件（`is_follow_up: true`），并调用 `play_follow_up_effect`
- 追击伤害在 `_finish()` 时执行，不消耗行动（无冷却消耗）
- 添加 `_follow_up_triggered` 标记防止重复触发

---

## 2. 状态效果剩余回合显示

### StatusEffect.gd
- 已有 `duration_remaining` 属性（剩余回合数），无需修改

### HUD.gd — 新增状态效果图标 UI
- `_status_effect_icons: Dictionary`（ship_id → {eff_type → icon_panel}）
- `update_status_effects_ui(ship: ShipCombatData)`：外部调用刷新指定船只的状态图标
- `_create_status_icon()`：创建带边框的状态图标 + emoji + 回合数 "x3" 小标签
- `_get_status_emoji()` / `_get_status_color()`：根据状态类型返回对应 emoji 和边框颜色
- 图标定位在屏幕底部中央，按船只索引横向排列

---

## 3. 战斗速度选项

### HUD.gd — 加速按钮
- `animation_speed_multiplier: float`（默认 1.0，点击切换 2.0x）
- `setup_battle_speed_button()`：在 `_detect_battle_mode` 时自动创建
- `_toggle_battle_speed()`：按钮文本切换 "⏩ x1" / "⏩ x2"
- 位置：右上角，anchor_right=1.0，offset_right=-22

---

## 4. 战斗结束特殊效果

### BattleEndState.gd — 重构
- `_show_victory_panel(gold, items)`：胜利时弹出奖励面板（金币 + 物品列表），5秒后自动返回或等待点击
- `_show_game_over_panel()`：失败时弹出 Game Over 面板，提供「重新挑战」和「返回港口」两个按钮
- `_setup_return_timer(delay)`：延迟从 3 秒改为 5 秒，支持点击提前关闭
- `_on_victory_panel_clicked`：点击胜利面板可立即返回
- `_find_hud()`：安全查找 HUD 节点用于添加结算面板

### BattleManager.gd — 新增接口
- `play_follow_up_effect(target_id)`：追击特效（打印日志）
- `show_battle_end_ui(victory, loot)`：战斗结算 UI（打印日志）
- `get_battle_result()`：返回当前战斗结果

---

## 文件变更清单
| 文件 | 变更 |
|------|------|
| `src/scripts/battles/CombatCalculator.gd` | +`check_follow_up_attack`, +`calc_follow_up_damage` |
| `src/scripts/battles/states/DamageResolveState.gd` | +追击检测与执行逻辑 |
| `src/scripts/battles/states/BattleEndState.gd` | 重构胜利/失败结算，5秒延迟 |
| `src/scripts/battles/BattleManager.gd` | +追击特效、结算UI接口 |
| `src/scripts/ui/HUD.gd` | +战斗加速按钮、+状态效果图标UI |
