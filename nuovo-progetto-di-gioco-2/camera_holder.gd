extends Node3D

@export var target: Node3D  # Trascina qui il Player nell'inspector

func _physics_process(_delta) -> void:
	if target:
		global_position = target.global_position
	global_rotation = Vector3.ZERO
