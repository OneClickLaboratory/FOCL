extends Control

const API_URL = "https://oneclicklabsofficial.onrender.com"  # Замените на ваш реальный URL

@onready var mode_tabs: TabContainer = $MainContainer/AuthPanel/AuthContainer/ModeTabs
@onready var login_email: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/LoginTab/LoginEmail
@onready var login_password: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/LoginTab/LoginPassword
@onready var login_button: Button = $MainContainer/AuthPanel/AuthContainer/ModeTabs/LoginTab/LoginButton
@onready var google_login_button: Button = $MainContainer/AuthPanel/AuthContainer/ModeTabs/LoginTab/GoogleLoginButton
@onready var register_username: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/RegisterTab/RegisterUsername
@onready var register_email: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/RegisterTab/RegisterEmail
@onready var register_password: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/RegisterTab/RegisterPassword
@onready var register_confirm: LineEdit = $MainContainer/AuthPanel/AuthContainer/ModeTabs/RegisterTab/RegisterConfirmPassword
@onready var register_button: Button = $MainContainer/AuthPanel/AuthContainer/ModeTabs/RegisterTab/RegisterButton
@onready var error_label: Label = $MainContainer/AuthPanel/AuthContainer/ErrorLabel

var auth_token = ""
var http_request = HTTPRequest.new()

func _ready():
	# Добавляем HTTPRequest в дерево
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	# Подключаем сигналы кнопок
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	
	# Проверяем сохранённую сессию
	check_saved_session()

func check_saved_session():
	var file = FileAccess.open("user://auth_token.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			var data = json.data
			auth_token = data.get("token", "")
			Global.set_user_data(data.get("user", {}))
			change_to_main_menu()

func _on_login_pressed():
	var email = login_email.text.strip_edges()
	var password = login_password.text.strip_edges()
	
	if not email or not password:
		show_error("Заполните все поля")
		return
	
	show_error("")
	http_request.request(API_URL + "/api/auth/login", ["Content-Type: application/json"], true, HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": password}))
	show_loading("Вход...")

func _on_register_pressed():
	var username = register_username.text.strip_edges()
	var email = register_email.text.strip_edges()
	var password = register_password.text.strip_edges()
	var confirm = register_confirm.text.strip_edges()
	
	if not username or not email or not password or not confirm:
		show_error("Заполните все поля")
		return
	
	if password != confirm:
		show_error("Пароли не совпадают")
		return
	
	show_error("")
	http_request.request(API_URL + "/api/auth/register", ["Content-Type: application/json"], true, HTTPClient.METHOD_POST, JSON.stringify({"username": username, "email": email, "password": password}))
	show_loading("Регистрация...")

func _on_http_request_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var json = JSON.new()
		var parse_error = json.parse(body.get_string_from_utf8())
		if parse_error == OK:
			var data = json.data
			
			# Сохраняем токен и данные пользователя
			auth_token = data.get("token", "")
			if data.get("user"):
				Global.set_user_data(data.get("user"))
			
			# Сохраняем в файл
			save_session(auth_token, data.get("user", {}))
			
			change_to_main_menu()
		else:
			show_error("Ошибка ответа сервера")
	else:
		show_error("Ошибка: Код ответа %d" % response_code)

func save_session(token, user_data):
	var file = FileAccess.open("user://auth_token.json", FileAccess.WRITE)
	if file:
		var save_data = {"token": token, "user": user_data}
		file.store_string(JSON.stringify(save_data))
		file.close()

func show_error(text):
	error_label.text = text

func show_loading(text):
	error_label.text = text
	error_label.modulate = Color(0.5, 0.7, 1.0, 1.0)

func change_to_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")