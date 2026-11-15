extends Node

# Global game state
var user_data = null
var current_scene = null
var places_data = []
var is_mobile = false

func _ready():
	# Check if running on mobile
	is_mobile = OS.get_name() in ["Android", "iOS"]
	print("Running on mobile: ", is_mobile)

func set_user_data(data):
	user_data = data

func get_user_data():
	return user_data