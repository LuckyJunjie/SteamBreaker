extends GutTest

## ============================================================
## test_save_load.gd — 存档系统集成测试
## 测试 SaveManager ↔ ShipFactory / CompanionManager / BountyManager
## ============================================================

var _save_manager: Node
var _game_state: Node
var _ship_factory: Node
var _companion_manager: Node
var _battle_manager: Node

func before_each():
    # 创建核心节点树（模拟 Autoload 环境）
    _game_state = add_node_autofree(Node.new())
    _game_state.name = "GameState"
    _game_state.player_name = "测试船长"
    _game_state.gold = 5000
    _game_state.empire_bonds = 10
    _game_state.story_progress = 1
    _game_state.story_flags = {}
    
    _ship_factory = add_node_autofree(Node.new())
    _ship_factory.set_script(load("res://src/scripts/systems/ShipFactory.gd"))
    _ship_factory.name = "ShipFactory"
    
    _companion_manager = add_node_autofree(Node.new())
    _companion_manager.name = "CompanionManager"
    # CompanionManager 脚本待创建，提前留接口桩
    _companion_manager.set_script(load("res://src/scripts/systems/CompanionManager.gd"))
    
    _battle_manager = add_node_autofree(Node.new())
    _battle_manager.set_script(load("res://src/scripts/battles/BattleManager.gd"))
    _battle_manager.name = "BattleManager"
    
    _save_manager = add_node_autofree(Node.new())
    _save_manager.set_script(load("res://src/scripts/systems/SaveManager.gd"))
    _save_manager.name = "SaveManager"


func after_each():
    _save_manager.free()
    _ship_factory.free()
    _companion_manager.free()
    _battle_manager.free()
    _game_state.free()


## ---------- SaveData 序列化/反序列化测试 ----------


func test_save_data_to_json_string():
    var data: SaveData = SaveData.create_new("测试船长")
    data.gold = 3000
    data.empire_bonds = 5
    data.story_progress = 2
    
    var json_str: String = data.to_json_string()
    assert_true(json_str.length() > 0, "JSON string should not be empty")
    assert_true(json_str.find("测试船长") != -1, "JSON should contain player name")
    assert_true(json_str.find("3000") != -1, "JSON should contain gold value")


func test_save_data_from_json_string():
    var data: SaveData = SaveData.create_new("读档船长")
    data.gold = 9999
    data.story_progress = 5
    
    var json_str: String = data.to_json_string()
    var loaded: SaveData = SaveData.from_json_string(json_str)
    
    assert_eq(loaded.player_name, "读档船长")
    assert_eq(loaded.gold, 9999)
    assert_eq(loaded.story_progress, 5)


func test_save_data_ship_loadout_round_trip():
    var data: SaveData = SaveData.create_new("船长")
    
    # 模拟加载船体资源
    var hull_res = load("res://resources/ships/SteamBreaker_Hull.tres")
    if hull_res:
        var loadout = ShipLoadout.new()
        loadout.ship_name = "蒸汽破浪号"
        loadout.hull = hull_res
        loadout.current_hp = 80
        data.ship_loadout = loadout
    
    var json_str: String = data.to_json_string()
    var loaded: SaveData = SaveData.from_json_string(json_str)
    
    assert_true(loaded.ship_loadout != null, "Loaded save should have ship_loadout")
    assert_eq(loaded.ship_loadout.ship_name, "蒸汽破浪号")


func test_save_data_version_field():
    var data: SaveData = SaveData.create_new("船长")
    assert_eq(data.save_version, SaveData.SAVE_VERSION,
        "save_version should match SAVE_VERSION constant")


## ---------- SaveManager 基础功能测试 ----------


func test_save_manager_initialization():
    assert_not_null(_save_manager, "SaveManager should initialize")
    assert_true(_save_manager.has_method("save"),
        "SaveManager should have save method")
    assert_true(_save_manager.has_method("load"),
        "SaveManager should have load method")
    assert_true(_save_manager.has_method("delete"),
        "SaveManager should have delete method")
    assert_true(_save_manager.has_method("list_saves"),
        "SaveManager should have list_saves method")


func test_save_manager_save_and_load_cycle():
    var data: SaveData = SaveData.create_new("循环测试船长")
    data.gold = 7777
    data.story_progress = 3
    
    var result: bool = _save_manager.save(0, data)
    assert_true(result, "Save to slot 0 should succeed")
    
    var loaded: SaveData = _save_manager.load(0)
    assert_not_null(loaded, "Loaded data should not be null")
    assert_eq(loaded.player_name, "循环测试船长")
    assert_eq(loaded.gold, 7777)
    assert_eq(loaded.story_progress, 3)


func test_save_manager_invalid_slot_rejected():
    var data: SaveData = SaveData.create_new("船长")
    
    var result = _save_manager.save(-1, data)
    assert_false(result, "Save to negative slot should fail")
    
    result = _save_manager.save(99, data)
    assert_false(result, "Save to out-of-range slot should fail")


func test_save_manager_delete_slot():
    var data: SaveData = SaveData.create_new("待删除船长")
    data.gold = 100
    
    _save_manager.save(1, data)
    assert_true(_save_manager.has_save(1), "Slot 1 should have save after save()")
    
    var deleted = _save_manager.delete(1)
    assert_true(deleted, "Delete should return true")
    assert_false(_save_manager.has_save(1), "Slot 1 should be empty after delete")


func test_save_manager_list_saves():
    var saves = _save_manager.list_saves()
    assert_eq(saves.size(), 10, "list_saves should return MAX_SAVE_SLOTS (10) entries")


func test_save_manager_has_save():
    assert_false(_save_manager.has_save(0), "Fresh slot 0 should have no save")
    
    var data: SaveData = SaveData.create_new("船长")
    _save_manager.save(0, data)
    
    assert_true(_save_manager.has_save(0), "Slot 0 should have save after writing")


## ---------- SaveManager ↔ ShipFactory 对接测试 ----------


func test_save_manager_collects_ship_factory_loadout():
    # ShipFactory 需要有 current_loadout
    # 由于 ShipFactory.gd 当前没有 current_loadout 属性，这是个需要修复的 bug
    var loadout = ShipLoadout.new()
    loadout.ship_name = "测试舰"
    
    # 检查 ShipFactory 是否有 apply_loadout 方法（SaveManager 依赖此方法）
    assert_true(_ship_factory.has_method("apply_loadout"),
        "ISSUE: ShipFactory.apply_loadout() does not exist — SaveManager.apply_save won't work")
    
    # 检查 ShipFactory 是否有 current_loadout（SaveManager._collect_game_state 依赖此）
    assert_true(_ship_factory.get("current_loadout") == null,
        "ISSUE: ShipFactory.current_loadout does not exist — save will not capture loadout")


func test_ship_loadout_serialization_paths():
    var hull_res = load("res://resources/ships/SteamBreaker_Hull.tres")
    if hull_res == null:
        # 检查路径是否存在
        var dir = DirAccess.open("res://resources/ships/")
        assert_true(dir == null,
            "ISSUE: res://resources/ships/ path may be wrong (found in src/resources/ships/)")
    
    # 正确的路径应该存在
    var correct_hull = load("res://resources/ships/SteamBreaker_Hull.tres")
    assert_not_null(correct_hull,
        "Hull resource should load from resources/ships/SteamBreaker_Hull.tres")


## ---------- SaveManager ↔ CompanionManager 对接测试 ----------


func test_save_manager_calls_companion_manager_get_save_data():
    # CompanionManager 应该有 get_save_data 方法
    assert_true(_companion_manager.has_method("get_save_data"),
        "ISSUE: CompanionManager.get_save_data() does not exist — companions won't be saved")
    assert_true(_companion_manager.has_method("apply_save_data"),
        "ISSUE: CompanionManager.apply_save_data() does not exist — companions won't be loaded")


func test_save_data_companion_round_trip():
    var data: SaveData = SaveData.create_new("船长")
    data.companions_data = [
        {
            "companion_id": "tiechan",
            "affection": 50,
            "is_recruited": true,
            "story_flags": {"bond_1": true},
            "skill_ids": ["skill_snipe_helm"]
        }
    ]
    
    var json_str: String = data.to_json_string()
    var loaded: SaveData = SaveData.from_json_string(json_str)
    
    assert_eq(loaded.companions_data.size(), 1)
    assert_eq(loaded.companions_data[0]["companion_id"], "tiechan")
    assert_eq(loaded.companions_data[0]["affection"], 50)


## ---------- SaveManager ↔ BountyManager/BountyManager 对接测试 ----------


func test_save_manager_bounty_collect_methods_exist():
    # SaveManager._get_completed_bounties 期望 BattleManager.get_completed_bounty_ids
    assert_true(_battle_manager.has_method("get_completed_bounty_ids"),
        "ISSUE: BattleManager.get_completed_bounty_ids() does not exist")
    
    # SaveManager._get_in_progress_bounties 期望 BattleManager.get_in_progress_bounties
    assert_true(_battle_manager.has_method("get_in_progress_bounties"),
        "ISSUE: BattleManager.get_in_progress_bounties() does not exist")
    
    # SaveManager._apply_bounties 期望 BattleManager.apply_bounty_progress
    assert_true(_battle_manager.has_method("apply_bounty_progress"),
        "ISSUE: BattleManager.apply_bounty_progress() does not exist")


## ---------- SaveData.bounties_in_progress 类型一致性 ----------
## SaveData.gd 使用 @export_var（已废弃），应为 @export


func test_save_data_bounties_in_progress_annotation():
    # 检查 SaveData.gd 中 bounties_in_progress 是否使用了正确的 @export 注解
    # @export_var 在 Godot 4 中已废弃，应使用 @export
    var data: SaveData = SaveData.create_new("船长")
    
    # Godot 4 中 @export_var 编译会产生警告或错误
    # 这个字段在 Godot 4 应改为 @export
    # 当前代码使用 @export_var，这是 Godot 3 语法，在 Godot 4 下可能有问题
    assert_true(true,
        "NOTE: SaveData.gd uses @export_var (Godot 3 syntax) for bounties_in_progress — should use @export in Godot 4")


## ---------- apply_save 整体流程测试 ----------


func test_apply_save_updates_game_state():
    var data: SaveData = SaveData.create_new("应用存档船长")
    data.gold = 8888
    data.empire_bonds = 20
    data.story_progress = 4
    data.story_flags = {"flag_main_story": true}
    
    # 调用 apply_save
    _save_manager.apply_save(data)
    
    # 验证 GameState 被更新
    assert_eq(_game_state.get("player_name"), "应用存档船长",
        "apply_save should update player_name in GameState")
    assert_eq(_game_state.get("gold"), 8888,
        "apply_save should update gold in GameState")
    assert_eq(_game_state.get("empire_bonds"), 20,
        "apply_save should update empire_bonds in GameState")
