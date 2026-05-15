@tool
extends Node2D

## ============================================================
##  MOUNTAIN BACKGROUND GENERATOR 2D - Platformer
##  Attacca questo script a un Node2D nella tua scena.
##  Funziona anche nell'editor (@tool).
##
##  Struttura generata automaticamente:
##  Node2D (questo script)
##  └── ParallaxBackground
##      ├── Layer_0 (più lontano)  → montagne piccole + cielo
##      ├── Layer_1
##      ├── ...
##      └── Layer_N (più vicino)  → colline scure
## ============================================================

# --- GENERAZIONE ---
@export_group("Generazione")
@export var genera_al_avvio := true
@export var seed_casuale: int = 0  ## 0 = casuale ogni volta

# --- SCHERMO ---
@export_group("Dimensioni")
@export var larghezza_scena: int = 1920
@export var altezza_scena: int = 1080
@export var estensione_x: int = 400  ## pixel extra a sx/dx per il parallasse

# --- PIANI ---
@export_group("Piani (layers)")
@export var numero_piani: int = 5
## Velocità parallasse: 0 = fermo, 1 = si muove con la camera (piano di gioco)
@export var parallax_min: float = 0.05  ## piano più lontano
@export var parallax_max: float = 0.45  ## piano più vicino

# --- MONTAGNE ---
@export_group("Montagne")
@export var montagne_per_piano: int = 8
@export var altezza_min: float = 120.0
@export var altezza_max: float = 380.0
@export var larghezza_min: float = 150.0
@export var larghezza_max: float = 400.0
@export var jaggedness: float = 0.35  ## 0 = triangolo liscio, 1 = molto frastagliato
@export var vertici_profilo: int = 12  ## più vertici = profilo più dettagliato

# --- COLORI ---
@export_group("Colori")
@export var colore_cielo_top: Color = Color(0.10, 0.16, 0.32)
@export var colore_cielo_orizzonte: Color = Color(0.75, 0.42, 0.22)
@export var colore_montagna_lontana: Color = Color(0.55, 0.62, 0.72)
@export var colore_montagna_vicina: Color = Color(0.18, 0.28, 0.16)
@export var colore_collina_base: Color = Color(0.10, 0.18, 0.08)

# --- DETTAGLI ---
@export_group("Dettagli")
@export var neve_sulle_cime := true
@export var soglia_neve: float = 0.72   ## 0~1, da dove inizia la neve
@export var colore_neve: Color = Color(0.93, 0.96, 1.0)
@export var genera_stelle := true
@export var numero_stelle: int = 120
@export var colore_stelle: Color = Color(1.0, 1.0, 0.95, 0.8)

# --- SOLE / LUNA ---
@export_group("Sole / Luna")
@export var mostra_astro := true
@export var e_luna := false  ## false = sole, true = luna
@export var posizione_astro := Vector2(0.75, 0.22)  ## 0~1 relativo allo schermo
@export var raggio_astro: float = 55.0
@export var colore_astro: Color = Color(1.0, 0.88, 0.55)

# --- NEBBIA ---
@export_group("Nebbia")
@export var nebbia_abilitata := true
@export var altezza_nebbia: float = 0.45  ## 0~1 dal basso: quanto sale la nebbia
@export var colore_nebbia: Color = Color(0.62, 0.72, 0.80, 0.55)


# ============================================================
var _rng := RandomNumberGenerator.new()
var _parallax_bg: ParallaxBackground


func _ready():
	if genera_al_avvio:
		genera()


func genera():
	_pulisci()

	if seed_casuale != 0:
		_rng.seed = seed_casuale
	else:
		_rng.randomize()

	# Nodo ParallaxBackground radice
	_parallax_bg = ParallaxBackground.new()
	_parallax_bg.name = "ParallaxBackground"
	add_child(_parallax_bg)
	if Engine.is_editor_hint():
		_parallax_bg.set_owner(get_tree().edited_scene_root)

	# 1. Cielo (layer speciale, non si muove)
	_crea_layer_cielo()

	# 2. Stelle (sopra il cielo, quasi ferme)
	if genera_stelle:
		_crea_layer_stelle()

	# 3. Astro (sole/luna)
	if mostra_astro:
		_crea_layer_astro()

	# 4. Piani di montagne
	for i in numero_piani:
		var t = float(i) / float(max(numero_piani - 1, 1))
		var parallax = lerp(parallax_min, parallax_max, t)
		var colore = lerp(colore_montagna_lontana, colore_montagna_vicina, t)
		var h_min = lerp(altezza_min * 0.5, altezza_min, t)
		var h_max = lerp(altezza_max * 0.5, altezza_max, t)
		var y_base = lerp(altezza_scena * 0.55, altezza_scena * 0.72, t)
		_crea_layer_montagne(i, parallax, colore, h_min, h_max, y_base)

	# 5. Collina base (piano più vicino, scuro)
	_crea_layer_collina_base()

	# 6. Nebbia
	if nebbia_abilitata:
		_crea_layer_nebbia()

	print("[MountainBG2D] Generato! Seed: %d" % _rng.seed)


# ============================================================
#  PULIZIA
# ============================================================
func _pulisci():
	for c in get_children():
		c.queue_free()


# ============================================================
#  LAYER CIELO
# ============================================================
func _crea_layer_cielo():
	var layer = _nuovo_layer("Cielo", Vector2.ZERO)
	var ci = _nuovo_canvas_item(layer, "CieloGradiente")

	# Disegna il gradiente cielo con CanvasItem via _draw su script inline
	var script_draw = GDScript.new()
	script_draw.source_code = """
extends Node2D
@export var col_top: Color
@export var col_bottom: Color
@export var w: int
@export var h: int
func _draw():
	var steps = 60
	for i in steps:
		var t = float(i) / steps
		var col = col_top.lerp(col_bottom, t)
		var y = t * h
		draw_line(Vector2(0, y), Vector2(w, y), col, h / float(steps) + 1.0)
"""
	script_draw.reload()
	ci.set_script(script_draw)
	ci.set("col_top", colore_cielo_top)
	ci.set("col_bottom", colore_cielo_orizzonte)
	ci.set("w", larghezza_scena + estensione_x * 2)
	ci.set("h", altezza_scena)
	ci.position = Vector2(-estensione_x, 0)
	ci.queue_redraw()


# ============================================================
#  LAYER STELLE
# ============================================================
func _crea_layer_stelle():
	var layer = _nuovo_layer("Stelle", Vector2(0.02, 0.0))
	var ci = _nuovo_canvas_item(layer, "Stelle")

	var posizioni: Array[Vector2] = []
	var dimensioni: Array[float] = []
	for i in numero_stelle:
		posizioni.append(Vector2(
			_rng.randf_range(0, larghezza_scena),
			_rng.randf_range(0, altezza_scena * 0.65)
		))
		dimensioni.append(_rng.randf_range(1.0, 2.5))

	var scr = GDScript.new()
	scr.source_code = """
extends Node2D
@export var colore: Color
var posizioni: Array[Vector2] = []
var dimensioni: Array[float] = []
func _draw():
	for i in posizioni.size():
		draw_circle(posizioni[i], dimensioni[i], colore)
"""
	scr.reload()
	ci.set_script(scr)
	ci.set("colore", colore_stelle)
	ci.set("posizioni", posizioni)
	ci.set("dimensioni", dimensioni)
	ci.queue_redraw()


# ============================================================
#  LAYER ASTRO (sole / luna)
# ============================================================
func _crea_layer_astro():
	var layer = _nuovo_layer("Astro", Vector2(0.05, 0.0))
	var ci = _nuovo_canvas_item(layer, "Astro")
	var pos = Vector2(posizione_astro.x * larghezza_scena, posizione_astro.y * altezza_scena)

	var scr = GDScript.new()
	if e_luna:
		scr.source_code = """
extends Node2D
@export var col: Color
@export var raggio: float
@export var pos: Vector2
func _draw():
	draw_circle(pos, raggio, col)
	# Ombra luna
	draw_circle(pos + Vector2(raggio * 0.3, -raggio * 0.1), raggio * 0.85,
		Color(0.10, 0.16, 0.32))
"""
	else:
		scr.source_code = """
extends Node2D
@export var col: Color
@export var raggio: float
@export var pos: Vector2
func _draw():
	# Alone
	draw_circle(pos, raggio * 1.6, col.lightened(0.1) * Color(1,1,1,0.15))
	draw_circle(pos, raggio * 1.2, col.lightened(0.2) * Color(1,1,1,0.25))
	draw_circle(pos, raggio, col)
"""
	scr.reload()
	ci.set_script(scr)
	ci.set("col", colore_astro)
	ci.set("raggio", raggio_astro)
	ci.set("pos", pos)
	ci.queue_redraw()


# ============================================================
#  LAYER MONTAGNE
# ============================================================
func _crea_layer_montagne(indice: int, parallax: float, colore: Color,
		h_min: float, h_max: float, y_base: float):
	var layer = _nuovo_layer("Montagne_%d" % indice, Vector2(parallax, 0.0))
	var ci = _nuovo_canvas_item(layer, "MeshMontagne")

	var larghezza_tot = larghezza_scena + estensione_x * 2

	# Genera i poligoni di tutte le montagne
	var polys: Array = []  # Array di PackedVector2Array
	var neve_polys: Array = []

	for i in montagne_per_piano:
		var cx = _rng.randf_range(-estensione_x, larghezza_scena + estensione_x)
		var h = _rng.randf_range(h_min, h_max)
		var w = _rng.randf_range(larghezza_min, larghezza_max)
		var poly = _genera_profilo_montagna(cx, y_base, w, h)
		polys.append(poly)

		if neve_sulle_cime:
			var cima_y = y_base - h
			var neve_h = h * (1.0 - soglia_neve)
			var neve_w = w * (1.0 - soglia_neve) * 0.9
			neve_polys.append(_genera_profilo_montagna(cx, cima_y + neve_h, neve_w, neve_h))

	# Piano terra sotto le montagne
	var terra = PackedVector2Array([
		Vector2(-estensione_x, y_base),
		Vector2(larghezza_scena + estensione_x, y_base),
		Vector2(larghezza_scena + estensione_x, altezza_scena + 10),
		Vector2(-estensione_x, altezza_scena + 10),
	])
	polys.append(terra)

	var col_variata = colore.darkened(_rng.randf_range(0.0, 0.08))

	var scr = GDScript.new()
	scr.source_code = """
extends Node2D
@export var colore: Color
@export var colore_neve: Color
var polys: Array = []
var neve_polys: Array = []
func _draw():
	for p in polys:
		draw_colored_polygon(p, colore)
	for p in neve_polys:
		draw_colored_polygon(p, colore_neve)
"""
	scr.reload()
	ci.set_script(scr)
	ci.set("colore", col_variata)
	ci.set("colore_neve", colore_neve)
	ci.set("polys", polys)
	ci.set("neve_polys", neve_polys)
	ci.position = Vector2(-estensione_x, 0)
	ci.queue_redraw()


func _genera_profilo_montagna(cx: float, y_base: float, w: float, h: float) -> PackedVector2Array:
	var punti = PackedVector2Array()
	# Base sinistra
	punti.append(Vector2(cx - w * 0.5, y_base))

	# Profilo superiore con vertici irregolari
	for i in vertici_profilo + 1:
		var t = float(i) / vertici_profilo
		var px = cx - w * 0.5 + t * w
		# Curva a campana per la forma base
		var forma = 1.0 - pow((t * 2.0 - 1.0), 2)
		# Rumore per irregolarità
		var rumore = _rng.randf_range(-jaggedness, jaggedness) * h * 0.25
		var py = y_base - forma * h + rumore * (1.0 - abs(t * 2.0 - 1.0))
		punti.append(Vector2(px, py))

	# Base destra
	punti.append(Vector2(cx + w * 0.5, y_base))
	return punti


# ============================================================
#  COLLINA BASE
# ============================================================
func _crea_layer_collina_base():
	var layer = _nuovo_layer("CollinaBase", Vector2(parallax_max + 0.1, 0.0))
	var ci = _nuovo_canvas_item(layer, "Collina")

	var y_base = altezza_scena * 0.80
	var larghezza_tot = larghezza_scena + estensione_x * 2
	var punti = PackedVector2Array()
	var segmenti = 40

	punti.append(Vector2(-estensione_x, altezza_scena + 10))
	punti.append(Vector2(-estensione_x, y_base))

	for i in segmenti + 1:
		var t = float(i) / segmenti
		var px = -estensione_x + t * larghezza_tot
		var py = y_base \
			+ sin(t * 5.5) * 25.0 \
			+ sin(t * 11.0) * 12.0 \
			+ sin(t * 23.0) * 6.0
		punti.append(Vector2(px, py))

	punti.append(Vector2(larghezza_scena + estensione_x, altezza_scena + 10))

	var scr = GDScript.new()
	scr.source_code = """
extends Node2D
@export var colore: Color
var punti: PackedVector2Array
func _draw():
	draw_colored_polygon(punti, colore)
"""
	scr.reload()
	ci.set_script(scr)
	ci.set("colore", colore_collina_base)
	ci.set("punti", punti)
	ci.position = Vector2(-estensione_x, 0)
	ci.queue_redraw()


# ============================================================
#  NEBBIA
# ============================================================
func _crea_layer_nebbia():
	var layer = _nuovo_layer("Nebbia", Vector2.ZERO)
	var ci = _nuovo_canvas_item(layer, "Nebbia")

	var scr = GDScript.new()
	scr.source_code = """
extends Node2D
@export var col: Color
@export var w: int
@export var h: int
@export var altezza_nebbia: float
func _draw():
	var steps = 40
	var y_start = h * (1.0 - altezza_nebbia)
	for i in steps:
		var t = float(i) / steps
		var alpha = col.a * t * t
		var c = Color(col.r, col.g, col.b, alpha)
		var y = lerp(y_start, float(h), t)
		draw_line(Vector2(0, y), Vector2(w, y), c, (h * altezza_nebbia) / float(steps) + 1.0)
"""
	scr.reload()
	ci.set_script(scr)
	ci.set("col", colore_nebbia)
	ci.set("w", larghezza_scena)
	ci.set("h", altezza_scena)
	ci.set("altezza_nebbia", altezza_nebbia)
	ci.queue_redraw()


# ============================================================
#  HELPERS
# ============================================================
func _nuovo_layer(nome: String, motion_scale: Vector2) -> ParallaxLayer:
	var layer = ParallaxLayer.new()
	layer.name = nome
	layer.motion_scale = motion_scale
	layer.motion_mirroring = Vector2(larghezza_scena + estensione_x * 2, 0)
	_parallax_bg.add_child(layer)
	if Engine.is_editor_hint():
		layer.set_owner(get_tree().edited_scene_root)
	return layer


func _nuovo_canvas_item(parent: Node, nome: String) -> Node2D:
	var ci = Node2D.new()
	ci.name = nome
	parent.add_child(ci)
	if Engine.is_editor_hint():
		ci.set_owner(get_tree().edited_scene_root)
	return ci


# ============================================================
#  PULSANTE EDITOR
# ============================================================
@export_tool_button("🏔 Genera Sfondo 2D", "Reload") var _btn = genera
