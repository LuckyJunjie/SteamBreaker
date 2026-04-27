extends Node2D

const SHIP_RESOURCE_PATH = "res://resources/ships/SteamBreaker_Hull.tres"

var current_loadout: ShipLoadout = null

func _ready():
    print("[ShipFactory] System ready")
    # Initialize default loadout
    if current_loadout == null:
        current_loadout = ShipLoadout.new()
        current_loadout.ship_name = "蒸汽破浪号"
        current_loadout.current_hp = 100

func CreateShip(hull_resource: Resource = null) -> Node2D:
    var ship: Node2D = Node2D.new()
    ship.set_script(load("res://scripts/systems/ShipEntity.gd"))
    add_child(ship)
    return ship

func SpawnShipAt(resource_path: String, position: Vector2) -> Node2D:
    var res: Resource = load(resource_path) if resource_path != "" else load(SHIP_RESOURCE_PATH)
    var ship: Node2D = CreateShip(res)
    ship.position = position
    return ship

func GetDefaultHull() -> Resource:
    return load(SHIP_RESOURCE_PATH)

## Get current ship loadout
func get_current_loadout() -> ShipLoadout:
    return current_loadout

## Apply a loadout to the current ship
func apply_loadout(loadout: ShipLoadout) -> void:
    if loadout == null:
        return
    current_loadout = loadout.duplicate()
    print("[ShipFactory] Loadout applied: %s (HP=%d/%d)" % [
        current_loadout.ship_name,
        current_loadout.current_hp,
        current_loadout.get_max_hp()])
