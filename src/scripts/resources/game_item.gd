class_name GameItem
extends Resource

## 物品数据资源

enum ItemType {
    CONSUMABLE,    # 消耗品（使用后消失）
    EQUIPMENT,     # 装备（穿戴后生效）
    KEY_ITEM,      # 关键道具（剧情/传送）
    GIFT           # 礼物（赠送给伙伴增加好感）
}

@export var item_id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var icon_emoji: String = "📦"
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var effect_data: Dictionary = {}  # 类型特定效果数据

## 获取物品类型名称（中文）
func get_type_name() -> String:
    match item_type:
        ItemType.CONSUMABLE: return "消耗品"
        ItemType.EQUIPMENT: return "装备"
        ItemType.KEY_ITEM: return "关键道具"
        ItemType.GIFT: return "礼物"
    return "未知"

## 是否可出售
func can_sell() -> bool:
    return sell_price > 0

## 是否可购买
func can_buy() -> bool:
    return buy_price > 0

## 获取效果描述
func get_effect_description() -> String:
    match item_type:
        ItemType.CONSUMABLE:
            return effect_data.get("description", "使用后获得效果")
        ItemType.EQUIPMENT:
            return effect_data.get("description", "装备后生效")
        ItemType.KEY_ITEM:
            return effect_data.get("description", "关键剧情道具")
        ItemType.GIFT:
            var bonus_min = effect_data.get("affection_min", 0)
            var bonus_max = effect_data.get("affection_max", 0)
            return "好感度 +%d~%d" % [bonus_min, bonus_max]
    return ""
