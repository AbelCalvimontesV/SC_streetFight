
extends Node

const SOUND_HEAVY_ATTACK: AudioStream = preload("res://assets/audio/heavyatackSound.wav")
const SOUND_JAB: AudioStream = preload("res://assets/audio/jabSonido.wav")
const SOUND_KICK: AudioStream = preload("res://assets/audio/kickSound.wav")
const SOUND_HITS: AudioStream = preload("res://assets/audio/sonidos.wav")
const SOUND_SPECIAL: AudioStream = preload("res://assets/audio/SpecialSonido.wav")

var audio_players: Array[AudioStreamPlayer] = []
const MAX_AUDIO_PLAYERS: int = 8


func _ready() -> void:
	for i in range(MAX_AUDIO_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SoundPlayer" + str(i + 1)
		add_child(player)
		audio_players.append(player)


func play_sound(sound: AudioStream, volume_db: float = 0.0) -> void:
	if sound == null:
		return

	for player in audio_players:
		if not player.playing:
			player.stream = sound
			player.volume_db = volume_db
			player.play()
			return

	# Si todos están ocupados, reutilizar el primero.
	var player := audio_players[0]
	player.stop()
	player.stream = sound
	player.volume_db = volume_db
	player.play()


func play_jab() -> void:
	play_sound(SOUND_JAB)


func play_heavy_attack() -> void:
	play_sound(SOUND_HEAVY_ATTACK)


func play_kick() -> void:
	play_sound(SOUND_KICK)


func play_hit() -> void:
	play_sound(SOUND_HITS)


func play_special() -> void:
	play_sound(SOUND_SPECIAL)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			play_jab()
			print("Prueba de sonido: jab")
