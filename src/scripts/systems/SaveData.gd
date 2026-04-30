extends Resource
class_name SaveData

## Steam Breaker Save Data Structure
## 存档数据结构

const SAVE_VERSION := "1.0.0"

@export var save_version: String = SAVE_VERSION
@export var timestamp: int = 0
@export var player_name: String = "船长"
@export var gold: int = 1000
@export var empire_bonds: int = 0
@export var ship_loadout: ShipLoadout = null

# Companion data with affection
@export var companions_data: Array[Dictionary] = []

# Bounty tracking
@export var bounties_completed: Array[String] = []
@export var bounties_in_progress: Array[Dictionary] = []

# Story progress
@export var story_progress: int = 0
@export var story_flags: Dictionary = {}

# Game settings snapshot
@export var settings: Dictionary = {}

# ============================================
# Factory Methods / 工厂方法
# ============================================

static func create_new(player_name: String = "船长") -> SaveData:
    var data := SaveData.new()
    data.save_version = SAVE_VERSION
    data.timestamp = Time.get_unix_time_from_system()
    data.player_name = player_name
    data.gold = 1000
    data.empire_bonds = 0
    data.ship_loadout = null
    data.companions_data = []
    data.bounties_completed = []
    data.bounties_in_progress = []
    data.story_progress = 0
    data.story_flags = {}
    data.settings = {}
    return data

# ============================================
# Serialization / 序列化
# ============================================

func to_dict() -> Dictionary:
    var dict: Dictionary = {
        "save_version": save_version,
        "timestamp": timestamp,
        "player_name": player_name,
        "gold": gold,
        "empire_bonds": empire_bonds,
        "story_progress": story_progress,
        "story_flags": story_flags,
        "bounties_completed": bounties_completed,
        "bounties_in_progress": bounties_in_progress,
        "settings": settings,
    }
    
    # Serialize ship loadout
    if ship_loadout:
        dict["ship_loadout"] = _serialize_ship_loadout(ship_loadout)
    
    # Serialize companions
    dict["companions_data"] = []
    for comp_data in companions_data:
        dict["companions_data"].append(_serialize_companion(comp_data))
    
    return dict

func from_dict(dict: Dictionary) -> void:
    save_version = dict.get("save_version", SAVE_VERSION)
    timestamp = dict.get("timestamp", 0)
    player_name = dict.get("player_name", "船长")
    gold = dict.get("gold", 1000)
    empire_bonds = dict.get("empire_bonds", 0)
    story_progress = dict.get("story_progress", 0)
    story_flags = dict.get("story_flags", {})
    bounties_completed = dict.get("bounties_completed", [])
    bounties_in_progress = dict.get("bounties_in_progress", [])
    settings = dict.get("settings", {})
    
    # Deserialize ship loadout
    if dict.has("ship_loadout"):
        ship_loadout = _deserialize_ship_loadout(dict["ship_loadout"])
    
    # Deserialize companions
    companions_data = []
    if dict.has("companions_data"):
        for comp_dict in dict["companions_data"]:
            companions_data.append(_deserialize_companion(comp_dict))

# ============================================
# Ship Loadout Serialization / 船只配置序列化
# ============================================

func _serialize_ship_loadout(loadout: ShipLoadout) -> Dictionary:
    var dict: Dictionary = {
        "ship_name": loadout.ship_name,
        "current_hp": loadout.current_hp,
        "current_overheat": loadout.current_overheat,
    }
    
    if loadout.hull:
        dict["hull_path"] = loadout.hull.resource_path
    if loadout.boiler:
        dict["boiler_path"] = loadout.boiler.resource_path
    if loadout.helm:
        dict["helm_path"] = loadout.helm.resource_path
    
    dict["main_weapons"] = []
    for w in loadout.main_weapons:
        if w and w.resource_path:
            dict["main_weapons"].append(w.resource_path)
    
    dict["secondary_weapons"] = []
    for s in loadout.secondary_weapons:
        if s and s.resource_path:
            dict["secondary_weapons"].append(s.resource_path)
    
    dict["special_devices"] = []
    for sp in loadout.special_devices:
        if sp and sp.resource_path:
            dict["special_devices"].append(sp.resource_path)
    
    return dict

func _deserialize_ship_loadout(dict: Dictionary) -> ShipLoadout:
    var loadout := ShipLoadout.new()
    loadout.ship_name = dict.get("ship_name", "蒸汽破浪号")
    loadout.current_hp = dict.get("current_hp", 100)
    loadout.current_overheat = dict.get("current_overheat", 0.0)
    
    if dict.has("hull_path"):
        loadout.hull = load(dict["hull_path"])
    if dict.has("boiler_path"):
        loadout.boiler = load(dict["boiler_path"])
    if dict.has("helm_path"):
        loadout.helm = load(dict["helm_path"])
    
    loadout.main_weapons = []
    if dict.has("main_weapons"):
        for path in dict["main_weapons"]:
            if path:
                loadout.main_weapons.append(load(path))
    
    loadout.secondary_weapons = []
    if dict.has("secondary_weapons"):
        for path in dict["secondary_weapons"]:
            if path:
                loadout.secondary_weapons.append(load(path))
    
    loadout.special_devices = []
    if dict.has("special_devices"):
        for path in dict["special_devices"]:
            if path:
                loadout.special_devices.append(load(path))
    
    return loadout

# ============================================
# Companion Serialization / 伙伴序列化
# ============================================

func _serialize_companion(comp_data: Dictionary) -> Dictionary:
    return {
        "companion_id": comp_data.get("companion_id", ""),
        "affection": comp_data.get("affection", 0),
        "is_recruited": comp_data.get("is_recruited", false),
        "story_flags": comp_data.get("story_flags", {}),
        "skill_ids": comp_data.get("skill_ids", []),
    }

func _deserialize_companion(dict: Dictionary) -> Dictionary:
    return {
        "companion_id": dict.get("companion_id", ""),
        "affection": dict.get("affection", 0),
        "is_recruited": dict.get("is_recruited", false),
        "story_flags": dict.get("story_flags", {}),
        "skill_ids": dict.get("skill_ids", []),
    }

# ============================================
# Utility Methods / 工具方法
# ============================================

func get_timestamp_formatted() -> String:
    var dt: Dictionary = Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]

func get_slot_name(slot: int) -> String:
    return "slot_%d.json" % slot

func get_save_path(slot: int) -> String:
    return "user://saves/slot_%d.json" % slot

func to_json_string() -> String:
    return JSON.stringify(to_dict())

static func from_json_string(json: String) -> SaveData:
    var data := SaveData.new()
    if json == null or json.is_empty():
        push_error("[SaveData] from_json_string: empty or null JSON string")
        return data
    
    var parsed = JSON.parse_string(json)
    if parsed == null:
        push_error("[SaveData] from_json_string: JSON parsing failed for input: ", json)
        return data
    
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("[SaveData] from_json_string: parsed result is not a Dictionary (type=%d)" % typeof(parsed))
        return data
    
    if parsed.is_empty():
        push_error("[SaveData] from_json_string: parsed dictionary is empty")
        return data
    
    data.from_dict(parsed)
    return data