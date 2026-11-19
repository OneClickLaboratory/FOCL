extends PlaceBase
## Пример «игры креатора» на API товаров: паркур, а в магазине (B) продаётся
## ковёр-самолёт. Товар объявлен в shop_items(), поведение - в этом же скрипте.

const FINISH_REWARD := 50
const CARPET_ID := "carpet"

var cz := -6.0   # текущая позиция по Z (край последней платформы)
var cy := 0.0    # текущая высота верхней грани
var idx := 0
var finished := false
var carpet: Node3D


# ----- товары плейса (магазин, клавиша B) -----
func shop_items() -> Array:
	return [{
		"id": CARPET_ID,
		"name": "Ковёр-самолёт",
		"price": 150,
		"desc": "Летающий ковёр из сказки: F - сесть/слезть, WASD - полёт, Пробел - вверх, Shift - вниз.",
		"color": Color(0.85, 0.25, 0.45),
	}]


func on_item_purchased(item: Dictionary) -> void:
	if item["id"] == CARPET_ID:
		show_toast("Жми F, чтобы сесть на ковёр!")


# ----- ковёр: включаем общую возможность полёта у игрока -----
func _on_player_spawned() -> void:
	player.flying_changed.connect(_on_flying_changed)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.physical_keycode != KEY_F:
		return
	if Game.is_ui_blocked() or player == null or player.dead:
		return
	if Game.has_item(CARPET_ID):
		player.set_flying(not player.flying)


func _on_flying_changed(on: bool) -> void:
	if on:
		carpet = Node3D.new()
		player.model.add_child(carpet)
		add_visual_box(carpet, Vector3(1.7, 0.06, 2.6), Vector3(0, 0.09, 0.15), Color(0.78, 0.2, 0.36))
		add_visual_box(carpet, Vector3(1.74, 0.06, 0.18), Vector3(0, 0.1, 0.85), Color(1.0, 0.8, 0.25))
		add_visual_box(carpet, Vector3(1.74, 0.06, 0.18), Vector3(0, 0.1, -0.55), Color(1.0, 0.8, 0.25))
	elif carpet:
		carpet.queue_free()
		carpet = null


func _hint_text() -> String:
	var t := super()
	if Game.has_item(CARPET_ID):
		t += "   F - ковёр"
	return t


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

	# 9) Прилавок магазина у старта
	_shop_stand(Vector3(-4.0, 0.0, 3.6))


func _shop_stand(p: Vector3) -> void:
	# Прилавок со свёрнутым ковром-самолётом: покупка - клавишей B.
	add_box(p + Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 1.0), Color(0.55, 0.38, 0.22))
	add_box(p + Vector3(0, 1.16, 0), Vector3(3.0, 0.12, 1.3), Color(0.35, 0.24, 0.14))
	add_box(p + Vector3(0.6, 1.4, 0), Vector3(0.45, 0.45, 1.4), Color(0.78, 0.2, 0.36))
	add_box(p + Vector3(0.6, 1.4, 0.45), Vector3(0.47, 0.47, 0.16), Color(1.0, 0.8, 0.25))
	add_box(p + Vector3(0.6, 1.4, -0.45), Vector3(0.47, 0.47, 0.16), Color(1.0, 0.8, 0.25))
	add_box(p + Vector3(-1.3, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(1.3, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 3.85, 0.2), Vector3(3.4, 0.15, 1.7), Color(0.8, 0.25, 0.25))
	add_sign("МАГАЗИН (B)", p + Vector3(0, 4.6, 0.2))


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
