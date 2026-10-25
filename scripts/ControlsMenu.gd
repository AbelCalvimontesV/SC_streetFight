
extends Control

signal back_to_menu_selected

const GOLD_COLOR := Color("#f4cf72")
const TEXT_COLOR := Color("#f4f5f7")
const MUTED_COLOR := Color("#aab0bf")
const PANEL_COLOR := Color("#171b25")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()


func _build_screen() -> void:
	var background := ColorRect.new()
	background.name = "ControlsBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var top_line := ColorRect.new()
	top_line.color = Color("#a83240")
	top_line.size = Vector2(960, 5)
	background.add_child(top_line)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.offset_left = -390
	layout.offset_right = 390
	layout.offset_top = -300
	layout.offset_bottom = 300
	layout.add_theme_constant_override("separation", 7)
	add_child(layout)

	_add_title(layout, "CONTROLS", 28, GOLD_COLOR, 38)

	_add_title(layout, "PLAYER 1 — KEYBOARD", 17, GOLD_COLOR, 24)
	_add_text(
		layout,
		"Move: A / D    |    Crouch: S    |    Jump: W\n"
		+ "Jab: J    |    Heavy Attack: K    |    Kick: L\n"
		+ "Special Attack: U    |    Block: I",
		14
	)

	_add_title(layout, "PLAYER 2 — KEYBOARD", 17, GOLD_COLOR, 24)
	_add_text(
		layout,
		"Move: LEFT / RIGHT ARROWS    |    Crouch: DOWN ARROW\n"
		+ "Jump: UP ARROW    |    Jab: F    |    Heavy Attack: G\n"
		+ "Kick: H    |    Special Attack: T    |    Block: Y",
		14
	)

	_add_title(layout, "CONTROLLER", 17, GOLD_COLOR, 24)
	_add_text(
		layout,
		"Move: Left Stick / D-pad    |    Crouch: D-pad Down\n"
		+ "Jump: A    |    Jab: X    |    Heavy Attack: Y\n"
		+ "Kick: B    |    Special Attack: RB    |    Block: LB",
		14
	)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "BACK TO MENU"
	back_button.custom_minimum_size = Vector2(240, 42)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.add_theme_color_override("font_color", TEXT_COLOR)
	back_button.add_theme_font_size_override("font_size", 14)

	back_button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(Color("#252c38"), Color("#5c6579"))
	)
	back_button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(Color("#353e4d"), Color("#8a94a8"))
	)

	back_button.pressed.connect(
		func(): back_to_menu_selected.emit()
	)

	layout.add_child(back_button)
	back_button.grab_focus()


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


func _add_text(
	parent: Control,
	content: String,
	font_size: int
) -> void:
	var label := Label.new()
	label.text = content
	label.custom_minimum_size = Vector2(760, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _make_panel_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
