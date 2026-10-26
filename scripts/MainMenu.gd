
extends Control

signal single_player_selected
signal local_multiplayer_selected
signal load_saved_game_selected
signal career_record_selected
signal exit_selected
signal controls_selected

const GOLD_COLOR := Color("#f4cf72")
const TEXT_COLOR := Color("#f4f5f7")
const MUTED_COLOR := Color("#aab0bf")
const PANEL_COLOR := Color("#171b25")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()


func _build_menu() -> void:
	# Background
	var background := ColorRect.new()
	background.name = "MenuBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Decorative top line
	var top_line := ColorRect.new()
	top_line.color = Color("#a83240")
	top_line.position = Vector2.ZERO
	top_line.size = Vector2(960, 5)
	background.add_child(top_line)

	# Centered menu panel
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(PANEL_COLOR, Color("#a83b48"), 2, 10)
	)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)

	_add_title(
		layout,
		"PIXEL BOXING CLUB",
		28,
		GOLD_COLOR,
		48
	)

	_add_title(
		layout,
		"CHOOSE YOUR GAME MODE",
		12,
		MUTED_COLOR,
		25
	)

	_add_button(
		layout,
		"SINGLE PLAYER",
		Color("#a83240"),
		Color("#f06b76"),
		42,
		func(): single_player_selected.emit()
	)

	_add_button(
		layout,
		"LOCAL MULTIPLAYER",
		Color("#283b42"),
		Color("#4b9d92"),
		38,
		func(): local_multiplayer_selected.emit()
	)

	

	_add_button(
		layout,
		"LOAD SAVED GAME",
		Color("#283b42"),
		Color("#4b9d92"),
		38,
		func(): load_saved_game_selected.emit()
	)

	_add_button(
		layout,
		"VIEW CAREER RECORD",
		Color("#252c38"),
		Color("#5c6579"),
		38,
		func(): career_record_selected.emit()
	)
	_add_button(
			layout,
			"CONTROLS",
			Color("#283b42"),
			Color("#4b9d92"),
			38,
			func(): controls_selected.emit()
		)

	var exit_button := _add_button(
		layout,
		"EXIT",
		Color("#252c38"),
		Color("#5c6579"),
		35,
		func(): exit_selected.emit()
	)

	# Keyboard/controller focus starts here.
	var first_button := layout.get_child(2) as Button
	if first_button != null:
		first_button.grab_focus()


func _add_title(
	parent: Control,
	title_text: String,
	font_size: int,
	font_color: Color,
	height: float
) -> void:
	var label := Label.new()
	label.text = title_text
	label.custom_minimum_size = Vector2(480, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)


func _add_button(
	parent: Control,
	button_text: String,
	background_color: Color,
	border_color: Color,
	height: float,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, height)

	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(background_color, border_color)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			background_color.lightened(0.12),
			border_color.lightened(0.12)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(
			background_color.darkened(0.12),
			border_color
		)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 13)

	button.pressed.connect(callback)
	parent.add_child(button)

	return button


func _make_panel_style(
	background_color: Color,
	border_color: Color,
	border_width: int = 1,
	radius: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
