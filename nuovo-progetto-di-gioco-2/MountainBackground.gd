@tool
extends Node3D

## ============================================================
##  MOUNTAIN BACKGROUND GENERATOR - Platformer 2.5D
##  Attacca questo script a un Node3D nella tua scena.
##  Funziona anche nell'editor (@tool) per vedere subito il risultato.
## ============================================================

# --- IMPOSTAZIONI GENERALI ---
@export_group("Generazione")
@export var genera_al_avvio := true
@export var seed_casuale: int = 0  ## 0 = completamente casuale ogni volta

# --- PIANI DI SFONDO ---
@export_group("Piani (layers)")
@export var numero_piani: int = 5  ## quanti strati di montagne
@export var z_primo_piano: float = -30.0  ## Z del piano più vicino
@export var z_ultimo_piano: float = -250.0  ## Z del piano più lontano

# --- MONTAGNE ---
@export_group("Montagne")
@export var montagne_per_piano: int = 10
@export var larghezza_spread: float = 120.0  ## quanto si estendono in X
@export var altezza_min: float = 8.0
@export var altezza_max: float = 28.0
@export var larghezza_min: float = 10.0
@export var larghezza_max: float = 30.0
@export var spessore_mesh: float = 3.0

# --- COLORI ATMOSFERICI ---
@export_group("Colori")
@export var colore_vicino: Color = Color(0.25, 0.38, 0.22)   ## verde scuro
@export var colore_lontano: Color = Color(0.68, 0.78, 0.85)  ## azzurro chiaro
@export var colore_terra: Color = Color(0.15, 0.22, 0.12)    ## verde molto scuro

# --- COLLINE BASE ---
@export_group("Colline base")
@export var genera_colline := true
@export var altezza_collina: float = 4.0
@export var segmenti_collina: int = 30

# --- NEVE ---
@export_group("Dettagli")
@export var neve_sulle_cime := true
@export var soglia_neve: float = 0.65  ## 0~1, quanto in alto inizia la neve
@export var colore_neve: Color = Color(0.92, 0.95, 1.0)

# --- NEBBIA AUTOMATICA ---
@export_group("Nebbia (WorldEnvironment)")
@export var imposta_nebbia_auto := true
@export var nebbia_density: float = 0.005
@export var nebbia_inizio: float = 30.0
@export var nebbia_fine: float = 300.0

# --- SKY AUTOMATICO ---
@export var imposta_sky_auto := true
@export var sky_top: Color = Color(0.10, 0.16, 0.30)
@export var sky_orizzonte: Color = Color(0.78, 0.44, 0.25)
@export var sky_terra: Color = Color(0.17, 0.23, 0.13)


# ============================================================
#  VARIABILI INTERNE
# ============================================================
var _rng := RandomNumberGenerator.new()
var _root_montagne: Node3D
var _root_colline: Node3D


# ============================================================
#  ENTRY POINT
# ============================================================
func _ready():
	if genera_al_avvio:
		genera()


## Chiamata principale — genera tutto lo sfondo
func genera():
	_pulisci()
	
	if seed_casuale != 0:
		_rng.seed = seed_casuale
	else:
		_rng.randomize()
	
	_root_montagne = Node3D.new()
	_root_montagne.name = "Montagne"
	add_child(_root_montagne)
	if Engine.is_editor_hint():
		_root_montagne.set_owner(get_tree().edited_scene_root)
	
	_genera_tutti_i_piani()
	
	if genera_colline:
		_root_colline = Node3D.new()
		_root_colline.name = "Colline"
		add_child(_root_colline)
		if Engine.is_editor_hint():
			_root_colline.set_owner(get_tree().edited_scene_root)
		_genera_colline_base()
	
	if imposta_nebbia_auto or imposta_sky_auto:
		_imposta_world_environment()
	
	print("[MountainBG] Sfondo generato con seed: ", _rng.seed)


# ============================================================
#  PULIZIA
# ============================================================
func _pulisci():
	for child in get_children():
		child.queue_free()


# ============================================================
#  GENERAZIONE PIANI
# ============================================================
func _genera_tutti_i_piani():
	for i in numero_piani:
		var t: float = float(i) / float(numero_piani - 1) if numero_piani > 1 else 0.0
		var z_piano: float = lerp(z_primo_piano, z_ultimo_piano, t)
		var colore_piano: Color = lerp(colore_vicino, colore_lontano, t)
		
		# Le montagne lontane sono più basse (effetto prospettico)
		var h_min = lerp(altezza_min, altezza_min * 0.5, t)
		var h_max = lerp(altezza_max, altezza_max * 0.6, t)
		
		_genera_piano_montagne(z_piano, colore_piano, h_min, h_max, i)


func _genera_piano_montagne(z: float, colore: Color, h_min: float, h_max: float, indice_piano: int):
	var container = Node3D.new()
	container.name = "Piano_%d_Z%.0f" % [indice_piano, z]
	_root_montagne.add_child(container)
	if Engine.is_editor_hint():
		container.set_owner(get_tree().edited_scene_root)
	
	for i in montagne_per_piano:
		var pos_x = _rng.randf_range(-larghezza_spread, larghezza_spread)
		var altezza = _rng.randf_range(h_min, h_max)
		var larghezza = _rng.randf_range(larghezza_min, larghezza_max)
		
		# Corpo principale della montagna
		_crea_montagna(container, pos_x, z, altezza, larghezza, colore)
		
		# Neve sulla cima se abilitata
		if neve_sulle_cime:
			_crea_neve_cima(container, pos_x, z, altezza, larghezza * 0.35, colore_neve)


func _crea_montagna(parent: Node3D, x: float, z: float, h: float, w: float, colore: Color):
	var mi = MeshInstance3D.new()
	mi.name = "Montagna"
	
	var prism = PrismMesh.new()
	prism.size = Vector3(w, h, spessore_mesh)
	mi.mesh = prism
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Leggera variazione di colore per ogni montagna
	mat.albedo_color = colore.darkened(_rng.randf_range(0.0, 0.15))
	mi.material_override = mat
	
	# La PrismMesh è centrata, la sposto in su di metà altezza
	mi.position = Vector3(x, h * 0.5 - 2.0, z)
	
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


func _crea_neve_cima(parent: Node3D, x: float, z: float, h_montagna: float, w: float, colore: Color):
	var mi = MeshInstance3D.new()
	mi.name = "Neve"
	
	var prism = PrismMesh.new()
	var h_neve = h_montagna * (1.0 - soglia_neve)
	prism.size = Vector3(w, h_neve, spessore_mesh + 0.1)
	mi.mesh = prism
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.roughness = 0.9
	mi.material_override = mat
	
	# Posiziona la neve sulla punta della montagna
	var y_cima = h_montagna - 2.0
	mi.position = Vector3(x, y_cima - h_neve * 0.5 + (h_neve * 0.5), z + 0.1)
	
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


# ============================================================
#  COLLINE BASE (terreno ondulato in lontananza)
# ============================================================
func _genera_colline_base():
	for i in numero_piani:
		var t: float = float(i) / float(numero_piani - 1) if numero_piani > 1 else 0.0
		var z: float = lerp(z_primo_piano + 2.0, z_ultimo_piano + 2.0, t)
		var colore: Color = lerp(colore_terra, colore_lontano.darkened(0.3), t)
		_crea_collina(z, colore, i)


func _crea_collina(z: float, colore: Color, indice: int):
	var mi = MeshInstance3D.new()
	mi.name = "Collina_%d" % indice
	
	# Crea una mesh pianeggiante ondulata con PlaneMesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var larghezza_tot = larghezza_spread * 2.2
	var step = larghezza_tot / segmenti_collina
	
	# Genera la forma ondulata con rumore
	var punti_top: Array[Vector3] = []
	for j in segmenti_collina + 1:
		var px = -larghezza_tot * 0.5 + j * step
		# Onda sinusoidale con rumore per sembrare naturale
		var py = sin(px * 0.08 + indice * 1.3) * altezza_collina * 0.5 \
			   + sin(px * 0.15 + indice * 0.7) * altezza_collina * 0.3 \
			   + altezza_collina * 0.2
		punti_top.append(Vector3(px, py, 0))
	
	var y_bottom = -altezza_collina - 5.0
	
	# Crea i triangoli della collina
	for j in segmenti_collina:
		var p0 = punti_top[j]
		var p1 = punti_top[j + 1]
		var p2 = Vector3(p0.x, y_bottom, 0)
		var p3 = Vector3(p1.x, y_bottom, 0)
		
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
	
	_root_colline.add_child(mi)
	if Engine.is_editor_hint():
		mi.set_owner(get_tree().edited_scene_root)


# ============================================================
#  WORLD ENVIRONMENT
# ============================================================
func _imposta_world_environment():
	# Cerca un WorldEnvironment esistente nella scena
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
	
	# SKY
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
	
	# NEBBIA
	if imposta_nebbia_auto:
		env.fog_enabled = true
		env.fog_density = nebbia_density
		env.fog_aerial_perspective = 0.5
	
	# TONEMAP
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	
	print("[MountainBG] WorldEnvironment configurato!")


func _trova_world_environment(nodo: Node) -> WorldEnvironment:
	if nodo is WorldEnvironment:
		return nodo
	for child in nodo.get_children():
		var risultato = _trova_world_environment(child)
		if risultato:
			return risultato
	return null


# ============================================================
#  PULSANTE EDITOR (rigenera dallo Inspector)
# ============================================================
func _get_property_list() -> Array:
	return []


## Chiama questa funzione dall'editor per rigenerare lo sfondo
@export_tool_button("🏔 Genera Sfondo", "Reload") var _btn_genera = genera
