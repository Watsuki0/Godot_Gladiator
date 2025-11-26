extends Node2D

# ==========================================
# 🛠️ CONFIGURATION
# ==========================================
@export_category("Configuration")
# INFO : Rayon du cercle de spawn (400px autour du centre)
@export var spawn_radius: float = 400.0

@export_category("References")
@export var player_ref: CharacterBody2D 
@export var enemy_scene: PackedScene 
# INFO : Le point central (Marker2D) placé au milieu de la map
@export var center_point: Marker2D 

func _ready():
	# SÉCURITÉ : Vérification des outils nécessaires
	if center_point == null:
		printerr("ERREUR : Glisse le CenterPoint (Marker2D) dans l'inspecteur !")
		set_physics_process(false)
		return
	
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
	
	# INFO : Démarrage du Timer
	var timer = $Timer
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	timer.start()
	print("--- SPAWNER CENTRAL ACTIVÉ (Rayon : ", spawn_radius, "px) ---")

func _on_timer_timeout():
	if not player_ref: return
	
	# 1. CALCUL MATHÉMATIQUE (Cercle)
	# On choisit un angle au hasard (0 à 360°)
	var random_angle = randf() * TAU
	# On choisit une distance au hasard (0 à 400px)
	var random_distance = randf_range(0, spawn_radius)
	
	# On calcule le décalage (Vecteur)
	var offset = Vector2.RIGHT.rotated(random_angle) * random_distance
	
	# Position finale = Centre de la map + Décalage
	var final_spawn_pos = center_point.global_position + offset
	
	# 2. CRÉATION DU MONSTRE
	spawn_enemy(final_spawn_pos)

func spawn_enemy(pos: Vector2):
	if enemy_scene == null:
		print("ERREUR : Pas de scène d'ennemi assignée !")
		return

	# Instanciation (Création de la copie)
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	
	# On donne la référence du joueur à l'ennemi (pour qu'il sache qui chasser)
	if "player_ref" in enemy:
		enemy.player_ref = player_ref
	
	get_tree().current_scene.add_child(enemy)
