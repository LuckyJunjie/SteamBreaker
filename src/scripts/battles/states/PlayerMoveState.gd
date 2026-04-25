extends BattleState

## PLAYER_MOVE — 玩家选择移动至目标射程环

signal move_confirmed(target_ring: int)

var selected_ring: int = -1
var is_waiting_input: bool = true

func _init(sm: BattleStateMachine) -> void:
    super._init(sm)
    name = "PLAYER_MOVE"

func enter() -> void:
    selected_ring = -1
    is_waiting_input = true
    print("[PlayerMove] 选择移动射程环（可跳过）")
    # 通知UI显示射程环
    _show_range_rings()

func _show_range_rings() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_range_ring_ui"):
        tm.show_range_ring_ui(true)

func handle_input(event: InputEvent) -> void:
    if not is_waiting_input:
        return

    # 跳过按钮（键盘 S 或 UI按钮）
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_S:
                _skip_move()
                return

    # 点击射程环
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _on_ring_click(int(event.position.x / 200) + 1)  # 简化: 根据x坐标判断

func _on_ring_click(ring: int) -> void:
    if ring < 1 or ring > 3:
        return
    selected_ring = ring
    _execute_move(ring)

func _execute_move(target_ring: int) -> void:
    is_waiting_input = false
    var tm: Node = get_turn_manager()
    if not tm or not tm.has_method("get_player_ship"):
        state_machine.set_state("PLAYER_ACTION")
        return

    var ship: ShipCombatData = tm.get_player_ship()
    if not ship:
        state_machine.set_state("PLAYER_ACTION")
        return

    # 已经在目标环
    if target_ring == ship.current_ring:
        print("[PlayerMove] 已在环%d，无移动" % target_ring)
        _on_move_complete()
        return

    # 机动值检查
    if not ship.can_move():
        print("[PlayerMove] 无法移动（瘫痪/过热）")
        state_machine.set_state("PLAYER_ACTION")
        return

    var cost: int = ship.get_mobility_cost_to_ring(target_ring)
    if cost > ship.mobility or cost == 999:
        print("[PlayerMove] 机动值不足: 需要%d, 现有%d" % [cost, ship.mobility])
        # 提示UI机动值不足
        _show_insufficient_mobility()
        return

    # 执行移动
    if ship.move_to_ring(target_ring):
        print("[PlayerMove] 移动至环%d，消耗%d机动值" % [target_ring, cost])
        _on_move_complete()
    else:
        state_machine.set_state("PLAYER_ACTION")

func _skip_move() -> void:
    is_waiting_input = false
    print("[PlayerMove] 跳过移动")
    _on_move_complete()

func _on_move_complete() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_range_ring_ui"):
        tm.show_range_ring_ui(false)
    state_machine.set_state("PLAYER_ACTION")

func _show_insufficient_mobility() -> void:
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_notification"):
        tm.show_notification("机动值不足！")

func update(delta: float) -> void:
    pass

func exit() -> void:
    is_waiting_input = false
    var tm: Node = get_turn_manager()
    if tm and tm.has_method("show_range_ring_ui"):
        tm.show_range_ring_ui(false)
