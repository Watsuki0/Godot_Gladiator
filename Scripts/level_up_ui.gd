extends Control

# Signal envoyé quand le joueur clique sur une carte
signal upgrade_chosen(stat_name, value)

# INFO : Liste des améliorations possibles
var upgrades = [
	{"text": "Force +5", "stat": "damage", "val": 5},
	{"text": "Vitesse +10", "stat": "speed", "val": 10},
	{"text": "Santé Max +20", "stat": "max_health", "val": 20},
	{"text": "Vitesse Atk +10%", "stat": "attack_speed", "val": 0.1},
	{"text": "Grandir +5%", "stat": "scale", "val": 0.05} # Bonus fun
]

@onready var buttons = [$HBoxContainer/card1, $HBoxContainer/card2, $HBoxContainer/card3]

func _ready():
	visible = false
	# IMPORTANT : Cette UI doit continuer de fonctionner même quand le jeu est en pause !
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	# Connexion des boutons
	for btn in buttons:
		btn.pressed.connect(_on_card_pressed.bind(btn))

func show_upgrades():
	visible = true
	# INFO : On met le jeu en pause (fige les ennemis et le joueur)
	get_tree().paused = true
	
	# On mélange les cartes pour avoir du hasard
	upgrades.shuffle()
	
	for i in range(buttons.size()):
		if i < upgrades.size():
			var upgrade = upgrades[i]
			buttons[i].text = upgrade["text"]
			# On stocke les données cachées dans le bouton (metadata)
			buttons[i].set_meta("stat", upgrade["stat"])
			buttons[i].set_meta("val", upgrade["val"])

func _on_card_pressed(btn):
	# On récupère les infos stockées
	var stat = btn.get_meta("stat")
	var val = btn.get_meta("val")
	
	# On prévient le joueur qu'il a choisi
	emit_signal("upgrade_chosen", stat, val)
	
	# On cache l'UI et on relance le jeu
	visible = false
	get_tree().paused = false
