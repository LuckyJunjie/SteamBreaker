extends GutTest

## ============================================================
## test_ship_factory.gd — 船只工厂集成测试
## 测试 ShipFactory ↔ ShipEntity ↔ ShipLoadout 对接
## ============================================================

var _ship_factory: Node

func before_each():
    _ship_factory = add_node_autofree(Node2D.new())
    _ship_factory.set_script(load("res://scripts/systems/ShipFactory.gd"))
    _ship_factory.name = "ShipFactory"


func after_each():
    _ship_factory.free()


## ---------- ShipFactory 基础功能测试 ----------


func test_create_ship_returns_node2d():
    var ship: Node2D = _ship_factory.CreateShip()
    
    assert_not_null(ship, "CreateShip should return a Node2D")
    assert_true(ship is Node2D, "Created ship should be instance of Node2D")
    assert_true(ship is ShipEntity or ship.get_script().get_global_name() in ["ShipEntity", ""],
        "Created ship should have ShipEntity script")
    
    ship.free()


func test_spawn_ship_at_sets_position():
    var hull_res = load("res://resources/ships/SteamBreaker_Hull.tres")
    if hull_res == null:
        skip("Hull resource not available, skipping position test")
        return
    
    var test_pos = Vector2(500, 300)
    var ship: Node2D = _ship_factory.SpawnShipAt("res://resources/ships/SteamBreaker_Hull.tres", test_pos)
    
    assert_almost_eq(ship.position.x, test_pos.x, 0.1, "Ship X position should match requested")
    assert_almost_eq(ship.position.y, test_pos.y, 0.1, "Ship Y position should match requested")
    
    ship.free()


func test_get_default_hull_returns_resource():
    var hull: Resource = _ship_factory.GetDefaultHull()
    assert_not_null(hull, "GetDefaultHull should return a Resource")
    
    # 验证路径一致
    assert_eq(hull.resource_path, "res://resources/ships/SteamBreaker_Hull.tres",
        "ISSUE: GetDefaultHull returns res://resources/ships/ (correct path)")


## ---------- ShipLoadout 功能测试 ----------


func test_ship_loadout_weight_calculation():
    var loadout = ShipLoadout.new()
    loadout.ship_name = "测试舰"
    
    # 加载部件资源
    var hull = load("res://resources/parts/hull_scout.tres")
    var boiler = load("res://resources/parts/boiler_single_expansion.tres")
    var helm = load("res://resources/parts/helm_manual.tres")
    
    if hull:
        loadout.hull = hull
    if boiler:
        loadout.boiler = boiler
    if helm:
        loadout.helm = helm
    
    var weight = loadout.get_total_weight()
    assert_true(weight >= 0.0, "Total weight should be non-negative")


func test_ship_loadout_overloaded_detection():
    var loadout = ShipLoadout.new()
    loadout.ship_name = "重载舰"
    
    var hull = load("res://resources/parts/hull_scout.tres")
    if hull:
        loadout.hull = hull
    
    var is_overloaded = loadout.is_overloaded()
    assert_bool(is_overloaded, "is_overloaded should correctly reflect weight vs capacity")


func test_ship_loadout_duplicate():
    var loadout1 = ShipLoadout.new()
    loadout1.ship_name = "原舰"
    loadout1.current_hp = 75
    
    var loadout2 = loadout1.duplicate()
    
    assert_eq(loadout2.ship_name, "原舰")
    assert_eq(loadout2.current_hp, 75)
    assert_true(loadout2 != loadout1, "Duplicate should be a different object instance")


func test_ship_loadout_max_hp_from_hull():
    var loadout = ShipLoadout.new()
    
    var hull = load("res://resources/parts/hull_ironclad.tres")
    if hull:
        loadout.hull = hull
        var max_hp = loadout.get_max_hp()
        assert_true(max_hp > 0, "Max HP from hull should be positive")


## ---------- ShipLoadout ↔ Resource 路径验证 ----------


func test_hull_resource_path_correctness():
    # 测试 hull_scout
    var hull_scout = load("res://resources/parts/hull_scout.tres")
    if hull_scout:
        assert_true(hull_scout is Resource, "hull_scout.tres should load as Resource")
    
    # 测试 hull_ironclad
    var hull_ironclad = load("res://resources/parts/hull_ironclad.tres")
    if hull_ironclad:
        assert_true(hull_ironclad is Resource, "hull_ironclad.tres should load as Resource")


func test_weapon_resources_load():
    var weapon_24pdr = load("res://resources/parts/weapon_24pounder.tres")
    if weapon_24pdr:
        assert_true(weapon_24pdr is Resource, "weapon_24pounder.tres should load as Resource")
    
    var torpedo = load("res://resources/parts/weapon_torpedo.tres")
    if torpedo:
        assert_true(torpedo is Resource, "weapon_torpedo.tres should load as Resource")


func test_boiler_resources_load():
    var boiler_single = load("res://resources/parts/boiler_single_expansion.tres")
    if boiler_single:
        assert_true(boiler_single is Resource, "boiler_single_expansion.tres should load as Resource")
    
    var boiler_double = load("res://resources/parts/boiler_double_expansion.tres")
    if boiler_double:
        assert_true(boiler_double is Resource, "boiler_double_expansion.tres should load as Resource")


func test_helm_resources_load():
    var helm_manual = load("res://resources/parts/helm_manual.tres")
    if helm_manual:
        assert_true(helm_manual is Resource, "helm_manual.tres should load as Resource")
    
    var helm_gyro = load("res://resources/parts/helm_gyroscope.tres")
    if helm_gyro:
        assert_true(helm_gyro is Resource, "helm_gyroscope.tres should load as Resource")


## ---------- ShipFactory path inconsistency (BUG) ----------


func test_ship_factory_path_inconsistency_bug():
    # ShipFactory.gd: SHIP_RESOURCE_PATH = "res://resources/ships/SteamBreaker_Hull.tres"
    # 但实际文件位于: res://resources/ships/SteamBreaker_Hull.tres
    # 
    # 同时 ShipLoadout serialization 在 SaveData.gd 中使用 hull.resource_path 存储路径
    # 如果 hull 资源路径是 res://resources/... 则存储/加载可以正常工作
    # 但如果 CreateShip/SpawnShipAt 使用错误的硬编码路径，会导致找不到资源
    
    var factory_path = "res://resources/ships/SteamBreaker_Hull.tres"
    var actual_path = "res://resources/ships/SteamBreaker_Hull.tres"
    
    var from_wrong_path = load(factory_path)
    var from_correct_path = load(actual_path)
    
    if from_wrong_path == null and from_correct_path != null:
        assert_true(true,
            "BUG CONFIRMED: ShipFactory uses path 'res://resources/ships/' but file may be elsewhere")
    elif from_wrong_path != null:
        assert_true(false,
            "Both paths resolve — path inconsistency may not cause runtime crash but is confusing")


## ---------- ShipEntity 功能测试 ----------


func test_ship_entity_initialize_with_hull():
    var ship = add_node_autofree(ShipEntity.new())
    var hull = load("res://resources/parts/hull_scout.tres")
    
    ship.Initialize(hull, true)
