class_name FloatingText
extends Node2D

## 浮动文字节点 - 显示伤害数字、状态提示等
## 可用作战斗中的伤害弹出、miss提示等

var text_label: Label = null
var _lifetime: float = 0.0
var _max_lifetime: float = 1.5
var _velocity: Vector2 = Vector2.ZERO
var _fade_out: bool = true

func _ready() -> void:
    text_label = Label.new()
    text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    text_label.z_index = 100
    add_child(text_label)

    # 默认样式
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.content_margin_left = 4
    style.content_margin_right = 4
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    text_label.add_theme_stylebox_override("normal", style)

func _process(delta: float) -> void:
    _lifetime += delta
    position += _velocity * delta

    # 上移减速
    _velocity.y = lerp(_velocity.y, 0.0, delta * 3.0)

    if _lifetime >= _max_lifetime:
        queue_free()
    elif _fade_out and _lifetime >= _max_lifetime * 0.6:
        # 后期淡出
        var alpha: float = 1.0 - ((_lifetime - _max_lifetime * 0.6) / (_max_lifetime * 0.4))
        modulate.a = maxf(0.0, alpha)

## 显示伤害数字
func show_damage(damage: float, is_crit: bool, screen_pos: Vector2) -> void:
    global_position = screen_pos
    text_label.text = "%.0f" % damage
    if is_crit:
        text_label.text += " CRIT!"
        text_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
        text_label.add_theme_font_size_override("font_size", 26)
        modulate = Color(1.0, 0.8, 0.8)
        _max_lifetime = 2.0
    else:
        text_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
        text_label.add_theme_font_size_override("font_size", 22)

    _velocity = Vector2(randf_range(-15.0, 15.0), -80.0)
    _fade_out = true

    get_tree().root.add_child(self)

## 显示Miss
func show_miss(screen_pos: Vector2) -> void:
    global_position = screen_pos
    text_label.text = "MISS"
    text_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    text_label.add_theme_font_size_override("font_size", 18)

    _velocity = Vector2(randf_range(-10.0, 10.0), -60.0)
    _max_lifetime = 1.0
    _fade_out = true

    get_tree().root.add_child(self)

## 显示状态效果（烧伤/减速等图标+名称）
func show_status(status_name: String, color: Color, screen_pos: Vector2) -> void:
    global_position = screen_pos
    text_label.text = "🔥 " if status_name.to_lower().contains("fire") else "❄️ "
    text_label.text += status_name
    text_label.add_theme_color_override("font_color", color)
    text_label.add_theme_font_size_override("font_size", 16)

    _velocity = Vector2(randf_range(-5.0, 5.0), -50.0)
    _max_lifetime = 1.5
    _fade_out = true

    get_tree().root.add_child(self)

## 显示通用提示（飘到屏幕中央）
func show_message(msg: String, color: Color, screen_pos: Vector2, lifetime: float = 2.0) -> void:
    global_position = screen_pos
    text_label.text = msg
    text_label.add_theme_color_override("font_color", color)
    text_label.add_theme_font_size_override("font_size", 20)

    _velocity = Vector2(0, -30.0)
    _max_lifetime = lifetime
    _fade_out = true

    get_tree().root.add_child(self)