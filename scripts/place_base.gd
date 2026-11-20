class_name PlaceBase
extends Node3D
## Базовый класс плейса: небо + солнце (реагируют на `time set`), игрок, HUD, меню Esc.
## Чтобы сделать новый плейс: унаследуйся и переопредели _build_world().

const PauseMenu := preload("res://scripts/pause_menu.gd")
const PlaceShop := preload("res://scripts/place_shop.gd")
const ItemPickupScript := preload("res://scripts/item_pickup.gd")

var player: Player
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var spawn_point := Vector3(0, 2, 0)

var shop  # PlaceShop; тип не указан - создаётся в _setup_ui
var hud: CanvasLayer
var hotbar: HBoxContainer
var hotbar_slots: Array = []
var focls_label: Label
var hint_label: Label
var toast_label: Label
var toast_tween: Tween


func _ready() -> void:
    for p in Game.PLACES:
        if p["scene"] == scene_file_path:
            Game.current_place_id = str(p["id"])
    for item in shop_items():
        Game.define_item(item)
    _setup_environment()
    _build_world()
    add_trigger(Vector3(0, -25, 0), Vector3(800, 2, 800), _kill_player)  # "бездна"
    _spawn_player()
    _on_player_spawned()
    _setup_ui()
    Game.time_changed.connect(_apply_time)
    _apply_time(Game.time_of_day)


func _build_world() -> void:
    pass


# ===== API для креаторов плейсов =====
## Товары твоего плейса, продающиеся в магазине (клавиша B). Пример:
##   func shop_items() -> Array:
##       return [{"id": "jetpack", "name": "Джетпак", "price": 200,
##                "desc": "Летай по плейсу", "color": Color(0.3, 0.6, 1.0)}]
func shop_items() -> Array:
    return []


## Вызывается после успешной покупки товара этого плейса - выдай возможность.
func on_item_purchased(item: Dictionary) -> void:
    pass


## Вызывается после создания игрока - удобно подключить его сигналы.
func _on_player_spawned() -> void:
    pass


# ---------- окружение ----------
func _setup_environment() -> void:
    sun = DirectionalLight3D.new()
    sun.shadow_enabled = true
    add_child(sun)
    sky_mat = ProceduralSkyMaterial.new()
    var sky := Sky.new()
    sky.sky_material = sky_mat
    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)


func _apply_time(h: float) -> void:
    var angle := (h - 6.0) / 24.0 * TAU
    var e := sin(angle)
    sun.rotation = Vector3(-angle, deg_to_rad(-35.0), 0.0)
    sun.visible = e > 0.0
    sun.light_energy = clampf(e * 1.5, 0.0, 1.0)
    sun.light_color = Color(1.0, 0.6, 0.35).lerp(Color(1.0, 0.97, 0.9), clampf(e * 2.0, 0.0, 1.0))
    var day := clampf(e * 3.0 + 0.5, 0.0, 1.0)
    sky_mat.sky_top_color = Color(0.02, 0.03, 0.08).lerp(Color(0.25, 0.5, 0.9), day)
    sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.15).lerp(Color(0.65, 0.8, 0.95), day)
    sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
    sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.05).lerp(Color(0.3, 0.3, 0.35), day)
    sky_mat.sky_energy_multiplier = lerpf(0.3, 1.0, day)
    env.ambient_light_energy = lerpf(0.2, 1.0, day)


# ---------- игрок ----------
func _spawn_player() -> void:
    player = Player.new()
    player.spawn_position = spawn_point
    player.position = spawn_point
    add_child(player)


func _kill_player(p: Player) -> void:
    p.die()


# ---------- UI ----------
func _setup_ui() -> void:
    hud = CanvasLayer.new()
    hud.layer = 10
    add_child(hud)

    focls_label = Label.new()
    focls_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    focls_label.offset_right = -16
    focls_label.offset_top = 10
    focls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    focls_label.add_theme_font_size_override("font_size", 22)
    focls_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
    focls_label.add_theme_color_override("font_outline_color", Color.BLACK)
    focls_label.add_theme_constant_override("outline_size", 5)
    focls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(focls_label)
    Game.focls_changed.connect(_on_focls_changed)
    _on_focls_changed(Game.focls)

    hint_label = Label.new()
    hint_label.text = _hint_text()
    hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hint_label.offset_top = -34
    hint_label.offset_left = 14
    hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
    hint_label.add_theme_constant_override("outline_size", 4)
    hint_label.modulate = Color(1, 1, 1, 0.8)
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hint_label)

    toast_label = Label.new()
    toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    toast_label.offset_top = 70
    toast_label.offset_bottom = 120
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 30)
    toast_label.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
    toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
    toast_label.add_theme_constant_override("outline_size", 6)
    toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_label.modulate.a = 0.0
    hud.add_child(toast_label)

    add_child(PauseMenu.new())
    shop = PlaceShop.new()
    shop.place = self
    add_child(shop)
    Game.item_purchased.connect(_on_game_item_purchased)
    player.drop_requested.connect(_on_drop_requested)
    if player.inventory_enabled:
        _build_hotbar()


func _on_focls_changed(v: int) -> void:
    focls_label.text = "%d Focls" % v


func _hint_text() -> String:
    var t := "WASD - ходьба   Пробел - прыжок   ПКМ - камера   Колесо - зум   Esc - меню   ` - консоль"
    if not shop_items().is_empty():
        t += "   B - магазин"
    if player.inventory_enabled:
        t += "   1-8 - слоты   E - подобрать   V - использовать   G - выбросить"
    return t


func _on_game_item_purchased(id: String) -> void:
    var item := Game.item_def(id)
    if item.is_empty() or str(item.get("place", "")) != Game.current_place_id:
        return
    show_toast("Куплено: %s" % str(item["name"]))
    hint_label.text = _hint_text()
    on_item_purchased(item)


func show_toast(text: String) -> void:
    toast_label.text = text
    toast_label.modulate.a = 1.0
    if toast_tween:
        toast_tween.kill()
    toast_tween = create_tween()
    toast_tween.tween_interval(2.0)
    toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


# ---------- хелперы для построения мира ----------
func _attach_box(body: Node3D, size: Vector3, color: Color, emissive := false) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.6
    bm.material = mat
    mi.mesh = bm
    body.add_child(mi)
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    body.add_child(cs)


func add_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    _attach_box(body, size, color)
    add_child(body)
    return body


## Блок без коллизии - для визуальных деталей, крепящихся к игроку (ковры, шляпы).
func add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.7
    bm.material = mat
    mi.mesh = bm
    mi.position = pos
    parent.add_child(mi)
    return mi


func add_kill_brick(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    _attach_box(body, size, Color(0.95, 0.1, 0.1), true)
    add_child(body)
    add_trigger(pos, size + Vector3(0.3, 0.3, 0.3), _kill_player)


func add_trigger(pos: Vector3, size: Vector3, cb: Callable) -> Area3D:
    var area := Area3D.new()
    area.position = pos
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    area.add_child(cs)
    area.body_entered.connect(_on_trigger_body.bind(cb))
    add_child(area)
    return area


func _on_trigger_body(body: Node3D, cb: Callable) -> void:
    if body is Player:
        cb.call(body)


func add_sign(text: String, pos: Vector3) -> void:
    var l := Label3D.new()
    l.text = text
    l.position = pos
    l.font_size = 96
    l.pixel_size = 0.01
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.outline_size = 24
    add_child(l)


# ---------- инвентарь: подбор, выброс и хотбар ----------
## Предмет на земле (подбор клавишей E). Спавн: add_pickup(pos, id, count).
func add_pickup(pos: Vector3, id: String, count := 1):
    var p := ItemPickupScript.new()
    p.place = self
    p.item_id = id
    p.count = count
    p.position = pos
    add_child(p)
    return p


func _on_drop_requested(id: String, count: int) -> void:
    var fwd := -player.model.global_basis.z
    var p = add_pickup(player.global_position + fwd * 1.8 + Vector3(0, 0.9, 0), id, count)
    p.grace_t = 1.2


## Хотбар строится автоматически, если у игрока включён inventory_enabled.
func _build_hotbar() -> void:
    hotbar = HBoxContainer.new()
    hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    hotbar.offset_left = -221
    hotbar.offset_right = 221
    hotbar.offset_top = -76
    hotbar.offset_bottom = -26
    hotbar.add_theme_constant_override("separation", 6)
    hud.add_child(hotbar)
    for i in player.inv_slots.size():
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(50, 50)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.06, 0.08, 0.12, 0.88)
        sb.set_corner_radius_all(7)
        sb.set_border_width_all(2)
        sb.border_color = Color(0.9, 0.72, 0.25, 0.22)
        panel.add_theme_stylebox_override("panel", sb)
        panel.set_meta("sb", sb)
        var fill := ColorRect.new()
        fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        fill.offset_left = 7
        fill.offset_top = 7
        fill.offset_right = -7
        fill.offset_bottom = -7
        fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(fill)
        panel.set_meta("fill", fill)
        var count_l := Label.new()
        count_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
        count_l.offset_left = -30
        count_l.offset_top = -22
        count_l.offset_right = -4
        count_l.offset_bottom = -2
        count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        count_l.add_theme_font_size_override("font_size", 15)
        count_l.add_theme_color_override("font_outline_color", Color.BLACK)
        count_l.add_theme_constant_override("outline_size", 4)
        count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(count_l)
        panel.set_meta("count", count_l)
        var key_l := Label.new()
        key_l.text = str(i + 1)
        key_l.position = Vector2(4, 1)
        key_l.add_theme_font_size_override("font_size", 12)
        key_l.modulate = Color(1, 1, 1, 0.55)
        key_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(key_l)
        hotbar.add_child(panel)
        hotbar_slots.append(panel)
    player.inventory_changed.connect(_refresh_hotbar)
    player.slot_selected.connect(func(_i: int) -> void: _refresh_hotbar())
    _refresh_hotbar()


func _refresh_hotbar() -> void:
    for i in hotbar_slots.size():
        var panel: PanelContainer = hotbar_slots[i]
        var fill: ColorRect = panel.get_meta("fill")
        var count_l: Label = panel.get_meta("count")
        var sb: StyleBoxFlat = panel.get_meta("sb")
        var s: Dictionary = player.inv_slots[i]
        if s.is_empty():
            fill.visible = false
            count_l.text = ""
        else:
            fill.visible = true
            fill.color = Game.item_def(str(s["id"])).get("color", Color(1, 1, 1))
            count_l.text = str(int(s["count"])) if int(s["count"]) > 1 else ""
        sb.border_color = Color(1.0, 0.84, 0.4) if i == player.inv_selected else Color(0.9, 0.72, 0.25, 0.22)
