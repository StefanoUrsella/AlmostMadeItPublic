extends Node3D

@export var character: RigidBody3D
@export var target_body: RigidBody3D
@export var segments_count: int = 5  # Più segmenti per corda più lunga (era 6)
@export var segment_radius: float = 0.03
@export var segment_distance: float = 0.3  # Distanza aumentata (era 0.2)
@export var constraint_stiffness: float = 1.0  # Massima rigidità
@export var rope_thickness: float = 0.02  # Spessore visivo della corda

@onready var segments_container: Node3D = $Segments
@onready var rope_visual_container: Node3D = Node3D.new()  # Container per i cilindri visivi

var segments: Array = []
var rope_segments_visual: Array = []  # Array di MeshInstance3D per visualizzare la corda
var is_target_grabbed: bool = false

func _ready():
	if not character or not target_body:
		push_error("Character o Target Body non assegnati!")
		return
	
	await get_tree().process_frame
	
	target_body.set_meta("rope_script", self)
	target_body.add_to_group("rope_attached")
	
	target_body.mass = 8.0  # Peso pesante (era 2.0)
	target_body.gravity_scale = 2.0
	target_body.linear_damp = 0.0
	target_body.angular_damp = 0.5
	target_body.continuous_cd = true
	target_body.contact_monitor = true
	target_body.max_contacts_reported = 4
	target_body.collision_layer = 1
	target_body.collision_mask = 1
	target_body.can_sleep = false
	
	# Aggiungi il container per la visualizzazione
	rope_visual_container.name = "RopeVisual"
	add_child(rope_visual_container)
	
	create_rope()

func on_target_grabbed():
	print("Corda: Target afferrato - segmenti congelati")
	is_target_grabbed = true
	
	# CONGELA completamente i segmenti
	for segment in segments:
		segment.freeze = true
		segment.set_collision_layer_value(2, false)
		segment.set_collision_mask_value(1, false)

func on_target_released():
	print("Corda: Target rilasciato - segmenti riattivati")
	is_target_grabbed = false
	
	# Riattiva la fisica dei segmenti
	for segment in segments:
		segment.freeze = false
		segment.set_collision_layer_value(2, true)
		segment.set_collision_mask_value(1, true)
		segment.mass = 0.05
		segment.linear_damp = 5.0
		segment.angular_damp = 8.0
		segment.gravity_scale = 1.0

func get_max_rope_length() -> float:
	# Calcola la lunghezza massima della corda
	return segment_distance * (segments_count + 1)

func get_rope_tension_on_character() -> Vector3:
	if not character or not is_instance_valid(target_body) or segments.size() == 0:
		return Vector3.ZERO
	
	var char_pos = character.global_position
	var weight_pos = target_body.global_position
	var rope_direction = weight_pos - char_pos
	var current_length = rope_direction.length()
	var max_length = get_max_rope_length()
	
	if current_length <= max_length * 1.05:
		return Vector3.ZERO
	
	var stretch_amount = current_length - max_length
	
	var weight_velocity = target_body.linear_velocity
	var direction_normalized = rope_direction.normalized()
	
	var velocity_along_rope = weight_velocity.dot(direction_normalized)
	
	if velocity_along_rope > 0.1 or weight_velocity.y < -1.0:
		var base_force = stretch_amount * 200.0
		
		var falling_force = 0.0
		if weight_velocity.y < -1.0:
			falling_force = abs(weight_velocity.y) * target_body.mass * 5.0
		
		var total_force_magnitude = base_force + falling_force
		var tension_force = direction_normalized * total_force_magnitude
		
		return tension_force
	
	return Vector3.ZERO

func create_rope():
	var start_pos = character.global_position
	var end_pos = target_body.global_position
	
	print("=== CREAZIONE CORDA ===")
	print("Segmenti: ", segments_count)
	print("Distanza tra segmenti: ", segment_distance)
	
	# Crea i segmenti fisici (invisibili, solo per fisica)
	for i in range(segments_count):
		var t = float(i + 1) / float(segments_count + 1)
		var pos = start_pos.lerp(end_pos, t)
		
		var segment = RigidBody3D.new()
		segment.name = "Segment_%d" % i
		segment.mass = 0.05  # Più leggeri (era 0.08)
		segment.linear_damp = 5.0  # Più damping per ridurre oscillazioni (era 3.0)
		segment.angular_damp = 8.0  # Più damping angolare (era 5.0)
		segment.gravity_scale = 1.0
		segment.continuous_cd = true  # Collision detection continua
		segment.collision_layer = 2
		segment.collision_mask = 1
		
		segments_container.add_child(segment)
		segment.global_position = pos
		segments.append(segment)
		
		# Collision shape PICCOLA (fisica)
		var shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = segment_radius * 0.3  # Molto piccola
		shape.shape = sphere_shape
		segment.add_child(shape)
	
	# Crea i cilindri visivi che collegano i segmenti
	# Numero di cilindri = segments_count + 1 (character->seg1, seg1->seg2, ..., segN->target)
	for i in range(segments_count + 1):
		var cylinder = MeshInstance3D.new()
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.top_radius = rope_thickness
		cylinder_mesh.bottom_radius = rope_thickness
		cylinder_mesh.height = segment_distance
		cylinder.mesh = cylinder_mesh
		
		# Materiale per la corda (colore marrone/beige)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.4, 0.2)  # Marrone corda
		cylinder.material_override = material
		
		rope_visual_container.add_child(cylinder)
		rope_segments_visual.append(cylinder)
	
	print("=== CORDA CREATA CON %d SEGMENTI VISIVI ===" % rope_segments_visual.size())

func _physics_process(delta):
	if not character or segments.size() == 0 or not is_instance_valid(target_body):
		return
	
	# Aggiorna la visualizzazione della corda
	update_rope_visual()
	
	if is_target_grabbed:
		update_segments_when_grabbed(delta)
	else:
		apply_distance_constraints()

func update_rope_visual():
	# Aggiorna posizione e rotazione dei cilindri per collegare i punti
	var points = []
	points.append(character.global_position)
	for segment in segments:
		points.append(segment.global_position)
	points.append(target_body.global_position)
	
	# Aggiorna ogni cilindro per collegare i punti
	for i in range(rope_segments_visual.size()):
		if i < points.size() - 1:
			var start_point = points[i]
			var end_point = points[i + 1]
			var midpoint = (start_point + end_point) / 2.0
			var direction = end_point - start_point
			var distance = direction.length()
			
			var cylinder = rope_segments_visual[i]
			cylinder.global_position = midpoint
			
			# Orienta il cilindro verso il punto successivo
			if distance > 0.001:
				# Il cilindro di default è orientato lungo l'asse Y
				# Dobbiamo ruotarlo per puntare nella direzione corretta
				var up = Vector3.UP
				var right = up.cross(direction.normalized())
				if right.length() < 0.001:
					right = Vector3.RIGHT
				var forward = direction.normalized()
				up = forward.cross(right).normalized()
				right = up.cross(forward).normalized()
				
				cylinder.global_transform.basis = Basis(right, forward, up)
			
			# Scala l'altezza del cilindro in base alla distanza
			var cylinder_mesh = cylinder.mesh as CylinderMesh
			if cylinder_mesh:
				cylinder_mesh.height = distance

func update_segments_when_grabbed(delta):
	# Fa seguire i segmenti congelati in modo smooth
	var start_pos = character.global_position
	var end_pos = target_body.global_position
	
	for i in range(segments.size()):
		var t = float(i + 1) / float(segments.size() + 1)
		var target_pos = start_pos.lerp(end_pos, t)
		segments[i].global_position = segments[i].global_position.lerp(target_pos, delta * 5.0)

func apply_distance_constraints():
	var iterations = 8  # Più iterazioni = corda più rigida
	var stiffness = constraint_stiffness
	
	for iteration in range(iterations):
		# Constraint: character -> primo segmento
		# Applica solo se la corda è TESA (troppo lunga), non se compressa
		if is_instance_valid(character):
			var char_pos = character.global_position
			var seg0_pos = segments[0].global_position
			var delta_vec = seg0_pos - char_pos
			var current_distance = delta_vec.length()
			
			# Solo se la distanza SUPERA segment_distance
			if current_distance > segment_distance:
				var diff = (current_distance - segment_distance) / current_distance
				var correction = delta_vec * diff * stiffness
				segments[0].global_position -= correction

		# Constraint: tra segmenti
		# Solo quando tesi, non compressi
		for i in range(segments.size() - 1):
			var pos_a = segments[i].global_position
			var pos_b = segments[i + 1].global_position
			var delta_vec2 = pos_b - pos_a
			var current_distance2 = delta_vec2.length()
			
			# Solo se la distanza SUPERA segment_distance
			if current_distance2 > segment_distance:
				var diff2 = (current_distance2 - segment_distance) / current_distance2
				var correction2 = delta_vec2 * diff2 * stiffness * 0.5
				segments[i].global_position += correction2
				segments[i + 1].global_position -= correction2
		
		# Constraint: ultimo segmento -> target
		# Solo quando teso
		if is_instance_valid(target_body):
			var last_seg_pos = segments[segments.size() - 1].global_position
			var target_pos = target_body.global_position
			var delta_vec3 = target_pos - last_seg_pos
			var current_distance3 = delta_vec3.length()
			
			# Solo se la distanza SUPERA segment_distance
			if current_distance3 > segment_distance:
				var diff3 = (current_distance3 - segment_distance) / current_distance3
				var correction3 = delta_vec3 * diff3 * stiffness * 0.5
				segments[segments.size() - 1].global_position += correction3
		
				var direction = -correction3.normalized()
		
				# Componente della velocità già nella direzione corretta
				var velocity_in_direction = target_body.linear_velocity.dot(direction)
		
				# Applica forza solo per la parte mancante (evita effetto elastico)
				var needed_velocity = correction3.length() * 10.0  # Fattore di correzione morbido
				var force_magnitude = max(0, needed_velocity - velocity_in_direction)
		
				target_body.apply_central_force(direction * force_magnitude * target_body.mass)

func _process(delta):
	if Engine.get_process_frames() % 60 == 0 and segments.size() > 0:
		var dist0 = character.global_position.distance_to(segments[0].global_position)
		var dist_last = segments[segments.size() - 1].global_position.distance_to(target_body.global_position)
		print("Char->Seg0: %.2f | SegN->Target: %.2f | Grabbed: %s" % [dist0, dist_last, is_target_grabbed])
