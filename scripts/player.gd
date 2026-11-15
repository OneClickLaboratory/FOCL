extends CharacterBody2D

@export var speed = 200.0
@export var jump_velocity = -300.0
@export var gravity = 980.0

var is_grounded = false
var is_paused = false
var is_console_open = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var console: Control = $Console
@onready var pause_menu: Control = $PauseMenu

func _ready():
	# Setup animations
	animated_sprite.animation = "idle"
	
	# Setup console
	console.setup_console()
	
	# Setup pause menu
	pause_menu.setup_pause_menu()

func _physics_process(delta):
	if is_paused or is_console_open:
		return
		
	# Handle gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Handle movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * speed
		animated_sprite.flip_h = direction < 0
		if is_on_floor():
			animated_sprite.animation = "run"
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor():
			animated_sprite.animation = "idle"
	
	# Handle animations
	if not is_on_floor():
		animated_sprite.animation = "jump"
	
	# Move the character
	move_and_slide()
	
	# Update grounded state
	is_grounded = is_on_floor()

func _unhandled_input(event):
	# Toggle console
	if event.is_action_pressed("console_toggle"):
		toggle_console()
	
	# Toggle pause menu
	if event.is_action_pressed("pause"):
		toggle_pause_menu()

func toggle_console():
	is_console_open = !is_console_open
	console.visible = is_console_open
	get_tree().paused = is_console_open

func toggle_pause_menu():
	is_paused = !is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused