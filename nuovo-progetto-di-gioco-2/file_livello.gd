extends Area3D

const menu = preload("res://main_menu.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		get_tree().change_scene_to_packed(menu)
		pass # Replace with function body.
