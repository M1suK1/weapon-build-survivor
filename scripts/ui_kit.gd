extends RefCounted
class_name UIKit
## UI 底座：统一按钮样式、返回键、tooltip。
## 所有界面都从这里取控件，避免每个面板各写一套 StyleBox。
##
## 设计约束（见 docs/plan-ui-v1.md §1.2）：
## - 可点元素最小 28×28
## - hover 白边 + 亮度提升 + 手型光标
## - press 缩小到 0.96 回弹
## - 禁用态亮度 45%，但仍显示 tooltip 说明缺什么

const C_TEXT := Color(0.90, 0.94, 1.0)
const C_DIM := Color(0.62, 0.68, 0.78)
const C_GOLD := Color(0.98, 0.84, 0.45)
const C_BLUE := Color(0.52, 0.76, 1.0)
const C_GREEN := Color(0.55, 0.90, 0.66)
const C_RED := Color(0.98, 0.45, 0.45)
const C_PANEL := Color(0.10, 0.12, 0.17, 0.97)
const C_PANEL_HOVER := Color(0.17, 0.20, 0.27, 0.99)


static func _sb(bg: Color, border: Color, w: int, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## 标准按钮：尺寸、配色、悬停/按下/禁用四套样式一次配好
static func button(text: String, size: Vector2, accent: Color = C_BLUE, font_size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.size = size
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64))

	b.add_theme_stylebox_override("normal", _sb(C_PANEL, accent * Color(1, 1, 1, 0.55), 1, 8))
	b.add_theme_stylebox_override("hover", _sb(C_PANEL_HOVER, accent, 2, 8))
	b.add_theme_stylebox_override("pressed", _sb(accent * Color(1, 1, 1, 0.25), accent, 2, 8))
	b.add_theme_stylebox_override("focus", _sb(C_PANEL_HOVER, accent, 2, 8))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.09, 0.10, 0.13, 0.9), Color(0.3, 0.32, 0.38, 0.6), 1, 8))
	return b


## 小号方形图标按钮（× / ← / 锁）
static func icon_button(glyph: String, side: float = 30.0, accent: Color = C_DIM) -> Button:
	var b := button(glyph, Vector2(side, side), accent, 18)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 右上角关闭按钮
static func close_button(parent: Control, on_press: Callable, margin: float = 18.0) -> Button:
	var b := icon_button("×", 34.0, C_RED)
	b.position = Vector2(1280.0 - margin - 34.0, margin)
	b.tooltip_text = "关闭（ESC / 右键）"
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## 左上角返回按钮
static func back_button(parent: Control, text: String, on_press: Callable, pos: Vector2 = Vector2(24, 18)) -> Button:
	var b := button("← " + text, Vector2(132, 34), C_DIM, 16)
	b.position = pos
	b.tooltip_text = "返回（ESC / 右键）"
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## 给控件挂 tooltip（Godot 用 tooltip_text，这里只是统一入口，方便以后加延迟显示）
static func hint(c: Control, text: String) -> void:
	c.tooltip_text = text


## 半透明遮罩
static func dim(parent: Control, alpha: float = 0.90) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.04, 0.07, alpha)
	r.size = Vector2(1280, 720)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)
	return r


## 画布缩放诊断：把 viewport / content scale / 控件全局矩形打出来。
## 用于验证「设计基准 1280×720 但 global_rect 是 2560×1440」这件事。
static func diag(node: Node, c: Control = null) -> String:
	var vp := node.get_viewport()
	var s := "viewport=%s content_scale=%s factor=%.2f stretch=%d" % [
		str(vp.get_visible_rect().size),
		str(vp.content_scale_size),
		vp.get_visible_rect().size.x / 1280.0,
		int(vp.content_scale_mode)]
	if c != null:
		s += " control_rect=%s" % str(c.get_global_rect())
	return s
