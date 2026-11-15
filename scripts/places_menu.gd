extends Control

@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var places_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/PlacesList
var places_data = [
	{"name": "Паркур арена", "description": "Тренируйся в паркуре на различных уровнях", "scene": "res://scenes/parkour_level.tscn"},
	{"name": "Битва на мечах", "description": "Соревнуйся с другими игроками в боях", "scene": "res://scenes/battle_arena.tscn"},
	{"name": "Строительство", "description": "Строй свои собственные миры", "scene": "res://scenes/build_mode.tscn"}
]

func _ready():
	# Setup back button
	back_button.pressed.connect(_on_back_pressed)
	
	# Setup places
	setup_places()

func setup_places():
	for place in places_data:
		var place_panel = Panel.new()
		place_panel.custom_minimum_size = Vector2(0, 80)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.text = place.name
		
		var desc_label = Label.new()
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.text = place.description
		
		var play_button = Button.new()
		play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play_button.add_theme_font_size_override("font_size", 16)
		play_button.text = "Играть"
		play_button.pressed.connect(_on_place_selected.bind(place.scene))
		
		vbox.add_child(name_label)
		vbox.add_child(desc_label)
		vbox.add_child(play_button)
		place_panel.add_child(vbox)
		places_list.add_child(place_panel)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_place_selected(scene_path: String):
	get_tree().change_scene_to_file(scene_path)