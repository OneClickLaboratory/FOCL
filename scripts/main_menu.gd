extends Node2D

@onready var games_button: Button = $GamesButton
@onready var create_game_button: Button = $CreateGameButton
@onready var shop_button: Button = $ShopButton
@onready var currency_label: Label = $CurrencyLabel
@onready var exit_button: Button = $ExitButton

var supabase_url = "https://qhxhpzmfwtfqbsjtiijf.supabase.co"
var supabase_anon_key = "sb_publishable_w8a3A5z994_t7zDkYwKivw_D9uCQhGb"
var supabase = null

func _ready():
	# Initialize Supabase client
	var supabase_gd = preload("res://scripts/supabase.gd").new()
	supabase = supabase_gd.create_client(supabase_url, supabase_anon_key)
	
	# Load user data
	load_user_data()
	
	# Connect button signals
	games_button.pressed.connect(_on_games_pressed)
	create_game_button.pressed.connect(_on_create_game_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func load_user_data():
	if Global.user_data:
		currency_label.text = "Focls: %d" % Global.user_data.get("balance", 0)

func _on_games_pressed():
	print("Opening game browser...")
	get_tree().change_scene_to_file("res://scenes/game_browser.tscn")

func _on_create_game_pressed():
	print("Opening game creator...")
	get_tree().change_scene_to_file("res://scenes/game_creator.tscn")

func _on_shop_pressed():
	print("Opening shop...")

func _on_exit_pressed():
	get_tree().quit()