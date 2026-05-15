extends RigidBody3D

@export var target: CharacterBody3D
@export var offset := Vector3.ZERO

func _physics_process(_delta):
	if target:
		global_position = target.global_position + offset
		linear_velocity = Vector3.ZERO
