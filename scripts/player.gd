class_name Player
extends CharacterBody3D
## Персонаж в стиле Roblox: ходьба (WASD/стрелки), прыжок (Пробел),
## камера от третьего лица (ПКМ - вращение, колесо - зум).

signal died
signal flying_changed(on: bool)
signal hp_changed(hp: float, max_hp: float)

const SPEED := 9.0
const FLY_SPEED := 14.0
const ACCEL := 60.0
const JUMP_VELOCITY := 10.5
const GRAVITY := 28.0
const RESPAWN_TIME := 2.0

var spawn_position := Vector3(0, 2, 0)
var dead := false
var flying := false
var fly_time := 0.0
var max_hp := 100.0
var hp := 100.0
var respawn_enabled := true

var yaw := 0.0
var pitch := -0.35
var zoom := 9.0

var model: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var cam_rig: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var walk_phase := 0.0


func _ready() -> void:
    add_to_group("player")
    var col := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.4
    cap.height = 2.0
    col.shape = cap
    col.position.y = 1.0
    add_child(col)
    _build_model()
    _build_camera()


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
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


func _pivot(parent: Node, pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    parent.add_child(n)
    return n


func _build_model() -> void:
    model = Node3D.new()
    add_child(model)
    var skin := Color(0.96, 0.8, 0.45)
    var legs := Color(0.25, 0.3, 0.4)

    _box(model, Vector3(0.8, 0.8, 0.4), Vector3(0, 1.1, 0), Game.equipped_color())
    var head := _box(model, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.75, 0), skin)
    _box(head, Vector3(0.08, 0.1, 0.02), Vector3(-0.12, 0.05, -0.255), Color.BLACK)
    _box(head, Vector3(0.08, 0.1, 0.02), Vector3(0.12, 0.05, -0.255), Color.BLACK)

    left_leg = _pivot(model, Vector3(-0.2, 0.7, 0))
    right_leg = _pivot(model, Vector3(0.2, 0.7, 0))
    _box(left_leg, Vector3(0.38, 0.7, 0.38), Vector3(0, -0.35, 0), legs)
    _box(right_leg, Vector3(0.38, 0.7, 0.38), Vector3(0, -0.35, 0), legs)

    left_arm = _pivot(model, Vector3(-0.55, 1.5, 0))
    right_arm = _pivot(model, Vector3(0.55, 1.5, 0))
    _box(left_arm, Vector3(0.28, 0.8, 0.36), Vector3(0, -0.4, 0), skin)
    _box(right_arm, Vector3(0.28, 0.8, 0.36), Vector3(0, -0.4, 0), skin)


func _build_camera() -> void:
    cam_rig = Node3D.new()
    cam_rig.top_level = true
    add_child(cam_rig)
    cam_pitch = Node3D.new()
    cam_rig.add_child(cam_pitch)
    spring = SpringArm3D.new()
    spring.spring_length = zoom
    spring.margin = 0.3
    spring.add_excluded_object(get_rid())
    cam_pitch.add_child(spring)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 70.0
    spring.add_child(camera)
    _update_camera()


func _update_camera() -> void:
    cam_rig.global_position = global_position + Vector3(0, 1.8, 0)
    cam_rig.rotation.y = yaw
    cam_pitch.rotation.x = pitch
    spring.spring_length = zoom


# ---------- полёт (общая возможность; креатор включает через set_flying) ----------
func set_flying(on: bool) -> void:
    if on == flying or dead:
        return
    flying = on
    if on:
        velocity.y = maxf(velocity.y, 3.0)
    else:
        model.position.y = 0.0
    flying_changed.emit(on)


# ---------- здоровье (общая система; креатор вызывает hurt/heal/set_max_hp) ----------
func set_max_hp(v: float) -> void:
    max_hp = maxf(v, 1.0)
    hp = minf(hp, max_hp)
    hp_changed.emit(hp, max_hp)


func heal(amount: float) -> void:
    if dead:
        return
    hp = minf(hp + amount, max_hp)
    hp_changed.emit(hp, max_hp)


func hurt(amount: float) -> void:
    if dead:
        return
    hp = maxf(hp - amount, 0.0)
    hp_changed.emit(hp, max_hp)
    if hp <= 0.0:
        die()


func _unhandled_input(event: InputEvent) -> void:
    if Game.is_ui_blocked():
        return
    var mb := event as InputEventMouseButton
    if mb:
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom = maxf(2.0, zoom - 1.0)
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom = minf(20.0, zoom + 1.0)
    var mm := event as InputEventMouseMotion
    if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= mm.relative.x * 0.004
        pitch = clampf(pitch - mm.relative.y * 0.004, -1.3, 0.6)


func _physics_process(delta: float) -> void:
    var blocked := Game.is_ui_blocked()
    if blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    if flying:
        var up := 0.0
        if not dead and not blocked:
            up = float(_key(KEY_SPACE)) - float(_key(KEY_SHIFT))
        velocity.y = move_toward(velocity.y, up * FLY_SPEED, ACCEL * delta)
        fly_time += delta
        model.position.y = sin(fly_time * 2.5) * 0.04  # лёгкое парение
    elif not is_on_floor():
        velocity.y -= GRAVITY * delta

    var input_dir := Vector2.ZERO
    if not dead and not blocked:
        input_dir.x = float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT))
        input_dir.y = float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP))
        if not flying and _key(KEY_SPACE) and is_on_floor():
            velocity.y = JUMP_VELOCITY

    var dir := Vector3.ZERO
    if input_dir != Vector2.ZERO:
        dir = (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed := FLY_SPEED if flying else SPEED
    velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * delta)
    velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * delta)
    move_and_slide()

    _animate(delta, dir)
    _update_camera()

    if global_position.y < -40.0:
        die()


func _key(code: Key) -> bool:
    return Input.is_physical_key_pressed(code)


func _animate(delta: float, dir: Vector3) -> void:
    if dead:
        return
    if flying:
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 1.35, 10.0 * delta)
        right_leg.rotation.x = lerpf(right_leg.rotation.x, 1.35, 10.0 * delta)
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.45, 10.0 * delta)
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.45, 10.0 * delta)
        return
    var speed := Vector2(velocity.x, velocity.z).length()
    if dir != Vector3.ZERO:
        model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 14.0 * delta)
    walk_phase += delta * speed * 1.4
    var amp := clampf(speed / SPEED, 0.0, 1.0) * 0.9
    var swing := sin(walk_phase) * amp
    if is_on_floor():
        left_leg.rotation.x = swing
        right_leg.rotation.x = -swing
        left_arm.rotation.x = -swing
        right_arm.rotation.x = swing
    else:
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.3, 10.0 * delta)
        right_leg.rotation.x = lerpf(right_leg.rotation.x, -0.3, 10.0 * delta)
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 2.6, 10.0 * delta)
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 2.6, 10.0 * delta)


func die() -> void:
    if dead:
        return
    set_flying(false)
    dead = true
    died.emit()
    if not respawn_enabled:
        return
    var tw := create_tween()
    tw.tween_property(model, "rotation:x", -PI / 2.0, 0.35)
    tw.tween_interval(RESPAWN_TIME - 0.35)
    tw.tween_callback(respawn)


func respawn() -> void:
    dead = false
    set_flying(false)
    model.rotation.x = 0.0
    position = spawn_position
    velocity = Vector3.ZERO
    hp = max_hp
    hp_changed.emit(hp, max_hp)
