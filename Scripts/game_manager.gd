extends Node

class_name GameManagerClass 

# ==========================================
# ⚙️ RÉGLAGES DIFFICULTÉ
# ==========================================
@export var difficulty_increase_interval: float = 30.0 # Tous les 30 secondes
@export var hp_bonus_per_tick: int = 10                # +10 PV aux ennemis
@export var damage_bonus_per_tick: int = 2             # +2 Dégâts aux ennemis

# INFO : Stats globales que les ennemis viendront lire
var current_enemy_hp_bonus: int = 0
var current_enemy_damage_bonus: int = 0

var time_survived: float = 0.0
var difficulty_timer: float = 0.0
var player: CharacterBody2D

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	# Si le joueur est mort, on arrête le temps
	if player and player.is_dead: return
	
	time_survived += delta
	difficulty_timer += delta
	
	# INFO : Augmentation cyclique de la difficulté
	if difficulty_timer >= difficulty_increase_interval:
		increase_difficulty()
		difficulty_timer = 0.0

func increase_difficulty():
	current_enemy_hp_bonus += hp_bonus_per_tick
	current_enemy_damage_bonus += damage_bonus_per_tick
	
	print("⚠️ ATTENTION : Les ennemis deviennent plus forts !")
	print("Bonus HP: ", current_enemy_hp_bonus, " Dégâts: ", current_enemy_damage_bonus)

# INFO : Fonction utilitaire pour formater le temps (ex: 02:15)
func get_formatted_time() -> String:
	var minutes = int(time_survived / 60)
	var seconds = int(time_survived) % 60
	return "%02d:%02d" % [minutes, seconds]
