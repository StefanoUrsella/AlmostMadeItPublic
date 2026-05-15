@tool
extends Node3D

## ============================================================
##  MOUNTAIN BACKGROUND GENERATOR 3D - Con parallasse camera
##  Lo sfondo segue la camera del player con velocità diverse
##  per ogni piano, simulando la profondità atmosferica.
## ============================================================

# --- GENERAZIONE ---
@export_group("Generazione")
@export var genera_al_avvio := true
@export var seed_casuale: int = 0

# --- CAMERA ---
@export_group("Camera")
## Lascia vuoto per trovare la Camera3D automaticamente
@export var camera_path: NodePath = NodePath("")
## Se true segue anche l'asse Y (utile per salti/cadute)
@export var segui_asse_y := false
## Quanto smorzare l'inseguimento (0 = istantaneo, 1 = molto lento)
@export_range(0.0, 0.99) var smoothing: float = 0.0

# --- PIANI ---
@export_group("Piani (layers)")
@export var numero_piani: int = 5
@export var z_primo_piano: float = -30.0
@export var z_ultimo_piano: float = -250.0
## Quanto ogni piano segue la camera: il piano più vicino si muove di più
## Il piano più lontano si muove pochissimo (quasi fermo = infinito)
@export var parallax_min: float = 0.02  ## piano lontano (quasi fermo)
@export var parallax_max: float = 0.55  ## piano vicino

# --- MONTAGNE ---
@export_group("Montagne")
@export var montagne_per_piano: int = 10
@export var larghezza_spread: float = 120.0
@export var altezza_min: float = 8.0
@export var altezza_max: float = 28.0
@export var larghezza_min: float = 10.0
@export var larghezza_max: float = 30.0
@export var spessore_mesh: float = 3.0

# --- COLORI ---
@export_group("Colori")
@export var colore_vicino: Color = Color(0.25, 0.38, 0.22)
@export var colore_lontano: Color = Color(0.68, 0.78, 0.85)
@export var colore_terra: Color = Color(0.15, 0.22, 0.12)

# --- DETTAGLI ---
@export_group("Dettagli")
@export var neve_sulle_cime := true
@export var soglia_neve: float = 0.65
@export var colore_neve: Color = Color(0.92, 0.95, 1.0)
@export var genera_colline := true
@export var altezza_collina: float = 4.0

# --- WORLD ENVIRONMENT ---
@export_group("WorldEnvironment")
@export var imposta_nebbia_auto := true
@export var nebbia_density: float = 0.005
@export var imposta_sky_auto := true
@export var sky_top: Color = Color(0.10, 0.16, 0.30)
@export var sky_orizzonte: Color = Color(0.78, 0.44, 0.25)
@export var sky_terra: Color = Color(0.17, 0.23, 0.13)


# ============================================================
#  VARIABILI INTERNE
# ============================================================
var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _piani: Array[Node3D] = []        ## ogni elemento = un piano di montagne
var _parallax_speeds: Array[float] = [] ## velocità parallasse per ogni piano
var _posizione_base: Vector3           ## posizione mondo al momento della generazione


# ============================================================
#  ENTRY POINT
# ============================================================
func _ready():
	if Engine.is_editor_hint():
		return
	_trova_camera()
	if genera_al_avvio:
		genera()


func _trova_camera():
	if camera_path != NodePath(""):
		_camera = get_node(camera_path)
	else:
		# Cerca la Camera3D nella scena automaticamente
		_camera = get_viewport().get_camera_3d()
	if _camera:
		print("[MountainBG] Camera trovata: ", _camera.name)
	else:
		push_warning("[MountainBG] Nessuna Camera3D trovata! Imposta camera_path.")


# ============================================================
#  UPDATE — segue la camera ogni frame
# ============================================================
func _process(delta: float):
	if Engine.is_editor_hint() or not _camera:
		return

	var cam_pos = _camera.global_position

	for i in _piani.size():
		if i >= _parallax_speeds.size():
			break
		var piano = _piani[i]
		var speed = _parallax_speeds[i]

		# Posizione target: il piano segue la camera in X con velocità propria
		var target_x = _posizione_base.x + (cam_pos.x - _posizione_base.x) * speed
		var target_y = piano.position.y  # Y immutabile di default

		if segui_asse_y:
			target_y = _posizione_base.y + (cam_pos.y - _posizione_base.y) * speed * 0.3

		if smoothing > 0.0:
			piano.position.x = lerp(piano.position.x, target_x, 1.0 - smoothing)
			if segui_asse_y:
				piano.position.y = lerp(piano.position.y, target_y, 1.0 - smoothing)
		else:
			piano.position.x = target_x
			if segui_asse_y:
				piano.position.y = target_y


# ============================================================
#  GENERAZIONE
# ============================================================
func genera():
	_pulisci()

	if seed_casuale != 0:
		_rng.seed = seed_casuale
	else:
		_rng.randomize()

	_piani.clear()
	_parallax_speeds.clear()

	# Salva la posizione iniziale come riferimento per il parallasse
	if _camera:
		_posizione_base = _camera.global_position
	else:
		_posizione_base = Vector3.ZERO

	var root_m = Node3D.new()
	root_m.name = "Montagne"
	add_child(root_m)
	if Engine.is_editor_hint():
		root_m.set_owner(get_tree().edited_scene_root)

	for i in numero_piani:
		var t = float(i) / float(max(numero_piani - 1, 1))
		var z_piano = lerp(z_primo_piano, z_ultimo_piano, t)
		var colore_piano = lerp(colore_vicino, colore_lontano, t)
		var h_min = lerp(altezza_min * 0.5, altezza_min, 1.0 - t)
		var h_max = lerp(altezza_max * 0.5, altezza_max, 1.0 - t)
		# Parallasse: piani lontani (t=0) si muovono poco, vicini (t=1) di più
		var parallax = lerp(parallax_min, parallax_max, t)

		var piano = _genera_piano(root_m, i, z_piano, colore_piano, h_min, h_max)
		_piani.append(piano)
		_parallax_speeds.append(parallax)

	if genera_colline:
		var root_c = Node3D.new()
		root_c.name = "Colline"
		add_child(root_c)
		if Engine.is_editor_hint():
			root_c.set_owner(get_tree().edited_scene_root)
		_genera_tutte_colline(root_c)

	if imposta_nebbia_auto or imposta_sky_auto:
		_imposta_world_environment()

	print("[MountainBG] Generato! Piani: %d  Seed: %d" % [numero_piani, _rng.seed])


func _pulisci():
	for c in get_children():
		c.queue_free()
	_piani.clear()
	_parallax_speeds.clear()


# ============================================================
#  COSTRUZIONE PIANO MONTAGNE
# ============================================================
func _genera_piano(parent: Node3D, idx: int, z: float,
		colore: Color, h_min: float, h_max: float) -> Node3D:
	var container = Node3D.new()
	container.name = "Piano_%d" % idx
	parent.add_child(container)
	if Engine.is_editor_hint():
		container.set_owner(get_tree().edited_scene_root)

	for i in montagne_per_piano:
		var px = _rng.randf_range(-larghezza_spread, larghezza_spread)
		var h   = _rng.randf_range(h_min, h_max)
		var w   = _rng.randf_range(larghezza_min, larghezza_max)
		_crea_montagna(container, px, z, h, w, colore)
		if neve_sulle_cime:
			_crea_neve(container, px, z, h, w * 0.35)

	return container


func _crea_montagna(parent: Node3D, x: float, z: float,
		h: float, w: float, colore: Color):
	var mi = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(w, h, spessore_mesh)
	mi.mesh = prism
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colore.darkened(_rng.randf_range(0.0, 0.12))
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = Vector3(x, h * 0.5 - 2.0, z)
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


func _crea_neve(parent: Node3D, x: float, z: float, h_mont: float, w: float):
	var mi = MeshInstance3D.new()
	var prism = PrismMesh.new()
	var h_neve = h_mont * (1.0 - soglia_neve)
	prism.size = Vector3(w, h_neve, spessore_mesh + 0.1)
	mi.mesh = prism
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colore_neve
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = Vector3(x, h_mont - 2.0 - h_neve * 0.5 + h_neve, z + 0.1)
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


# ============================================================
#  COLLINE BASE
# ============================================================
func _genera_tutte_colline(parent: Node3D):
	for i in numero_piani:
		var t = float(i) / float(max(numero_piani - 1, 1))
		var z = lerp(z_primo_piano + 2.0, z_ultimo_piano + 2.0, t)
		var colore = lerp(colore_terra, colore_lontano.darkened(0.3), t)
		_crea_collina(parent, z, colore, i)


func _crea_collina(parent: Node3D, z: float, colore: Color, idx: int):
	var mi = MeshInstance3D.new()
	mi.name = "Collina_%d" % idx
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lw = larghezza_spread * 2.2
	var step = lw / 30.0
	var top: Array[Vector3] = []
	for j in 31:
		var px = -lw * 0.5 + j * step
		var py = sin(px * 0.08 + idx * 1.3) * altezza_collina * 0.5 \
			   + sin(px * 0.15 + idx * 0.7) * altezza_collina * 0.3 \
			   + altezza_collina * 0.2
		top.append(Vector3(px, py, 0))
	var yb = -altezza_collina - 5.0
	for j in 30:
		var p0 = top[j]; var p1 = top[j+1]
		var p2 = Vector3(p0.x, yb, 0); var p3 = Vector3(p1.x, yb, 0)
		st.set_color(colore)
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)
	st.generate_normals()
	mi.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.position = Vector3(0, -2.0, z)
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


# ============================================================
#  WORLD ENVIRONMENT
# ============================================================
func _imposta_world_environment():
	var we = _trova_world_environment(get_tree().root)
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		get_parent().add_child(we)
		if Engine.is_editor_hint():
			we.set_owner(get_tree().edited_scene_root)
	var env = we.environment
	if env == null:
		env = Environment.new()
		we.environment = env
	if imposta_sky_auto:
		var sky = Sky.new()
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_orizzonte
		sky_mat.ground_horizon_color = sky_orizzonte.darkened(0.3)
		sky_mat.ground_bottom_color = sky_terra
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.5
	if imposta_nebbia_auto:
		env.fog_enabled = true
		env.fog_density = nebbia_density
		env.fog_aerial_perspective = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC


func _trova_world_environment(nodo: Node) -> WorldEnvironment:
	if nodo is WorldEnvironment:
		return nodo
	for child in nodo.get_children():
		var r = _trova_world_environment(child)
		if r: return r
	return null


# ============================================================
#  PULSANTE EDITOR
# ============================================================
@export_tool_button("🏔 Genera Sfondo", "Reload") var _btn = genera
