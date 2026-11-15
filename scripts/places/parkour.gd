extends PlaceBase
## Тестовый плейс "Parkour": платформы, балка, зигзаг, движущаяся платформа,
## красные блоки, лестница и финиш с наградой в Focls.

const FINISH_REWARD := 50

var cz := -6.0   # текущая позиция по Z (край последней платформы)
var cy := 0.0    # текущая высота верхней грани
var idx := 0
var finished := false


func _build_world() -> void:
    spawn_point = Vector3(0, 1.5, 0)

    # Старт
    add_box(Vector3(0, -0.5, 0), Vector3(12, 1, 12), Color(0.3, 0.7, 0.35))
    add_sign("START", Vector3(0, 4, 3))

    # 1) Камни разной высоты
    var xs := [0.0, 2.0, -2.0, 1.5, -1.5, 0.0]
    var dys := [0.0, 0.5, 0.5, 0.0, 0.5, 0.0]
    for i in xs.size():
        stone(xs[i], dys[i], 3.0, 3.0)

    # 2) Узкая балка
    stone(0.0, 0.0, 1.2, 3.0, 12.0)

    # 3) Чекпоинт
    stone(0.0, 0.0, 8.0, 3.0, 8.0, Color(0.3, 0.8, 0.9))
    _checkpoint(Vector3(0, cy, cz + 4.0))

    # 4) Зигзаг
    for i in 6:
        stone(2.5 if i % 2 == 0 else -2.5, 0.0, 2.5, 2.5)

    # 5) Движущаяся платформа через пропасть
    stone(0.0, 0.0, 6.0, 3.0, 6.0, Color(0.9, 0.7, 0.3))
    _moving_platform(cz)
    stone(0.0, 0.0, 6.0, 16.0, 6.0, Color(0.3, 0.8, 0.9))
    _checkpoint(Vector3(0, cy, cz + 3.0))

    # 6) Красные блоки на полу - перепрыгивай!
    stone(0.0, 0.0, 8.0, 3.0, 20.0, Color(0.85, 0.85, 0.9))
    var zc := cz + 10.0
    for o in [-7.0, -3.0, 1.0, 5.0, 8.0]:
        add_kill_brick(Vector3(0, cy + 0.2, zc + o), Vector3(8, 0.4, 1))

    # 7) Лестница вверх
    for i in 6:
        stone(0.0, 1.0, 3.0, 2.5, 3.0)

    # 8) Финиш
    stone(0.0, 0.5, 10.0, 3.0, 10.0, Color(1.0, 0.8, 0.2))
    add_sign("FINISH", Vector3(0, cy + 4, cz + 5))
    add_trigger(Vector3(0, cy + 1.5, cz + 5), Vector3(10, 3, 10), _on_finish)


func stone(x: float, dy: float, size: float, gap: float, length := -1.0, color := Color(0, 0, 0, 0)) -> void:
    if length < 0.0:
        length = size
    if color.a == 0.0:
        color = Color.from_hsv(fmod(idx * 0.07, 1.0), 0.45, 0.95)
    idx += 1
    cz -= gap + length / 2.0
    cy += dy
    add_box(Vector3(x, cy - 0.5, cz), Vector3(size, 1.0, length), color)
    cz -= length / 2.0


func _moving_platform(near_z: float) -> void:
    var body := AnimatableBody3D.new()
    body.sync_to_physics = true
    body.position = Vector3(0, cy - 0.5, near_z - 2.5)
    _attach_box(body, Vector3(4, 1, 4), Color(1.0, 0.5, 0.2))
    add_child(body)
    var tw := body.create_tween().set_loops()
    tw.tween_property(body, "position:z", near_z - 13.5, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_interval(0.5)
    tw.tween_property(body, "position:z", near_z - 2.5, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_interval(0.5)


func _checkpoint(pos: Vector3) -> void:
    var respawn := pos + Vector3(0, 1.5, 0)
    add_box(Vector3(pos.x + 3.0, pos.y + 1.0, pos.z), Vector3(0.2, 2.0, 0.2), Color(1, 0.9, 0.2))
    add_trigger(pos + Vector3(0, 1.5, 0), Vector3(8, 3, 8), _on_checkpoint.bind(respawn))


func _on_checkpoint(p: Player, respawn: Vector3) -> void:
    if p.spawn_position != respawn:
        p.spawn_position = respawn
        show_toast("Чекпоинт сохранён")


func _on_finish(_p: Player) -> void:
    if finished:
        return
    finished = true
    Game.add_focls(FINISH_REWARD)
    show_toast("Финиш! +%d Focls" % FINISH_REWARD)
