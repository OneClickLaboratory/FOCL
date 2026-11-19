extends Node
## Глобальное состояние: профиль, валюта Focls, магазин, время суток.

signal focls_changed(value: int)
signal time_changed(hours: float)
signal item_purchased(id: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LOGIN_SCENE := "res://scenes/login.tscn"

# Чтобы добавить плейс - просто добавь запись сюда.
const PLACES := [
    {
        "id": "parkour",
        "name": "Parkour Test",
        "desc": "Тестовый плейс: прыгай по платформам, избегай красных блоков и добегай до финиша. Награда - Focls. В магазине (B) продаётся ковёр-самолёт.",
        "scene": "res://scenes/places/parkour.tscn",
    },
    {
        "id": "zombies",
        "name": "Выживание: Зомби",
        "desc": "Волны зомби, стрельба (ЛКМ), 4 вида оружия и апгрейды в магазине (B). Рекорды сохраняются. За убийства дают Focls.",
        "scene": "res://scenes/places/zombies.tscn",
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
var item_catalog: Array = []
var items_owned: Array = []
var place_data: Dictionary = {}
var current_place_id := ""

var time_of_day := 14.0
var show_fps := false
var console_open := false
var pause_open := false
var shop_open := false


func is_ui_blocked() -> bool:
    return console_open or pause_open or shop_open


# ---------- профиль ----------
func _save_path() -> String:
    return "user://profile_%s.json" % user_id.validate_filename()


func load_profile(id: String, display_name: String) -> void:
    user_id = id
    username = display_name
    focls = 100
    owned = ["skin_blue"]
    equipped = "skin_blue"
    item_catalog = []
    items_owned = []
    place_data = {}
    var path := _save_path()
    if FileAccess.file_exists(path):
        var f := FileAccess.open(path, FileAccess.READ)
        var data = JSON.parse_string(f.get_as_text())
        f.close()
        if data is Dictionary:
            focls = int(data.get("focls", focls))
            owned = data.get("owned", owned)
            equipped = str(data.get("equipped", equipped))
            items_owned = data.get("items", data.get("game_items", items_owned))
            place_data = data.get("place_data", {})
    focls_changed.emit(focls)


func save() -> void:
    var f := FileAccess.open(_save_path(), FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"focls": focls, "owned": owned, "equipped": equipped, "items": items_owned, "place_data": place_data}))
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


# ---------- игровые товары (API для креаторов) ----------
## Креатор объявляет товары в своём плейсе: переопредели PlaceBase.shop_items()
## или вызывай Game.define_item({...}) из кода плейса. Покупки хранятся в профиле.
## Поля товара: id (ключ), name, price (Focls), desc, color, place (ставится сам).

func define_item(item: Dictionary) -> void:
    var it := item.duplicate()
    if str(it.get("id", "")) == "":
        push_warning("define_item: у товара должен быть id")
        return
    it["name"] = str(it.get("name", it["id"]))
    it["price"] = int(it.get("price", 0))
    it["place"] = str(it.get("place", current_place_id))
    for i in item_catalog.size():
        if str(item_catalog[i]["id"]) == it["id"]:
            item_catalog[i] = it
            return
    item_catalog.append(it)


func item_def(id: String) -> Dictionary:
    for item in item_catalog:
        if str(item["id"]) == id:
            return item
    return {}


func items_for_place(place_id: String) -> Array:
    var res: Array = []
    for item in item_catalog:
        if str(item["place"]) == place_id:
            res.append(item)
    return res


func has_item(id: String) -> bool:
    return items_owned.has(id)


func buy_item(id: String) -> bool:
    var item := item_def(id)
    if item.is_empty() or items_owned.has(id) or focls < int(item["price"]):
        return false
    focls -= int(item["price"])
    items_owned.append(id)
    save()
    focls_changed.emit(focls)
    item_purchased.emit(id)
    return true


# ---------- данные плейсов (API для креаторов) ----------
## Хранилище твоего плейса (рекорды, прогресс) - сохраняется в профиле игрока.
## Ключи действуют в пределах текущего плейса.

func set_place_data(key: String, value: Variant) -> void:
    if current_place_id == "":
        return
    if not place_data.has(current_place_id):
        place_data[current_place_id] = {}
    place_data[current_place_id][key] = value
    save()


func get_place_data(key: String, default: Variant = null) -> Variant:
    return place_data.get(current_place_id, {}).get(key, default)


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
            current_place_id = place_id
            pause_open = false
            shop_open = false
            get_tree().change_scene_to_file(p["scene"])
            return


func go_to_menu() -> void:
    _leave_place()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file(MENU_SCENE)


func go_to_login() -> void:
    _leave_place()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file(LOGIN_SCENE)


func _leave_place() -> void:
    pause_open = false
    shop_open = false
    current_place_id = ""
