class_name DialogueBox
extends Control

## 对话框UI
## 底部面板：头像 + 名字 + 文本 + 选项按钮
## 支持点击/空格键推进，带打字机效果

signal dialogue_ended()
signal option_selected(option_index: int, option_text: String)

const MOOD_EMOJIS: Dictionary = {
    "neutral": "",
    "happy": "😊",
    "angry": "😠",
    "sad": "😢",
    "proud": "😤",
    "peaceful": "🌊",
    "scared": "😨",
    "surprised": "😲"
}

const PORTRAIT_COLORS: Dictionary = {
    "neutral": Color(0.3, 0.3, 0.4),
    "happy": Color(0.4, 0.6, 0.4),
    "angry": Color(0.6, 0.3, 0.3),
    "sad": Color(0.3, 0.3, 0.5),
    "proud": Color(0.5, 0.4, 0.2),
    "peaceful": Color(0.2, 0.5, 0.6),
    "scared": Color(0.4, 0.35, 0.5),
    "surprised": Color(0.5, 0.5, 0.3)
}

# 打字机效果
const TYPEWRITER_SPEED: float = 0.03  # 每字符秒数
const TYPEWRITER_SPEED_FAST: float = 0.005

var _full_text: String = ""
var _displayed_text: String = ""
var _typewriter_active: bool = false
var _typewriter_timer: float = 0.0
var _typewriter_idx: int = 0
var _current_options: Array[Dictionary] = []
var _is_waiting_for_input: bool = false

# 节点引用
var _panel: PanelContainer = null
var _portrait: TextureRect = null
var _name_label: Label = null
var _mood_label: Label = null
var _text_label: RichTextLabel = null
var _options_vbox: VBoxContainer = null

# 样式
var _option_style_normal: StyleBoxFlat = null
var _option_style_hover: StyleBoxFlat = null
var _option_style_pressed: StyleBoxFlat = null

var _can_skip: bool = false

func _ready() -> void:
    _find_nodes()
    _build_option_styles()
    _connect_input()
    _panel.visible = false


func _find_nodes() -> void:
    _panel = $PanelContainer
    _portrait = $PanelContainer/VBox/HeaderRow/Portrait
    _name_label = $PanelContainer/VBox/HeaderRow/NameLabelContainer/NameLabel
    _mood_label = $PanelContainer/VBox/HeaderRow/MoodLabel
    _text_label = $PanelContainer/VBox/TextLabel
    _options_vbox = $PanelContainer/VBox/OptionsVBox


func _build_option_styles() -> void:
    _option_style_normal = StyleBoxFlat.new()
    _option_style_normal.bg_color = Color(0.12, 0.14, 0.2, 0.9)
    _option_style_normal.border_width_left = 1
    _option_style_normal.border_width_right = 1
    _option_style_normal.border_width_top = 1
    _option_style_normal.border_width_bottom = 1
    _option_style_normal.border_color = Color(0.35, 0.3, 0.18, 0.6)
    _option_style_normal.corner_radius_top_left = 6
    _option_style_normal.corner_radius_top_right = 6
    _option_style_normal.corner_radius_bottom_right = 6
    _option_style_normal.corner_radius_bottom_left = 6
    _option_style_normal.content_margin_left = 12
    _option_style_normal.content_margin_right = 12
    _option_style_normal.content_margin_top = 8
    _option_style_normal.content_margin_bottom = 8

    _option_style_hover = _option_style_normal.duplicate()
    _option_style_hover.bg_color = Color(0.2, 0.22, 0.32, 0.95)
    _option_style_hover.border_color = Color(0.6, 0.5, 0.25, 0.85)

    _option_style_pressed = _option_style_normal.duplicate()
    _option_style_pressed.bg_color = Color(0.08, 0.1, 0.16, 0.95)
    _option_style_pressed.border_color = Color(0.5, 0.4, 0.2, 0.7)


func _connect_input() -> void:
    # 点击任意位置推进对话
    mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
    if not _panel.visible:
        return

    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
            _handle_input_action()


func _gui_input(event: InputEvent) -> void:
    if not _panel.visible:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_input_action()


func _handle_input_action() -> void:
    if _typewriter_active:
        # 跳过打字机，直接显示完整文本
        _skip_typewriter()
    elif _is_waiting_for_input and _current_options.is_empty():
        # 无选项，直接结束
        _finish_dialogue()
    elif not _is_waiting_for_input:
        # 有选项时点击不推进（需要点选项）
        pass


func _skip_typewriter() -> void:
    _typewriter_active = false
    _displayed_text = _full_text
    _text_label.text = _full_text
    _is_waiting_for_input = true
    _update_options_visibility()


## ---------- 公开API ----------

func show_dialogue(speaker_name: String, text: String, mood: String = "neutral", options: Array[Dictionary] = [], portrait_color: Color = Color(0.3, 0.3, 0.4)) -> void:
    """
    显示一段对话。
    options: [{"text": "...", "affection_delta": int}, ...]
    """
    _panel.visible = true
    _can_skip = true

    # 名字
    _name_label.text = speaker_name

    # 情绪标签
    var emoji: String = MOOD_EMOJIS.get(mood, "")
    _mood_label.text = emoji

    # 头像颜色
    _portrait.self_modulate = portrait_color

    # 选项
    _current_options = options.duplicate()
    _build_option_buttons()

    # 打字机效果
    _start_typewriter(text)


func _start_typewriter(text: String) -> void:
    _full_text = text
    _displayed_text = ""
    _typewriter_idx = 0
    _typewriter_active = true
    _is_waiting_for_input = false
    _text_label.text = ""


func _process(delta: float) -> void:
    if not _typewriter_active:
        return

    _typewriter_timer += delta
    var speed: float = TYPEWRITER_SPEED

    if _typewriter_timer >= speed:
        _typewriter_timer = 0.0
        if _typewriter_idx < _full_text.length():
            _displayed_text += _full_text[_typewriter_idx]
            _text_label.text = _displayed_text
            _typewriter_idx += 1
        else:
            _typewriter_active = false
            _is_waiting_for_input = true
            _update_options_visibility()


func _build_option_buttons() -> void:
    for child in _options_vbox.get_children():
        child.queue_free()

    for i in range(_current_options.size()):
        var opt: Dictionary = _current_options[i]
        var btn = Button.new()
        btn.text = "▸ " + opt.get("text", "")
        btn.custom_minimum_size.y = 40
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.add_theme_stylebox_override("normal", _option_style_normal.duplicate())
        btn.add_theme_stylebox_override("hover", _option_style_hover.duplicate())
        btn.add_theme_stylebox_override("pressed", _option_style_pressed.duplicate())
        btn.pressed.connect(_on_option_pressed.bind(i))
        _options_vbox.add_child(btn)


func _update_options_visibility() -> void:
    # 选项始终显示（打字完成后才可点击）
    pass


func _on_option_pressed(index: int) -> void:
    if index < 0 or index >= _current_options.size():
        return
    var opt: Dictionary = _current_options[index]
    option_selected.emit(index, opt.get("text", ""))
    _finish_dialogue()


func _finish_dialogue() -> void:
    _panel.visible = false
    _can_skip = false
    dialogue_ended.emit()


func is_visible() -> bool:
    return _panel.visible
