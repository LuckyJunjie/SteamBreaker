extends Node

## Steam Breaker Save Manager
## 存档管理器 - 完善版：收集所有系统状态 + 自动存档

const MAX_SAVE_SLOTS := 10
const AUTO_SAVE_SLOT := -1  # Internal only, never shown in save list
const SAVE_EXTENSION := ".json"

signal save_completed(slot: int, success: bool, message: String)
signal load_completed(slot: int, success: bool, message: String)
signal delete_completed(slot: int, success: bool, message: String)
signal auto_save_triggered(reason: String)

var _save_directory: String = "user://saves"
var _current_save_data: Variant = null
var _is_auto_save_enabled: bool = true
var _last_auto_save_time: int = 0
var _auto_save_interval_seconds: int = 300  # 5分钟自动存档

# ============================================
# Initialization / 初始化
# ============================================

func _ready():
    print("[SaveManager] Initializing...")
    _ensure_save_directory()
    print("[SaveManager] Ready. Save path: ", _get_save_dir_path())

func _ensure_save_directory() -> void:
    var dir := DirAccess.open("user://")
    if dir:
        if not dir.dir_exists("saves"):
            dir.make_dir("saves")
            print("[SaveManager] Created saves directory")

# ============================================
# Public API / 公开接口
# ============================================

## Save game to slot / 保存游戏到槽位
func save(slot: int, data: Variant = null) -> bool:
    if slot != AUTO_SAVE_SLOT and (slot < 0 or slot >= MAX_SAVE_SLOTS):
        push_error("[SaveManager] Invalid slot: %d" % slot)
        save_completed.emit(slot, false, "无效的存档槽位")
        return false
    
    # Auto-save slot uses a fixed internal path
    if slot == AUTO_SAVE_SLOT and not _ensure_auto_save_path():
        push_error("[SaveManager] Failed to create auto-save directory")
        save_completed.emit(slot, false, "自动存档目录创建失败")
        return false
    
    # Use provided data or collect current game state
    if data == null:
        data = _collect_game_state()
    
    data.timestamp = Time.get_unix_time_from_system()
    
    var path: String = _get_save_path(slot)
    var json_str: String = data.to_json_string()
    
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(json_str)
        file.close()
        print("[SaveManager] Saved to slot %d: %s" % [slot, path])
        save_completed.emit(slot, true, "存档成功")
        _current_save_data = data
        return true
    else:
        push_error("[SaveManager] Failed to save: %s" % path)
        save_completed.emit(slot, false, "存档失败")
        return false

## Auto save (internal) / 自动存档（内部调用）
func auto_save(reason: String = "auto") -> void:
    if not _is_auto_save_enabled:
        return
    if not _should_auto_save():
        return
    
    # Use internal auto-save slot
    var success: bool = save(AUTO_SAVE_SLOT)
    if success:
        _last_auto_save_time = Time.get_unix_time_from_system()
        auto_save_triggered.emit(reason)
        print("[SaveManager] Auto-saved: %s" % reason)

func _should_auto_save() -> bool:
    var now: int = Time.get_unix_time_from_system()
    return (now - _last_auto_save_time) >= _auto_save_interval_seconds

## Trigger auto-save at key points / 在关键节点触发自动存档
func trigger_auto_save(reason: String) -> void:
    print("[SaveManager] Auto-save triggered: %s" % reason)
    auto_save(reason)

## Load game from slot / 从槽位加载存档
func load(slot: int) -> Variant :
    if slot != AUTO_SAVE_SLOT and (slot < 0 or slot >= MAX_SAVE_SLOTS):
        push_error("[SaveManager] Invalid slot: %d" % slot)
        load_completed.emit(slot, false, "无效的存档槽位")
        return null
    
    if slot == AUTO_SAVE_SLOT and not _ensure_auto_save_path():
        push_error("[SaveManager] Auto-save directory unavailable")
        load_completed.emit(slot, false, "自动存档不可用")
        return null
    
    var path: String = _get_save_path(slot)
    
    if not FileAccess.file_exists(path):
        print("[SaveManager] Save file not found: %s" % path)
        load_completed.emit(slot, false, "存档文件不存在")
        return null
    
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("[SaveManager] Failed to open save file: %s" % path)
        load_completed.emit(slot, false, "读取存档失败")
        return null
    
    var json_str: String = file.get_as_text()
    file.close()
    
    var data: Variant = SaveData.from_json_string(json_str)
    _current_save_data = data
    print("[SaveManager] Loaded from slot %d" % slot)
    load_completed.emit(slot, true, "读档成功")
    return data

## Delete save slot / 删除存档槽位
func delete(slot: int) -> bool:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        push_error("[SaveManager] Invalid slot: %d" % slot)
        delete_completed.emit(slot, false, "无效的存档槽位")
        return false
    
    var path: String = _get_save_path(slot)
    
    if not FileAccess.file_exists(path):
        print("[SaveManager] No save file to delete at slot %d" % slot)
        delete_completed.emit(slot, true, "存档为空")
        return true
    
    var dir := DirAccess.open("user://saves")
    if dir:
        var err: Error = dir.remove(_get_file_name(slot))
        if err == OK:
            print("[SaveManager] Deleted slot %d" % slot)
            delete_completed.emit(slot, true, "删除成功")
            return true
        else:
            push_error("[SaveManager] Failed to delete slot %d: %d" % [slot, err])
            delete_completed.emit(slot, false, "删除失败")
            return false
    
    delete_completed.emit(slot, false, "删除失败")
    return false

## List all saves / 列出所有存档
func list_saves() -> Array[Dictionary]:
    var saves: Array[Dictionary] = []
    for slot in range(MAX_SAVE_SLOTS):
        if slot == AUTO_SAVE_SLOT:
            continue  # skip internal auto-save
        var info: Dictionary = _get_slot_info(slot)
        saves.append(info)
    return saves

## Check if slot has save / 检查槽位是否有存档
func has_save(slot: int) -> bool:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        return false
    return FileAccess.file_exists(_get_save_path(slot))

## Get current save data / 获取当前存档数据
func get_current_save() -> Variant :
    return _current_save_data

## Apply loaded save to game / 将加载的存档应用到游戏
func apply_save(data: Variant) -> void:
    print("[SaveManager] Applying save data...")
    
    # Apply to GameState (金币/债券/剧情)
    var game_state := _get_game_state_node()
    if game_state:
        game_state.player_name = data.player_name
        game_state.gold = data.gold
        game_state.empire_bonds = data.empire_bonds
        game_state.story_progress = data.story_progress
        if data.story_flags:
            for k in data.story_flags:
                game_state.set_story_flag(k, data.story_flags[k])
        print("[SaveManager] GameState applied: gold=%d, bonds=%d, progress=%d" % [
            data.gold, data.empire_bonds, data.story_progress])
    
    # Apply ship loadout via ShipFactory
    if data.ship_loadout:
        var ship_factory := _get_ship_factory()
        if ship_factory and ship_factory.has_method("apply_loadout"):
            ship_factory.apply_loadout(data.ship_loadout)
            print("[SaveManager] Ship loadout applied")
    
    # Apply companions via CompanionManager
    _apply_companions(data.companions_data)
    
    # Apply inventory via InventoryManager
    _apply_inventory(data.inventory_data)
    
    # Apply bounty progress via BountyManager (directly, not via BattleManager)
    _apply_bounties(data)
    
    print("[SaveManager] Save data applied successfully")

# ============================================
# Auto-save Trigger Integration / 自动存档触发点
# ============================================

## Call this when player enters port / 玩家进入港口时调用
func on_entered_port(port_id: String) -> void:
    trigger_auto_save("entered_port:" + port_id)

## Call this when battle ends / 战斗结束时调用
func on_battle_ended(victory: bool) -> void:
    var reason: String = "battle_victory" if victory else "battle_defeat"
    trigger_auto_save(reason)

## Call this at key story points / 关键剧情节点时调用
func on_story_checkpoint(story_flag: String) -> void:
    trigger_auto_save("story:" + story_flag)

## Call this when player acquires important item / 获得重要物品时调用
func on_item_acquired(item_id: String) -> void:
    trigger_auto_save("item:" + item_id)

## Call this when bounty is completed / 赏金完成时调用
func on_bounty_completed(bounty_id: String) -> void:
    trigger_auto_save("bounty:" + bounty_id)

## Enable/disable auto-save / 启用/禁用自动存档
func set_auto_save_enabled(enabled: bool) -> void:
    _is_auto_save_enabled = enabled
    print("[SaveManager] Auto-save %s" % ("enabled" if enabled else "disabled"))

func is_auto_save_enabled() -> bool:
    return _is_auto_save_enabled

# ============================================
# Private Methods / 私有方法
# ============================================

func _get_save_dir_path() -> String:
    return "user://saves"

func _ensure_auto_save_path() -> bool:
    var dir := DirAccess.open("user://")
    if dir:
        if not dir.dir_exists("saves"):
            dir.make_dir("saves")
        if not dir.dir_exists("auto"):
            dir.make_dir("auto")
        return true
    return false

func _get_file_name(slot: int) -> String:
    if slot == AUTO_SAVE_SLOT:
        return "auto_save.json"
    return "slot_%d.json" % slot

func _get_save_path(slot: int) -> String:
    if slot == AUTO_SAVE_SLOT:
        return "user://saves/auto/auto_save.json"
    return "user://saves/slot_%d.json" % slot

func _get_slot_info(slot: int) -> Dictionary:
    var info: Dictionary = {
        "slot": slot,
        "has_save": false,
        "player_name": "",
        "timestamp": 0,
        "timestamp_formatted": "",
        "gold": 0,
        "story_progress": 0,
    }
    
    var path: String = _get_save_path(slot)
    
    if FileAccess.file_exists(path):
        var file := FileAccess.open(path, FileAccess.READ)
        if file:
            var json_str: String = file.get_as_text()
            file.close()
            
            var parsed = JSON.parse_string(json_str)
            if parsed and typeof(parsed) == TYPE_DICTIONARY:
                info["has_save"] = true
                info["player_name"] = parsed.get("player_name", "船长")
                info["timestamp"] = parsed.get("timestamp", 0)
                info["gold"] = parsed.get("gold", 0)
                info["story_progress"] = parsed.get("story_progress", 0)
                
                if info["timestamp"] > 0:
                    var dt: Dictionary = Time.get_datetime_dict_from_unix_time(info["timestamp"])
                    info["timestamp_formatted"] = "%04d-%02d-%02d %02d:%02d" % [
                        dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]
                    ]
                else:
                    info["timestamp_formatted"] = "未知时间"
    
    return info

func _collect_game_state() -> Variant :
    var data: Variant = SaveData.new()
    
    # ---- GameState (金币/债券/剧情进度) ----
    var game_state := _get_game_state_node()
    if game_state and game_state.has_method("get_save_data"):
        var gs_data: Dictionary = game_state.get_save_data()
        data.player_name = gs_data.get("player_name", "船长")
        data.gold = gs_data.get("gold", 1000)
        data.empire_bonds = gs_data.get("empire_bonds", 0)
        data.story_progress = gs_data.get("story_progress", 0)
        data.story_flags = gs_data.get("story_flags", {}).duplicate(true)
        print("[SaveManager] Collected GameState: gold=%d, bonds=%d, progress=%d" % [
            data.gold, data.empire_bonds, data.story_progress])
    
    # ---- ShipFactory (当前船只配置) ----
    var ship_factory := _get_ship_factory()
    if ship_factory:
        # Try to get current_loadout from ShipFactory
        if ship_factory.has_method("get_current_loadout") and ship_factory.get_current_loadout():
            data.ship_loadout = ship_factory.get_current_loadout().duplicate_loadout()
            print("[SaveManager] Collected ship loadout: %s" % data.ship_loadout.ship_name)
        # Fallback: collect from GameState player_ship reference
        elif game_state and game_state.player_ship:
            var ship = game_state.player_ship
            if ship.has_method("get_loadout"):
                data.ship_loadout = ship.get_loadout().duplicate()
    
    # ---- CompanionManager (伙伴数据) ----
    data.companions_data = _collect_companions()
    print("[SaveManager] Collected %d companions" % data.companions_data.size())
    
    # ---- InventoryManager (背包数据) ----
    data.inventory_data = _collect_inventory()
    print("[SaveManager] Collected inventory: %d slots" % data.inventory_data.size())
    
    # ---- BountyManager (赏金进度) ----
    data.bounties_completed = _get_completed_bounties()
    data.bounties_in_progress = _get_in_progress_bounties()
    print("[SaveManager] Collected bounties: %d completed, %d in progress" % [
        data.bounties_completed.size(), data.bounties_in_progress.size()])
    
    return data

func _get_game_state_node() -> Node:
    var root := get_tree().root
    var gs: Node = root.find_child("GameState", true, false)
    if not gs:
        gs = root.find_child("GameManager", true, false)
    return gs

func _get_ship_factory() -> Node:
    var root := get_tree().root
    return root.find_child("ShipFactory", true, false)

func _apply_companions(comp_data_list: Array[Dictionary]) -> void:
    var root := get_tree().root
    var companion_manager: Node = root.find_child("CompanionManager", true, false)
    if companion_manager and companion_manager.has_method("apply_save_data"):
        companion_manager.apply_save_data(comp_data_list)
        print("[SaveManager] Applied %d companion records" % comp_data_list.size())
    else:
        print("[SaveManager] CompanionManager not found or no apply_save_data method")

func _get_completed_bounties() -> Array[String]:
    # Try BountyManager directly first (not via BattleManager)
    var root := get_tree().root
    var bounty_manager: Node = root.find_child("BountyManager", true, false)
    if bounty_manager and bounty_manager.has_method("get_completed_bounty_ids"):
        return bounty_manager.get_completed_bounty_ids()
    return []

func _get_in_progress_bounties() -> Array[Dictionary]:
    var root := get_tree().root
    var bounty_manager: Node = root.find_child("BountyManager", true, false)
    if bounty_manager and bounty_manager.has_method("get_active_bounty_ids"):
        # Convert to Array[Dictionary] format
        var active_ids: Array = bounty_manager.get_active_bounty_ids()
        var result: Array[Dictionary] = []
        for bid in active_ids:
            result.append({"bounty_id": bid})
        return result
    return []

func _apply_bounties(data: Variant) -> void:
    var root := get_tree().root
    # Try BountyManager directly first
    var bounty_manager: Node = root.find_child("BountyManager", true, false)
    if bounty_manager and bounty_manager.has_method("apply_bounty_progress"):
        bounty_manager.apply_bounty_progress(data.bounties_completed, data.bounties_in_progress)
        print("[SaveManager] Applied bounty progress via BountyManager")
        return
    
    # Fallback: try via BattleManager
    var battle_manager: Node = root.find_child("BattleManager", true, false)
    if battle_manager and battle_manager.has_method("apply_bounty_progress"):
        battle_manager.apply_bounty_progress(data.bounties_completed, data.bounties_in_progress)
        print("[SaveManager] Applied bounty progress via BattleManager")
    else:
        print("[SaveManager] No BountyManager or BattleManager found for bounty restore")

func _collect_companions() -> Array[Dictionary]:
    var root := get_tree().root
    var companion_manager: Node = root.find_child("CompanionManager", true, false)
    if companion_manager and companion_manager.has_method("get_save_data"):
        return companion_manager.get_save_data()
    
    # Fallback: collect from companion nodes
    var comp_data: Array[Dictionary] = []
    var companions_node: Node = root.find_child("Companions", true, false)
    if companions_node:
        for c in companions_node.get_children():
            if c.has("companion_id") and c.get("is_recruited"):
                comp_data.append({
                    "companion_id": c.companion_id,
                    "affection": c.get("affection") if c.get("affection") else 0,
                    "is_recruited": true,
                    "story_flags": c.get("story_flags") if c.get("story_flags") else {},
                    "skill_ids": c.get("skill_ids") if c.get("skill_ids") else [],
                })
    return comp_data

func _collect_inventory() -> Array[Dictionary]:
    var root := get_tree().root
    var inv_manager: Node = root.find_child("InventoryManager", true, false)
    if inv_manager and inv_manager.has_method("get_save_data"):
        return inv_manager.get_save_data().get("inventory", [])
    return []

func _apply_inventory(inv_data: Array[Dictionary]) -> void:
    var root := get_tree().root
    var inv_manager: Node = root.find_child("InventoryManager", true, false)
    if inv_manager and inv_manager.has_method("apply_save_data"):
        inv_manager.apply_save_data({"inventory": inv_data})
        print("[SaveManager] Applied inventory: %d slots" % inv_data.size())
    else:
        print("[SaveManager] InventoryManager not found or no apply_save_data method")
