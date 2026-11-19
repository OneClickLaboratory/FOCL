extends CanvasLayer
## Меню по Esc: фиксированный размер, полупрозрачное. Список игроков, Reset, Выйти.

const SIZE := Vector2(420, 520)

var panel: Panel
var list_box: VBoxContainer
var count_label: Label


func _ready() -> void:
    layer = 50
    panel = Panel.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left = -SIZE.x / 2.0
    panel.offset_right = SIZE.x / 2.0
    panel.offset_top = -SIZE.y / 2.0
    panel.offset_bottom = SIZE.y / 2.0
    panel.clip_contents = true
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.12, 0.78)
    sb.set_corner_radius_all(12)
    sb.border_color = Color(1, 1, 1, 0.15)
    sb.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel", sb)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    margin.add_child(box)

    var title := Label.new()
    title.text = "Меню"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    box.add_child(HSeparator.new())

    count_label = Label.new()
    box.add_child(count_label)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)
    list_box = VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list_box)

    var reset_btn := Button.new()
    reset_btn.text = "Reset (убить персонажа)"
    reset_btn.custom_minimum_size.y = 42
    reset_btn.pressed.connect(_on_reset)
    box.add_child(reset_btn)

    var leave_btn := Button.new()
    leave_btn.text = "Выйти из плейса"
    leave_btn.custom_minimum_size.y = 42
    leave_btn.pressed.connect(_on_leave)
    box.add_child(leave_btn)

    panel.visible = false


func _input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
        return
    if Game.console_open or Game.shop_open:
        return  # Esc закроет консоль или магазин
    set_open(not panel.visible)
    get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
    panel.visible = value
    Game.pause_open = value
    if value:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        _refresh_players()


func _refresh_players() -> void:
    for c in list_box.get_children():
        c.queue_free()
    var names := Game.get_player_names()
    count_label.text = "Игроки (%d)" % names.size()
    for n in names:
        var l := Label.new()
        l.text = "●  " + str(n) + ("  (вы)" if n == Game.username else "")
        l.add_theme_font_size_override("font_size", 18)
        list_box.add_child(l)


func _on_reset() -> void:
    var p := get_tree().get_first_node_in_group("player")
    if p:
        p.die()
    set_open(false)


func _on_leave() -> void:
    Game.save()
    Game.go_to_menu()
