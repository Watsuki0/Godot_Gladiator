extends CharacterBody2D

# ==========================================
# 📊 STATISTIQUES (MODIFIABLES DANS L'INSPECTEUR)
# ==========================================
@export_group("Stats")
@export var speed: float = 120.0       # Vitesse de déplacement
@export var max_health: int = 100      # Vie maximum
@export var damage: int = 10           # Dégâts par coup
@export var attack_speed: float = 1.0  # Vitesse d'animation d'attaque

# ==========================================
# 📈 PROGRESSION (XP & NIVEAUX)
# ==========================================
@export_group("Progression")
var current_xp: int = 0
var xp_to_next_level: int = 100
var current_level: int = 1
var current_health: int
var is_dead: bool = false

# INFO : État actuel du joueur (Machine à états simple)
# Peut être : "IDLE" (repos), "MOVE" (bouge), "ATTACK" (tape)
var current_state = "IDLE"

# ==========================================
# 🔗 LIENS (NODES)
# ==========================================
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var health_bar = $HealthBar
@onready var xp_bar = $XPBar

func _ready():
	# INFO : On s'assure que le joueur est bien dans le groupe "player" pour que les ennemis le trouvent
	add_to_group("player")
	
	# INFO : On remplit la vie au démarrage
	current_health = max_health
	update_ui()
	update_xp_ui()
	
	# INFO : On connecte les signaux (réactions aux événements)
	# "animation_finished" nous sert à savoir quand l'attaque est finie
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# "body_entered" nous sert à savoir quand l'épée touche un monstre
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
	# SÉCURITÉ : On désactive l'épée au début (pour ne pas blesser sans attaquer)
	hitbox_shape.disabled = true
	
	# TODO : Connexion à l'interface de Level Up
	var ui = get_tree().root.find_child("LevelUpUI", true, false)
	if ui:
		ui.upgrade_chosen.connect(apply_upgrade)

func _physics_process(_delta):
	if is_dead: return
	
	# SÉCURITÉ : Si on est en mode ATTACK mais que l'animation s'est arrêtée, on force la fin
	if current_state == "ATTACK" and not animated_sprite.is_playing():
		_on_animation_finished()
	
	# INFO : Gestion des états
	match current_state:
		"IDLE", "MOVE":
			handle_input() # On écoute le clavier
		"ATTACK":
			velocity = Vector2.ZERO # On ne bouge pas pendant qu'on tape
	
	move_and_slide()

func handle_input():
	# 1. Est-ce qu'on attaque ?
	if Input.is_action_just_pressed("attack"):
		attack()
		return

	# 2. Est-ce qu'on bouge ?
	var direction = Input.get_vector("left", "right", "up", "down")
	velocity = direction * speed
	
	if direction != Vector2.ZERO:
		current_state = "MOVE"
		animated_sprite.play("moving")
		
		# EXPLICATION : On retourne le sprite (image) selon la direction gauche/droite
		if direction.x < 0: 
			animated_sprite.flip_h = true   # Regarde à gauche
			hitbox.scale.x = -1             # L'épée tape à gauche
		elif direction.x > 0: 
			animated_sprite.flip_h = false  # Regarde à droite
			hitbox.scale.x = 1              # L'épée tape à droite
	else:
		current_state = "IDLE"
		animated_sprite.play("idle")

func attack():
	current_state = "ATTACK"
	animated_sprite.speed_scale = attack_speed
	animated_sprite.play("attacking")
	
	# INFO : On active la zone de collision de l'épée via "set_deferred" (plus sûr pour la physique)
	hitbox_shape.set_deferred("disabled", false)

func _on_animation_finished():
	# Cette fonction est appelée quand N'IMPORTE QUELLE animation finit.
	# On vérifie si c'était bien l'attaque.
	if animated_sprite.animation == "attacking":
		current_state = "IDLE"
		hitbox_shape.set_deferred("disabled", true) # On range l'épée
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")

# --- XP & NIVEAUX ---

func gain_xp(amount):
	current_xp += amount
	if current_xp >= xp_to_next_level: 
		level_up()
	update_xp_ui()

func level_up():
	current_xp -= xp_to_next_level
	current_level += 1
	xp_to_next_level = int(xp_to_next_level * 1.5) # Le prochain niveau est 50% plus dur
	
	# BONUS : On soigne le joueur quand il monte de niveau
	current_health = max_health
	update_ui()
	update_xp_ui()
	
	print("DEBUG: NIVEAU ", current_level, " ATTEINT !")
	
	# Afficher l'écran de choix
	var ui = get_tree().root.find_child("LevelUpUI", true, false)
	if ui:
		ui.show_upgrades()

func apply_upgrade(stat: String, value):
	print("DEBUG: Upgrade reçu -> ", stat, " +", value)
	
	match stat:
		"damage": damage += int(value)
		"speed": speed += float(value)
		"max_health": 
			max_health += int(value)
			current_health += int(value) # On donne aussi les PV gagnés tout de suite
		"attack_speed": attack_speed += float(value)
		"scale": 
			# Attention : grandir change la taille des collisions avec les murs !
			scale += Vector2(value, value)
	
	update_ui()

# --- SANTÉ & DÉGÂTS ---

func take_damage(amount):
	if is_dead: return
	
	current_health -= amount
	update_ui()
	
	# FEEDBACK : Le joueur clignote en rouge
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if current_health <= 0: 
		die()

func die():
	is_dead = true
	animated_sprite.play("ko")
	print("GAME OVER")
	# TODO: Appeler ici le GameManager pour afficher l'écran de fin

func _on_hitbox_body_entered(body):
	# INFO : Quand l'épée touche quelque chose
	if body.has_method("take_damage") and body != self:
		body.take_damage(damage)

# --- UI ---

func update_ui():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func update_xp_ui():
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = current_xp
