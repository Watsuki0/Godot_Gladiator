extends Label

var game_manager

func _ready():
	game_manager = get_tree().root.find_child("GameManager", true, false)

func _process(_delta):
	if game_manager:
		text = game_manager.get_formatted_time()
	else:
		text = "00:00"
