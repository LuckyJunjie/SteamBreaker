extends Node

## 玩家背包管理器
## 管理物品的获取、使用、存储

var inventory: Array[Dictionary] = []  # [{item_id: String, quantity: int}]

signal inventory_changed()
signal item_used(item_id: String, success: bool)
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)

# 引用其他管理器
var _game_state = null
var _item_db = null
var _companion_manager = null

func _ready() -> void:
    _game_state = GameState if has_node("/root/GameState") else null
    
    # 连接ItemDatabase
    if has_node("/root/ItemDatabase"):
        _item_db = get_node("/root/ItemDatabase")
        print("[InventoryManager] Connected to ItemDatabase")
    
    # 连接CompanionManager
    if has_node("/root/CompanionManager"):
        _companion_manager = get_node("/root/CompanionManager")
        print("[InventoryManager] Connected to CompanionManager")
    
    print("[InventoryManager] Initialized")

## 设置物品数据库引用
func set_item_database(db: Node) -> void:
    _item_db = db

## 设置伙伴管理器引用（用于礼物效果）
func set_companion_manager(cm: Node) -> void:
    _companion_manager = cm

## 添加物品到背包
func add_item(item_id: String, quantity: int = 1) -> void:
    if quantity <= 0:
        return

    # 查找是否已有该物品
    for slot in inventory:
        if slot.item_id == item_id:
            slot.quantity += quantity
            inventory_changed.emit()
            item_added.emit(item_id, quantity)
            print("[InventoryManager] Added %dx %s (total: %d)" % [quantity, item_id, slot.quantity])
            return

    # 新增物品槽位
    inventory.append({item_id = item_id, quantity = quantity})
    inventory_changed.emit()
    item_added.emit(item_id, quantity)
    print("[InventoryManager] Added new slot: %dx %s" % [quantity, item_id])

## 移除物品
func remove_item(item_id: String, quantity: int = 1) -> bool:
    if quantity <= 0:
        return false

    for i in range(inventory.size()):
        var slot = inventory[i]
        if slot.item_id == item_id:
            if slot.quantity >= quantity:
                slot.quantity -= quantity
                if slot.quantity == 0:
                    inventory.remove_at(i)
                inventory_changed.emit()
                item_removed.emit(item_id, quantity)
                print("[InventoryManager] Removed %dx %s" % [quantity, item_id])
                return true
            else:
                print("[InventoryManager] Not enough %s to remove (have %d, need %d)" % [item_id, slot.quantity, quantity])
                return false

    print("[InventoryManager] Item not found in inventory: %s" % item_id)
    return false

## 检查是否拥有物品
func has_item(item_id: String, min_quantity: int = 1) -> bool:
    for slot in inventory:
        if slot.item_id == item_id and slot.quantity >= min_quantity:
            return true
    return false

## 获取物品数量
func get_item_count(item_id: String) -> int:
    for slot in inventory:
        if slot.item_id == item_id:
            return slot.quantity
    return 0

## 使用物品
func use_item(item_id: String) -> bool:
    var item_res = _get_item_resource(item_id)
    if not item_res:
        print("[InventoryManager] Unknown item: %s" % item_id)
        item_used.emit(item_id, false)
        return false

    # 检查是否拥有该物品
    if not has_item(item_id):
        print("[InventoryManager] Cannot use %s: not in inventory" % item_id)
        item_used.emit(item_id, false)
        return false

    var success = false

    match item_res.item_type:
        0:
            success = _use_consumable(item_res)
        2:
            success = _use_key_item(item_res)
        3:
            # 礼物需要指定目标伙伴，这里简化处理
            success = _use_gift(item_res)
        1:
            # 装备暂未实现
            print("[InventoryManager] Equipment not yet implemented: %s" % item_id)
            item_used.emit(item_id, false)
            return false

    if success:
        # 消耗品使用后消失
        if item_res.item_type == 0:
            remove_item(item_id, 1)
        item_used.emit(item_id, true)
    else:
        item_used.emit(item_id, false)

    return success

## 使用消耗品
func _use_consumable(item: Resource) -> bool:
    var effect_type = item.effect_data.get("type", "")

    match effect_type:
        "repair_ship":
            var hp_restore = item.effect_data.get("hp_restore", 0)
            if _game_state and _game_state.player_ship:
                var ship = _game_state.player_ship
                if "current_hp" in ship and "max_hp" in ship:
                    var old_hp = ship.current_hp
                    ship.current_hp = mini(ship.current_hp + hp_restore, ship.max_hp)
                    var actual = ship.current_hp - old_hp
                    print("[InventoryManager] Repaired ship +%d HP (now %d/%d)" % [actual, ship.current_hp, ship.max_hp])
                    return true
            elif _game_state:
                # 没有船只时给予金币补偿
                _game_state.add_gold(hp_restore * 2)
                print("[InventoryManager] No ship, granted %d gold instead" % (hp_restore * 2))
                return true
            return false

        "heal":
            var heal_amount = item.effect_data.get("heal_amount", 0)
            print("[InventoryManager] Healing not implemented fully: +%d HP" % heal_amount)
            return true

        _:
            print("[InventoryManager] Unknown consumable effect: %s" % effect_type)
            return false

    return true

## 使用关键道具
func _use_key_item(item: Resource) -> bool:
    var effect_type = item.effect_data.get("type", "")

    match effect_type:
        "teleport":
            var target = item.effect_data.get("target", "")
            print("[InventoryManager] Teleport to: %s" % target)
            # 触发传送逻辑
            if _game_state:
                if target == "rusty_bay":
                    _game_state.enter_port("rusty_bay")
                    return true
            return false

        "reveal_area":
            var area_id = item.effect_data.get("area_id", "")
            print("[InventoryManager] Revealing area: %s" % area_id)
            if _game_state:
                _game_state.set_story_flag("revealed_" + area_id, true)
                return true
            return false

        _:
            print("[InventoryManager] Unknown key item effect: %s" % effect_type)
            return false

    return true

## 使用礼物（增加好感度）
func _use_gift(item: Resource) -> bool:
    var effect_type = item.effect_data.get("type", "")
    if effect_type != "affection":
        return false

    var affection_min = item.effect_data.get("affection_min", 5)
    var affection_max = item.effect_data.get("affection_max", 10)
    var target_companion = item.effect_data.get("target_companion", "")
    var applicable_to = item.effect_data.get("applicable_to", "all")

    # 计算好感度增量（随机）
    var affection_bonus = randi() % (affection_max - affection_min + 1) + affection_min

    if target_companion != "" and _companion_manager:
        # 送给指定伙伴
        if _companion_manager.has_method("add_affection"):
            _companion_manager.add_affection(target_companion, affection_bonus)
            print("[InventoryManager] Gift %s -> %s (+%d affection)" % [item.item_id, target_companion, affection_bonus])
            return true
    elif _companion_manager and _companion_manager.has_method("add_affection_to_all"):
        # 送给所有伙伴
        _companion_manager.add_affection_to_all(affection_bonus)
        print("[InventoryManager] Gift %s -> all companions (+%d affection each)" % [item.item_id, affection_bonus])
        return true

    # 备用：没有伙伴管理器时，仅移除物品并打印信息
    print("[InventoryManager] Gift %s used (+%d affection, no companion manager)" % [item.item_id, affection_bonus])
    return true

## 获取物品资源（优先从ItemDatabase）
func _get_item_resource(item_id: String) -> Resource:
    if _item_db and _item_db.has_method("get_item"):
        var item = _item_db.get_item(item_id)
        if item:
            return item

    # 备用：直接从resources加载
    var path = "res://resources/items/item_%s.tres" % item_id
    if ResourceLoader.exists(path):
        return load(path)

    return null

## 获取背包快照（用于UI显示）
func get_inventory_snapshot() -> Array[Dictionary]:
    var snapshot: Array[Dictionary] = []
    for slot in inventory:
        var item_res = _get_item_resource(slot.item_id)
        if item_res:
            snapshot.append({
                item_id = slot.item_id,
                name = item_res.name,
                icon = item_res.icon_emoji,
                quantity = slot.quantity,
                type = item_res.item_type,
                type_name = item_res.get_type_name(),
                description = item_res.description,
                effect_desc = item_res.get_effect_description()
            })
        else:
            # 未知物品
            snapshot.append({
                item_id = slot.item_id,
                name = slot.item_id,
                icon = "❓",
                quantity = slot.quantity,
                type = -1,
                type_name = "未知",
                description = "",
                effect_desc = ""
            })
    return snapshot

## 存储/读取存档数据
func get_save_data() -> Dictionary:
    return {
        inventory = inventory.duplicate(true)
    }

func apply_save_data(data: Dictionary) -> void:
    inventory = data.get("inventory", []).duplicate(true)
    inventory_changed.emit()
    print("[InventoryManager] Save data applied: %d slots" % inventory.size())

## 清空背包
func clear() -> void:
    inventory.clear()
    inventory_changed.emit()
    print("[InventoryManager] Inventory cleared")
