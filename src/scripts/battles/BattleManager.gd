extends Node2D
class_name BattleManager

enum Phase { PLAYER_TURN, ENEMY_TURN, ANIMATING, GAME_OVER }

var current_phase: Phase = Phase.PLAYER_TURN
var selected_ship: Node2D = null
var ships: Array[Node2D] = []

signal phase_changed(phase: Phase)
signal turn_ended()

func _ready():
    print("[BattleManager] Battle initialized")

func _process(delta):
    pass

func StartBattle():
    current_phase = Phase.PLAYER_TURN
    phase_changed.emit(current_phase)
    print("[BattleManager] Battle started")

func EndTurn():
    if current_phase == Phase.PLAYER_TURN:
        current_phase = Phase.ENEMY_TURN
    elif current_phase == Phase.ENEMY_TURN:
        current_phase = Phase.PLAYER_TURN
    phase_changed.emit(current_phase)
    turn_ended.emit()
    print("[BattleManager] Phase: ", Phase.keys()[current_phase])

func SelectShip(ship: Node2D):
    selected_ship = ship
    print("[BattleManager] Selected ship: ", ship.name)

func AddShip(ship: Node2D):
    ships.append(ship)

func GetShipsInRange(origin: Vector2, min_range: float, max_range: float) -> Array[Node2D]:
    var result: Array[Node2D] = []
    for ship in ships:
        var dist: float = origin.distance_to(ship.position)
        if dist >= min_range and dist <= max_range:
            result.append(ship)
    return result

func CheckGameOver() -> bool:
    var player_ships: int = 0
    var enemy_ships: int = 0
    for ship in ships:
        if ship.has_method("IsPlayer") and ship.IsPlayer():
            player_ships += 1
        else:
            enemy_ships += 1
    if player_ships == 0 or enemy_ships == 0:
        current_phase = Phase.GAME_OVER
        phase_changed.emit(current_phase)
        return true
    return false
