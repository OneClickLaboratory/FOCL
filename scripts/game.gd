extends Node
## Глобальное состояние: профиль, валюта Focls, магазин, время суток.

signal focls_changed(value: int)
signal time_changed(hours: float)

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LOGIN_SCENE := "res://scenes/login.tscn"

# Чтобы добавить плейс - просто добавь запись сюда.
const PLACES := [
    {
        "id": "parkour",
        "name": "Parkour Test",
        "desc": "Тестовый плейс: прыгай по платформам, избегай красных блоков и добегай до финиша. Награда - Focls.",
        "scene": "res://scenes/places/parkour.tscn",
    },
]

const SHOP_ITEMS := [
    {"id": "skin_blue", "name": "Синий скин", "price": 0, "color": Color(0.2, 0.45, 0.9)},
    {"id": "skin_red", "name": "Красный скин", "price": 50, "color": Color(0.9, 0.2, 0.2)},
    {"id": "skin_green", "name": "Зелёный скин", "price": 50, "color": Color(0.2, 0.75, 0.3)},
    {"id": "skin_purple", "name": "Фиолетовый скин", "price": 100, "color": Color(0.6, 0.3, 0.85)},
    {"id": "skin_black", "name": "Чёрный скин", "price": 150, "color": Color(0.12, 0.12, 0.14)},
    {"id": "skin_gold", "name": "Золотой скин", "price": 250, "color": Color(1.0, 0.78, 0.2)},
]

var user_id := "guest"
var username := "Гость"
var focls := 0
var owned: Array = ["skin_blue"]
var equipped := "skin_blue"

var time_of_day := 14.0
var show_fps := false
var console_open := false
var pause_open := false


func is_ui_blocked() -> bool:
    return console_open or pause_open


# ---------- профиль ----------
func _save_path() -> String:
    return "user://profile_%s.json" % user_id.validate_filename()


func load_profile(id: String, display_name: String) -> void:
    user_id = id
    username = display_name
    focls = 100
    owned = ["skin_blue"]
    equipped = "skin_blue"
    var path := _save_path()
    if FileAccess.file_exists(path):
        var f := FileAccess.open(path, FileAccess.READ)
        var data = JSON.parse_string(f.get_as_text())
        f.close()
        if data is Dictionary:
            focls = int(data.get("focls", focls))
            owned = data.get("owned", owned)
            equipped = str(data.get("equipped", equipped))
    focls_changed.emit(focls)


func save() -> void:
    var f := FileAccess.open(_save_path(), FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"focls": focls, "owned": owned, "equipped": equipped}))
        f.close()


# ---------- Focls / магазин ----------
func add_focls(amount: int) -> void:
    focls += amount
    save()
    focls_changed.emit(focls)


func item_by_id(id: String) -> Dictionary:
    for item in SHOP_ITEMS:
        if item["id"] == id:
            return item
    return {}


func buy(id: String) -> bool:
    var item := item_by_id(id)
    if item.is_empty() or owned.has(id) or focls < int(item["price"]):
        return false
    focls -= int(item["price"])
    owned.append(id)
    save()
    focls_changed.emit(focls)
    return true


func equip(id: String) -> void:
    if owned.has(id):
        equipped = id
        save()


func equipped_color() -> Color:
    var item := item_by_id(equipped)
    return item["color"] if not item.is_empty() else Color(0.2, 0.45, 0.9)


func get_player_names() -> Array:
    # Сейчас только локальный игрок. Когда появится мультиплеер - добавь сюда остальных.
    return [username]


# ---------- время ----------
func set_time(hours: float) -> void:
    time_of_day = clampf(hours, 0.0, 24.0)
    time_changed.emit(time_of_day)


# ---------- сцены ----------
func go_to_place(place_id: String) -> void:
    for p in PLACES:
        if p["id"] == place_id:
            pause_open = false
            get_tree().change_scene_to_file(p["scene"])
            return


func go_to_menu() -> void:
    pause_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file(MENU_SCENE)


func go_to_login() -> void:
    pause_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file(LOGIN_SCENE)
