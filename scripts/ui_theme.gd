class_name UITheme
extends RefCounted
## Единый стиль интерфейса «Золотой Фокус» (арт-деко):
## тёмное стекло + золото + слоновая кость. Подключай через
## const UITheme := preload("res://scripts/ui_theme.gd") и вызывай статические funcs.

const GOLD := Color(0.9, 0.72, 0.25)
const GOLD_BRIGHT := Color(1.0, 0.84, 0.4)
const GOLD_DIM := Color(0.9, 0.72, 0.25, 0.42)
const CREAM := Color(0.95, 0.91, 0.8)
const INK := Color(0.06, 0.075, 0.11)


## Основная панель: тёмное стекло, золотая рамка, мягкая тень.
static func panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.07, 0.105, 0.97)
	sb.set_corner_radius_all(14)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.set_content_margin_all(18)
	return sb


## Карточка внутри панели.
static func card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.17, 0.92)
	sb.set_corner_radius_all(9)
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	return sb


## Заголовок: золото, крупно.
static func title(label: Label) -> void:
	label.add_theme_color_override("font_color", GOLD_BRIGHT)
	label.add_theme_font_size_override("font_size", 24)


## Золотая кнопка (главное действие).
static func gold_button(b: Button, big := false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = GOLD_BRIGHT
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.72, 0.55, 0.16)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.32, 0.3, 0.24, 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.72, 0.7, 0.62, 0.75))
	b.add_theme_font_size_override("font_size", 20 if big else 17)


## Тёмная кнопка с золотой рамкой (выбор ставки/цвета/переключатель).
static func dark_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.15, 0.2)
	normal.set_corner_radius_all(8)
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_content_margin_all(9)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.2, 0.23, 0.3)
	hover.border_color = GOLD
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = GOLD
	pressed.border_color = GOLD
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_size_override("font_size", 16)
