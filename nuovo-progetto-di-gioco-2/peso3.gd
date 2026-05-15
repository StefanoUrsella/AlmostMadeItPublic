extends RigidBody3D

func _ready() -> void:
	add_to_group("grabbable")
	mass                  = 10.0
	gravity_scale         = 1.0
	linear_damp           = 1.5
	angular_damp          = 3.0
	continuous_cd         = true
	contact_monitor       = true
	max_contacts_reported = 4
	collision_layer       = 1
	collision_mask        = 1
	can_sleep             = false
	
	# Blocco iniziale: muove solo verticalmente (Y)
	axis_lock_linear_x = true
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
