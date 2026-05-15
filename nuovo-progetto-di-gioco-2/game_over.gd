extends Control

const menu = preload("res://main_menu.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Options.pressed.connect(_on_options_pressed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_options_pressed() -> void:
	get_tree().change_scene_to_packed(menu)
	pass # Replace with function body.
