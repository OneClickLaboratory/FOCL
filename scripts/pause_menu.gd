extends Control

var players_list = []
var menu_visible = false

@onready var players_container: VBoxContainer = $MarginContainer/VBoxContainer/PlayersContainer
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ResetButton
@onready var players_label: Label = $MarginContainer/VBoxContainer/PlayersLabel

func _ready():
	hide()
	exit_button.pressed.connect(_on_exit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Setup mobile controls if needed
	if OS.get_name() in ["Android", "iOS"]:
		setup_mobile_controls()

func setup_pause_menu():
	# Update players list
	update_players_list()

func update_players_list():
	players_container.clear_children()
	
	# Mock players data - in real implementation, get from server
	var mock_players = [
		{"name": "Player1", "id": 1},
		{"name": "Player2", "id": 2},
		{"name": "You", "id": 3}
	]
	
	for player in mock_players:
		var player_label = Label.new()
		player_label.text = player.name
		player_label.add_theme_font_size_override("font_size", 18)
		players_container.add_child(player_label)

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		toggle_menu()

func toggle_menu():
	menu_visible = !menu_visible
	visible = menu_visible
	get_tree().paused = menu_visible
	
	if menu_visible:
		update_players_list()

func _on_exit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_reset_pressed():
	# Reset player character
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.queue_free()
		# Spawn new player
		var player_scene = preload("res://scenes/player.tscn").instantiate()
		get_tree().current_scene.add_child(player_scene)
		player_scene.position = Vector2(0, 0)
		console_history.append("Player reset")

func setup_mobile_controls():
	# Add virtual buttons for mobile devices
	var pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.position = Vector2(10, 10)
	pause_button.pressed.connect(toggle_menu)
	add_child(pause_button)