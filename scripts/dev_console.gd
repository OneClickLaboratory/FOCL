extends CanvasLayer
## Консоль разработчика. Открывается клавишей ` (Ё) или F1.

var panel: Panel
var log_label: RichTextLabel
var input: LineEdit
var fps_label: Label
var history: Array[String] = []
var hist_pos := 0


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS

    panel = Panel.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_bottom = 320
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0.78)
    panel.add_theme_stylebox_override("panel", sb)
    add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
    panel.add_child(vbox)

    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.scroll_following = true
    log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(log_label)

    input = LineEdit.new()
    input.placeholder_text = "Введите команду (help)"
    input.text_submitted.connect(_on_submit)
    vbox.add_child(input)

    fps_label = Label.new()
    fps_label.position = Vector2(10, 8)
    fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
    fps_label.add_theme_constant_override("outline_size", 5)
    fps_label.add_theme_font_size_override("font_size", 18)
    fps_label.visible = false
    add_child(fps_label)

    panel.visible = false
    _print("[color=cyan]Консоль. Введите help для списка команд.[/color]")


func _process(_delta: float) -> void:
    fps_label.visible = Game.show_fps
    if Game.show_fps:
        fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k == null or not k.pressed or k.echo:
        return
    if k.physical_keycode == KEY_QUOTELEFT or k.keycode == KEY_F1:
        toggle_console()
        get_viewport().set_input_as_handled()
    elif panel.visible and k.keycode == KEY_ESCAPE:
        toggle_console()
        get_viewport().set_input_as_handled()
    elif panel.visible and k.keycode == KEY_UP:
        _history_step(-1)
        get_viewport().set_input_as_handled()
    elif panel.visible and k.keycode == KEY_DOWN:
        _history_step(1)
        get_viewport().set_input_as_handled()


func toggle_console() -> void:
    panel.visible = not panel.visible
    Game.console_open = panel.visible
    if panel.visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        input.clear()
        input.grab_focus()
    else:
        input.release_focus()


func _history_step(dir: int) -> void:
    if history.is_empty():
        return
    hist_pos = clampi(hist_pos + dir, 0, history.size())
    input.text = history[hist_pos] if hist_pos < history.size() else ""
    input.caret_column = input.text.length()


func _print(text: String) -> void:
    log_label.append_text(text + "\n")


func _on_submit(text: String) -> void:
    input.clear()
    if text.strip_edges() == "":
        return
    history.append(text)
    hist_pos = history.size()
    _print("[color=gray]> " + text.replace("[", "[lb]") + "[/color]")
    run_command(text)
    input.grab_focus()


func run_command(text: String) -> void:
    var parts := text.strip_edges().split(" ", false)
    if parts.is_empty():
        return
    match parts[0].to_lower():
        "help":
            _print("[color=yellow]Команды:[/color]")
            _print("  help               - список команд")
            _print("  time set <0-24>    - установить время суток (например: time set 18.5 или time set 6:30)")
            _print("  fps_show [on|off]  - показать/скрыть счётчик FPS")
            _print("  reset              - убить персонажа (он возродится на последнем чекпоинте)")
            _print("  focls <n>          - выдать себе Focls")
            _print("  give <id>          - выдать игровой товар (бесплатно)")
            _print("  items              - список товаров магазина")
            _print("  quit               - закрыть игру")
        "time":
            _cmd_time(parts)
        "fps_show":
            if parts.size() > 1:
                Game.show_fps = parts[1].to_lower() in ["on", "1", "true"]
            else:
                Game.show_fps = not Game.show_fps
            _print("FPS: " + ("включён" if Game.show_fps else "выключен"))
        "reset":
            var p := get_tree().get_first_node_in_group("player")
            if p and p.has_method("die"):
                p.die()
                _print("Персонаж сброшен.")
            else:
                _print("[color=red]Нет персонажа (вы не в плейсе).[/color]")
        "focls":
            if parts.size() > 1 and parts[1].is_valid_int():
                Game.add_focls(parts[1].to_int())
                _print("Баланс: %d Focls" % Game.focls)
            else:
                _print("[color=red]Использование: focls <число>[/color]")
        "give":
            _cmd_give(parts)
        "items":
            if Game.item_catalog.is_empty():
                _print("Товары не найдены - они регистрируются при входе в плейс.")
            for item in Game.item_catalog:
                _print("  %s - %s, %d Focls%s" % [item["id"], item["name"], int(item["price"]), "  [куплено]" if Game.has_item(str(item["id"])) else ""])
        "quit":
            get_tree().quit()
        _:
            _print("[color=red]Неизвестная команда. Введите help.[/color]")


func _cmd_give(parts: PackedStringArray) -> void:
    if parts.size() < 2:
        _print("[color=red]Использование: give <id>[/color]")
        return
    var id := parts[1]
    if Game.item_def(id).is_empty():
        _print("[color=red]Нет товара с id \"%s\" (список: items)[/color]" % id)
    elif Game.has_item(id):
        _print("Товар \"%s\" уже выдан." % id)
    else:
        Game.items_owned.append(id)
        Game.save()
        Game.item_purchased.emit(id)
        _print("Выдан товар \"%s\"." % id)


func _cmd_time(parts: PackedStringArray) -> void:
    if parts.size() == 1:
        _print("Текущее время: %.2f ч" % Game.time_of_day)
        return
    if parts[1].to_lower() != "set" or parts.size() < 3:
        _print("[color=red]Использование: time set <0-24>[/color]")
        return
    var arg := parts[2]
    var hours := -1.0
    if ":" in arg:
        var hm := arg.split(":")
        if hm.size() == 2 and hm[0].is_valid_int() and hm[1].is_valid_int():
            hours = hm[0].to_int() + hm[1].to_int() / 60.0
    elif arg.is_valid_float():
        hours = arg.to_float()
    if hours < 0.0 or hours > 24.0:
        _print("[color=red]Время должно быть числом от 0 до 24.[/color]")
        return
    Game.set_time(hours)
    _print("Время установлено: %.2f ч" % hours)
