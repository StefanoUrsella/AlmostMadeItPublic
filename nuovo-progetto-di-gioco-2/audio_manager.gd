extends Node

@onready var music = AudioStreamPlayer.new()
const MUSIC = preload("res://Sounds/moodmode-game-8-bit-on-278083_rCsKTe1M.mp3")

func _ready() -> void:
	add_child(music)
	music.stream = MUSIC
	music.bus = "Music"
	music.finished.connect(_on_music_finished)
	music.play()

func _on_music_finished() -> void:
	music.play()
