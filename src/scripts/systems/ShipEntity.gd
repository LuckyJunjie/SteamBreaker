extends Node2D
class_name ShipEntity

var hull: Resource = null
var current_hp: int = 100
var is_player: bool = false
var faction: String = "neutral"

func _ready():
    print("[ShipEntity] Initialized")

func Initialize(hull_resource: Resource, player: bool = false):
    hull = hull_resource
    is_player = player
    if hull:
        current_hp = hull.max_hp
    print("[ShipEntity] Setup: ", hull.hull_name if hull else "No Hull")

func IsPlayer() -> bool:
    return is_player

func TakeDamage(amount: int):
    var dmg: int = max(1, amount - (hull.armor if hull else 0))
    current_hp = max(0, current_hp - dmg)
    print("[ShipEntity] Took %d damage, HP: %d/%d" % [dmg, current_hp, hull.max_hp if hull else 100])

func Heal(amount: int):
    current_hp = min(hull.max_hp if hull else 100, current_hp + amount)
