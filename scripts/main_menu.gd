extends Control
## Главное меню: список плейсов, магазин, валюта Focls.

var focls_label: Label
var places_grid: GridContainer
var shop_grid: GridContainer


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    Game.pause_open = false

    var bg := ColorRect.new()
    bg.color = Color(0.09, 0.1, 0.14)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    # --- верхняя панель ---
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 16)
    root.add_child(top)

    var title := Label.new()
    title.text = "ROBLOX CLONE"
    title.add_theme_font_size_override("font_size", 32)
    top.add_child(title)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)

    focls_label = Label.new()
    focls_label.add_theme_font_size_override("font_size", 22)
    focls_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
    top.add_child(focls_label)

    var user_label := Label.new()
    user_label.text = "👤 " + Game.username
    user_label.add_theme_font_size_override("font_size", 20)
    top.add_child(user_label)

    var logout := Button.new()
    logout.text = "Выйти из аккаунта"
    logout.pressed.connect(_on_logout)
    top.add_child(logout)

    # --- вкладки ---
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(tabs)

    var places_scroll := ScrollContainer.new()
    places_scroll.name = "Плейсы"
    tabs.add_child(places_scroll)
    places_grid = GridContainer.new()
    places_grid.columns = 3
    places_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    places_grid.add_theme_constant_override("h_separation", 16)
    places_grid.add_theme_constant_override("v_separation", 16)
    places_scroll.add_child(places_grid)

    var shop_scroll := ScrollContainer.new()
    shop_scroll.name = "Магазин"
    tabs.add_child(shop_scroll)
    shop_grid = GridContainer.new()
    shop_grid.columns = 4
    shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop_grid.add_theme_constant_override("h_separation", 16)
    shop_grid.add_theme_constant_override("v_separation", 16)
    shop_scroll.add_child(shop_grid)

    var hint := Label.new()
    hint.text = "Консоль: ` (Ё) или F1  •  В плейсе: Esc - меню"
    hint.modulate = Color(1, 1, 1, 0.45)
    root.add_child(hint)

    Game.focls_changed.connect(_update_focls)
    _update_focls(Game.focls)
    _build_places()
    _build_shop()


func _update_focls(value: int) -> void:
    focls_label.text = "%d Focls" % value


func _card_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.15, 0.16, 0.21)
    sb.set_corner_radius_all(10)
    sb.set_content_margin_all(14)
    return sb


func _build_places() -> void:
    for place in Game.PLACES:
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(300, 190)
        card.add_theme_stylebox_override("panel", _card_style())
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 8)
        card.add_child(box)

        var name_l := Label.new()
        name_l.text = place["name"]
        name_l.add_theme_font_size_override("font_size", 22)
        box.add_child(name_l)

        var desc := Label.new()
        desc.text = place["desc"]
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.custom_minimum_size.x = 270
        desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
        desc.modulate = Color(1, 1, 1, 0.7)
        box.add_child(desc)

        var play := Button.new()
        play.text = "▶  Играть"
        play.pressed.connect(Game.go_to_place.bind(place["id"]))
        box.add_child(play)
        places_grid.add_child(card)


func _build_shop() -> void:
    for c in shop_grid.get_children():
        c.queue_free()
    for item in Game.SHOP_ITEMS:
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(230, 190)
        card.add_theme_stylebox_override("panel", _card_style())
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 8)
        card.add_child(box)

        var swatch := ColorRect.new()
        swatch.color = item["color"]
        swatch.custom_minimum_size = Vector2(0, 70)
        box.add_child(swatch)

        var name_l := Label.new()
        name_l.text = item["name"]
        name_l.add_theme_font_size_override("font_size", 18)
        box.add_child(name_l)

        var id: String = item["id"]
        var price: int = item["price"]
        var btn := Button.new()
        if Game.equipped == id:
            btn.text = "Надето"
            btn.disabled = true
        elif Game.owned.has(id):
            btn.text = "Надеть"
            btn.pressed.connect(_on_equip.bind(id))
        else:
            btn.text = "Купить за %d Focls" % price
            btn.disabled = Game.focls < price
            btn.pressed.connect(_on_buy.bind(id))
        box.add_child(btn)
        shop_grid.add_child(card)


func _on_buy(id: String) -> void:
    if Game.buy(id):
        Game.equip(id)
    _build_shop()


func _on_equip(id: String) -> void:
    Game.equip(id)
    _build_shop()


func _on_logout() -> void:
    Game.save()
    Supabase.sign_out()
    Game.go_to_login()
