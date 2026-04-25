extends Node2D

const SHIP_RESOURCE_PATH = "res://resources/ships/SteamBreaker_Hull.tres"

func _ready():
    print("[ShipFactory] System ready")

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
