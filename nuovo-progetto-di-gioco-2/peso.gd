extends RigidBody3D

func _ready() -> void:
	add_to_group("grabbable")
	print("Peso aggiunto al gruppo grabbable!")
	
	# Configurazione fisica - PESO PESANTE che può trascinare il player
	mass = 8.0  # Molto pesante! (era 2.0)
	gravity_scale = 2.0
	linear_damp = 0.0
	angular_damp = 0.5
	continuous_cd = true  # IMPORTANTE: previene attraversamento del terreno
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 1
	collision_mask = 1
	
	# Assicurati che il peso non dorma mai
	can_sleep = false

func _process(delta: float) -> void:
	# Previeni che il peso affondi controllando la posizione Y
	# (opzionale, solo se il problema persiste)
	pass
