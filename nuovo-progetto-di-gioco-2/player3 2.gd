extends RigidBody3D

@export_group("Controlli")
@export var input_sinistra:   String = "sinistra1"
@export var input_destra:     String = "destra1"
@export var input_su:         String = "su1"
@export var input_tira_corda: String = "afferrare1"

@export_group("Parametri")
@export var grab_distance:    float = 1.7
const SPEED:      float = 5.0
const JUMP_SPEED: float = 7.0
const BRAKE_DAMP: float = 15.0

var rope_script    = null
var grabbed_object: RigidBody3D = null
var grab_position:  Marker3D    = null
var is_on_floor:    bool        = false
var _floor_ray:     RayCast3D   = null
var _grab_blocked:  bool        = false

func _ready() -> void:
	lock_rotation   = true
	gravity_scale   = 1.0
	mass            = 1.0
	linear_damp     = 0.0
	angular_damp    = 10.0
	collision_layer = 1
	collision_mask  = 1

	# Punto in cui il peso viene "tenuto" (leggermente davanti e sopra)
	grab_position          = Marker3D.new()
	grab_position.position = Vector3(1, 0.5, 0)
	add_child(grab_position)

	# Setup Raycast per il salto
	_floor_ray                 = RayCast3D.new()
	_floor_ray.name            = "FloorRay"
	_floor_ray.target_position = Vector3(0, -1.1, 0)
	_floor_ray.collision_mask  = 1
	add_child(_floor_ray)

func _physics_process(delta: float) -> void:
	is_on_floor = _floor_ray.is_colliding()

	# SBLOCCO GRAB: Solo quando il tasto viene fisicamente rilasciato
	if _grab_blocked and Input.is_action_just_released(input_tira_corda):
		_grab_blocked = false

	# GESTIONE INPUT CORDA/PESO
	if Input.is_action_just_pressed(input_tira_corda):
		if grabbed_object != null:
			_release_object()
			_grab_blocked = true # Impedisce ri-presa immediata

	# Se teniamo premuto e non abbiamo nulla in mano
	if Input.is_action_pressed(input_tira_corda) and not _grab_blocked and grabbed_object == null:
		if rope_script != null:
			var dist := global_position.distance_to(rope_script.target_body.global_position)
			if dist <= grab_distance:
				_grab_object(rope_script.target_body)
			else:
				# Tira il player verso il peso (scalata)
				rope_script.pull_target_towards_character(delta)

	# MOVIMENTO ORIZZONTALE
	var is_pulling = Input.is_action_pressed(input_tira_corda) and not _grab_blocked and grabbed_object == null
	
	if not is_pulling:
		var input_x := Input.get_axis(input_sinistra, input_destra)
		if grabbed_object == null:
			if abs(input_x) > 0.05:
				linear_velocity.x = input_x * SPEED
			else:
				linear_velocity.x = move_toward(linear_velocity.x, 0.0, BRAKE_DAMP * delta)
		else:
			# Se abbiamo il peso in mano, il player sta fermo (o gestisci diversamente)
			linear_velocity.x = 0.0
		
		linear_velocity.z = 0.0 # Forza il movimento 2D in ambiente 3D

	# SALTO
	if Input.is_action_just_pressed(input_su) and is_on_floor:
		linear_velocity.y = JUMP_SPEED

	# AGGIORNAMENTO POSIZIONE PESO (Se afferrato)
	if grabbed_object != null and is_instance_valid(grabbed_object):
		grabbed_object.global_position  = grab_position.global_position
		grabbed_object.linear_velocity  = Vector3.ZERO
		grabbed_object.angular_velocity = Vector3.ZERO

func _grab_object(object: RigidBody3D) -> void:
	grabbed_object = object
	
	# Recupera il riferimento allo script della corda se non ce l'ha
	if rope_script == null and object.has_meta("rope_script"):
		rope_script = object.get_meta("rope_script")
	
	if rope_script != null:
		rope_script.on_target_grabbed()
	
	# Sblocca assi per permettere il trasporto laterale
	object.axis_lock_linear_x = false
	object.axis_lock_linear_z = false
	object.gravity_scale      = 0.0
	object.set_collision_mask_value(1, false) # Non collidere col player mentre lo tieni

func _release_object() -> void:
	# FIX SICUREZZA: Controllo validità prima di ogni operazione
	if grabbed_object == null:
		return
		
	if not is_instance_valid(grabbed_object):
		grabbed_object = null
		return

	# Notifica la corda
	if rope_script != null:
		rope_script.on_target_released()

	# RIPRISTINO FISICO (Eseguito PRIMA di annullare la variabile)
	grabbed_object.axis_lock_linear_x = true
	grabbed_object.axis_lock_linear_z = true
	grabbed_object.gravity_scale     = 1.0
	grabbed_object.linear_damp       = 1.5
	grabbed_object.set_collision_mask_value(1, true)
	
	# Lancia il peso con la velocità attuale del player
	grabbed_object.linear_velocity   = linear_velocity
	
	# Annulla il riferimento solo alla fine
	grabbed_object = null
