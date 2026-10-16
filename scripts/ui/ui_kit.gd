class_name UiKit
extends RefCounted
## Shared colours, theme and small widget helpers for the greybox screens.
## Greybox only: final look comes from the Design Officer's style frames.

const BG := Color("1b2327")
const PANEL := Color("24313a")
const TEXT := Color("eef2f4")
const TEXT_DIM := Color("a9b6bd")
const ACCENT := Color("ffc93c")
const ACCENT_TEXT := Color("1b2327")


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT_TEXT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT_TEXT)
	t.set_stylebox("normal", "Button", _box(PANEL))
	t.set_stylebox("hover", "Button", _box(PANEL.lightened(0.08)))
	t.set_stylebox("pressed", "Button", _box(ACCENT))
	t.set_stylebox("hover_pressed", "Button", _box(ACCENT))
	t.set_stylebox("disabled", "Button", _box(PANEL.darkened(0.3)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 18))
	return t


static func _box(col: Color, radius: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(radius)
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 14
	b.content_margin_bottom = 14
	return b


static func label(text: String, font_size: int = 30, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, min_height: int = 88) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	return b


## Main action on a screen: filled accent colour so it stands out on any panel.
static func primary_button(text: String, min_height: int = 88) -> Button:
	var b := button(text, min_height)
	b.add_theme_stylebox_override("normal", _box(ACCENT))
	b.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.1)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ACCENT_TEXT)
	return b


## Secondary action on a panel: a lighter fill than the panel behind it.
static func panel_button(text: String, min_height: int = 80) -> Button:
	var b := button(text, min_height)
	b.add_theme_stylebox_override("normal", _box(PANEL.lightened(0.12)))
	b.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.2)))
	return b


## Full-screen root with safe margins, background and theme.
static func screen(root: Control) -> VBoxContainer:
	root.theme = make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	return col
