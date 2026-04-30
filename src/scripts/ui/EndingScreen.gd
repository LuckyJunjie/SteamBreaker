extends CanvasLayer

## EndingScreen.gd - 结局画面控制器
## 显示结局类型名称、描述文字、"返回标题"按钮

signal ending_screen_closed()

# 结局类型映射
const ENDING_NAMES: Dictionary = {
    0: "普通隐退",
    1: "伙伴结局",
    2: "富豪结局",
    3: "传说结局",
    4: "悲剧结局",
    5: "未知结局"
}

const ENDING_COLORS: Dictionary = {
    0: Color(0.3, 0.5, 0.7, 1.0),    # 普通隐退 - 蓝色
    1: Color(0.9, 0.6, 0.3, 1.0),    # 伙伴结局 - 金色
    2: Color(0.8, 0.7, 0.2, 1.0),    # 富豪结局 - 明黄
    3: Color(0.7, 0.3, 0.9, 1.0),    # 传说结局 - 紫色
    4: Color(0.5, 0.2, 0.2, 1.0),    # 悲剧结局 - 暗红
    5: Color(0.4, 0.4, 0.4, 1.0)     # 未知 - 灰色
}

var _ending_type: int = 5
var _narrative_text: String = ""
var _slide_index: int = 0
var _slides: Array[String] = []
var _fade_overlay: ColorRect = null

func _ready() -> void:
    print("[EndingScreen] Ready")
    _setup_ui()

func setup(ending_type: int, narrative: String) -> void:
    _ending_type = ending_type
    _narrative_text = narrative
    _slide_index = 0
    
    # 分割旁白文本为幻灯片
    _slides = narrative.split("\n", true)
    
    # 刷新 UI
    _update_display()
    print("[EndingScreen] Setup with ending_type=%d" % ending_type)

func _setup_ui() -> void:
    # 深色背景
    var bg = ColorRect.new()
    bg.name = "Background"
    bg.color = Color(0.05, 0.05, 0.10, 0.98)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    
    # 淡入叠加层
    _fade_overlay = ColorRect.new()
    _fade_overlay.name = "FadeOverlay"
    _fade_overlay.color = Color(0, 0, 0, 1.0)
    _fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade_overlay.z_index = 100
    add_child(_fade_overlay)
    
    # 中央容器
    var center = CenterContainer.new()
    center.name = "CenterContainer"
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    
    var vbox = VBoxContainer.new()
    vbox.name = "MainVBox"
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 20)
    center.add_child(vbox)
    
    # 结局类型标签
    var ending_label = Label.new()
    ending_label.name = "EndingLabel"
    ending_label.text = ENDING_NAMES.get(_ending_type, "未知结局")
    ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ending_label.add_theme_color_override("font_color", ENDING_COLORS.get(_ending_type, Color.WHITE))
    ending_label.add_theme_font_size_override("font_size", 48)
    ending_label.name = "EndingTypeLabel"
    vbox.add_child(ending_label)
    
    # 分隔装饰线
    var separator = ColorRect.new()
    separator.name = "Separator"
    separator.custom_minimum_size = Vector2(300, 2)
    separator.color = Color(0.4, 0.5, 0.6, 0.5)
    vbox.add_child(separator)
    
    # 旁白文本区域
    var narrative_label = Label.new()
    narrative_label.name = "NarrativeLabel"
    narrative_label.text = _narrative_text
    narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    narrative_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
    narrative_label.add_theme_font_size_override("font_size", 22)
    narrative_label.name = "NarrativeLabel"
    vbox.add_child(narrative_label)
    
    # 间隔
    var spacer = Control.new()
    spacer.custom_minimum_size.y = 60
    vbox.add_child(spacer)
    
    # 返回标题按钮
    var return_btn = Button.new()
    return_btn.text = "⚓ 返回标题"
    return_btn.custom_minimum_size = Vector2(200, 50)
    return_btn.pressed.connect(_on_return_title_pressed)
    
    var normal_style = StyleBoxFlat.new()
    normal_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
    normal_style.set_corner_radius_all(6)
    normal_style.set_border_width_all(1)
    normal_style.border_color = Color(0.35, 0.50, 0.65, 0.7)
    return_btn.add_theme_stylebox_override("normal", normal_style)
    
    var hover_style = StyleBoxFlat.new()
    hover_style.bg_color = Color(0.12, 0.18, 0.26, 0.95)
    hover_style.set_corner_radius_all(6)
    hover_style.set_border_width_all(1)
    hover_style.border_color = Color(0.60, 0.80, 1.0, 0.9)
    return_btn.add_theme_stylebox_override("hover", hover_style)
    
    var pressed_style = StyleBoxFlat.new()
    pressed_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
    pressed_style.set_corner_radius_all(6)
    pressed_style.set_border_width_all(1)
    pressed_style.border_color = Color(0.50, 0.70, 0.90, 0.8)
    return_btn.add_theme_stylebox_override("pressed", pressed_style)
    
    return_btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
    return_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
    return_btn.add_theme_font_size_override("font_size", 18)
    
    vbox.add_child(return_btn)
    
    # 淡入动画
    _fade_overlay.color.a = 1.0
    var tween = create_tween()
    tween.tween_property(_fade_overlay, "color:a", 0.0, 1.5)

func _update_display() -> void:
    var ending_lbl = find_child("EndingTypeLabel", true, false)
    if ending_lbl:
        ending_lbl.text = ENDING_NAMES.get(_ending_type, "未知结局")
        ending_lbl.add_theme_color_override("font_color", ENDING_COLORS.get(_ending_type, Color.WHITE))
    
    var narrative_lbl = find_child("NarrativeLabel", true, false)
    if narrative_lbl:
        narrative_lbl.text = _narrative_text

func _on_return_title_pressed() -> void:
    print("[EndingScreen] Return to title pressed")
    _fade_to_black()
    await get_tree().create_timer(0.8).timeout
    ending_screen_closed.emit()
    
    # 切换到标题画面
    get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _fade_to_black() -> void:
    var tween = create_tween()
    tween.tween_property(_fade_overlay, "color:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
    # 按任意键或点击继续（如果有多张幻灯片的话）
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _advance_slide()

func _advance_slide() -> void:
    if _slide_index < _slides.size() - 1:
        _slide_index += 1
        # 更新旁白（如果有幻灯片逻辑的话）
        print("[EndingScreen] Slide %d/%d" % [_slide_index + 1, _slides.size()])