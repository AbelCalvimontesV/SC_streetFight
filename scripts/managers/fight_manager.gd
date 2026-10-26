
extends Node

const CAMERA_ZOOM := 0.8
const SAVE_PATH := "user://boxing_progress.json"
const MATCH_SAVE_PATH := "user://partida_guardada.save"

var saved_match: Dictionary = {}
const PLAYER_SCENE := "res://Scenes/characters/MamenSavedra.tscn"
const ENEMY_SCENE := "res://Scenes/enemies/ChichoMedina.tscn"

const MAMEN_SCENE := "res://Scenes/characters/MamenSavedra.tscn"
const CHICHO_SCENE := "res://Scenes/enemies/ChichoMedina.tscn"

const MARIO_SCENE := "res://Scenes/characters/MarioCronenbold.tscn"
const VINCHITA_SCENE := "res://Scenes/characters/Vinchita.tscn"
const MAJU_SCENE := "res://Scenes/characters/Maju.tscn"

const AVAILABLE_CHARACTERS: Array[Dictionary] = [
	{
		"name": "Mamen Savedra",
		"id": "MamenSavedra",
		"scene": MAMEN_SCENE
	},
	{
		"name": "Chicho Medina",
		"id": "ChichoMedina",
		"scene": CHICHO_SCENE
	},
	{
		"name": "Mario Cronenbold",
		"id": "MarioCronenbold",
		"scene": MARIO_SCENE
	},
	{
		"name": "Vinchita",
		"id": "Vinchita",
		"scene": VINCHITA_SCENE
	},
	{
		"name": "Maju",
		"id": "Maju",
		"scene": MAJU_SCENE
	}
]

const CAMPAIGN_SCENES: Array[String] = [
	VINCHITA_SCENE,
	MAMEN_SCENE,
	MARIO_SCENE,
	MAJU_SCENE,
	CHICHO_SCENE
]

const CAMPAIGN_NAMES: Array[String] = [
	"Vinchita",
	"Mamen Savedra",
	"Mario Cronenbold",
	"Maju",
	"Chicho Medina"
]

var selected_character_scene: String = MAMEN_SCENE
var selected_character_name: String = "MamenSavedra"
var selected_player2_scene: String = CHICHO_SCENE
var selected_player2_name: String = "ChichoMedina"

var selecting_player_number: int = 1

# 0 = Mamen Savedra, 1 = Chicho Medina.
var campaign_fight_index: int = 0
var multijugador_local: bool = false
var solo_mando: bool = false

const ROUNDS_TO_WIN := 2
const TOTAL_ROUNDS := 3
const ROUND_DURATION := 60.0
const KO_DISPLAY_DURATION := 2.5
const BOXER_SCENE := "res://Scenes/enemies/ChichoMedina.tscn"

const ESCENARIOS: Array[String] = [
	"res://assets/escenarios/UTEPSA_dia.ogv",
	"res://assets/escenarios/escenario_banderas.ogv",
	"res://assets/escenarios/hinchas_luces_parpadeando_10s.ogv",
	"res://assets/escenarios/Gradas_publico_10s_loop.ogv"
]



var escenario_actual: String = ""

const BREAK_DURATION := 3.0

const GOLD_COLOR := Color("#f4cf72")
const RED_COLOR := Color("#ff4657")
const TEXT_COLOR := Color("#f4f5f7")
const MUTED_COLOR := Color("#aab0bf")
const PANEL_COLOR := Color("#171b25")
const HEALTH_COLOR := Color("#f04d5d")
const STAMINA_COLOR := Color("#328bff")

@onready var ring: Node2D = get_node_or_null("Ring")

var progress: Dictionary = {
	"wins": 0,
	"losses": 0
}

var camera: Camera2D
var player: BoxerBase
var enemy: BoxerBase

var fight_ui: CanvasLayer
var hud: Control
var menu_overlay: Control
var main_menu: Control

var player_health_bar: ProgressBar
var player_stamina_bar: ProgressBar
var enemy_health_bar: ProgressBar
var enemy_stamina_bar: ProgressBar

var player_health_value: Label
var player_stamina_value: Label
var enemy_health_value: Label
var enemy_stamina_value: Label

var player_title_label: Label
var enemy_title_label: Label
var round_label: Label
var timer_label: Label
var score_label: Label
var result_label: Label

var save_button: Button
var continue_button: Button
var saved_progress: Dictionary = {}

var round_timer: float = ROUND_DURATION
var break_timer: float = 0.0
var current_round: int = 1
var player_round_wins: int = 0
var enemy_round_wins: int = 0

var fight_started := false
var fight_finished := false
var waiting_next_round := false
var announcement_id := 0
var round_transition_in_progress := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_progress()

	if ring == null:
		push_error("Main: Ring node is missing.")
		return

	_setup_camera()
	_setup_ui()
	show_main_menu()


func _process(delta: float) -> void:
	if (fight_started or waiting_next_round) and not fight_finished:
		if not _check_controller():
			return
	if fight_finished:
		return

	if waiting_next_round:
		break_timer = maxf(0.0, break_timer - delta)

		if break_timer > 0.0:
			if is_instance_valid(timer_label):
				timer_label.text = "BREAK  %02d" % ceili(break_timer)
		else:
			_start_next_round()

		return

	if not fight_started:
		return

	round_timer = maxf(0.0, round_timer - delta)
	_update_timer_label()

	if round_timer <= 0.0:
		_end_round_by_time()


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func _setup_camera() -> void:
	var old_camera := get_node_or_null("FightCamera")

	if old_camera != null:
		remove_child(old_camera)
		old_camera.queue_free()

	camera = Camera2D.new()
	camera.name = "FightCamera"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = false
	add_child(camera)

	var background := ring.get_node_or_null("Background") as Sprite2D

	if background == null:
		background = ring.get_node_or_null("backround") as Sprite2D

	if background != null and background.texture != null:
		camera.global_position = background.to_global(
			background.get_rect().get_center()
		)
	else:
		camera.global_position = ring.global_position

	camera.make_current()


# --------------------------------------------------
# UI HELPERS
# --------------------------------------------------

func _panel_style(
	background: Color,
	border: Color,
	border_width: int = 1,
	radius: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _make_label(
	parent: Control,
	label_name: String,
	text_value: String,
	pos: Vector2,
	label_size: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _style_button(
	button: Button,
	background: Color,
	border: Color
) -> void:
	button.add_theme_stylebox_override(
		"normal", _panel_style(background, border)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(background.lightened(0.12), border.lightened(0.12))
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(background.darkened(0.12), border)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 13)


func _create_bar(
	parent: Control,
	bar_name: String,
	pos: Vector2,
	width: float,
	color: Color,
	height: float
) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.position = pos
	bar.size = Vector2(width, height)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false

	bar.add_theme_stylebox_override(
		"background",
		_panel_style(Color("#282d38"), Color("#555c6b"), 1, 5)
	)
	bar.add_theme_stylebox_override(
		"fill",
		_panel_style(color, color.lightened(0.12), 1, 5)
	)

	parent.add_child(bar)
	return bar


func _clear_ui() -> void:
	if not is_instance_valid(fight_ui):
		return

	for child in fight_ui.get_children():
		fight_ui.remove_child(child)
		child.queue_free()

	hud = null
	menu_overlay = null

	player_health_bar = null
	player_stamina_bar = null
	enemy_health_bar = null
	enemy_stamina_bar = null

	player_health_value = null
	player_stamina_value = null
	enemy_health_value = null
	enemy_stamina_value = null

	player_title_label = null
	enemy_title_label = null
	round_label = null
	timer_label = null
	score_label = null
	result_label = null

	save_button = null
	continue_button = null


func _setup_ui() -> void:
	if is_instance_valid(fight_ui):
		fight_ui.queue_free()

	fight_ui = CanvasLayer.new()
	fight_ui.name = "FightUI"
	fight_ui.layer = 5
	add_child(fight_ui)


# --------------------------------------------------
# MAIN MENU
# --------------------------------------------------







func show_main_menu() -> void:
	ring.process_mode = Node.PROCESS_MODE_INHERIT
	_remove_boxers()

	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	multijugador_local = false
	solo_mando = false

	_clear_ui()

	main_menu = Control.new()
	main_menu.set_script(load("res://scripts/MainMenu.gd"))
	fight_ui.add_child(main_menu)

	main_menu.single_player_selected.connect(
		_on_single_player_selected
	)

	main_menu.local_multiplayer_selected.connect(
		_on_local_multiplayer_selected
	)

	main_menu.load_saved_game_selected.connect(
		show_saved_match
	)

	main_menu.career_record_selected.connect(
		show_progress
	)

	main_menu.controls_selected.connect(
		show_controls_menu
	)

	main_menu.exit_selected.connect(
		_exit_game
	)


func show_controls_menu() -> void:
	_clear_ui()

	var controls_menu := Control.new()
	controls_menu.set_script(
		load("res://scripts/ControlsMenu.gd")
	)

	fight_ui.add_child(controls_menu)

	controls_menu.back_to_menu_selected.connect(
		show_main_menu
	)



func _on_single_player_selected() -> void:
	multijugador_local = false
	solo_mando = false
	show_character_select()


func _on_local_multiplayer_selected() -> void:
	multijugador_local = true
	solo_mando = false
	show_character_select()


# --------------------------------------------------
# CHARACTER SELECT
# --------------------------------------------------



func show_character_select() -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	_clear_ui()

	var background := ColorRect.new()
	background.name = "CharacterSelectBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(background)

	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(screen)

	var heading := "SELECT YOUR FIGHTER"

	if multijugador_local:
		heading = "PLAYER %d — SELECT YOUR FIGHTER" % selecting_player_number

	var title := _make_label(
		screen,
		"CharacterSelectTitle",
		heading,
		Vector2(100, 35),
		Vector2(760, 50),
		27,
		GOLD_COLOR
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var current_scene := selected_character_scene
	var current_name := selected_character_name

	if multijugador_local and selecting_player_number == 2:
		current_scene = selected_player2_scene
		current_name = selected_player2_name

	var columns := 3
	var button_size := Vector2(220, 90)
	var horizontal_gap := 30.0
	var vertical_gap := 20.0
	var total_width := columns * button_size.x + (columns - 1) * horizontal_gap
	var start_x := (960.0 - total_width) / 2.0
	var start_y := 115.0

	for i in range(AVAILABLE_CHARACTERS.size()):
		var character: Dictionary = AVAILABLE_CHARACTERS[i]
		var scene_path: String = character["scene"]
		var character_name: String = character["id"]
		var display_name: String = character["name"]

		var character_button := Button.new()
		character_button.name = character_name + "SelectButton"
		character_button.text = display_name.to_upper()
		character_button.size = button_size

		var column := i % columns
		var row := int(i / columns)

		character_button.position = Vector2(
			start_x + column * (button_size.x + horizontal_gap),
			start_y + row * (button_size.y + vertical_gap)
		)

		if scene_path == current_scene:
			_style_button(
				character_button,
				Color("#a83240"),
				Color("#f4cf72")
			)
		else:
			_style_button(
				character_button,
				Color("#283b42"),
				Color("#4b9d92")
			)

		character_button.pressed.connect(
			_select_character.bind(scene_path, character_name)
		)

		screen.add_child(character_button)

	var selected_label := _make_label(
		screen,
		"SelectedCharacterLabel",
		"SELECTED: " + current_name.to_upper(),
		Vector2(180, 335),
		Vector2(600, 30),
		16,
		GOLD_COLOR
	)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "CONFIRM"
	confirm_button.position = Vector2(370, 380)
	confirm_button.size = Vector2(220, 45)
	_style_button(
		confirm_button,
		Color("#a83240"),
		Color("#f06b76")
	)
	confirm_button.pressed.connect(_confirm_character_selection)
	screen.add_child(confirm_button)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "BACK TO MENU"
	back_button.position = Vector2(370, 440)
	back_button.size = Vector2(220, 38)
	_style_button(
		back_button,
		Color("#252c38"),
		Color("#5c6579")
	)
	back_button.pressed.connect(show_main_menu)
	screen.add_child(back_button)



func _select_character(scene_path: String, character_name: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Character scene not found: " + scene_path)
		return

	if multijugador_local and selecting_player_number == 2:
		selected_player2_scene = scene_path
		selected_player2_name = character_name
	else:
		selected_character_scene = scene_path
		selected_character_name = character_name

	show_character_select()


func _confirm_character_selection() -> void:
	if multijugador_local:
		if selecting_player_number == 1:
			selecting_player_number = 2
			show_character_select()
		else:
			_start_new_match()
	else:
		_start_new_match()



# --------------------------------------------------
# FIGHT HUD
# --------------------------------------------------

func _setup_fight_ui() -> void:
	_clear_ui()

	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(hud)

	player_title_label = _make_label(
		hud, "PlayerLabel", "PLAYER",
		Vector2(28, 10), Vector2(300, 22), 15, GOLD_COLOR
	)

	_make_label(
		hud, "PlayerHealthCaption", "HEALTH",
		Vector2(29, 32), Vector2(90, 12), 9, MUTED_COLOR
	)

	player_health_bar = _create_bar(
		hud, "PlayerHealthBar",
		Vector2(28, 44), 300, HEALTH_COLOR, 17
	)

	player_health_value = _make_label(
		hud, "PlayerHealthValue", "100 / 100",
		Vector2(250, 32), Vector2(78, 12), 9, TEXT_COLOR
	)
	player_health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_make_label(
		hud, "PlayerStaminaCaption", "STAMINA",
		Vector2(29, 64), Vector2(90, 12), 9, MUTED_COLOR
	)

	player_stamina_bar = _create_bar(
		hud, "PlayerStaminaBar",
		Vector2(28, 76), 300, STAMINA_COLOR, 13
	)

	player_stamina_value = _make_label(
		hud, "PlayerStaminaValue", "100 / 100",
		Vector2(250, 64), Vector2(78, 12), 9, TEXT_COLOR
	)
	player_stamina_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_title_label = _make_label(
		hud, "EnemyLabel", "OPPONENT",
		Vector2(632, 10), Vector2(300, 22), 15, GOLD_COLOR
	)
	enemy_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var enemy_health_caption := _make_label(
		hud, "EnemyHealthCaption", "HEALTH",
		Vector2(842, 32), Vector2(90, 12), 9, MUTED_COLOR
	)
	enemy_health_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_health_bar = _create_bar(
		hud, "EnemyHealthBar",
		Vector2(632, 44), 300, HEALTH_COLOR, 17
	)

	enemy_health_value = _make_label(
		hud, "EnemyHealthValue", "100 / 100",
		Vector2(632, 32), Vector2(78, 12), 9, TEXT_COLOR
	)

	var enemy_stamina_caption := _make_label(
		hud, "EnemyStaminaCaption", "STAMINA",
		Vector2(842, 64), Vector2(90, 12), 9, MUTED_COLOR
	)
	enemy_stamina_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_stamina_bar = _create_bar(
		hud, "EnemyStaminaBar",
		Vector2(632, 76), 300, STAMINA_COLOR, 13
	)

	enemy_stamina_value = _make_label(
		hud, "EnemyStaminaValue", "100 / 100",
		Vector2(632, 64), Vector2(78, 12), 9, TEXT_COLOR
	)

	var timer_panel := Panel.new()
	timer_panel.position = Vector2(382, 8)
	timer_panel.size = Vector2(196, 82)
	timer_panel.add_theme_stylebox_override(
		"panel", _panel_style(PANEL_COLOR, Color("#b94a52"), 2, 9)
	)
	hud.add_child(timer_panel)

	var brand := _make_label(
		hud, "BrandLabel", "PIXEL BOXING CLUB",
		Vector2(386, 12), Vector2(188, 15), 10, MUTED_COLOR
	)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	round_label = _make_label(
		hud, "RoundLabel", "ROUND 1",
		Vector2(386, 28), Vector2(188, 25), 18, GOLD_COLOR
	)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	timer_label = _make_label(
		hud, "TimerLabel", "01:00",
		Vector2(386, 52), Vector2(188, 23), 15, TEXT_COLOR
	)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	score_label = _make_label(
		hud, "ScoreLabel", "ROUNDS  0 - 0",
		Vector2(386, 94), Vector2(188, 20), 11, TEXT_COLOR
	)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	save_button = Button.new()
	save_button.text = "MAIN MENU"
	save_button.position = Vector2(793, 119)
	save_button.size = Vector2(139, 29)
	save_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(save_button, Color("#252c38"), Color("#5c6579"))
	save_button.pressed.connect(show_main_menu)
	hud.add_child(save_button)

	result_label = _make_label(
		hud, "ResultLabel", "",
		Vector2(150, 180), Vector2(660, 120), 28, RED_COLOR
	)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_update_stats_ui()
	_update_round_label()
	_update_timer_label()


func _make_controls_panel() -> void:
	var controls_panel := PanelContainer.new()
	controls_panel.position = Vector2(24, 472)
	controls_panel.size = Vector2(912, 54)
	controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#121620"), Color("#454b5c"), 1, 7)
	)
	hud.add_child(controls_panel)

	var label := Label.new()
	label.text = "TECLADO: A/D mover | W salto | S agachar | J/K golpes | L patada | U especial | I bloqueo\nMANDO: stick/cruceta mover | A salto | X/Y golpes | B patada | RB especial | LB bloqueo"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	controls_panel.add_child(label)


func _update_stats_ui() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	if is_instance_valid(player_title_label):
		player_title_label.text = player.boxer_name
	if is_instance_valid(enemy_title_label):
		enemy_title_label.text = enemy.boxer_name

	if is_instance_valid(player_health_bar):
		player_health_bar.max_value = maxf(1.0, player.max_health)
		player_health_bar.value = player.health
	if is_instance_valid(player_stamina_bar):
		player_stamina_bar.max_value = maxf(1.0, player.max_stamina)
		player_stamina_bar.value = player.stamina
	if is_instance_valid(enemy_health_bar):
		enemy_health_bar.max_value = maxf(1.0, enemy.max_health)
		enemy_health_bar.value = enemy.health
	if is_instance_valid(enemy_stamina_bar):
		enemy_stamina_bar.max_value = maxf(1.0, enemy.max_stamina)
		enemy_stamina_bar.value = enemy.stamina

	if is_instance_valid(player_health_value):
		player_health_value.text = "%d / %d" % [
			roundi(player.health), roundi(player.max_health)
		]
	if is_instance_valid(player_stamina_value):
		player_stamina_value.text = "%d / %d" % [
			roundi(player.stamina), roundi(player.max_stamina)
		]
	if is_instance_valid(enemy_health_value):
		enemy_health_value.text = "%d / %d" % [
			roundi(enemy.health), roundi(enemy.max_health)
		]
	if is_instance_valid(enemy_stamina_value):
		enemy_stamina_value.text = "%d / %d" % [
			roundi(enemy.stamina), roundi(enemy.max_stamina)
		]

	if is_instance_valid(score_label):
		score_label.text = "ROUNDS  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	if is_instance_valid(save_button):
		save_button.disabled = (
			not fight_started
			or waiting_next_round
			or fight_finished
		)


func _update_timer_label() -> void:
	if not is_instance_valid(timer_label):
		return

	var seconds := ceili(maxf(0.0, round_timer))
	timer_label.text = "%02d:%02d" % [
		int(seconds / 60), seconds % 60
	]
	timer_label.add_theme_color_override(
		"font_color", RED_COLOR if seconds <= 10 else TEXT_COLOR
	)


func _update_round_label() -> void:
	if is_instance_valid(round_label):
		round_label.text = "ROUND %d" % current_round


# --------------------------------------------------
# FIGHT SETUP
# --------------------------------------------------

func start_fight() -> void:
	multijugador_local = false
	solo_mando = false
	_start_new_match()


func start_controller_fight() -> void:
	multijugador_local = false
	solo_mando = true
	_start_new_match()


func start_local_multiplayer() -> void:
	multijugador_local = true
	solo_mando = false
	_start_new_match()





func _start_new_match() -> void:
	# Permitir iniciar la partida con teclado, mando o ambos.
	ring.process_mode = Node.PROCESS_MODE_INHERIT
	announcement_id += 1
	campaign_fight_index = 0

	fight_started = false
	fight_finished = false
	waiting_next_round = false
	round_transition_in_progress = false
	break_timer = 0.0

	current_round = 1
	player_round_wins = 0
	enemy_round_wins = 0
	round_timer = ROUND_DURATION

	# Elegir el escenario para esta pelea.
	_elegir_escenario_aleatorio()

	if not _spawn_boxers():
		return

	_start_round()




func _spawn_boxers() -> bool:
	var player_scene_path: String = selected_character_scene
	var enemy_scene_path: String
	var enemy_name: String

	# Elegir al rival según el modo de juego.
	if multijugador_local:
		enemy_scene_path = selected_player2_scene
		enemy_name = selected_player2_name
	else:
		# Campaña:
		# 0 = Vinchita
		# 1 = Mamen Savedra
		# 2 = Mario Cronenbold
		# 3 = Maju
		# 4 = Chicho Medina
		campaign_fight_index = clampi(
			campaign_fight_index,
			0,
			CAMPAIGN_SCENES.size() - 1
		)

		enemy_scene_path = CAMPAIGN_SCENES[campaign_fight_index]
		enemy_name = CAMPAIGN_NAMES[campaign_fight_index]

	# Comprobar que las escenas existan.
	if not ResourceLoader.exists(player_scene_path):
		push_error("Player scene not found: " + player_scene_path)
		_show_message("ERROR: PLAYER SCENE NOT FOUND")
		return false

	if not ResourceLoader.exists(enemy_scene_path):
		push_error("Enemy scene not found: " + enemy_scene_path)
		_show_message("ERROR: ENEMY SCENE NOT FOUND")
		return false

	# Cargar las escenas.
	var player_packed := load(player_scene_path) as PackedScene
	var enemy_packed := load(enemy_scene_path) as PackedScene

	if player_packed == null or enemy_packed == null:
		push_error("Could not load boxer scenes.")
		_show_message("ERROR: COULD NOT LOAD BOXER SCENES")
		return false

	# Limpiar los boxeadores anteriores.
	_remove_boxers()

	# Crear los nuevos boxeadores.
	var new_player := player_packed.instantiate() as BoxerBase
	var new_enemy := enemy_packed.instantiate() as BoxerBase

	if new_player == null or new_enemy == null:
		if is_instance_valid(new_player):
			new_player.free()

		if is_instance_valid(new_enemy):
			new_enemy.free()

		push_error("Both boxer scenes must use BoxerBase.gd.")
		_show_message("ERROR: INVALID BOXER SCENE")
		return false

	player = new_player
	enemy = new_enemy

	player.name = "Player"
	enemy.name = "Enemy"

	# Obtener los mandos conectados.
	var pads: Array[int] = Input.get_connected_joypads()

	# Configurar al Jugador 1.
	player.is_player = true
	player.boxer_name = selected_character_name

	# Configurar al rival o Jugador 2.
	enemy.boxer_name = enemy_name

	if multijugador_local:
		# MULTIJUGADOR LOCAL.
		player.boxer_name = "J1 - " + selected_character_name
		enemy.boxer_name = "J2 - " + selected_player2_name

		# J1 usa el primer mando o el teclado.
		if pads.size() >= 1:
			player.mando_id = pads[0]
			player.usar_teclado = false
		else:
			player.mando_id = -1
			player.usar_teclado = true

		# J2 usa el segundo mando o el teclado.
		if pads.size() >= 2:
			enemy.mando_id = pads[1]
			enemy.usar_teclado = false
		else:
			enemy.mando_id = -1
			enemy.usar_teclado = true

		# Ambos boxeadores son jugadores.
		enemy.is_player = true

	else:
		# MODO INDIVIDUAL.

		# J1 usa el primer mando si existe;
		# de lo contrario, usa el teclado.
		if not pads.is_empty():
			player.mando_id = pads[0]
			player.usar_teclado = false
		else:
			player.mando_id = -1
			player.usar_teclado = true

		# El rival será controlado por la IA.
		enemy.mando_id = -1
		enemy.usar_teclado = false
		enemy.is_player = false

	# Posiciones iniciales.
	player.position = Vector2(-100, 0)
	enemy.position = Vector2(100, 0)

	# Vincular a los oponentes.
	player.opponent = enemy
	enemy.opponent = player

	# Añadir los boxeadores al ring.
	ring.add_child(player)
	ring.add_child(enemy)

	# Conectar las señales de estadísticas y KO.
	player.stats_changed.connect(_on_stats_changed)
	enemy.stats_changed.connect(_on_stats_changed)

	player.knocked_out.connect(_on_knockout)
	enemy.knocked_out.connect(_on_knockout)

	return true


func _remove_boxers() -> void:
	if is_instance_valid(player):
		player.queue_free()

	if is_instance_valid(enemy):
		enemy.queue_free()

	player = null
	enemy = null


func _start_round() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	player.reset_for_round()
	enemy.reset_for_round()

	player.opponent = enemy
	enemy.opponent = player

	player.position = Vector2(-100, 0)
	enemy.position = Vector2(100, 0)

	round_timer = ROUND_DURATION
	break_timer = 0.0
	fight_started = true
	fight_finished = false
	waiting_next_round = false

	_setup_fight_ui()
	_update_stats_ui()
	_update_round_label()
	_update_timer_label()

	if current_round == 1:
		_show_announcement("FIGHT!", 1.5)
	else:
		_show_announcement("ROUND %d" % current_round, 1.2)


func _on_stats_changed(_boxer: BoxerBase) -> void:
	_update_stats_ui()


# --------------------------------------------------
# ROUND FLOW
# --------------------------------------------------


func _on_knockout(boxer: BoxerBase) -> void:
	if (
		not fight_started
		or fight_finished
		or round_transition_in_progress
	):
		return

	round_transition_in_progress = true
	fight_started = false
	waiting_next_round = false
	break_timer = 0.0

	if boxer == player:
		enemy_round_wins += 1
		_show_round_result("YOU GOT KNOCKED OUT")
	else:
		player_round_wins += 1
		_show_round_result("OPPONENT KNOCKED OUT!")



func _end_round_by_time() -> void:
	if not fight_started or fight_finished or waiting_next_round:
		return

	fight_started = false

	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	if player.health > enemy.health:
		player_round_wins += 1
		_show_round_result("ROUND WON!")
	elif enemy.health > player.health:
		enemy_round_wins += 1
		_show_round_result("ROUND LOST!")
	else:
		_show_round_result("ROUND DRAW!")



func _show_round_result(message: String) -> void:
	if fight_finished:
		return

	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	_update_stats_ui()

	if is_instance_valid(result_label):
		result_label.text = message
		result_label.add_theme_color_override("font_color", GOLD_COLOR)

	if is_instance_valid(score_label):
		score_label.text = "ROUNDS  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	# Mantener a los boxeadores en sus posiciones.
	# No llamar a reset_for_round durante esta espera.
	await get_tree().create_timer(KO_DISPLAY_DURATION).timeout

	if not is_inside_tree() or fight_finished:
		return

	if player_round_wins >= ROUNDS_TO_WIN:
		_finish_fight(true)
		return

	if enemy_round_wins >= ROUNDS_TO_WIN:
		_finish_fight(false)
		return

	if current_round >= TOTAL_ROUNDS:
		if player_round_wins > enemy_round_wins:
			_finish_fight(true)
		elif enemy_round_wins > player_round_wins:
			_finish_fight(false)
		else:
			_finish_fight(false, true)
		return

	if is_instance_valid(result_label):
		result_label.text = message + "\n\nNEXT ROUND SOON"

	if is_instance_valid(timer_label):
		timer_label.text = "BREAK  03"

	waiting_next_round = true
	break_timer = BREAK_DURATION
	_update_stats_ui()



func _start_next_round() -> void:
	if not waiting_next_round or fight_finished:
		return

	waiting_next_round = false
	round_transition_in_progress = false
	current_round += 1

	_start_round()




func _finish_fight(player_won: bool, is_draw: bool = false) -> void:
	if fight_finished:
		return

	fight_started = false
	fight_finished = true
	waiting_next_round = false
	round_transition_in_progress = false
	break_timer = 0.0
	announcement_id += 1

	# Resultado del multijugador local.
	if multijugador_local:
		if is_draw:
			_show_final_result("EMPATE")
		elif player_won:
			_show_final_result("GANA JUGADOR 1")
		else:
			_show_final_result("GANA JUGADOR 2")
		return

	# Avanzar al siguiente rival si ganamos la pelea.
	if player_won and campaign_fight_index < CAMPAIGN_SCENES.size() - 1:
		progress["wins"] = int(progress.get("wins", 0)) + 1
		save_progress()

		if is_instance_valid(result_label):
			result_label.text = "VICTORY!\n\nA NEW CHALLENGER APPROACHES!"
			result_label.add_theme_color_override(
				"font_color", GOLD_COLOR
			)

		if is_instance_valid(round_label):
			round_label.text = "NEXT CHALLENGER"

		if is_instance_valid(timer_label):
			timer_label.text = "GET READY"

		if is_instance_valid(save_button):
			save_button.visible = false

		# SoundManager.set_crowd_enabled(false)
		# SoundManager.play_sfx("victory", -0.5, 0.0)

		await get_tree().create_timer(2.5).timeout

		if not is_inside_tree():
			return

		# Pasar al siguiente rival de la campaña.
		campaign_fight_index += 1

		current_round = 1
		player_round_wins = 0
		enemy_round_wins = 0
		round_timer = ROUND_DURATION

		fight_finished = false

		# Elegir un escenario distinto al de la pelea anterior.
		_elegir_escenario_aleatorio()

		if not _spawn_boxers():
			fight_finished = true
			return

		# SoundManager.set_crowd_enabled(true)
		# SoundManager.play_sfx("round_bell", -1.0, 0.0)

		_start_round()

		var next_opponent_name: String = CAMPAIGN_NAMES[campaign_fight_index]
		_show_announcement(
			"A NEW CHALLENGER APPROACHES!\n" + next_opponent_name.to_upper(),
			2.0
		)
		return

	# Resultado definitivo: derrota, empate o victoria final.
	if player_won:
		progress["wins"] = int(progress.get("wins", 0)) + 1
		_show_final_result(
			"CAMPAIGN COMPLETE!\nYOU DEFEATED CHICHO MEDINA"
		)
	elif is_draw:
		_show_final_result("DRAW!")
	else:
		progress["losses"] = int(progress.get("losses", 0)) + 1
		_show_final_result("DEFEAT")

	save_progress()




func _show_final_result(message: String) -> void:
	if not is_instance_valid(hud):
		return

	if is_instance_valid(result_label):
		result_label.text = message
		result_label.add_theme_color_override(
			"font_color",
			GOLD_COLOR if message == "VICTORY!" else RED_COLOR
		)

	if is_instance_valid(timer_label):
		timer_label.text = "FIGHT OVER"

	if is_instance_valid(round_label):
		round_label.text = "FINAL RESULT"

	if is_instance_valid(score_label):
		score_label.text = "FINAL SCORE  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	if is_instance_valid(save_button):
		save_button.visible = false

	var rematch_button := Button.new()
	rematch_button.text = "REMATCH"
	rematch_button.position = Vector2(350, 330)
	rematch_button.size = Vector2(120, 40)
	_style_button(rematch_button, Color("#a83240"), Color("#f06b76"))
	rematch_button.pressed.connect(_start_rematch)
	hud.add_child(rematch_button)

	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.position = Vector2(490, 330)
	menu_button.size = Vector2(120, 40)
	_style_button(menu_button, Color("#252c38"), Color("#5c6579"))
	menu_button.pressed.connect(show_main_menu)
	hud.add_child(menu_button)


func _start_rematch() -> void:
	announcement_id += 1
	_start_new_match()


func _show_announcement(message: String, duration: float = 1.5) -> void:
	if not is_instance_valid(result_label):
		return

	announcement_id += 1
	var current_id := announcement_id

	result_label.text = message
	result_label.add_theme_color_override("font_color", RED_COLOR)

	await get_tree().create_timer(duration).timeout

	if not is_inside_tree() or not is_instance_valid(result_label):
		return

	if (
		current_id == announcement_id
		and not waiting_next_round
		and not fight_finished
	):
		result_label.text = ""


func _show_message(message: String) -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	announcement_id += 1

	_clear_ui()

	var error_screen := Control.new()
	error_screen.name = "ErrorScreen"
	error_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(error_screen)

	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	error_screen.add_child(background)

	var label := _make_label(
		error_screen,
		"ErrorLabel",
		message,
		Vector2(30, 30),
		Vector2(700, 70),
		22,
		RED_COLOR
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var button := Button.new()
	button.text = "BACK TO MAIN MENU"
	button.position = Vector2(30, 115)
	button.size = Vector2(220, 42)

	_style_button(button, Color("#a83240"), Color("#f06b76"))
	button.pressed.connect(show_main_menu)
	error_screen.add_child(button)


# --------------------------------------------------
# CAREER RECORD
# --------------------------------------------------

func show_progress() -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	_clear_ui()

	var screen := Control.new()
	screen.name = "ProgressScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(screen)

	var background := ColorRect.new()
	background.name = "ProgressBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)

	_make_label(
		screen, "ProgressTitle", "CAREER RECORD",
		Vector2(30, 30), Vector2(500, 50), 32, GOLD_COLOR
	)

	_make_label(
		screen, "WinsLabel",
		"WINS: %d" % int(progress.get("wins", 0)),
		Vector2(30, 100), Vector2(300, 35), 22, TEXT_COLOR
	)

	_make_label(
		screen, "LossesLabel",
		"LOSSES: %d" % int(progress.get("losses", 0)),
		Vector2(30, 145), Vector2(300, 35), 22, TEXT_COLOR
	)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "BACK"
	back_button.position = Vector2(30, 215)
	back_button.size = Vector2(180, 42)

	_style_button(back_button, Color("#252c38"), Color("#5c6579"))
	back_button.pressed.connect(show_main_menu)
	screen.add_child(back_button)


# --------------------------------------------------
# SAVE / LOAD
# --------------------------------------------------

func save_progress() -> void:
	if multijugador_local:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not save progress.")
		return

	file.store_string(JSON.stringify(progress))
	file.close()

	saved_progress = progress.duplicate(true)

	if is_instance_valid(continue_button):
		continue_button.disabled = saved_progress.is_empty()


func load_progress() -> void:
	progress = {
		"wins": 0,
		"losses": 0
	}
	saved_progress.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("Could not read progress.")
		return

	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)

	if parsed is Dictionary:
		progress["wins"] = int(parsed.get("wins", 0))
		progress["losses"] = int(parsed.get("losses", 0))
		saved_progress = progress.duplicate(true)



func _resume_saved_progress() -> void:
	if not _read_saved_match():
		_show_message("NO HAY UNA PARTIDA GUARDADA VÁLIDA")
		return

	announcement_id += 1

	multijugador_local = false
	solo_mando = false

	fight_started = false
	fight_finished = false
	waiting_next_round = false
	round_transition_in_progress = false
	break_timer = 0.0

	selected_character_scene = str(
		saved_match["character_scene"]
	)

	selected_character_name = str(
		saved_match["character_name"]
	)

	# Permitir cargar cualquiera de las cinco peleas.
	campaign_fight_index = clampi(
		int(saved_match["campaign_fight_index"]),
		0,
		CAMPAIGN_SCENES.size() - 1
	)

	ring.process_mode = Node.PROCESS_MODE_INHERIT

	if not _spawn_boxers():
		return

	current_round = clampi(
		int(saved_match["current_round"]),
		1,
		TOTAL_ROUNDS
	)

	round_timer = clampf(
		float(saved_match["round_timer"]),
		0.0,
		ROUND_DURATION
	)

	player_round_wins = int(
		saved_match["player_round_wins"]
	)

	enemy_round_wins = int(
		saved_match["enemy_round_wins"]
	)

	_restore_fighter_snapshot(player, saved_match["player"])
	_restore_fighter_snapshot(enemy, saved_match["enemy"])

	fight_started = true

	_setup_fight_ui()
	_update_stats_ui()
	_update_round_label()
	_update_timer_label()

	_show_announcement("PARTIDA CARGADA", 1.2)

# --------------------------------------------------
# EXIT
# --------------------------------------------------

func _exit_game() -> void:
	get_tree().quit()


func _check_controller() -> bool:
	# Obtener los mandos conectados.
	var pads: Array[int] = Input.get_connected_joypads()

	# Revisar al jugador 1.
	if is_instance_valid(player):
		if player.mando_id >= 0 and not pads.has(player.mando_id):
			# Si se desconecta su mando, pasa a usar teclado.
			player.mando_id = -1
			player.usar_teclado = true

	# Revisar al jugador 2 en multijugador local.
	if multijugador_local and is_instance_valid(enemy):
		if enemy.mando_id >= 0 and not pads.has(enemy.mando_id):
			# Si se desconecta su mando, pasa a usar teclado.
			enemy.mando_id = -1
			enemy.usar_teclado = true

	# No bloquear la pelea por falta de mandos.
	if is_instance_valid(ring):
		ring.process_mode = Node.PROCESS_MODE_INHERIT

	return true


#guardado de datos de los personajes 
func _get_fighter_snapshot(boxer: BoxerBase) -> Dictionary:
	return {
		"health": boxer.health,
		"stamina": boxer.stamina,
		"position": boxer.position,
		"velocity": boxer.velocity,
		"regen_wait": boxer.regen_wait,
		"hit_stun_time": boxer.hit_stun_time,
		"knockback_velocity": boxer.knockback_velocity
	}
	
func save_current_match() -> void:
	if multijugador_local:
		_show_announcement("GUARDADO SOLO EN MODO INDIVIDUAL", 1.5)
		return

	if (
		not fight_started
		or fight_finished
		or waiting_next_round
		or round_transition_in_progress
	):
		return

	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	if player.health <= 0.0 or enemy.health <= 0.0:
		return

	var snapshot: Dictionary = {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(
			false, true
		),
		"character_scene": selected_character_scene,
		"character_name": selected_character_name,
		"campaign_fight_index": campaign_fight_index,
		"current_round": current_round,
		"round_timer": round_timer,
		"player_round_wins": player_round_wins,
		"enemy_round_wins": enemy_round_wins,
		"player": _get_fighter_snapshot(player),
		"enemy": _get_fighter_snapshot(enemy)
	}

	var file := FileAccess.open(
		MATCH_SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		_show_announcement("NO SE PUDO GUARDAR", 1.5)
		return

	file.store_var(snapshot)
	file.flush()

	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		_show_announcement("ERROR AL GUARDAR LA PARTIDA", 1.5)
		return

	saved_match = snapshot.duplicate(true)
	_show_announcement("PARTIDA GUARDADA", 1.2)
	
#guardao con tecla g
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_G:
				save_current_match()
				get_viewport().set_input_as_handled()
				
#restauracion de partida 
func _read_saved_match() -> bool:
	saved_match.clear()

	if not FileAccess.file_exists(MATCH_SAVE_PATH):
		return false

	var file := FileAccess.open(
		MATCH_SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return false

	var data: Variant = file.get_var(false)
	file.close()

	if not (data is Dictionary):
		return false

	if int(data.get("version", 0)) != 1:
		return false

	var required_keys := [
		"saved_at",
		"character_scene",
		"character_name",
		"campaign_fight_index",
		"current_round",
		"round_timer",
		"player_round_wins",
		"enemy_round_wins",
		"player",
		"enemy"
	]

	for key in required_keys:
		if not data.has(key):
			return false

	# Verificar que el personaje guardado esté entre los cinco disponibles.
	var saved_character_scene := str(data["character_scene"])
	var valid_character := false

	for character in AVAILABLE_CHARACTERS:
		if saved_character_scene == str(character["scene"]):
			valid_character = true
			break

	if not valid_character:
		return false

	# Validar los datos de ambos boxeadores.
	for fighter_key in ["player", "enemy"]:
		var fighter: Variant = data[fighter_key]

		if not (fighter is Dictionary):
			return false

		for key in [
			"health",
			"stamina",
			"position",
			"velocity",
			"regen_wait",
			"hit_stun_time",
			"knockback_velocity"
		]:
			if not fighter.has(key):
				return false

		if float(fighter["health"]) <= 0.0:
			return false

		for key in ["position", "velocity", "knockback_velocity"]:
			if not (fighter[key] is Vector2):
				return false

	if float(data["round_timer"]) <= 0.0:
		return false

	saved_match = data
	return true
	
func _restore_fighter_snapshot(
	boxer: BoxerBase,
	data: Dictionary
) -> void:
	# Limpia ataques y estados temporales del personaje.
	boxer.reset_for_round()

	# Después recupera los valores guardados.
	boxer.health = clampf(
		float(data["health"]),
		0.0,
		boxer.max_health
	)

	boxer.stamina = clampf(
		float(data["stamina"]),
		0.0,
		boxer.max_stamina
	)

	boxer.position = data["position"]
	boxer.velocity = data["velocity"]

	boxer.regen_wait = maxf(
		0.0,
		float(data["regen_wait"])
	)

	boxer.hit_stun_time = maxf(
		0.0,
		float(data["hit_stun_time"])
	)

	boxer.knockback_velocity = data["knockback_velocity"]
	
#partidad guardada
func show_saved_match() -> void:
	if not _read_saved_match():
		_show_message(
			"NO HAY PARTIDA GUARDADA\nPresiona G durante una pelea."
		)
		return

	# Reutiliza la pantalla que ya incluye un botón para volver.
	_show_message("PARTIDA GUARDADA")

	var screen := fight_ui.get_node("ErrorScreen") as Control

	var details := Label.new()
	details.position = Vector2(30, 180)
	details.size = Vector2(850, 100)
	details.add_theme_font_size_override("font_size", 20)

	details.text = (
		"Guardado: %s\n"
		+ "Personaje: %s | Ronda: %d | Tiempo: %d s\n"
		+ "Tu vida: %d | Vida rival: %d"
	) % [
		str(saved_match["saved_at"]),
		str(saved_match["character_name"]),
		int(saved_match["current_round"]),
		ceili(float(saved_match["round_timer"])),
		roundi(float(saved_match["player"]["health"])),
		roundi(float(saved_match["enemy"]["health"]))
	]

	screen.add_child(details)

	var resume_button := Button.new()
	resume_button.text = "CONTINUAR PARTIDA"
	resume_button.position = Vector2(30, 310)
	resume_button.size = Vector2(260, 45)

	_style_button(
		resume_button,
		Color("#283b42"),
		Color("#4b9d92")
	)

	resume_button.pressed.connect(_resume_saved_progress)
	screen.add_child(resume_button)
##cambio de fondo 
func _aplicar_escenario(ruta: String) -> void:
	var fondo := ring.get_node_or_null("FondoAnimado") as VideoStreamPlayer

	if fondo == null:
		push_error("Falta el nodo FondoAnimado dentro de Ring.")
		return

	if not ResourceLoader.exists(ruta):
		push_error("No se encuentra el escenario: " + ruta)
		return

	var video := load(ruta) as VideoStream

	if video == null:
		push_error("No se pudo cargar el video: " + ruta)
		return

	fondo.stop()
	fondo.stream = video
	fondo.expand = true
	fondo.loop = true
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.z_index = -10

	# Ajustar el tamaño y la posición de cada escenario.
# Ajustar el tamaño y la posición de cada escenario.
	if ruta == "res://assets/escenarios/escenario_banderas.ogv":
		fondo.size = Vector2(1584, 891)
		fondo.position = Vector2(-792, -510.5)

	elif ruta == "res://assets/escenarios/hinchas_luces_parpadeando_10s.ogv":
		fondo.position.y -= 10


	fondo.show()
	fondo.play()

	escenario_actual = ruta
	print("Escenario seleccionado: ", escenario_actual)


func _elegir_escenario_aleatorio() -> void:
	var opciones: Array[String] = []

	for ruta in ESCENARIOS:
		if ruta != escenario_actual:
			opciones.append(ruta)

	# Permitir que funcione incluso si solo queda un escenario.
	if opciones.is_empty():
		opciones.append_array(ESCENARIOS)

	if opciones.is_empty():
		return

	var indice: int = randi_range(0, opciones.size() - 1)
	_aplicar_escenario(opciones[indice])
