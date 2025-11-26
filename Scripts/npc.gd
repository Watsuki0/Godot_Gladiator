extends CharacterBody2D

# ==========================================
# 📊 STATS ENNEMI
# ==========================================
@export_group("Stats")
@export var speed: float = 70.0
@export var hp: int = 30
@export var damage: int = 5
@export var xp_reward: int = 25

# ==========================================
# 🧬 ÉVOLUTION (TAILLE)
# ==========================================
@export_group("Evolution")
@export var max_size_limit: float = 3.0 # Limite max (x3 taille d'origine)

# ==========================================
# ⚔️ COMBAT
# ==========================================
@export_group("Combat")
@export var attack_cooldown: float = 1.5
# INFO : Cette variable sera calculée automatiquement selon la taille de la hitbox
var real_attack_range: float = 40.0 

# ==========================================
# 🔗 LIENS
# ==========================================
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $HealthBar2
@onready var nav_agent = $NavigationAgent2D
@onready var hitbox = $Hitbox
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var collision_shape = $CollisionShape2D

# INFO : Référence vers le joueur pour savoir qui poursuivre
var player_ref: Node2D = null
var is_dead: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var default_modulate: Color = Color.WHITE 

func _ready():
	# INFO : On attend une image physique pour que la carte de navigation soit prête
	await get_tree().physics_frame
	
	# 1. RECHERCHE DU JOUEUR (Sécurité maximale)
	if player_ref == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0: player_ref = players[0]
		else:
			# Essai de secours avec majuscule
			players = get_tree().get_nodes_in_group("Player")
			if players.size() > 0: player_ref = players[0]
	
	if player_ref == null:
		# Si on ne trouve personne, on ne fait rien (économie de performance)
		set_physics_process(false)
		return

	# 2. DIFFICULTÉ DYNAMIQUE & TAILLE
	# On récupère les PV de base définis dans l'éditeur
	var original_hp = float(hp) 
	if original_hp <= 0: original_hp = 1.0
	
	# On demande au GameManager : "On en est où dans la difficulté ?"
	var game_manager = get_tree().root.find_child("GameManager", true, false)
	if game_manager:
		hp += game_manager.current_enemy_hp_bonus
		damage += game_manager.current_enemy_damage_bonus
		
		# EXPLICATION : Plus l'ennemi a de PV par rapport à la base, plus il est gros
		# Exemple : 60 PV actuels / 30 PV base = Taille x2
		var growth_ratio = float(hp) / original_hp
		var new_scale = clamp(growth_ratio, 1.0, max_size_limit)
		
		scale = Vector2(new_scale, new_scale)
		
		# Feedback Visuel : Plus il est gros, plus il est sombre/rouge
		var tint = clamp(1.0 - (growth_ratio * 0.1), 0.4, 1.0)
		modulate = Color(1, tint, tint)
	
	default_modulate = modulate

	# 3. CALCUL PORTÉE & NAVIGATION
	calculate_reach_from_hitbox()
	
	# On s'arrête un peu avant la portée maximale (90%) pour être sûr de toucher
	nav_agent.path_desired_distance = 20.0 * scale.x
	nav_agent.target_desired_distance = real_attack_range * 0.9 

	# 4. UI & SIGNAUX
	health_bar.max_value = hp
	health_bar.value = hp
	health_bar.visible = false
	
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	hitbox_shape.disabled = true

func calculate_reach_from_hitbox():
	# EXPLICATION : Cette fonction mesure la taille de l'arme (Hitbox)
	# pour savoir à quelle distance exacte s'arrêter du joueur.
	var shape = hitbox_shape.shape
	var extent = 40.0 # Valeur par défaut
	
	if shape is RectangleShape2D:
		extent = (shape.size.x / 2) + abs(hitbox_shape.position.x)
	elif shape is CircleShape2D:
		extent = shape.radius + abs(hitbox_shape.position.x)
	elif shape is CapsuleShape2D:
		extent = shape.radius + abs(hitbox_shape.position.x)
	
	# On multiplie par l'échelle (Scale) car si l'ennemi est géant, son bras est géant !
	real_attack_range = extent * scale.x

func _physics_process(delta):
	if is_dead or not player_ref: return

	# Gestion du chronomètre d'attaque
	if attack_timer > 0:
		attack_timer -= delta

	# Sécurité visuelle
	if is_attacking and animated_sprite.animation != "attacking":
		_force_stop_attack()

	var dist = global_position.distance_to(player_ref.global_position)
	
	# --- IA DU MONSTRE ---
	
	# CAS 1 : À PORTÉE -> ATTAQUE
	if dist <= real_attack_range:
		if attack_timer <= 0 and not is_attacking:
			start_attack()
		velocity = Vector2.ZERO 
	
	# CAS 2 : TROP LOIN -> POURSUITE
	elif not is_attacking:
		# On dit au GPS (NavAgent) où est le joueur
		nav_agent.target_position = player_ref.global_position
		
		# Est-ce qu'on est arrivé ?
		if not nav_agent.is_target_reached():
			# On demande la prochaine étape
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			
			velocity = direction * speed
			
			# Orientation du sprite (Gauche/Droite)
			if velocity.x < 0: 
				animated_sprite.flip_h = true
				hitbox.scale.x = -1 
			elif velocity.x > 0: 
				animated_sprite.flip_h = false
				hitbox.scale.x = 1
				
			animated_sprite.play("moving")
		else:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
	
	move_and_slide()

# --- FONCTIONS DE COMBAT ---

func start_attack():
	is_attacking = true
	attack_timer = attack_cooldown
	animated_sprite.play("attacking")
	hitbox_shape.set_deferred("disabled", false)

func _on_animation_finished():
	if animated_sprite.animation == "attacking":
		_force_stop_attack()

func _force_stop_attack():
	is_attacking = false
	hitbox_shape.set_deferred("disabled", true)
	animated_sprite.play("idle")

func _on_hitbox_body_entered(body):
	# Si on touche le joueur (et qu'on est vivant)
	if not is_dead and body == player_ref:
		if body.has_method("take_damage"):
			body.take_damage(damage)

# --- DÉGÂTS & MORT ---

func take_damage(amount):
	if is_dead: return
	hp -= amount
	health_bar.visible = true
	health_bar.value = hp
	
	# Effet rouge quand touché
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead: modulate = default_modulate 
	
	if hp <= 0: die()

func die():
	is_dead = true
	health_bar.visible = false
	
	# On désactive la physique pour qu'il devienne traversable
	hitbox_shape.set_deferred("disabled", true)
	collision_shape.set_deferred("disabled", true)
	
	velocity = Vector2.ZERO
	animated_sprite.play("ko")
	
	if player_ref and player_ref.has_method("gain_xp"):
		# BONUS : Les gros ennemis donnent plus d'XP !
		var xp_bonus_size = int(xp_reward * scale.x)
		player_ref.gain_xp(xp_bonus_size)
	
	await animated_sprite.animation_finished
	queue_free() # Suppression de l'objet
