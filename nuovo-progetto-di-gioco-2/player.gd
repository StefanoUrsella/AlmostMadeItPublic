extends RigidBody3D

#------GESTIONE MOVIMENTI------
@export_group("Controlli")
@export var input_sinistra = "sinistra1"
@export var input_destra = "destra1"
@export var input_su = "su1"
@export var input_tira_corda = "ui_down"
@export var input_tira_corda_a_me = "ui_up"
@export var limite_y: float = -20.0

const gameover = preload("res://game_over.tscn")

const SPEED = 5.0
const JUMP_VELOCITY = 5.0
const ROPE_PULL_SPEED = 3.0
var rotatedDestra = false
var rotatedSinistra = false

var is_stunned: bool = false
var stun_timer: float = 0.0
var is_grabbed: bool = false

#------GESTIONE AFFERRARE PESO------
var grabbed_object = null
var grab_position = null
var rope_script = null

@export var grab_distance = 1.0
@export var auto_grab_distance = 0.4
@export var grab_key = "afferrare"
@export var throw_key = "lanciare"
@export var aim_up_key = "ui_up"
@export var aim_down_key = "ui_down"
@export var min_angle = -90.0
@export var max_angle = 90.0

var is_aiming = false
var throw_angle = 45.0
var throw_power = 0.0
var max_throw_power = 700.0
var power_charge_speed = 400.0

@onready var anim = $Knight/AnimationPlayer
var current_anim = ""

@export var aim_ui: Control

func play_anim(anim_name: String) -> void:
	if current_anim != anim_name:
		current_anim = anim_name
		anim.play(anim_name)

func _ready() -> void:
	rotatedDestra = true
	grab_position = Marker3D.new()
	add_child(grab_position)
	grab_position.position = Vector3(0.5, 0.0, 0)
	
	add_to_group("players")
	add_to_group("grabbable")
	
	lock_rotation = true
	axis_lock_linear_z = true

func _physics_process(delta):
	if global_position.y < limite_y:
		get_tree().change_scene_to_packed(gameover)
	var is_grounded = _is_on_floor()
	if not is_grounded:
		if linear_velocity.y > 0:
			play_anim("camminare/Jump_Full_Short")
		else: 
			play_anim("camminare/Jump_Idle")
	elif abs(linear_velocity.x) > 0.1:
		play_anim("camminare/Running_A")
	else:
		play_anim("camminare/idle")
	if is_grabbed:
		linear_velocity = Vector3.ZERO
		return

	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			print(name, " non è più stordito!")
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
			return

	if rope_script and not grabbed_object and rope_script.character == self:
		var tension = rope_script.get_rope_tension_on_character()
		if tension.length() > 0:
			apply_central_force(tension)

	if input_su != "" and Input.is_action_just_pressed(input_su) and is_grounded:
		linear_velocity.y = JUMP_VELOCITY

	var input_x = Input.get_axis(input_sinistra, input_destra)

	if input_x > 0:
		rotatedDestra = true
		rotatedSinistra = false
	elif input_x < 0:
		rotatedDestra = false
		rotatedSinistra = true

	if grabbed_object == null or not is_instance_valid(grabbed_object):
		var is_pulling_rope = Input.is_action_pressed(input_tira_corda)
		var is_pulling_to_rope_a_me = Input.is_action_pressed(input_tira_corda_a_me)

		if is_pulling_rope and rope_script:
			var weight_position = rope_script.target_body.global_position
			var direction_to_weight = (weight_position - global_position).normalized()

			linear_velocity.x = direction_to_weight.x * ROPE_PULL_SPEED
			linear_velocity.y = direction_to_weight.y * ROPE_PULL_SPEED

			var distance_to_weight = global_position.distance_to(weight_position)
			if distance_to_weight <= auto_grab_distance:
				grab_object(rope_script.target_body)
				print("Afferrato automaticamente tirando la corda!")
		elif is_pulling_to_rope_a_me and rope_script:
			var weight_position = rope_script.target_body.global_position
			var direction_to_player = (global_position - weight_position).normalized()

			linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
			rope_script.target_body.apply_central_force(direction_to_player * 50.0)
		elif input_x != 0:
			linear_velocity.x = input_x * SPEED
			if rotatedDestra:
				rotation.y = deg_to_rad(0)
			elif rotatedSinistra:
				rotation.y = deg_to_rad(180)
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
	else:
		if input_x != 0:
			linear_velocity.x = input_x * SPEED
			if rotatedDestra:
				rotation.y = deg_to_rad(0)
			elif rotatedSinistra:
				rotation.y = deg_to_rad(180)
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)

	if grabbed_object != null and is_instance_valid(grabbed_object) and grabbed_object.is_in_group("players"):
		grabbed_object.global_position = grab_position.global_position
		grabbed_object.linear_velocity = Vector3.ZERO

	# BLOCCO CORDA - deve essere ULTIMO
	if rope_script and not grabbed_object and rope_script.character == self:
		var points = [global_position]
		for seg in rope_script.segments:
			points.append(seg.global_position)
		points.append(rope_script.target_body.global_position)
		
		var real_length = 0.0
		for i in range(points.size() - 1):
			real_length += points[i].distance_to(points[i+1])
		
		var max_length = rope_script.get_max_rope_length()
		if real_length >= max_length + 3:
			var away_dir = -(rope_script.target_body.global_position - global_position).normalized()
			var vel_away = linear_velocity.dot(away_dir)
			if vel_away > 0:
				linear_velocity -= away_dir * vel_away

func _process(delta):
	if grabbed_object != null:
		if not is_aiming:
			if Input.is_action_pressed(throw_key):
				is_aiming = true
				throw_power = 0.0
				if aim_ui:
					aim_ui.show_aim(true)
		else:
			if Input.is_action_pressed(aim_up_key):
				throw_angle = min(throw_angle + 60 * delta, max_angle)
			if Input.is_action_pressed(aim_down_key):
				throw_angle = max(throw_angle - 60 * delta, min_angle)
			print(throw_angle)

			throw_power = min(throw_power + power_charge_speed * delta, max_throw_power)

			if aim_ui:
				aim_ui.update_aim(throw_angle, throw_power / max_throw_power)

			if Input.is_action_just_released(throw_key):
				throw_object()
				is_aiming = false
				if aim_ui:
					aim_ui.show_aim(false)
	else:
		if Input.is_action_just_pressed(grab_key):
			try_grab()

func get_stunned(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

	if grabbed_object != null:
		throw_angle = 0
		throw_power = 5
		throw_object()

	print(name, " è stato colpito dal guano e stordito per ", duration, " secondi!")

func _is_on_floor() -> bool:
	if not is_inside_tree():
		return false
	
	var world = get_world_3d()
	if not world:
		return false
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 1.1
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func try_grab():
	var bodies = get_tree().get_nodes_in_group("grabbable")
	var closest_body = null
	var closest_distance = grab_distance

	for body in bodies:
		if body == self:
			continue
		var distance = global_position.distance_to(body.global_position)
		print("Distanza da ", body.name, ": ", distance)
		if distance <= closest_distance:
			closest_body = body
			closest_distance = distance

	if closest_body:
		grab_object(closest_body)
		print("Afferrato: ", closest_body.name)
	else:
		print("Nessun oggetto abbastanza vicino!")

func grab_object(object):
	grabbed_object = object

	if object.has_meta("rope_script"):
		rope_script = object.get_meta("rope_script")
		if rope_script and rope_script.has_method("on_target_grabbed"):
			rope_script.on_target_grabbed()

	if object.is_in_group("players"):
		object.is_grabbed = true
		object.linear_velocity = Vector3.ZERO
	else:
		for i in range(1, 33):
			object.set_collision_layer_value(i, false)
			object.set_collision_mask_value(i, false)
		object.freeze = true
		var old_parent = object.get_parent()
		if old_parent:
			old_parent.remove_child(object)
		grab_position.add_child(object)
		object.position = Vector3.ZERO

func throw_object():
	if grabbed_object != null:
		if grabbed_object.is_in_group("players"):
			grabbed_object.is_grabbed = false

			if grabbed_object is RigidBody3D:
				var angle_rad = deg_to_rad(throw_angle)
				var horizontal_dir = 1.0 if rotation.y == 0 else -1.0
				var throw_direction = Vector3(
					cos(angle_rad) * horizontal_dir,
					sin(angle_rad),
					0
				).normalized()
				grabbed_object.apply_central_impulse(throw_direction * throw_power)
		else:
			var global_pos = grabbed_object.global_position
			grab_position.remove_child(grabbed_object)
			get_tree().current_scene.add_child(grabbed_object)
			grabbed_object.global_position = global_pos
			grabbed_object.set_collision_layer_value(1, true)
			grabbed_object.set_collision_mask_value(1, true)
			grabbed_object.freeze = false

			if rope_script and rope_script.has_method("on_target_released"):
				rope_script.on_target_released()

			if grabbed_object is RigidBody3D:
				var angle_rad = deg_to_rad(throw_angle)
				var horizontal_dir = 1.0 if rotation.y == 0 else -1.0
				var throw_direction = Vector3(
					cos(angle_rad) * horizontal_dir,
					sin(angle_rad),
					0
				).normalized()
				grabbed_object.apply_central_impulse(throw_direction * throw_power)

		grabbed_object = null
