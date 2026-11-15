extends Control

@onready var search_input: LineEdit = $MainContainer/SearchBar/SearchContainer/SearchInput
@onready var filter_button: Button = $MainContainer/SearchBar/SearchContainer/FilterButton
@onready var sort_button: Button = $MainContainer/SearchBar/SearchContainer/SortButton
@onready var games_grid: GridContainer = $MainContainer/GamesContainer/GamesGrid
@onready var create_game_button: Button = $MainContainer/BottomPanel/BottomButtons/CreateGameButton
@onready var my_games_button: Button = $MainContainer/BottomPanel/BottomButtons/MyGamesButton
@onready var back_button: Button = $MainContainer/BottomPanel/BottomButtons/BackButton

var games_data = []
var displayed_games = []
var current_filter = {"category": "all", "sort_by": "newest"}
var user_games = []

func _ready():
	setup_signals()
	load_games()
	load_user_games()

func setup_signals():
	search_input.text_changed.connect(_on_search_changed)
	filter_button.pressed.connect(_on_filter_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	create_game_button.pressed.connect(_on_create_game_pressed)
	my_games_button.pressed.connect(_on_my_games_pressed)
	back_button.pressed.connect(_on_back_pressed)

func load_games():
	# Simulate loading games from Supabase
	games_data = [
		{
			"id": 1,
			"name": "Супер паркур",
			"description": "Эпичная паркур игра с множеством уровней",
			"author": "Player1",
			"rating": 4.5,
			"plays": 1234,
			"thumbnail": "🏃‍♂️",
			"category": "parkour",
			"created_at": "2024-01-15T10:00:00Z",
			"published": true
		},
		{
			"id": 2,
			"name": "Замок призраков",
			"description": "Страшное приключение в заброшенном замке",
			"author": "GhostHunter",
			"rating": 4.2,
			"plays": 856,
			"thumbnail": "🏰",
			"category": "adventure",
			"created_at": "2024-01-10T14:30:00Z",
			"published": true
		},
		{
			"id": 3,
			"name": "Космический бой",
			"description": "Экшен игра в космосе",
			"author": "SpaceWarrior",
			"rating": 4.8,
			"plays": 2341,
			"thumbnail": "🚀",
			"category": "action",
			"created_at": "2024-01-08T09:15:00Z",
			"published": true
		},
		{
			"id": 4,
			"name": "Магическая головоломка",
			"description": "Интеллектуальная игра с магией",
			"author": "WizardPuzzle",
			"rating": 4.0,
			"plays": 567,
			"thumbnail": "🧩",
			"category": "puzzle",
			"created_at": "2024-01-05T16:45:00Z",
			"published": true
		},
		{
			"id": 5,
			"name": "Драконья битва",
			"description": "Эпичные битвы с драконами",
			"author": "DragonSlayer",
			"rating": 4.7,
			"plays": 3456,
			"thumbnail": "🐉",
			"category": "battle",
			"created_at": "2024-01-01T12:20:00Z",
			"published": true
		}
	]
	
	displayed_games = games_data.duplicate()
	update_games_display()

func load_user_games():
	# Simulate loading user's games
	user_games = [
		{
			"id": 101,
			"name": "Моя первая игра",
			"description": "Простой платформер",
			"author": "Я",
			"rating": 0.0,
			"plays": 0,
			"thumbnail": "🎮",
			"category": "platformer",
			"created_at": "2024-01-20T11:00:00Z",
			"published": false
		}
	]

func update_games_display():
	# Clear existing games
	for child in games_grid.get_children():
		child.queue_free()
	
	# Add games to grid
	for game in displayed_games:
		var game_card = create_game_card(game)
		games_grid.add_child(game_card)

func create_game_card(game):
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(280, 200)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Game thumbnail and header
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var thumbnail = Label.new()
	thumbnail.text = game.thumbnail
	thumbnail.custom_minimum_size = Vector2(60, 60)
	thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = game.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 18)
	
	var author = Label.new()
	author.text = "by " + game.author
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	author.add_theme_font_size_override("font_size", 14)
	author.modulate = Color(0.7, 0.7, 0.7, 1)
	
	info.add_child(title)
	info.add_child(author)
	header.add_child(thumbnail)
	header.add_child(info)
	vbox.add_child(header)
	
	# Description
	var desc = Label.new()
	desc.text = game.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)
	
	# Stats and actions
	var stats = HBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rating = Label.new()
	rating.text = "⭐ %.1f" % game.rating
	rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rating.add_theme_font_size_override("font_size", 14)
	
	var plays = Label.new()
	plays.text = "👁 %d" % game.plays
	plays.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	plays.add_theme_font_size_override("font_size", 14)
	
	stats.add_child(rating)
	stats.add_child(plays)
	vbox.add_child(stats)
	
	# Play button
	var play_button = Button.new()
	play_button.text = "Играть"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(_on_game_selected.bind(game))
	vbox.add_child(play_button)
	
	card_panel.add_child(vbox)
	return card_panel

func filter_games():
	var search_term = search_input.text.to_lower()
	var filtered = games_data.duplicate()
	
	# Apply search filter
	if search_term:
		filtered = filtered.filter(func(game):
			return game.name.to_lower().contains(search_term) or \
				   game.description.to_lower().contains(search_term) or \
				   game.author.to_lower().contains(search_term)
		)
	
	# Apply category filter
	if current_filter.category != "all":
		filtered = filtered.filter(func(game):
			return game.category == current_filter.category
		)
	
	# Apply sorting
	match current_filter.sort_by:
		"newest":
			filtered.sort_custom(func(a, b):
				return a.created_at > b.created_at
			)
		"oldest":
			filtered.sort_custom(func(a, b):
				return a.created_at < b.created_at
			)
		"rating":
			filtered.sort_custom(func(a, b):
				return a.rating > b.rating
			)
		"popular":
			filtered.sort_custom(func(a, b):
				return a.plays > b.plays
			)
	
	displayed_games = filtered
	update_games_display()

func _on_search_changed(new_text):
	filter_games()

func _on_filter_pressed():
	print("Filter pressed - would show filter dialog")
	# In real implementation, show a filter dialog
	filter_games()

func _on_sort_pressed():
	print("Sort pressed - would show sort options")
	# Cycle through sort options
	var sort_options = ["newest", "oldest", "rating", "popular"]
	var current_index = sort_options.find(current_filter.sort_by)
	current_filter.sort_by = sort_options[(current_index + 1) % sort_options.size()]
	sort_button.text = "Сортировка: " + current_filter.sort_by
	filter_games()

func _on_game_selected(game):
	print("Starting game: ", game.name)
	start_game(game)

func start_game(game):
	# Load and start the selected game
	print("Loading game: ", game.name)
	
	# In real implementation, this would:
	# 1. Download game data from Supabase
	# 2. Create game scene from the data
	# 3. Load the game scene
	
	# For now, show a placeholder
	var game_label = Label.new()
	game_label.text = "Игра: " + game.name
	game_label.horizontal_alignment = 1
	game_label.vertical_alignment = 1
	game_label.add_theme_font_size_override("font_size", 48)
	add_child(game_label)
	
	await get_tree().create_timer(3.0).timeout
	game_label.queue_free()

func _on_create_game_pressed():
	print("Opening game creator")
	get_tree().change_scene_to_file("res://scenes/game_creator.tscn")

func _on_my_games_pressed():
	print("Showing user games")
	show_user_games()

func show_user_games():
	# Show user's games instead of all games
	displayed_games = user_games
	update_games_display()
	
	# Update button text to show we're in user games mode
	my_games_button.text = "Все игры"

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")