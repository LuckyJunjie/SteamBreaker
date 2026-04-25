extends CanvasLayer

@onready var HealthLabel: Label = null
@onready var PhaseLabel: Label = null
@onready var ActionPanel: Panel = null

var current_health: int = 100
var max_health: int = 100

func _ready():
    print("[HUD] Initialized")
    _setup_ui()

func _setup_ui():
    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
    vbox.offset_left = 20.0
    vbox.offset_top = 20.0
    vbox.offset_right = 300.0
    vbox.offset_bottom = 200.0
    add_child(vbox)

    PhaseLabel = Label.new()
    PhaseLabel.text = "Phase: Player Turn"
    PhaseLabel.add_theme_font_size_override("font_size", 18)
    vbox.add_child(PhaseLabel)

    HealthLabel = Label.new()
    HealthLabel.text = "HP: %d / %d" % [current_health, max_health]
    HealthLabel.add_theme_font_size_override("font_size", 16)
    vbox.add_child(HealthLabel)

func UpdateHealth(current: int, maximum: int):
    current_health = current
    max_health = maximum
    if HealthLabel:
        HealthLabel.text = "HP: %d / %d" % [current, maximum]

func UpdatePhase(phase_name: String):
    if PhaseLabel:
        PhaseLabel.text = "Phase: " + phase_name

func ShowActionPanel(actions: Array[String]):
    if ActionPanel:
        ActionPanel.visible = true

func HideActionPanel():
    if ActionPanel:
        ActionPanel.visible = false
