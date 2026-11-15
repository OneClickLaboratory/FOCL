extends Control
## Экран входа / регистрации (Supabase).

var email_edit: LineEdit
var pass_edit: LineEdit
var status: Label
var login_btn: Button
var reg_btn: Button
var guest_btn: Button


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build_ui()
    Supabase.auth_result.connect(_on_auth_result)

    if Supabase.is_configured():
        _set_busy(true)
        status.text = "Проверка сохранённой сессии..."
        if await Supabase.try_restore():
            _enter()
            return
        _set_busy(false)
        status.text = ""
    else:
        status.text = "Supabase не настроен: заполни supabase_config.cfg. Пока можно войти как гость."


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.09, 0.1, 0.14)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(400, 0)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.15, 0.16, 0.21)
    sb.set_corner_radius_all(12)
    sb.set_content_margin_all(24)
    card.add_theme_stylebox_override("panel", sb)
    center.add_child(card)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)

    var title := Label.new()
    title.text = "ROBLOX CLONE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)

    var sub := Label.new()
    sub.text = "Вход или регистрация"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.modulate = Color(1, 1, 1, 0.6)
    box.add_child(sub)

    email_edit = LineEdit.new()
    email_edit.placeholder_text = "Email"
    box.add_child(email_edit)

    pass_edit = LineEdit.new()
    pass_edit.placeholder_text = "Пароль (минимум 6 символов)"
    pass_edit.secret = true
    pass_edit.text_submitted.connect(func(_t: String) -> void: _on_login())
    box.add_child(pass_edit)

    login_btn = Button.new()
    login_btn.text = "Войти"
    login_btn.pressed.connect(_on_login)
    box.add_child(login_btn)

    reg_btn = Button.new()
    reg_btn.text = "Зарегистрироваться"
    reg_btn.pressed.connect(_on_register)
    box.add_child(reg_btn)

    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size = Vector2(350, 40)
    box.add_child(status)

    box.add_child(HSeparator.new())

    guest_btn = Button.new()
    guest_btn.text = "Играть как гость (без аккаунта)"
    guest_btn.pressed.connect(_on_guest)
    box.add_child(guest_btn)


func _set_busy(busy: bool) -> void:
    login_btn.disabled = busy
    reg_btn.disabled = busy


func _validate() -> bool:
    if not Supabase.is_configured():
        status.text = "Supabase не настроен (supabase_config.cfg)."
        return false
    if not email_edit.text.contains("@"):
        status.text = "Введите корректный email."
        return false
    if pass_edit.text.length() < 6:
        status.text = "Пароль должен быть не короче 6 символов."
        return false
    return true


func _on_login() -> void:
    if not _validate():
        return
    _set_busy(true)
    status.text = "Входим..."
    Supabase.sign_in(email_edit.text.strip_edges(), pass_edit.text)


func _on_register() -> void:
    if not _validate():
        return
    _set_busy(true)
    status.text = "Создаём аккаунт..."
    Supabase.sign_up(email_edit.text.strip_edges(), pass_edit.text)


func _on_guest() -> void:
    Game.load_profile("guest", "Гость")
    get_tree().change_scene_to_file(Game.MENU_SCENE)


func _on_auth_result(ok: bool, message: String, logged_in: bool) -> void:
    _set_busy(false)
    status.text = message
    status.modulate = Color(0.5, 1, 0.6) if ok else Color(1, 0.5, 0.5)
    if ok and logged_in:
        _enter()


func _enter() -> void:
    Game.load_profile(Supabase.user_id, Supabase.display_name())
    get_tree().change_scene_to_file(Game.MENU_SCENE)
