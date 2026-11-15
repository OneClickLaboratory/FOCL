class_name PlaceBase
extends Node3D
## Базовый класс плейса: небо + солнце (реагируют на `time set`), игрок, HUD, меню Esc.
## Чтобы сделать новый плейс: унаследуйся и переопредели _build_world().

const PauseMenu := preload("res://scripts/pause_menu.gd")

var player: Player
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var spawn_point := Vector3(0, 2, 0)

var focls_label: Label
var toast_label: Label
var toast_tween: Tween


func _ready() -> void:
    _setup_environment()
    _build_world()
    add_trigger(Vector3(0, -25, 0), Vector3(800, 2, 800), _kill_player)  # "бездна"
    _spawn_player()
    _setup_ui()
    Game.time_changed.connect(_apply_time)
    _apply_time(Game.time_of_day)


func _build_world() -> void:
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
    var hud := CanvasLayer.new()
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

    var hint := Label.new()
    hint.text = "WASD - ходьба   Пробел - прыжок   ПКМ - камера   Колесо - зум   Esc - меню   ` - консоль"
    hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hint.offset_top = -34
    hint.offset_left = 14
    hint.add_theme_color_override("font_outline_color", Color.BLACK)
    hint.add_theme_constant_override("outline_size", 4)
    hint.modulate = Color(1, 1, 1, 0.8)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hint)

    toast_label = Label.new()
    toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    toast_label.offset_top = 70
    toast_label.offset_bottom = 120
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 30)
    toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
    toast_label.add_theme_constant_override("outline_size", 6)
    toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_label.modulate.a = 0.0
    hud.add_child(toast_label)

    add_child(PauseMenu.new())


func _on_focls_changed(v: int) -> void:
    focls_label.text = "%d Focls" % v


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
