# Steam Breaker 资源清单 (Assets Map)

> 本文档定义 Steam Breaker 游戏所需的所有美术资源，包含用途、描述、类型和 AI 生成提示词。
> 生成时请严格按 prompt 描述执行，确保风格统一（蒸汽朋克+航海+日式动画风格）。

---

## 一、角色立绘 (Character Portraits)

### 1.1 伙伴立绘 (Companion Portraits)

| ID | 名称 | 种族 | 用途 | 描述 |
|----|------|------|------|------|
| char_keerli | 珂尔莉 | 鸟族 | 瞭望手/狙击手 | 傲娇但怕雷声，寻找失踪的飞行舰队 |
| char_tiechan | 铁砧 | 机械改造人 | 轮机长/修理师 | 沉默寡言，嗜喝机油，找回被洗掉的记忆 |
| char_shenlan | 深蓝 | 鱼人 | 导航员/潜航士 | 内向，能与鱼群对话，阻止帝国污染故乡海沟 |
| char_beisuo | 贝索船长 | 人类 | 炮术长/老兵 | 酒鬼，爱讲旧事，与昔日叛徒决斗 |
| char_linhuo | 磷火 | 珊瑚精 | 医疗/炼金 | 天真但拥有毒素，寻找"生命之核"进化 |

**Prompt 模板**：
```
[角色名] portrait for steampunk naval RPG game.
Style: Japanese anime art with Victorian industrial elements.
Character features: [详细描述].
Background: Rusted iron port with steam and gears.
Color palette: Rust red, copper green, fog gray, steel blue accent.
Expression: [表情].
High quality, detailed, game-ready sprite sheet.
```

**示例 - 珂尔莉**：
```
Bird-winged female ranger portrait for steampunk naval RPG game.
Style: Japanese anime art with Victorian industrial elements.
Character features: Young bird-woman with large bird wings, silver hair in braided ponytail,傲娇 expression, wearing leather aviator coat with gear buttons, brass binoculars hanging from belt, damaged feathered cape.
Background: Rusted iron port with steam and gears, foggy sky.
Color palette: Rust red, copper green, fog gray, steel blue accent.
Expression: 傲娇 smirk but with slight vulnerability in eyes.
High quality, detailed, game-ready portrait, 512x512.
```

---

### 1.2 NPC 立绘 (NPC Portraits)

| ID | 名称 | 用途 | 描述 |
|----|------|------|------|
| npc_old_fisherman | 老渔夫 | 铁锈湾港口NPC | 初始村铁锈湾的老渔夫，救过玩家 |
| npc_tavern_keeper | 酒馆老板 | 沉锚酒馆老板 | 独臂海盗出身，热情豪爽 |
| npc_bounty_clerk | 赏金公会职员 | 赏金公会NPC | 戴着单片眼镜的官僚 |
| npc_shipwright | 船坞工匠 | 船坞NPC | 浑身油污的机械师 |
| npc_imperial_officer | 帝国女军官 | 剧情NPC | 神秘帝国女军官，调查大沸腾遗迹 |

---

## 二、船只精灵 (Ship Sprites)

### 2.1 玩家船只 (Player Ships)

| ID | 名称 | 类型 | 用途 | 描述 |
|----|------|------|------|------|
| ship_steam_breaker | 蒸汽破浪号 | 初始船 | 玩家初始船只 | 破旧的二手蒸汽船，玩家起点 |
| ship_scout | 侦察艇 | 船体 | 高速侦查用 | 轻量化船体，高闪避 |
| ship_ironclad | 铁甲战列舰 | 船体 | 重装战斗用 | 高耐久，高载重 |
| ship_submarine | 潜水艇 | 船体 | 深海探索用 | 可下潜，特殊战斗场景 |
| ship_gyro_steamer | 陀螺仪蒸汽船 | 改装参考 | 改装后外观示例 | 改装后的平衡型船只 |

**Prompt 模板**：
```
Steampunk sailing ship sprite for turn-based RPG game.
Style: Victorian ironclad warship with exposed brass pipes and gears.
Design: [详细描述船体结构].
View: Top-down 2D sprite, 256x256 canvas.
Details: Smokestacks with steam effects, rivets on hull, rotating turrets.
Color palette: Rust red, tarnished brass, sea-worn steel, coal smoke gray.
Animated: Idle steam puffing animation frames (optional).
High quality pixel art style.
```

### 2.2 敌方船只 (Enemy Ships)

| ID | 名称 | 用途 | 描述 |
|----|------|------|------|
| enemy_irontooth_shark | 铁牙独眼鲨 | 赏金首 | 装备铁制下颚的巨大鲨鱼（非船） |
| enemy_ghost_queen | 幽灵船悔恨女王 | 赏金首 | 无人幽灵船，亡灵罗盘所在 |
| enemy_black_furnace | 黑炉战舰 | 赏金首 | 雷钢战列舰，旧帝国将军座舰 |
| enemy_pirate_sloop | 海盗单桅帆船 | 普通敌人 | 小型海盗船 |
| enemy_imperial_frigate | 帝国轻型护卫舰 | 普通敌人 | 帝国海军标准战舰 |

---

## 三、武器与装备 (Weapons & Equipment)

### 3.1 主炮 (Main Weapons)

| ID | 名称 | 类型 | 描述 |
|----|------|------|------|
| weapon_24pounder | 24磅卡隆炮 | 主炮 | 高伤害，低命中率 |
| weapon_torpedo | 旋转式鱼雷管 | 主炮 | 无视护甲，特定距离有效 |
| weapon_steam_cannon | 高压蒸汽炮 | 主炮 | 击退效果，蒸汽朋克特色 |

### 3.2 副炮 (Secondary Weapons)

| ID | 名称 | 类型 | 描述 |
|----|------|------|------|
| weapon_gatling | 速射转管炮 | 副炮 | 高拦截率 |
| weapon_depth_charge | 火箭深弹发射器 | 副炮 | 反潜专用 |
| weapon_signal_flare | 信号弹发射器 | 副炮 | 照明效果 |

### 3.3 特殊装置 (Special Equipment)

| ID | 名称 | 效果描述 |
|----|------|----------|
| equip_ramming | 蒸汽撞角 | 近战冲撞伤害 |
| equip_smoke_screen | 烟幕发生器 | 大幅提升闪避 |
| equip_repair_arm | 修理用机械臂 | 战斗中修复耐久 |
| equip_sonar | 声呐浮标 | 探隐形 |
| equip_eagle_eyes | 鹰眼瞄准器 | 珂尔莉专属，提高命中率 |

---

## 四、UI 资源 (UI Assets)

### 4.1 图标 (Icons)

| ID | 用途 | 描述 |
|----|------|------|
| icon_hull | 船体图标 | 盾牌+船体轮廓 |
| icon_boiler | 锅炉图标 | 齿轮+火焰 |
| icon_helm | 操舵室图标 | 舵轮 |
| icon_main_weapon | 主炮图标 | 大炮 |
| icon_secondary_weapon | 副炮图标 | 双筒炮 |
| icon_special | 特殊装置图标 | 齿轮组 |
| icon_gold | 金币图标 | 金克朗 |
| icon_bond | 帝国债券图标 | 帝国徽章 |
| icon_scrap | 废料图标 | 齿轮零件 |
| icon_health | 耐久图标 | 心形/船体 |
| icon_heat | 过热图标 | 温度计+蒸汽 |
| icon_distance | 射程环图标 | 同心圆 |

### 4.2 UI 面板 (UI Panels)

| ID | 名称 | 描述 |
|----|------|------|
| ui_battle_frame | 战斗界面边框 | 蒸汽朋克齿轮边框 |
| ui_dialogue_box | 对话框 | 复古航海风格 |
| ui_item_slot | 物品槽 | 金属边框凹槽 |
| ui_button | 按钮样式 | 齿轮铆钉风格 |
| ui_progress_bar | 进度条 | 锅炉压力表风格 |
| ui_skill_button | 技能按钮 | 圆形齿轮边框 |

---

## 五、环境背景 (Environment Backgrounds)

### 5.1 港口场景 (Port Scenes)

| ID | 名称 | 描述 |
|----|------|------|
| bg_rusty_bay | 铁锈湾 | 初始港口，破旧但温馨 |
| bg_industrial_port | 工业港 | 帝国控制的机械港 |
| bg_pirate_haven | 海盗避风港 | 混乱的自由港 |
| bg_deep_sea_port | 深海港 | 潜水艇基地 |

### 5.2 港口内部 (Port Interiors)

| ID | 名称 | 描述 |
|----|------|------|
| bg_tavern | 沉锚酒馆 | 酒桶、油灯、木质吧台 |
| bg_bounty_hall | 赏金公会大厅 | 公告板、悬赏海报 |
| bg_shipyard | 船坞 | 起重机、维修站 |
| bg_shop | 商店 | 货架、柜台 |

### 5.3 战斗场景 (Battle Scenes)

| ID | 名称 | 描述 |
|----|------|------|
| bg_ocean_battle | 公海战斗 | 雾蒙蒙的海面 |
| bg_reef_battle | 礁石战斗 | 珊瑚礁背景 |
| bg_storm_battle | 风暴战斗 | 暴风雨中的海战 |
| bg_underwater_battle | 潜水战斗 | 深海场景（潜水艇用） |

### 5.4 世界地图 (World Map)

| ID | 名称 | 描述 |
|----|------|------|------|
| bg_world_map | 世界地图 | 手绘风格群岛图 |
| bg_region_map | 区域地图 | 局部海域详图 |
| bg_minimap | 小地图 | HUD用简化地图 |

---

## 六、特效动画 (VFX / Animations)

### 6.1 战斗特效 (Battle Effects)

| ID | 名称 | 描述 |
|----|------|------|
| fx_cannon_fire | 主炮发射 | 炮弹飞行轨迹+爆炸 |
| fx_torpedo | 鱼雷 | 水下轨迹+命中 |
| fx_intercept | 迎击 | 弹幕拦截闪光 |
| fx_smoke | 烟幕 | 灰色烟雾扩散 |
| fx_fire | 火灾 | 火焰蔓延 |
| fx_explosion | 爆炸 | 船只受损爆炸 |
| fx_splash | 水花 | 鱼类/潜水命中 |
| fx_heal | 治疗 | 修理臂发光 |
| fx_status_overheat | 过热 | 蒸汽喷射+红色 |
| fx_status_paralysis | 瘫痪 | 电流+火花 |
| fx_ghost | 幽灵 | 透明+飘渺效果 |

### 6.2 UI 特效 (UI Effects)

| ID | 名称 | 描述 |
|----|------|------|
| ui_glow_select | 选中高亮 | 金色光晕 |
| ui_damage_number | 伤害数字 | 浮动数字 |
| ui_critical | 暴击 | 红色闪烁 |
| ui_miss | 闪避 | "MISS" 文字 |
| ui_level_up | 升级 | 光柱+粒子 |

---

## 七、UI/UX 设计规范 (Design Guidelines)

### 7.1 色彩规范

| 名称 | 色值 | 用途 |
|------|------|------|
| 锈红 | #8B4513 | 主色调，船只/边框 |
| 铜绿 | #2E8B57 | 副色调，蒸汽/生命值 |
| 雾灰 | #708090 | 背景/海洋 |
| 钢铁蓝 | #4682B4 | 高亮/交互 |
| 荧光蓝 | #00FFFF | 雷钢/特殊效果 |
| 煤炭黑 | #1C1C1C | 文字/深色背景 |
| 象牙白 | #FFFFF0 | 高亮文字 |

### 7.2 字体规范

- **标题**: Victorian Gothic / Steampunk Display Font
- **正文**: 清晰易读的 sans-serif
- **数字**: 等宽数字用于数值显示

### 7.3 统一风格要素

- 所有边框使用齿轮/铆钉装饰
- 按钮使用金属质感+凹陷效果
- 图标使用单色+高光风格
- 保持日式动画风格的角色设计

---

## 八、音频资源占位 (Audio Assets - Placeholders)

> 音频资源后续单独定义，此处占位

| ID | 类型 | 用途 |
|----|------|------|
| bgm_ocean | BGM | 航行/探索 |
| bgm_battle | BGM | 战斗音乐 |
| bgm_tavern | BGM | 酒馆音乐 |
| bgm_boss | BGM | BOSS战 |
| sfx_cannon | SFX | 主炮射击 |
| sfx_torpedo | SFX | 鱼雷发射 |
| sfx_intercept | SFX | 迎击成功 |
| sfx_hit | SFX | 命中 |
| sfx_miss | SFX | 闪避 |
| sfx_select | SFX | UI选择 |
| sfx_click | SFX | UI点击 |
| sfx_steam | SFX | 蒸汽喷射 |
| sfx_wave | SFX | 海浪声 |

---

## 九、生成优先级 (Generation Priority)

### 高优先级 (P0) - 原型必须
1. 珂尔莉立绘 (char_keerli)
2. 蒸汽破浪号精灵 (ship_steam_breaker)
3. 战斗界面边框 (ui_battle_frame)
4. 射程环UI图标 (icon_distance)
5. 铁锈湾港口背景 (bg_rusty_bay)
6. 战斗特效 - 炮弹轨迹 (fx_cannon_fire)

### 中优先级 (P1) - Alpha 需要
1. 其他4个伙伴立绘
2. 敌方船只精灵
3. 武器图标组
4. 酒馆/公会内部背景
5. 伤害数字UI (ui_damage_number)
6. 状态效果图标 (过热/瘫痪/漏水)

### 低优先级 (P2) - Beta 完善
1. NPC立绘
2. 世界地图背景
3. BOSS专属精灵
4. 全部UI面板
5. 全部SFX占位
6. BGM占位

---

## 十、生成 Prompt 速查表

### 角色立绘
```
steampunk naval RPG character portrait, Japanese anime style, Victorian industrial fashion with gears and brass, fog gray and rust red color scheme, high quality, detailed, game-ready
```

### 船只精灵
```
steampunk warship top-down sprite, Victorian ironclad with brass pipes and gears, exposed steam engine, 256x256, pixel art style, detailed rivets and smokestacks
```

### UI 边框
```
steampunk UI frame, Victorian industrial border with gears and rivets, brass and rust colors, metal texture, game HUD frame, transparent center
```

### 战斗特效
```
steampunk battle effect sprite sheet, cannon fire and explosion, brass and steam, transparent background, top-down RPG perspective, high quality VFX
```

### 环境背景
```
steampunk seaport background, Victorian industrial architecture, foggy atmosphere, brass and rust tones, detailed illustration, game background
```

---

*最后更新: 2026-04-25*
*用途: AI 图像生成参考，严格按 prompt 执行*
