extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var level_info: Label = $LevelInfo
@onready var fps_label: Label = $FPSLabel
var fps_counter = 0
var fps_timer = 0

func _ready():
	# Add player to group for easy access
	player.add_to_group("player")
	
	# Setup input actions
	setup_input_actions()

func setup_input_actions():
	# Define input actions for different platforms
	if OS.get_name() in ["Android", "iOS"]:
		# Mobile controls
		InputMap.add_action("move_left")
		InputMap.add_action("move_right")
		InputMap.add_action("jump")
		InputMap.add_action("pause")
		
		# Add touch controls here if needed
	else:
		# Desktop controls
		InputMap.add_action("move_left")
		InputMap.add_action("move_right")
		InputMap.add_action("jump")
		InputMap.add_action("pause")
		InputMap.add_action("console_toggle")
		
		# Map keyboard inputs
		InputMap.action_add_event("move_left", InputEventKey.new().with_physical_key(KEY_A))
		InputMap.action_add_event("move_right", InputEventKey.new().with_physical_key(KEY_D))
		InputMap.action_add_event("jump", InputEventKey.new().with_physical_key(KEY_SPACE))
		InputMap.action_add_event("pause", InputEventKey.new().with_physical_key(KEY_ESCAPE))
		InputMap.action_add_event("console_toggle", InputEventKey.new().with_physical_key(KEY_TILDE))

func _process(delta):
	# FPS counter
	fps_timer += delta
	if fps_timer >= 1.0:
		fps_label.text = "FPS: %d" % fps_counter
		fps_counter = 0
		fps_timer = 0
	else:
		fps_counter += 1

func _on_goal_body_entered(body):
	if body == player:
		level_info.text = "Level Complete! Press ESC to continue..."
		get_tree().paused = true
		
		# Show completion message
		var completion_label = Label.new()
		completion_label.text = "LEVEL COMPLETE!"
		completion_label.horizontal_alignment = 1
		completion_label.vertical_alignment = 1
		completion_label.add_theme_font_size_override("font_size", 48)
		add_child(completion_label)
		
		# Remove label after 3 seconds
		await get_tree().create_timer(3.0).timeout
		completion_label.queue_free()
		get_tree().paused = false