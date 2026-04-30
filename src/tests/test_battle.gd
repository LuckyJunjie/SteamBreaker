extends GutTest

## ============================================================
## test_battle.gd — 战斗系统集成测试
## 测试 BattleManager ↔ ShipCombatData ↔ WeaponData 对接
## ============================================================

var _battle_manager: Node
var _player_ship: Node2D
var _enemy_ship: Node2D
var _player_combat_data: Node
var _enemy_combat_data: Node

func before_each():
    # 初始化 BattleManager
    _battle_manager = add_node_autofree(BattleManager.new())
    _battle_manager.name = "BattleManager"
    
    # 初始化玩家 ShipCombatData
    _player_combat_data = add_node_autofree(Node.new())
    _player_combat_data.set_script(load("res://src/scripts/battles/ShipCombatData.gd"))
    
    # 初始化敌人 ShipCombatData
    _enemy_combat_data = add_node_autofree(Node.new())
    _enemy_combat_data.set_script(load("res://src/scripts/battles/ShipCombatData.gd"))


func after_each():
    _battle_manager.free()
    _player_combat_data.free()
    _enemy_combat_data.free()


## ---------- 基础流程测试 ----------

func test_battle_initialization():
    _battle_manager.StartBattle()
    assert_eq(_battle_manager.current_phase, BattleManager.Phase.PLAYER_TURN,
        "Battle should start in PLAYER_TURN phase")


func test_turn_alternation():
    _battle_manager.StartBattle()
    assert_eq(_battle_manager.current_phase, BattleManager.Phase.PLAYER_TURN)
    
    _battle_manager.EndTurn()
    assert_eq(_battle_manager.current_phase, BattleManager.Phase.ENEMY_TURN,
        "After EndTurn from PLAYER_TURN, should be ENEMY_TURN")
    
    _battle_manager.EndTurn()
    assert_eq(_battle_manager.current_phase, BattleManager.Phase.PLAYER_TURN,
        "After EndTurn from ENEMY_TURN, should cycle back to PLAYER_TURN")


func test_phase_changed_signal_emitted():
    _battle_manager.StartBattle()
    var phase_emitted = await _battle_manager.phase_changed
    assert_eq(phase_emitted, BattleManager.Phase.PLAYER_TURN)


func test_ship_selection():
    var ship = Node2D.new()
    ship.name = "TestShip"
    add_child(ship)
    
    _battle_manager.SelectShip(ship)
    assert_eq(_battle_manager.selected_ship, ship,
        "Selected ship should match the ship passed to SelectShip")
    
    ship.free()


func test_add_ship():
    var ship = Node2D.new()
    ship.name = "Ship1"
    add_child(ship)
    
    _battle_manager.AddShip(ship)
    assert_true(_battle_manager.ships.has(ship),
        "Added ship should be in BattleManager ships array")
    
    ship.free()


func test_get_ships_in_range():
    var ship1 = Node2D.new()
    ship1.name = "Ship1"
    ship1.position = Vector2(100, 100)
    add_child(ship1)
    
    var ship2 = Node2D.new()
    ship2.name = "Ship2"
    ship2.position = Vector2(500, 100)
    add_child(ship2)
    
    _battle_manager.AddShip(ship1)
    _battle_manager.AddShip(ship2)
    
    var in_range = _battle_manager.GetShipsInRange(Vector2(100, 100), 0, 500)
    assert_true(in_range.size() >= 1,
        "GetShipsInRange should find at least one ship within range")
    
    ship1.free()
    ship2.free()


## ---------- ShipCombatData ↔ WeaponData 对接测试 ----------


func test_ship_combat_data_init_with_weapons():
    var weapon1 = WeaponData.new("wpn_01", "24pounder", WeaponData.WeaponType.MAIN_GUN, 30, 0, 10, 0, 999, 2)
    var weapon2 = WeaponData.new("wpn_02", "Gatling", WeaponData.WeaponType.SUB_GUN, 15, 0, 5, 0, 30, 1)
    
    _player_combat_data.setup("player_001", 150, 10, [weapon1, weapon2], 10, 100)
    
    assert_eq(_player_combat_data.ship_id, "player_001")
    assert_eq(_player_combat_data.max_hp, 150)
    assert_eq(_player_combat_data.current_hp, 150)
    assert_eq(_player_combat_data.weapons.size(), 2,
        "ShipCombatData should hold 2 weapons after setup")


func test_weapon_damage_vs_target_ring():
    var main_gun = WeaponData.new("wpn_main", "MainGun", WeaponData.WeaponType.MAIN_GUN, 100, 0, 10, 0, 999, 2)
    var torpedo = WeaponData.new("wpn_torpedo", "Torpedo", WeaponData.WeaponType.TORPEDO, 80, 0, 20, 0, 999, 3)
    var sub_gun = WeaponData.new("wpn_sub", "SubGun", WeaponData.WeaponType.SUB_GUN, 40, 0, 5, 0, 30, 1)
    
    # 主炮：全距离可用，近距0.8系数
    assert_almost_eq(main_gun.get_damage_vs(1, "hull"), 80.0, 0.1, "Main gun near range damage should be 80 (0.8x)")
    assert_almost_eq(main_gun.get_damage_vs(2, "hull"), 100.0, 0.1, "Main gun mid range should be 100 (1.0x)")
    assert_almost_eq(main_gun.get_damage_vs(3, "hull"), 100.0, 0.1, "Main gun far range should be 100 (1.0x)")
    
    # 鱼雷：仅远距有效
    assert_almost_eq(torpedo.get_damage_vs(1, "hull"), 0.0, 0.1, "Torpedo near range should be 0")
    assert_almost_eq(torpedo.get_damage_vs(3, "hull"), 80.0, 0.1, "Torpedo far range should be 80")
    
    # 副炮：近距1.5x
    assert_almost_eq(sub_gun.get_damage_vs(1, "hull"), 60.0, 0.1, "Sub gun near range should be 60 (1.5x)")
    assert_almost_eq(sub_gun.get_damage_vs(3, "hull"), 0.0, 0.1, "Sub gun far range should be 0")


func test_weapon_ammo_type_damage_modifier():
    var ap_gun = WeaponData.new("wpn_ap", "APGun", WeaponData.WeaponType.MAIN_GUN, 100, 0, 10, 0, 999, 2)
    ap_gun.ammo_type = WeaponData.AmmoType.ARMOR_PIERCE
    
    var he_gun = WeaponData.new("wpn_he", "HEGun", WeaponData.WeaponType.MAIN_GUN, 100, 0, 10, 0, 999, 2)
    he_gun.ammo_type = WeaponData.AmmoType.HIGH_EXPLOSIVE
    
    assert_almost_eq(ap_gun.get_damage_vs(2, "hull"), 150.0, 0.1, "AP ammo should deal 1.5x damage")
    assert_almost_eq(he_gun.get_damage_vs(2, "hull"), 200.0, 0.1, "HE ammo should deal 2.0x damage")


func test_weapon_can_fire_at_ring():
    var torpedo = WeaponData.new("wpn_torpedo", "Torpedo", WeaponData.WeaponType.TORPEDO, 80, 0, 20, 0, 999, 3)
    var ram = WeaponData.new("wpn_ram", "Ram", WeaponData.WeaponType.RAM, 120, 0, 0, 0, 999, 99)
    var boarding = WeaponData.new("wpn_board", "Boarding", WeaponData.WeaponType.BOARDING, 50, 0, 0, 0, 999, 2)
    
    assert_false(torpedo.can_fire_at_ring(1), "Torpedo should NOT fire at near range")
    assert_true(torpedo.can_fire_at_ring(3), "Torpedo should fire at far range")
    
    assert_true(ram.can_fire_at_ring(1), "Ram should fire at near range")
    assert_false(ram.can_fire_at_ring(3), "Ram should NOT fire at far range")
    
    assert_true(boarding.can_fire_at_ring(1), "Boarding should fire at near range")


func test_weapon_cooldown_consume_and_tick():
    var weapon = WeaponData.new("wpn_cd", "CDGun", WeaponData.WeaponType.MAIN_GUN, 50, 0, 10, 0, 999, 3)
    assert_true(weapon.is_loaded, "New weapon should be loaded")
    assert_eq(weapon.current_cooldown, 0, "New weapon should have 0 cooldown")
    
    weapon.consume()
    assert_false(weapon.is_loaded, "After consume, weapon should not be loaded")
    assert_eq(weapon.current_cooldown, 3, "After consume, cooldown should be 3")
    
    weapon.tick_cooldown()
    assert_false(weapon.is_loaded, "After 1 tick, still not loaded (cooldown=2)")
    assert_eq(weapon.current_cooldown, 2)
    
    weapon.current_cooldown = 1
    weapon.tick_cooldown()
    assert_true(weapon.is_loaded, "When cooldown reaches 0, weapon should be loaded")


## ---------- ShipCombatData 伤害处理测试 ----------


func test_take_damage_basic():
    _player_combat_data.setup("test_ship", 100, 10, [], 10, 100)
    var initial_hp = _player_combat_data.current_hp
    
    _player_combat_data.take_damage(30.0)
    
    assert_lt(_player_combat_data.current_hp, initial_hp,
        "HP should decrease after taking damage")
    assert_true(_player_combat_data.current_hp < 100,
        "HP should be less than max after damage")


func test_take_damage_triggers_hp_changed_signal():
    _player_combat_data.setup("test_ship", 100, 10, [], 10, 100)
    var emitted = await _player_combat_data.hp_changed
    assert_eq(emitted[0], 90, "hp_changed should emit with (current=90, max=100)")


func test_ship_destroyed_when_hp_zero():
    _player_combat_data.setup("test_ship", 100, 10, [], 10, 100)
    
    var destroyed = false
    _player_combat_data.ship_destroyed.connect(func(): destroyed = true)
    
    _player_combat_data.take_damage(200.0)
    
    assert_true(destroyed or _player_combat_data.current_hp <= 0,
        "ship_destroyed signal should fire when HP reaches 0")


func test_take_damage_reduces_part_hp():
    var weapon = WeaponData.new("wpn_01", "TestGun", WeaponData.WeaponType.MAIN_GUN, 50, 0, 10, 0, 999, 2)
    _player_combat_data.setup("test_ship", 100, 10, [weapon], 10, 100)
    
    var initial_hull = _player_combat_data.part_hp.get("hull", 100.0)
    _player_combat_data.take_damage(30.0, "hull")
    
    assert_lt(_player_combat_data.part_hp.get("hull", 100.0), initial_hull,
        "Part HP should decrease after targeted damage")


func test_part_destruction_emits_signal():
    var weapon = WeaponData.new("wpn_01", "TestGun", WeaponData.WeaponType.MAIN_GUN, 50, 0, 10, 0, 999, 2)
    _player_combat_data.setup("test_ship", 100, 10, [weapon], 10, 100)
    
    var destroyed_part = ""
    _player_combat_data.part_destroyed.connect(func(part): destroyed_part = part)
    
    # 模拟 helm 被击毁
    _player_combat_data.part_hp["helm"] = 0.0
    _player_combat_data.destroyed_parts.append("helm")
    _player_combat_data._handle_part_destruction("helm")
    
    assert_true(_player_combat_data.is_paralyzed,
        "Helm destruction should set is_paralyzed=true")
    assert_true(_player_combat_data.has_status(StatusEffect.StatusType.PARALYSIS),
        "Helm destruction should apply PARALYSIS status")


func test_weapons_slot_hp_array_initialized():
    var weapon1 = WeaponData.new("wpn_01", "Gun1", WeaponData.WeaponType.MAIN_GUN, 50, 0, 10, 0, 999, 2)
    var weapon2 = WeaponData.new("wpn_02", "Gun2", WeaponData.WeaponType.MAIN_GUN, 50, 0, 10, 0, 999, 2)
    
    _player_combat_data.setup("test_ship", 100, 10, [weapon1, weapon2], 10, 100)
    
    assert_eq(_player_combat_data.part_hp["weapon_slots"].size(), 2,
        "weapon_slots array should have entry per weapon")


## ---------- 状态效果测试 ----------


func test_apply_status_effect():
    var effect = StatusEffect.make_overheat(3, 2)
    _player_combat_data.apply_status(effect)
    
    assert_true(_player_combat_data.has_status(effect.type),
        "Status should be present after apply_status")


func test_status_severity_stacking():
    var weak_effect = StatusEffect.make_overheat(1, 1)
    var strong_effect = StatusEffect.make_overheat(3, 2)
    
    _player_combat_data.apply_status(weak_effect)
    _player_combat_data.apply_status(strong_effect)
    
    assert_true(_player_combat_data.has_status(StatusEffect.StatusType.OVERHEAT),
        "OVERHEAT status should be present")


## ---------- 移动与距离环测试 ----------


func test_move_to_ring_costs_mobility():
    _player_combat_data.setup("test_ship", 100, 10, [], 10, 100)
    _player_combat_data.mobility = 40
    _player_combat_data.current_ring = 1
    
    var moved = _player_combat_data.move_to_ring(3)
    
    assert_true(moved, "Should be able to move from ring 1 to 3 with 40 mobility")
    assert_eq(_player_combat_data.current_ring, 3,
        "Current ring should be updated after move")


func test_cannot_move_when_paralyzed():
    _player_combat_data.setup("test_ship", 100, 10, [], 10, 100)
    _player_combat_data.is_paralyzed = true
    _player_combat_data.mobility = 100
    
    var moved = _player_combat_data.move_to_ring(2)
    
    assert_false(moved, "Should NOT be able to move when paralyzed")


func test_check_game_over_all_player_ships_destroyed():
    var player_ship1 = Node2D.new()
    player_ship1.name = "Player1"
    player_ship1.set_script(load("res://src/scripts/systems/ShipEntity.gd"))
    add_child(player_ship1)
    
    var enemy_ship = Node2D.new()
    enemy_ship.name = "Enemy1"
    enemy_ship.set_script(load("res://src/scripts/systems/ShipEntity.gd"))
    add_child(enemy_ship)
    
    _battle_manager.AddShip(player_ship1)
    _battle_manager.AddShip(enemy_ship)
    
    var game_over = _battle_manager.CheckGameOver()
    assert_false(game_over, "Should not be game over when all ships alive")
    
    player_ship1.free()
    enemy_ship.free()
