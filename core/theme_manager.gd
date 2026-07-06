extends Node

# ═══════════════════════════════════════════════════════════════
# THEME MANAGER — Космическая тема UI для ZooPark: Тау Цети
# Autoload: создаёт и применяет тему глобально
# ═══════════════════════════════════════════════════════════════

# === ПАЛИТРА ЦВЕТОВ ===
const COL_BG_DARKEST    = Color("#060a14")  # Самый тёмный фон
const COL_BG_DARK       = Color("#0c1222")  # Основной тёмный фон
const COL_BG_PANEL      = Color("#111a30")  # Фон панелей
const COL_BG_SECONDARY  = Color("#162040")  # Вторичный фон (вкладки, поля)
const COL_BG_TERTIARY   = Color("#1c2850")  # Третичный фон (hover)
const COL_BG_INPUT      = Color("#0e1628")  # Фон полей ввода

const COL_ACCENT        = Color("#00d4ff")  # Основной акцент — бирюзовый
const COL_ACCENT_DIM    = Color("#0088aa")  # Приглушённый акцент
const COL_ACCENT_GLOW   = Color("#00d4ff40") # Свечение акцента (40% прозрачность)
const COL_ACCENT_PURPLE = Color("#7c3aed")  # Фиолетовый акцент

const COL_TEXT          = Color("#e0e8f5")  # Основной текст
const COL_TEXT_DIM      = Color("#6b7fa0")  # Приглушённый текст
const COL_TEXT_ACCENT   = Color("#00d4ff")  # Акцентный текст

const COL_BORDER        = Color("#1e3050")  # Рамки
const COL_BORDER_FOCUS  = Color("#00d4ff")  # Рамка фокуса
const COL_BORDER_HOVER  = Color("#00a0cc")  # Рамка при наведении

const COL_HOVER         = Color("#1a2d50")  # Фон при наведении
const COL_PRESSED       = Color("#0a2040")  # Фон при нажатии
const COL_DISABLED      = Color("#0a0e18")  # Фон disabled
const COL_DISABLED_TEXT = Color("#3a4a60")  # Текст disabled

const COL_SLIDER_BG     = Color("#0e1628")  # Фон слайдера
const COL_SLIDER_FILL   = Color("#00d4ff")  # Заполнение слайдера
const COL_SLIDER_GRAB   = Color("#00eeff")  # Ручка слайдера

const COL_CHECK_ON      = Color("#00d4ff")  # Чекбокс включён
const COL_CHECK_OFF     = Color("#2a3a55")  # Чекбокс выключен

const COL_TAB_ACTIVE    = Color("#162040")  # Активная вкладка
const COL_TAB_INACTIVE  = Color("#0c1222")  # Неактивная вкладка

const CORNER_RADIUS     = 6
const BORDER_WIDTH      = 1

var theme: Theme
var font_regular: Font
var font_bold: Font

func _ready():
	_load_fonts()
	theme = Theme.new()
	_setup_default_font()
	_setup_button()
	_setup_label()
	_setup_hslider()
	_setup_checkbox()
	_setup_option_button()
	_setup_tab_container()
	_setup_panel_container()
	_setup_margin_container()
	_setup_scroll_container()
	_setup_separator()
	_setup_popup_menu()
	_setup_confirmation_dialog()
	
	# Применяем тему глобально ко всему дереву сцен
	get_tree().root.theme = theme

# ========== ШРИФТЫ ==========
func _load_fonts():
	var font_path = "res://assets/fonts/Exo2-VariableFont_wght.ttf"
	if ResourceLoader.exists(font_path):
		var font_data = load(font_path)
		if font_data:
			font_regular = font_data
			font_bold = font_data  # Variable font — используем вариации
	
	if not font_regular:
		font_regular = ThemeDB.fallback_font
	if not font_bold:
		font_bold = ThemeDB.fallback_font

func _setup_default_font():
	theme.default_font = font_regular
	theme.default_font_size = 16

# ========== STYLEBOXES УТИЛИТЫ ==========
func _make_flat(bg_color: Color, border_color := Color.TRANSPARENT, 
	corner := CORNER_RADIUS, border := 0, content_margin := 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = float(content_margin)
	sb.content_margin_right = float(content_margin)
	sb.content_margin_top = float(content_margin) / 2.0
	sb.content_margin_bottom = float(content_margin) / 2.0
	return sb

func _make_empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

# ========== BUTTON ==========
func _setup_button():
	# StyleBoxes для разных состояний
	var normal = _make_flat(Color.TRANSPARENT, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 16)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover = _make_flat(COL_HOVER, COL_BORDER_HOVER, CORNER_RADIUS, BORDER_WIDTH, 16)
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	
	var pressed = _make_flat(COL_PRESSED, COL_ACCENT, CORNER_RADIUS, 2, 16)
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8
	
	var disabled = _make_flat(COL_DISABLED, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 16)
	disabled.content_margin_top = 8
	disabled.content_margin_bottom = 8
	
	var focus = _make_flat(Color.TRANSPARENT, COL_BORDER_FOCUS, CORNER_RADIUS, 2, 16)
	focus.content_margin_top = 8
	focus.content_margin_bottom = 8
	
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_ACCENT)
	theme.set_color("font_pressed_color", "Button", COL_TEXT)
	theme.set_color("font_disabled_color", "Button", COL_DISABLED_TEXT)
	theme.set_color("font_focus_color", "Button", COL_ACCENT)
	
	theme.set_font_size("font_size", "Button", 16)

# ========== LABEL ==========
func _setup_label():
	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_stylebox("normal", "Label", _make_empty())

# ========== HSLIDER ==========
func _setup_hslider():
	# Дорожка слайдера (фон)
	var slider_bg = _make_flat(COL_SLIDER_BG, COL_BORDER, 3, 1, 0)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	slider_bg.content_margin_left = 0
	slider_bg.content_margin_right = 0
	
	# Заполненная часть
	var slider_fill = _make_flat(COL_ACCENT_DIM, Color.TRANSPARENT, 3, 0, 0)
	slider_fill.content_margin_top = 4
	slider_fill.content_margin_bottom = 4
	slider_fill.content_margin_left = 0
	slider_fill.content_margin_right = 0
	
	# Ручка (grabber) — через StyleBoxFlat создаём квадратную ручку
	var grabber_normal = _make_flat(COL_SLIDER_GRAB, COL_ACCENT, 10, 2, 0)
	var grabber_hover = _make_flat(Color.WHITE, COL_ACCENT, 10, 2, 0)
	var grabber_disabled = _make_flat(COL_DISABLED, COL_BORDER, 10, 1, 0)
	
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	
	# Иконки ручки
	theme.set_constant("grabber_offset", "HSlider", 0)
	theme.set_constant("center_grabber", "HSlider", 1)
	
	# Размер
	theme.set_constant("slider_min_size", "HSlider", 24)

# ========== CHECKBOX ==========
func _setup_checkbox():
	var normal = _make_flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4)
	var hover = _make_flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4)
	var pressed = _make_flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4)
	var focus = _make_flat(Color.TRANSPARENT, COL_BORDER_FOCUS, CORNER_RADIUS, 1, 4)
	
	theme.set_stylebox("normal", "CheckBox", normal)
	theme.set_stylebox("hover", "CheckBox", hover)
	theme.set_stylebox("pressed", "CheckBox", pressed)
	theme.set_stylebox("hover_pressed", "CheckBox", hover)
	theme.set_stylebox("focus", "CheckBox", focus)
	
	theme.set_color("font_color", "CheckBox", COL_TEXT)
	theme.set_color("font_hover_color", "CheckBox", COL_ACCENT)
	theme.set_color("font_pressed_color", "CheckBox", COL_ACCENT)
	
	theme.set_font_size("font_size", "CheckBox", 16)
	
	# Размеры иконок чекбокса
	theme.set_constant("check_v_offset", "CheckBox", 0)

# ========== OPTION BUTTON ==========
func _setup_option_button():
	var normal = _make_flat(COL_BG_INPUT, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 12)
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	
	var hover = _make_flat(COL_BG_TERTIARY, COL_BORDER_HOVER, CORNER_RADIUS, BORDER_WIDTH, 12)
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	
	var pressed = _make_flat(COL_PRESSED, COL_ACCENT, CORNER_RADIUS, 2, 12)
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	
	var disabled = _make_flat(COL_DISABLED, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 12)
	disabled.content_margin_top = 6
	disabled.content_margin_bottom = 6
	
	var focus = _make_flat(COL_BG_INPUT, COL_BORDER_FOCUS, CORNER_RADIUS, 2, 12)
	focus.content_margin_top = 6
	focus.content_margin_bottom = 6
	
	theme.set_stylebox("normal", "OptionButton", normal)
	theme.set_stylebox("hover", "OptionButton", hover)
	theme.set_stylebox("pressed", "OptionButton", pressed)
	theme.set_stylebox("disabled", "OptionButton", disabled)
	theme.set_stylebox("focus", "OptionButton", focus)
	
	theme.set_color("font_color", "OptionButton", COL_TEXT)
	theme.set_color("font_hover_color", "OptionButton", COL_ACCENT)
	theme.set_color("font_pressed_color", "OptionButton", COL_TEXT)
	theme.set_color("font_disabled_color", "OptionButton", COL_DISABLED_TEXT)
	theme.set_color("font_focus_color", "OptionButton", COL_ACCENT)
	
	theme.set_font_size("font_size", "OptionButton", 16)

# ========== TAB CONTAINER ==========
func _setup_tab_container():
	# Панель вкладок
	var panel = _make_flat(COL_BG_PANEL, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 12)
	panel.content_margin_top = 12
	
	# Стиль вкладок
	var tab_selected = _make_flat(COL_TAB_ACTIVE, COL_ACCENT, CORNER_RADIUS, 1, 16)
	tab_selected.content_margin_top = 8
	tab_selected.content_margin_bottom = 8
	tab_selected.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	tab_selected.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	tab_selected.set_border_width(SIDE_BOTTOM, 2)
	tab_selected.border_color = COL_ACCENT
	
	var tab_unselected = _make_flat(COL_TAB_INACTIVE, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 16)
	tab_unselected.content_margin_top = 8
	tab_unselected.content_margin_bottom = 8
	tab_unselected.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	tab_unselected.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	
	var tab_hovered = _make_flat(COL_HOVER, COL_BORDER_HOVER, CORNER_RADIUS, BORDER_WIDTH, 16)
	tab_hovered.content_margin_top = 8
	tab_hovered.content_margin_bottom = 8
	tab_hovered.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	tab_hovered.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	
	var tab_disabled = _make_flat(COL_DISABLED, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 16)
	tab_disabled.content_margin_top = 8
	tab_disabled.content_margin_bottom = 8
	
	var tab_focus = _make_flat(COL_TAB_ACTIVE, COL_BORDER_FOCUS, CORNER_RADIUS, 2, 16)
	tab_focus.content_margin_top = 8
	tab_focus.content_margin_bottom = 8
	
	theme.set_stylebox("panel", "TabContainer", panel)
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hovered)
	theme.set_stylebox("tab_disabled", "TabContainer", tab_disabled)
	theme.set_stylebox("tab_focus", "TabContainer", tab_focus)
	
	theme.set_color("font_selected_color", "TabContainer", COL_ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", COL_TEXT_DIM)
	theme.set_color("font_hovered_color", "TabContainer", COL_TEXT)
	theme.set_color("font_disabled_color", "TabContainer", COL_DISABLED_TEXT)
	
	theme.set_font_size("font_size", "TabContainer", 16)

# ========== PANEL CONTAINER ==========
func _setup_panel_container():
	var panel = _make_flat(COL_BG_DARK, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 0)
	theme.set_stylebox("panel", "PanelContainer", panel)

# ========== MARGIN CONTAINER ==========
func _setup_margin_container():
	pass # MarginContainer не требует особой стилизации

# ========== SCROLL CONTAINER ==========
func _setup_scroll_container():
	# Стилизация полосы прокрутки
	var scrollbar_bg = _make_flat(COL_BG_DARKEST, Color.TRANSPARENT, 4, 0, 0)
	var scrollbar_grabber = _make_flat(COL_ACCENT_DIM, Color.TRANSPARENT, 4, 0, 0)
	var scrollbar_grabber_hover = _make_flat(COL_ACCENT, Color.TRANSPARENT, 4, 0, 0)
	var scrollbar_grabber_pressed = _make_flat(COL_ACCENT, Color.TRANSPARENT, 4, 0, 0)
	
	theme.set_stylebox("scroll", "VScrollBar", scrollbar_bg)
	theme.set_stylebox("grabber", "VScrollBar", scrollbar_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scrollbar_grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scrollbar_grabber_pressed)

# ========== SEPARATOR ==========
func _setup_separator():
	var sep = _make_flat(COL_BORDER, Color.TRANSPARENT, 0, 0, 0)
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_constant("separation", "HSeparator", 12)

# ========== POPUP MENU ==========
func _setup_popup_menu():
	var panel = _make_flat(COL_BG_DARK, COL_BORDER, CORNER_RADIUS, BORDER_WIDTH, 4)
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	
	var hover = _make_flat(COL_HOVER, Color.TRANSPARENT, 4, 0, 4)
	
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", hover)
	
	theme.set_color("font_color", "PopupMenu", COL_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", COL_ACCENT)
	theme.set_color("font_accelerator_color", "PopupMenu", COL_TEXT_DIM)
	theme.set_color("font_disabled_color", "PopupMenu", COL_DISABLED_TEXT)
	
	theme.set_font_size("font_size", "PopupMenu", 16)

# ========== CONFIRMATION DIALOG ==========
func _setup_confirmation_dialog():
	# AcceptDialog / ConfirmationDialog используют стили Window и Button
	# Window panel:
	var window_panel = _make_flat(COL_BG_PANEL, COL_ACCENT_DIM, CORNER_RADIUS, 2, 16)
	window_panel.content_margin_top = 16
	theme.set_stylebox("embedded_border", "Window", window_panel)
	theme.set_stylebox("embedded_unfocused_border", "Window", window_panel)
	
	theme.set_color("title_color", "Window", COL_ACCENT)
	theme.set_font_size("title_font_size", "Window", 18)
