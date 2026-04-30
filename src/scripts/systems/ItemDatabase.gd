extends Node

## 物品数据库 - 单例模式加载所有物品定义

var _items_by_id: Dictionary = {}

signal database_loaded()

func _ready() -> void:
    _load_all_items()
    database_loaded.emit()
    print("[ItemDatabase] Loaded %d items" % _items_by_id.size())

func _load_all_items() -> void:
    var items_path = "res://resources/items/"
    var dir = DirAccess.open(items_path)
    if not dir:
        push_error("[ItemDatabase] Cannot open items directory: " + items_path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res = load(items_path + file_name)
            if res and res.get("item_id"):
                _items_by_id[res.item_id] = res
                print("[ItemDatabase] Registered item: %s (%s)" % [res.name, res.item_id])
        file_name = dir.get_next()
    dir.list_dir_end()

## 根据ID获取物品资源
func get_item(item_id: String) -> Resource:
    return _items_by_id.get(item_id)

## 获取所有物品
func get_all_items() -> Array[Resource]:
    var result: Array[Resource] = []
    for item in _items_by_id.values():
        result.append(item)
    return result

## 获取可购买的物品
func get_buyable_items() -> Array[Resource]:
    var result: Array[Resource] = []
    for item in _items_by_id.values():
        if item.buy_price > 0:
            result.append(item)
    return result

## 根据类型获取物品
func get_items_by_type(item_type: int) -> Array[Resource]:
    var result: Array[Resource] = []
    for item in _items_by_id.values():
        if item.item_type == item_type:
            result.append(item)
    return result

## 检查物品是否存在
func has_item(item_id: String) -> bool:
    return _items_by_id.has(item_id)
