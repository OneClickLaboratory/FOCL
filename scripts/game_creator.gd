extends Control

@onready var templates_list: VBoxContainer = $MainContainer/Content/LeftPanel/LeftPanelContainer/TemplatesList
@onready var objects_list: VBoxContainer = $MainContainer/Content/LeftPanel/LeftPanelContainer/ObjectsList
@onready var game_name: LineEdit = $MainContainer/Content/RightPanel/RightPanelContainer/Properties/PropertiesContainer/GameName
@onready var game_description: TextEdit = $MainContainer/Content/RightPanel/RightPanelContainer/Properties/PropertiesContainer/GameDescription
@onready var save_button: Button = $MainContainer/BottomPanel/BottomButtons/SaveButton
@onready var test_button: Button = $MainContainer/BottomPanel/BottomButtons/TestButton
@onready var publish_button: Button = $MainContainer/BottomPanel/BottomButtons/PublishButton
@onready var back_button: Button = $MainContainer/BottomPanel/BottomButtons/BackButton

var game_data = {
	"name": "",
	"description": "",
	"scenes": [],
	"objects": [],
	"settings": {
		"gravity": 980,
		"player_speed": 200,
		"jump_velocity": -300
	}
}

var templates = [
	{"name": "Паркур игра", "description": "Беговая игра с препятствиями", "type": "parkour"},
	{"name": "Платформер", "description": "Классическая платформенная игра", "type": "platformer"},
	{"name": "Головоломка", "description": "Игра на логику и решение задач", "type": "puzzle"},
	{"name": "Битва", "description": "Боевая игра с различными противниками", "type": "battle"}
]

var game_objects = [
	{"name": "Игрок", "type": "player", "icon": "👤"},
	{"name": "Враг", "type": "enemy", "icon": "👹"},
	{"name": "Предмет", "type": "item", "icon": "📦"},
	{"name": "Платформа", "type": "platform", "icon": "🟫"},
	{"name": "Монета", "type": "coin", "icon": "🪙"},
	{"name": "Дверь", "type": "door", "icon": "🚪"},
	{"name": "Ключ", "type": "key", "icon": "🔑"},
	{"name": "Триггер", "type": "trigger", "icon": "⚡"}
]

func _ready():
	setup_templates()
	setup_objects()
	setup_signals()

func setup_templates():
	for template in templates:
		var template_button = Button.new()
		template_button.custom_minimum_size = Vector2(0, 60)
		template_button.text = "%s\n%s" % [template.name, template.description]
		template_button.pressed.connect(_on_template_selected.bind(template))
		templates_list.add_child(template_button)

func setup_objects():
	for obj in game_objects:
		var obj_button = Button.new()
		obj_button.custom_minimum_size = Vector2(0, 50)
		obj_button.text = "%s %s" % [obj.icon, obj.name]
		obj_button.pressed.connect(_on_object_selected.bind(obj))
		objects_list.add_child(obj_button)

func setup_signals():
	save_button.pressed.connect(_on_save_pressed)
	test_button.pressed.connect(_on_test_pressed)
	publish_button.pressed.connect(_on_publish_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_template_selected(template):
	print("Selected template: ", template.name)
	game_data["settings"]["template"] = template.type
	
	# Apply template settings
	match template.type:
		"parkour":
			game_data["settings"]["gravity"] = 980
			game_data["settings"]["player_speed"] = 250
			game_data["settings"]["jump_velocity"] = -400
		"platformer":
			game_data["settings"]["gravity"] = 980
			game_data["settings"]["player_speed"] = 200
			game_data["settings"]["jump_velocity"] = -350
		"puzzle":
			game_data["settings"]["gravity"] = 0
			game_data["settings"]["player_speed"] = 150
			game_data["settings"]["jump_velocity"] = 0
		"battle":
			game_data["settings"]["gravity"] = 980
			game_data["settings"]["player_speed"] = 180
			game_data["settings"]["jump_velocity"] = -300

func _on_object_selected(obj):
	print("Selected object: ", obj.name)
	# Add object to current scene
	add_object_to_scene(obj)

func add_object_to_scene(obj):
	var new_object = {
		"id": len(game_data["objects"]),
		"type": obj.type,
		"name": obj.name,
		"position": Vector2(400, 300),  # Default position
		"properties": {}  # Custom properties
	}
	game_data["objects"].append(new_object)
	print("Added object: ", new_object)

func _on_save_pressed():
	game_data["name"] = game_name.text
	game_data["description"] = game_description.text
	
	# Save game data
	var save_result = save_game_data()
	if save_result:
		print("Game saved successfully!")
	else:
		print("Failed to save game")

func save_game_data():
	var save_path = "user://games/%s.json" % game_data["name"].replace(" ", "_")
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(game_data)
		file.store_string(json_string)
		file.close()
		return true
	return false

func _on_test_pressed():
	print("Testing game...")
	# Create test scene and load it
	test_game()

func test_game():
	# Create a temporary test scene
	var test_scene = PackedScene.new()
	
	# Add basic game elements
	var test_node = Node2D.new()
	test_node.name = "TestGame"
	
	# Add player
	var player = CharacterBody2D.new()
	player.name = "Player"
	var collision = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 16
	capsule.height = 48
	collision.shape = capsule
	player.add_child(collision)
	test_node.add_child(player)
	
	# Add ground
	var ground = StaticBody2D.new()
	ground.name = "Ground"
	var ground_collision = CollisionShape2D.new()
	var ground_rect = RectangleShape2D.new()
	ground_rect.size = Vector2(2000, 100)
	ground_collision.shape = ground_rect
	ground.add_child(ground_collision)
	test_node.add_child(ground)
	
	test_scene.pack(test_node)
	
	# Change to test scene
	get_tree().change_scene_to_packed(test_scene)

func _on_publish_pressed():
	print("Publishing game...")
	publish_game()

func publish_game():
	if not game_data["name"] or not game_data["description"]:
		print("Please fill in game name and description")
		return
	
	# Create game data for Supabase
	var game_to_publish = {
		"name": game_data["name"],
		"description": game_data["description"],
		"author_id": Global.user_data["id"] if Global.user_data else null,
		"objects": game_data["objects"],
		"settings": game_data["settings"],
		"created_at": Time.get_datetime_string_from_system(),
		"published": true,
		"rating": 0,
		"plays": 0
	}
	
	# Save to Supabase (simulated)
	print("Publishing game: ", game_data["name"])
	print("Game data: ", game_to_publish)
	
	# In real implementation, this would save to Supabase
	# var result = await supabase.from("user_games").insert(game_to_publish).execute()
	
	# Show success message
	var success_label = Label.new()
	success_label.text = "Игра опубликована!"
	success_label.horizontal_alignment = 1
	success_label.vertical_alignment = 1
	success_label.add_theme_font_size_override("font_size", 24)
	add_child(success_label)
	
	await get_tree().create_timer(2.0).timeout
	success_label.queue_free()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")