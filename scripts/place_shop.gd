extends CanvasLayer
## Магазин плейса - общая система для креаторов: товары берутся из
## place.shop_items(), покупка - Game.buy_item, владение - Game.has_item.
## Открывается клавишей B. Перед списанием показывается окно подтверждения оплаты.

const SIZE := Vector2(640, 500)

var place  # PlaceBase-плейс, которому принадлежит магазин (без типа - динамический доступ)

var panel: Panel
var balance_label: Label
var items_box: VBoxContainer
var empty_label: Label
var confirm_panel: Control
var confirm_name: Label
var confirm_price: Label
var confirm_balance: Label
var confirm_error: Label
var pay_btn: Button
var pending: Dictionary = {}


func _ready() -> void:
    layer = 40
    Game.focls_changed.connect(_on_focls_changed)
    _build_panel()
    _build_confirm()
    _on_focls_changed(Game.focls)
    panel.visible = false


func _input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k == null or not k.pressed or k.echo:
        return
    if Game.console_open or Game.pause_open:
        return
    if k.physical_keycode == KEY_B and not confirm_panel.visible:
        set_open(not panel.visible)
        get_viewport().set_input_as_handled()
    elif k.keycode == KEY_ESCAPE and panel.visible:
        if confirm_panel.visible:
            _hide_confirm()
        else:
            set_open(false)
        get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
    panel.visible = value
    Game.shop_open = value
    if value:
        _hide_confirm()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        _refresh()


# ---------- окно списка товаров ----------
func _build_panel() -> void:
    panel = Panel.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left = -SIZE.x / 2.0
    panel.offset_right = SIZE.x / 2.0
    panel.offset_top = -SIZE.y / 2.0
    panel.offset_bottom = SIZE.y / 2.0
    panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    margin.add_child(box)

    var title_row := HBoxContainer.new()
    box.add_child(title_row)
    var title := Label.new()
    title.text = "🛒  Магазин плейса"
    title.add_theme_font_size_override("font_size", 26)
    title_row.add_child(title)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(spacer)
    var close_btn := Button.new()
    close_btn.text = "✕  Закрыть"
    close_btn.pressed.connect(set_open.bind(false))
    title_row.add_child(close_btn)

    balance_label = Label.new()
    balance_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
    balance_label.add_theme_font_size_override("font_size", 20)
    box.add_child(balance_label)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)
    items_box = VBoxContainer.new()
    items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    items_box.add_theme_constant_override("separation", 10)
    scroll.add_child(items_box)

    empty_label = Label.new()
    empty_label.text = "В этом плейсе пока нет товаров."
    empty_label.modulate = Color(1, 1, 1, 0.5)
    empty_label.visible = false
    box.add_child(empty_label)

    var hint := Label.new()
    hint.text = "B / Esc - закрыть"
    hint.modulate = Color(1, 1, 1, 0.45)
    box.add_child(hint)


func _refresh() -> void:
    for c in items_box.get_children():
        c.queue_free()
    var items: Array = place.shop_items() if place else []
    empty_label.visible = items.is_empty()
    for item in items:
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel", _card_style())
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        card.add_child(row)

        var swatch := ColorRect.new()
        swatch.color = item["color"]
        swatch.custom_minimum_size = Vector2(52, 52)
        row.add_child(swatch)

        var mid := VBoxContainer.new()
        mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mid.add_theme_constant_override("separation", 4)
        row.add_child(mid)
        var name_l := Label.new()
        name_l.text = str(item["name"])
        name_l.add_theme_font_size_override("font_size", 19)
        mid.add_child(name_l)
        var desc := Label.new()
        desc.text = str(item["desc"])
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.modulate = Color(1, 1, 1, 0.65)
        mid.add_child(desc)

        var price: int = item["price"]
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(190, 0)
        if Game.has_item(str(item["id"])):
            btn.text = "Куплено ✓"
            btn.disabled = true
        else:
            btn.text = "Купить\n%d Focls" % price
            btn.disabled = Game.focls < price
            btn.pressed.connect(_ask_confirm.bind(item))
        row.add_child(btn)
        items_box.add_child(card)


# ---------- окно подтверждения оплаты ----------
func _build_confirm() -> void:
    confirm_panel = Control.new()
    confirm_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_child(confirm_panel)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirm_panel.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    confirm_panel.add_child(center)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(380, 0)
    card.add_theme_stylebox_override("panel", _card_style())
    center.add_child(card)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)

    var title := Label.new()
    title.text = "ПОДТВЕРЖДЕНИЕ ОПЛАТЫ"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 21)
    title.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
    box.add_child(title)
    box.add_child(HSeparator.new())

    confirm_name = Label.new()
    confirm_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirm_name.add_theme_font_size_override("font_size", 22)
    box.add_child(confirm_name)

    confirm_price = Label.new()
    confirm_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(confirm_price)

    confirm_balance = Label.new()
    confirm_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirm_balance.modulate = Color(1, 1, 1, 0.7)
    box.add_child(confirm_balance)

    confirm_error = Label.new()
    confirm_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    confirm_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirm_error.custom_minimum_size = Vector2(340, 0)
    confirm_error.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
    box.add_child(confirm_error)

    box.add_child(HSeparator.new())
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    box.add_child(buttons)
    var cancel_btn := Button.new()
    cancel_btn.text = "Отмена"
    cancel_btn.custom_minimum_size = Vector2(140, 44)
    cancel_btn.pressed.connect(_hide_confirm)
    buttons.add_child(cancel_btn)
    pay_btn = Button.new()
    pay_btn.custom_minimum_size = Vector2(200, 44)
    pay_btn.pressed.connect(_on_pay)
    buttons.add_child(pay_btn)

    confirm_panel.visible = false


func _ask_confirm(item: Dictionary) -> void:
    pending = item
    var price: int = item["price"]
    var enough := Game.focls >= price
    confirm_name.text = str(item["name"])
    confirm_price.text = "Цена: %d Focls" % price
    confirm_balance.text = "Баланс: %d → %d Focls" % [Game.focls, Game.focls - price]
    pay_btn.text = "Оплатить %d Focls" % price
    pay_btn.disabled = not enough
    confirm_error.visible = not enough
    if not enough:
        confirm_error.text = "Не хватает %d Focls - заработай их в этом плейсе!" % (price - Game.focls)
    confirm_panel.visible = true


func _hide_confirm() -> void:
    confirm_panel.visible = false
    pending = {}


func _on_pay() -> void:
    if pending.is_empty():
        return
    if Game.buy_item(str(pending["id"])):
        _hide_confirm()
        _refresh()


func _on_focls_changed(v: int) -> void:
    balance_label.text = "Твой баланс: %d Focls" % v
    if panel.visible and not confirm_panel.visible:
        _refresh()


# ---------- стили ----------
func _panel_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.12, 0.92)
    sb.set_corner_radius_all(12)
    sb.border_color = Color(1, 0.82, 0.25, 0.35)
    sb.set_border_width_all(1)
    return sb


func _card_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.15, 0.16, 0.21)
    sb.set_corner_radius_all(10)
    sb.set_content_margin_all(14)
    return sb
