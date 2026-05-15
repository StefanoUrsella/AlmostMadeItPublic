extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var start: Panel = $Start

var mode = "singleplayer"
var difficulty = "normal"

const map1 = preload("res://map.tscn")
const map2 = preload("res://mapDark.tscn")
const map3 = preload("res://map2Players.tscn")
const map4 = preload("res://map2PlayersDark.tscn")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_buttons.visible = true
	options.visible = false
	start.visible = false
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	main_buttons.visible = false
	start.visible = true
	pass # Replace with function body.


func _on_options_pressed() -> void:
	main_buttons.visible = false
	options.visible = true
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_back_pressed() -> void:
	options.visible = false
	main_buttons.visible = true
	pass # Replace with function body.


func _on_start_game_pressed() -> void:
	if (mode == "singleplayer" && difficulty == "normal"):
		get_tree().change_scene_to_packed(map1)
	elif (mode == "singleplayer" && difficulty == "darkness"):
		get_tree().change_scene_to_packed(map2)
	elif (mode == "multiplayer" && difficulty == "normal"):
		get_tree().change_scene_to_packed(map3)
	elif (mode == "multiplayer" && difficulty == "darkness"):
		get_tree().change_scene_to_packed(map4)
	pass # Replace with function body.


func _on_back_menu_pressed() -> void:
	start.visible = false
	main_buttons.visible = true
	pass # Replace with function body.


func _on_mode_item_selected(index: int) -> void:
	if index == 0:
		mode = "singleplayer"
	elif index == 1:
		mode = "multiplayer"
	pass # Replace with function body.


func _on_difficulty_item_selected(index: int) -> void:
	if index == 0:
		difficulty = "normal"
	elif index == 1:
		difficulty = "darkness"
	pass # Replace with function body.
