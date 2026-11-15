extends Control

var console_visible = false
var console_history = []
var console_input = ""
var max_history = 50

@onready var console_label: RichTextLabel = $ConsoleLabel
@onready var input_line: LineEdit = $InputLine
@onready var history_label: Label = $HistoryLabel

func _ready():
	hide()
	input_line.text = ""
	input_line.grab_focus()

func _process(delta):
	if visible:
		input_line.grab_focus()

func setup_console():
	console_label.text = ""
	console_history.append("FOCL Console v1.0")
	console_history.append("Type 'help' for available commands")
	update_display()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		hide()
		get_tree().paused = false
		console_visible = false

func _on_input_line_text_submitted(new_text):
	console_input = new_text
	console_history.append("> " + new_text)
	process_command(console_input)
	input_line.text = ""
	input_line.grab_focus()

func process_command(command: String):
	command = command.strip_edges().to_lower()
	
	var parts = command.split(" ")
	var cmd = parts[0]
	var args = parts.slice(1)
	
	match cmd:
		"help":
			console_history.append("Available commands:")
			console_history.append("  help - Show this help")
			console_history.append("  time set <hour> - Set game time")
			console_history.append("  fps_show - Toggle FPS display")
			console_history.append("  reset - Reset player position")
			console_history.append("  quit - Exit game")
			console_history.append("  clear - Clear console")
		
		"time":
			if args.size() > 0 and args[0] == "set":
				if args.size() > 1:
					var hour = int(args[1])
					if hour >= 0 and hour <= 23:
						set_time(hour)
					else:
						console_history.append("Error: Hour must be 0-23")
				else:
					console_history.append("Usage: time set <hour>")
			else:
				console_history.append("Usage: time set <hour>")
		
		"fps_show":
			toggle_fps()
		
		"reset":
			reset_player()
		
		"quit":
			get_tree().quit()
		
		"clear":
			console_history.clear()
			console_history.append("Console cleared")
		
		_:
			console_history.append("Unknown command: " + cmd)
	
	update_display()

func update_display():
	console_label.text = ""
	for line in console_history.slice(-20):  # Show last 20 lines
		console_label.text += line + "\n"

func set_time(hour: int):
	# This would set the game time in a real implementation
	console_history.append("Time set to %02d:00" % hour)
	Engine.time_scale = 1.0  # Reset time scale

func toggle_fps():
	var fps_label = get_node_or_null("/root/Main/FPSLabel")
	if fps_label:
		fps_label.visible = !fps_label.visible
	else:
		console_history.append("FPS label not found")

func reset_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.position = Vector2(0, 0)
		player.velocity = Vector2.ZERO
		console_history.append("Player position reset")
	else:
		console_history.append("Player not found")