extends Node

const GREEN := Color("#16b86a")
const GREEN_LIGHT := Color("#69f0a0")
const GOLD := Color("#ffd447")
const WHITE := Color("#f5fff8")
const MUTED := Color("#9bb8a7")
const DEEP := Color("#07130f")
const PANEL := Color("#10251c")
const PORTRAITS := {
	"MamenSavedra": "res://assets/arcade/portrait_mamen.png",
	"MarioCronenbold": "res://assets/arcade/portrait_mario.png",
	"Maju": "res://assets/arcade/portrait_maju.png",
	"Vinchita": "res://assets/arcade/portrait_vinchita.png",
	"ChichoMedina": "res://assets/arcade/portrait_chicho.png",
}
const DISPLAY_NAMES := {
	"MamenSavedra": "MAMEN SAAVEDRA",
	"MarioCronenbold": "MARIO CRONENBOLD",
	"Maju": "MAJU",
	"Vinchita": "VINCHITA",
	"ChichoMedina": "CHICHO MEDINA",
}

const MAIN_MENU_MUSIC_PATH := "res://assets/Sonidos/Sonidos/Mobb-Deep-Shook-Ones_-Pt.-II-_Official-Audio_.wav"
const BUTTON_CLICK_PATH := "res://assets/Sonidos/Sonidos/sonido-menu-_712BE0B_.wav"

var _menu_music_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _click_stream: AudioStream
var _music_mode := ""

var _styled: Dictionary = {}
var _result_text_by_id: Dictionary = {}
var _bell_player: AudioStreamPlayer
var _bell_stream: AudioStream
var _music_player: AudioStreamPlayer




func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Sonido de campana de combate
	_bell_stream = load("res://assets/audio/arcade_round_bell.wav") as AudioStream

	_bell_player = AudioStreamPlayer.new()
	_bell_player.name = "ArcadeRoundBell"
	_bell_player.volume_db = -2.0
	_bell_player.stream = _bell_stream
	add_child(_bell_player)

	# Sonido de clic de los botones
	if ResourceLoader.exists(BUTTON_CLICK_PATH):
		_click_stream = load(BUTTON_CLICK_PATH) as AudioStream

	if _click_stream != null:
		_click_player = AudioStreamPlayer.new()
		_click_player.name = "ButtonClickSound"
		_click_player.volume_db = 0.0
		_click_player.stream = _click_stream
		add_child(_click_player)
	else:
		push_error("No se pudo cargar el sonido: " + BUTTON_CLICK_PATH)

	# Música única para menú y combate
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MainMenuMusic"
	_menu_music_player.stream = load(MAIN_MENU_MUSIC_PATH) as AudioStream
	_menu_music_player.volume_db = -6.0
	_menu_music_player.bus = &"Master"
	add_child(_menu_music_player)

	if _menu_music_player.stream != null:
		_menu_music_player.play()
	else:
		push_error("No se pudo cargar la música: " + MAIN_MENU_MUSIC_PATH)

	# No iniciar la música anterior de combate





func _process(_delta: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	_style_tree(root)
	_watch_announcement(root)
	_enforce_local_controls(root)
	_update_controls_layout(root)
	_update_music(root)



func _style_tree(node: Node) -> void:
	if node is Control:
		var control := node as Control
		var key := control.get_instance_id()
		if not _styled.has(key):
			_styled[key] = true
			_style_control(control)
	for child in node.get_children():
		_style_tree(child)



func _style_control(control: Control) -> void:
	# Conectar el sonido a botones normales y TextureButton.
	if control is BaseButton:
		var base_button := control as BaseButton

		if not base_button.pressed.is_connected(_play_button_click):
			base_button.pressed.connect(_play_button_click)

	# Mantener el estilo visual existente.
	if control is Button:
		var button := control as Button

		if button.name.ends_with("SelectButton"):
			_style_character_card(button)
		else:
			_translate_button(button)
			_style_arcade_button(button)

	elif control is ProgressBar:
		_style_status_bar(control as ProgressBar)

	elif control is Label:
		_translate_label(control as Label)
		_style_label(control as Label)

	elif control.name == "MenuBackground" or control.name == "CharacterSelectBackground":
		_style_backdrop(control)

	elif control.name == "MenuPanel" or control.name == "TimerPanel":
		_style_panel(control)

	elif control.name == "HUD":
		_build_arcade_hud(control)






func _build_arcade_hud(hud: Control) -> void:
	_make_hud_card(hud, "ArcadePlayerCard", Vector2(18, 4), Vector2(324, 92), GREEN)
	_make_hud_card(hud, "ArcadeRivalCard", Vector2(618, 4), Vector2(324, 92), GOLD)
	_remove_arcade_controls(hud)


func _make_hud_card(parent: Control, card_name: String, card_position: Vector2, card_size: Vector2, accent: Color) -> void:
	if parent.has_node(card_name):
		return
	var card := Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _box(Color("#07150f"), accent, 2, 4))
	parent.add_child(card)
	parent.move_child(card, 0)



func _build_arcade_controls(hud: Control) -> void:
	if hud.has_node("ArcadeControlsPanel"):
		return
	var panel := PanelContainer.new()
	panel.name = "ArcadeControlsPanel"
	panel.position = Vector2(24, 452)
	panel.size = Vector2(912, 76)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("#07150f"), GREEN, 2, 4))
	hud.add_child(panel)
	var columns := HBoxContainer.new()
	columns.name = "ControlColumns"
	columns.add_theme_constant_override("separation", 10)
	panel.add_child(columns)
	_add_control_column(columns, "P1 · KEYBOARD", "Move A/D · Jump W\nCrouch S · Block I\nJ Jab · K Heavy · L Kick\nU Special")
	_add_control_column(columns, "P2 · KEYBOARD", "Move ←/→ · Jump ↑\nCrouch ↓ · Block Y\nF Jab · G Heavy · H Kick\nT Special")
	_add_control_column(columns, "CONTROLLER", "Left Stick/D-pad: Move · A: Jump\nX: Jab · Y: Heavy · B: Kick\nRB: Special · LB: Block")

func _add_control_column(parent: HBoxContainer, heading_text: String, body_text: String) -> void:
	var column := VBoxContainer.new()
	column.name = "P1Controls" if heading_text.begins_with("P1") else ("P2Controls" if heading_text.begins_with("P2") else "PadControls")
	column.custom_minimum_size = Vector2(290, 65)
	column.add_theme_constant_override("separation", 1)
	parent.add_child(column)
	var heading := Label.new()
	heading.name = "ArcadeControlHeading"
	heading.text = heading_text
	heading.custom_minimum_size.y = 15
	heading.add_theme_color_override("font_color", GOLD)
	heading.add_theme_font_size_override("font_size", 10)
	column.add_child(heading)
	var body := Label.new()
	body.name = "ArcadeControlBody"
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_theme_color_override("font_color", WHITE)
	body.add_theme_font_size_override("font_size", 9)
	column.add_child(body)



func _enforce_local_controls(root: Node) -> void:
	if not bool(root.get("multijugador_local")):
		return
	var pads := Input.get_connected_joypads()
	var selecting_player := int(root.get("selecting_player_number"))
	var confirm := root.find_child("ConfirmButton", true, false) as Button
	if confirm != null and selecting_player == 2:
		confirm.disabled = pads.is_empty()
		confirm.text = "CONNECT P2 CONTROLLER" if pads.is_empty() else "LET'S FIGHT!"
	if not bool(root.get("fight_started")):
		return
	var player_one := root.get("player") as Node
	var player_two := root.get("enemy") as Node
	if player_one != null:
		player_one.set("usar_teclado", true)
		player_one.set("mando_id", -1)
	if player_two != null:
		player_two.set("usar_teclado", false)
		player_two.set("mando_id", pads[0] if not pads.is_empty() else -1)




func _update_controls_layout(root: Node) -> void:
	var panel := root.find_child("ArcadeControlsPanel", true, false) as Control
	if panel == null:
		return
	var columns := panel.get_node_or_null("ControlColumns") as HBoxContainer
	if columns == null or columns.get_child_count() < 3:
		return
	var local_mode := bool(root.get("multijugador_local"))
	var connected := not Input.get_connected_joypads().is_empty()
	var p1_column := columns.get_child(0) as VBoxContainer
	var p2_column := columns.get_child(1) as VBoxContainer
	var pad_column := columns.get_child(2) as VBoxContainer
	if local_mode:
		p1_column.custom_minimum_size.x = 290
		p2_column.visible = true
		p2_column.custom_minimum_size.x = 290
		pad_column.custom_minimum_size.x = 290
		(p2_column.get_child(0) as Label).text = "P2 · CONTROLLER"
		(p2_column.get_child(1) as Label).text = "Left Stick: Move · A: Jump\nX: Jab · Y: Heavy · B: Kick\nRB: Special · LB: Block"
		(pad_column.get_child(0) as Label).text = "CONTROLLER STATUS"
		(pad_column.get_child(1) as Label).text = "P2 Ready · Controller Connected" if connected else "P2 Controller Missing\nConnect a controller to start"
	else:
		p1_column.custom_minimum_size.x = 430
		p2_column.visible = false
		pad_column.custom_minimum_size.x = 430
		(pad_column.get_child(0) as Label).text = "OPTIONAL CONTROLLER · P1"
		(pad_column.get_child(1) as Label).text = "Left Stick/D-pad: Move · A: Jump\nX: Jab · Y: Heavy · B: Kick\nRB: Special · LB: Block"
	


func _translate_button(button: Button) -> void:
	var translations := {
		"SINGLE PLAYER": "SINGLE PLAYER",
		"LOCAL MULTIPLAYER": "LOCAL MULTIPLAYER",
		"LOAD SAVED GAME": "CONTINUE",
		"VIEW CAREER RECORD": "CAREER RECORD",
		"CONTROLS": "CONTROLS",
		"BACK TO MENU": "BACK TO MENU",
		"CONFIRM": "LET'S FIGHT!",
		"MAIN MENU": "MAIN MENU",
		"REMATCH": "REMATCH",
		"EXIT": "EXIT",
	}
	var original := button.text.strip_edges().to_upper()
	if translations.has(original):
		button.text = translations[original]




func _translate_label(label: Label) -> void:
	var original := label.text.strip_edges()
	var translations := {
		"PIXEL BOXING CLUB": "PIXEL BOXING CLUB",
		"CHOOSE YOUR GAME MODE": "CHOOSE YOUR GAME MODE",
		"HEALTH": "HEALTH",
		"STAMINA": "STAMINA",
	}
	if translations.has(original):
		label.text = translations[original]
	elif original == "SELECT YOUR FIGHTER":
		label.text = "SELECT YOUR FIGHTER"
	elif original.begins_with("PLAYER ") and original.ends_with(" SELECT YOUR FIGHTER"):
		var player_number := original.trim_prefix("PLAYER ").trim_suffix(" SELECT YOUR FIGHTER")
		label.text = "PLAYER %s · SELECT YOUR FIGHTER" % player_number



func _style_arcade_button(button: Button) -> void:
	var accent := GREEN
	if button.text.to_upper().contains("EXIT") or button.text.to_upper().contains("SALIR"):
		accent = Color("#c8444d")
	var base := Color("#123425")
	if button.text.to_upper().contains("SINGLE") or button.text.to_upper().contains("PLAYER") or button.text.to_upper().contains("CONFIRM") or button.text.to_upper().contains("UN JUGADOR") or button.text.to_upper().contains("PELEAR"):
		base = Color("#12633b")
	button.add_theme_stylebox_override("normal", _box(base, accent, 2, 3))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.18), GOLD, 2, 3))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.15), GREEN_LIGHT, 2, 3))
	button.add_theme_stylebox_override("focus", _box(Color("#133321"), GOLD, 2, 3))
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_font_size_override("font_size", 13)


func _style_character_card(button: Button) -> void:
	var character_id := button.name.trim_suffix("SelectButton")
	if not PORTRAITS.has(character_id):
		return
	var was_selected := false
	var existing := button.get_theme_stylebox("normal")
	if existing is StyleBoxFlat:
		was_selected = (existing as StyleBoxFlat).border_color == Color("#f4cf72")
	var border := GOLD if was_selected else GREEN
	var fill := Color("#0b2016") if was_selected else Color("#0a1712")
	button.add_theme_stylebox_override("normal", _box(fill, border, 3 if was_selected else 2, 4))
	button.add_theme_stylebox_override("hover", _box(Color("#143b27"), GOLD, 3, 4))
	button.add_theme_stylebox_override("pressed", _box(Color("#1b5234"), GREEN_LIGHT, 3, 4))
	button.add_theme_stylebox_override("focus", _box(fill, GOLD, 3, 4))
	button.text = ""
	button.clip_contents = true
	var portrait := TextureRect.new()
	portrait.name = "ArcadePortrait"
	portrait.texture = load(PORTRAITS[character_id]) as Texture2D
	portrait.position = Vector2((button.size.x - 58.0) / 2.0, 3.0)
	portrait.size = Vector2(58, 53)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	var name_label := Label.new()
	name_label.name = "ArcadeFighterName"
	name_label.text = DISPLAY_NAMES[character_id]
	name_label.position = Vector2(4, 61)
	name_label.size = Vector2(button.size.x - 8, 23)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", GOLD if was_selected else WHITE)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)


func _style_status_bar(bar: ProgressBar) -> void:
	var is_stamina := bar.name.to_lower().contains("stamina")
	var accent := GOLD if is_stamina else GREEN_LIGHT
	var fill := Color("#e0b82f") if is_stamina else Color("#18c66b")
	bar.add_theme_stylebox_override("background", _box(Color("#06110d"), Color("#38724f"), 2, 3))
	bar.add_theme_stylebox_override("fill", _box(fill, accent, 1, 2))
	bar.add_theme_color_override("font_color", WHITE)
	bar.add_theme_color_override("font_outline_color", DEEP)
	bar.add_theme_constant_override("outline_size", 2)
	if bar.name == "EnemyHealthBar" or bar.name == "EnemyStaminaBar":
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN



func _style_label(label: Label) -> void:
	if label.name == "ArcadeControlHeading":
		label.add_theme_color_override("font_color", GOLD)
		label.add_theme_font_size_override("font_size", 10)
	elif label.name == "ArcadeControlBody":
		label.add_theme_color_override("font_color", WHITE)
		label.add_theme_font_size_override("font_size", 9)
	elif label.name == "CharacterSelectTitle":
		label.text = "SELECT YOUR FIGHTER"
		label.add_theme_color_override("font_color", GOLD)
		label.add_theme_font_size_override("font_size", 29)
	elif label.name == "SelectedCharacterLabel":
		label.add_theme_color_override("font_color", GREEN_LIGHT)
		label.add_theme_font_size_override("font_size", 14)
	elif label.name in ["PlayerLabel", "EnemyLabel"]:
		label.add_theme_color_override("font_color", GREEN_LIGHT if label.name == "PlayerLabel" else GOLD)
	elif label.name in ["PlayerHealthCaption", "PlayerStaminaCaption", "EnemyHealthCaption", "EnemyStaminaCaption"]:
		label.add_theme_color_override("font_color", MUTED)
	elif label.name == "BrandLabel":
		label.text = "SANTA CRUZ • ARCADE FIGHT"
		label.add_theme_color_override("font_color", GREEN_LIGHT)
	elif label.name == "RoundLabel":
		label.add_theme_color_override("font_color", GOLD)
	elif label.name == "ResultLabel":
		label.add_theme_color_override("font_color", GOLD)
	else:
		label.add_theme_color_override("font_color", WHITE)



func _style_backdrop(control: Control) -> void:
	if control is ColorRect:
		(control as ColorRect).color = Color("#06110d")
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := ColorRect.new()
	top.name = "ArcadeTopStripe"
	top.position = Vector2.ZERO
	top.size = Vector2(960, 6)
	top.color = GREEN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(top)
	var bottom := ColorRect.new()
	bottom.name = "ArcadeBottomStripe"
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -4.0
	bottom.offset_bottom = 0.0
	bottom.color = GOLD
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(bottom)


func _style_panel(control: Control) -> void:
	control.add_theme_stylebox_override("panel", _box(PANEL, GREEN, 3, 5))


func _box(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _watch_announcement(root: Node) -> void:
	var label := root.find_child("ResultLabel", true, false) as Label
	if label == null:
		return
	label.add_theme_color_override("font_color", GOLD)
	var key := label.get_instance_id()
	var current_text := label.text.strip_edges().to_upper()
	if _result_text_by_id.get(key, "") == current_text:
		return
	_result_text_by_id[key] = current_text
	if current_text == "FIGHT!" or current_text == "FIGHT" or current_text.begins_with("ROUND "):
		if _bell_player != null and _bell_stream != null:
			_bell_player.stream = _bell_stream
			_bell_player.play()
			
			

func _remove_arcade_controls(hud: Control) -> void:
	var controls_panel := hud.get_node_or_null("ArcadeControlsPanel")
	if controls_panel != null:
		controls_panel.queue_free()


func _update_music(_root: Node) -> void:
	if _menu_music_player == null:
		return

	if not _menu_music_player.playing:
		_menu_music_player.play()

	_music_mode = "main"


func _play_button_click() -> void:
	if _click_player == null or _click_stream == null:
		return

	_click_player.stop()
	_click_player.play()
	
