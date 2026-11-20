extends PlaceBase
## Пример большой «игры креатора»: выживание с волнами зомби.
## Стрельба ЛКМ (4 оружия: пистолет бесплатный, остальные - в магазине (B)),
## апгрейды (броня/регенерация/двойные Focls), босс каждые 5 волн,
## рекорды через Game.set_place_data (доска у спавна, сохраняются в профиле).

const ARENA := 60.0
const FIRST_WAVE_DELAY := 5.0
const INTERMISSION := 8.0
const SPAWN_STEP := 0.6
const BASE_HP := 100.0

enum State { INTERMISSION, WAVE, OVER }

const WEAPONS := [
	{"id": "wpn_pistol", "name": "Пистолет", "dmg": 26.0, "rate": 0.35, "range": 45.0, "mag": 12, "reload": 1.0, "pellets": 1, "spread": 0.0, "hand": Color(0.32, 0.32, 0.36), "free": true},
	{"id": "wpn_smg", "name": "ПП «Оса»", "dmg": 13.0, "rate": 0.09, "range": 38.0, "mag": 30, "reload": 1.6, "pellets": 1, "spread": 0.05, "hand": Color(0.85, 0.55, 0.12), "price": 100},
	{"id": "wpn_shotgun", "name": "Дробовик «Бублик»", "dmg": 20.0, "rate": 0.95, "range": 16.0, "mag": 6, "reload": 2.2, "pellets": 6, "spread": 0.1, "hand": Color(0.72, 0.28, 0.2), "price": 250},
	{"id": "wpn_sniper", "name": "Снайперка «Игла»", "dmg": 160.0, "rate": 1.25, "range": 120.0, "mag": 5, "reload": 2.4, "pellets": 1, "spread": 0.0, "hand": Color(0.22, 0.5, 0.85), "price": 400},
]

const ZOMBIE_TYPES := {
	"normal": {"hp": 50.0, "hp_grow": 6.0, "speed": 2.6, "dmg": 8.0, "reward": 3, "color": Color(0.42, 0.6, 0.3)},
	"fast": {"hp": 30.0, "hp_grow": 4.0, "speed": 4.4, "dmg": 6.0, "reward": 4, "color": Color(0.78, 0.32, 0.26)},
	"tank": {"hp": 140.0, "hp_grow": 12.0, "speed": 1.7, "dmg": 16.0, "reward": 9, "color": Color(0.32, 0.36, 0.48)},
	"boss": {"hp": 600.0, "hp_grow": 80.0, "speed": 2.0, "dmg": 25.0, "reward": 60, "color": Color(0.28, 0.16, 0.4)},
}


# ----- товары плейса (магазин, клавиша B) -----
func shop_items() -> Array:
	var items: Array = []
	for w in WEAPONS:
		if w.get("free", false):
			continue
		items.append({
			"id": w["id"],
			"name": w["name"],
			"price": int(w["price"]),
			"desc": "Урон %d, %d выстр/с, обойма %d." % [int(w["dmg"]), int(round(1.0 / float(w["rate"]))), int(w["mag"])],
			"color": w["hand"],
		})
	items.append({"id": "up_armor", "name": "Бронежилет", "price": 120, "desc": "+50 к максимуму здоровья (навсегда).", "color": Color(0.3, 0.62, 0.9)})
	items.append({"id": "up_regen", "name": "Регенерация", "price": 220, "desc": "+2 HP в секунду (навсегда).", "color": Color(0.3, 0.8, 0.4)})
	items.append({"id": "up_x2", "name": "Двойные Focls", "price": 300, "desc": "Двойная награда за зомби (навсегда).", "color": Color(1.0, 0.82, 0.25)})
	return items


func on_item_purchased(item: Dictionary) -> void:
	match str(item["id"]):
		"up_armor":
			_apply_upgrades()
			player.heal(50.0)
		"up_regen":
			pass
		_:
			for i in WEAPONS.size():
				if WEAPONS[i]["id"] == item["id"]:
					show_toast("Клавиша %d - %s" % [i + 1, item["name"]])


# ----- запуск плейса -----
func _on_player_spawned() -> void:
	player.respawn_enabled = false
	player.died.connect(_on_player_died)
	_apply_upgrades()
	player.heal(9999.0)
	_equip("wpn_pistol")


func _apply_upgrades() -> void:
	player.set_max_hp(BASE_HP + (50.0 if Game.has_item("up_armor") else 0.0))


func _hint_text() -> String:
	var t := super()
	t += "   ЛКМ - стрелять   1-4 - оружие   R - перезарядка"
	return t


# ----- мир -----
func _build_world() -> void:
	spawn_point = Vector3(0, 1.5, 0)
	var half := ARENA / 2.0

	# Пол и стены
	add_box(Vector3(0, -0.5, 0), Vector3(ARENA, 1, ARENA), Color(0.24, 0.42, 0.26))
	add_box(Vector3(half + 1, 2, 0), Vector3(2, 6, ARENA + 4), Color(0.35, 0.28, 0.22))
	add_box(Vector3(-half - 1, 2, 0), Vector3(2, 6, ARENA + 4), Color(0.35, 0.28, 0.22))
	add_box(Vector3(0, 2, half + 1), Vector3(ARENA + 4, 6, 2), Color(0.35, 0.28, 0.22))
	add_box(Vector3(0, 2, -half - 1), Vector3(ARENA + 4, 6, 2), Color(0.35, 0.28, 0.22))

	# Ящики - укрытия
	var crates := [
		[Vector3(-14, 0.9, -10), Vector3(2, 1.8, 2), Color(0.55, 0.4, 0.24)],
		[Vector3(-12, 0.6, -13), Vector3(1.4, 1.2, 1.4), Color(0.5, 0.36, 0.22)],
		[Vector3(15, 1.2, -14), Vector3(3, 2.4, 2), Color(0.55, 0.4, 0.24)],
		[Vector3(-18, 1.0, 12), Vector3(2.4, 2.0, 2.4), Color(0.5, 0.36, 0.22)],
		[Vector3(12, 0.8, 16), Vector3(2, 1.6, 2), Color(0.55, 0.4, 0.24)],
		[Vector3(0, 1.0, -20), Vector3(4, 2.0, 1.6), Color(0.48, 0.34, 0.2)],
		[Vector3(6, 0.7, 12), Vector3(1.6, 1.4, 1.6), Color(0.55, 0.4, 0.24)],
		[Vector3(-8, 0.9, -6), Vector3(1.8, 1.8, 1.8), Color(0.52, 0.38, 0.23)],
	]
	for c in crates:
		add_box(c[0], c[1], c[2])

	# Точки спавна зомби у стен
	for x in [-half + 4, 0.0, half - 4]:
		for z in [-half + 4, half - 4]:
			spawn_points.append(Vector3(x, 1.0, z))
	spawn_points.append(Vector3(half - 4, 1.0, 0))
	spawn_points.append(Vector3(-half + 4, 1.0, 0))

	# Оружейная лавка и доска рекордов
	_shop_stand(Vector3(9.0, 0.0, 6.0))
	_build_board(Vector3(-9.0, 0.0, 6.0))


func _shop_stand(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 1.0), Color(0.55, 0.38, 0.22))
	add_box(p + Vector3(0, 1.16, 0), Vector3(3.6, 0.12, 1.3), Color(0.35, 0.24, 0.14))
	var i := 0
	for w in WEAPONS:
		add_box(p + Vector3(-1.2 + i * 0.8, 1.45, 0), Vector3(0.16, 0.5, 0.7), w["hand"])
		i += 1
	add_box(p + Vector3(-1.9, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(1.9, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 3.85, 0.2), Vector3(4.2, 0.15, 1.7), Color(0.8, 0.25, 0.25))
	add_sign("ОРУЖЕЙНАЯ (B)", p + Vector3(0, 4.6, 0.2))


func _build_board(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.8, 0), Vector3(0.25, 1.6, 0.25), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 1.7, 0), Vector3(3.2, 2.2, 0.2), Color(0.16, 0.12, 0.1))
	board = Label3D.new()
	board.text = _board_text()
	board.position = p + Vector3(0, 1.7, 0.15)
	board.font_size = 48
	board.pixel_size = 0.01
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.outline_size = 8
	add_child(board)


func _board_text() -> String:
	var best := int(Game.get_place_data("best_wave", 0))
	var total := int(Game.get_place_data("total_kills", 0))
	return "РЕКОРДЫ\nВолна: %d\nУбийств всего: %d" % [best, total]


# ----- волны -----
var state := State.INTERMISSION
var wave := 0
var countdown := FIRST_WAVE_DELAY
var to_spawn: Array = []
var spawn_timer := 0.0
var alive := 0
var kills := 0
var spawn_points: Array = []
var board: Label3D


func _process(delta: float) -> void:
	if player == null:
		return
	if Game.has_item("up_regen") and state != State.OVER and not Game.is_ui_blocked():
		player.heal(2.0 * delta)
	_tick_weapons(delta)
	if not Game.is_ui_blocked():
		_tick_waves(delta)
	_update_hud()


func _tick_waves(delta: float) -> void:
	match state:
		State.INTERMISSION:
			countdown -= delta
			if countdown <= 0.0:
				_start_wave()
		State.WAVE:
			if to_spawn.size() > 0:
				spawn_timer -= delta
				if spawn_timer <= 0.0:
					spawn_timer = SPAWN_STEP
					_spawn_zombie(str(to_spawn.pop_front()))
			elif alive <= 0:
				_wave_cleared()
		State.OVER:
			pass


func _start_wave() -> void:
	wave += 1
	state = State.WAVE
	to_spawn.clear()
	for i in 3 + 2 * wave:
		var r := randf()
		if wave >= 3 and r < 0.12:
			to_spawn.append("tank")
		elif wave >= 2 and r < 0.32:
			to_spawn.append("fast")
		else:
			to_spawn.append("normal")
	if wave % 5 == 0:
		to_spawn.append("boss")
		show_toast("Волна %d - БОСС!" % wave)
	else:
		show_toast("Волна %d" % wave)
	spawn_timer = 0.5


func _wave_cleared() -> void:
	var bonus := (10 + 5 * wave) * (2 if Game.has_item("up_x2") else 1)
	Game.add_focls(bonus)
	player.heal(25.0)
	show_toast("Волна %d пройдена! +%d Focls" % [wave, bonus])
	state = State.INTERMISSION
	countdown = INTERMISSION


func _spawn_zombie(type: String) -> void:
	var t: Dictionary = ZOMBIE_TYPES[type]
	var z := Zombie.new()
	z.place = self
	z.hp = float(t["hp"]) + float(t["hp_grow"]) * (wave - 1)
	z.speed = float(t["speed"]) * (1.0 + 0.02 * wave)
	z.dmg = float(t["dmg"])
	z.reward = int(t["reward"])
	z.torso_color = t["color"]
	if type == "boss":
		z.is_boss = true
		z.scale = Vector3(1.5, 1.5, 1.5)
	z.position = (spawn_points.pick_random() as Vector3) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	z.killed.connect(_on_zombie_killed)
	add_child(z)
	alive += 1


func _on_zombie_killed(z) -> void:
	alive -= 1
	kills += 1
	var reward: int = z.reward * (2 if Game.has_item("up_x2") else 1)
	Game.add_focls(reward)
	_float_text(z.global_position + Vector3(0, 1.8, 0), "+%d" % reward, Color(1.0, 0.82, 0.25))


# ----- стрельба -----
var cur_weapon := "wpn_pistol"
var ammo := 12
var shoot_cd := 0.0
var reload_t := 0.0
var hand_box: MeshInstance3D


func _weapon() -> Dictionary:
	for w in WEAPONS:
		if w["id"] == cur_weapon:
			return w
	return WEAPONS[0]


func _tick_weapons(delta: float) -> void:
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = int(_weapon()["mag"])
		return
	if state != State.OVER and not player.dead and not Game.is_ui_blocked() \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_shoot()


func _try_shoot() -> void:
	if shoot_cd > 0.0:
		return
	var w := _weapon()
	if ammo <= 0:
		_start_reload()
		return
	shoot_cd = float(w["rate"])
	ammo -= 1
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var space := cam.get_world_3d().direct_space_state
	for i in int(w["pellets"]):
		var dir := -cam.global_basis.z
		if float(w["spread"]) > 0.0:
			dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(w["spread"])).normalized()
		var end := from + dir * float(w["range"])
		var q := PhysicsRayQueryParameters3D.create(from, end)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit:
			end = hit["position"]
			if hit["collider"] is Zombie:
				(hit["collider"] as Zombie).take_hit(float(w["dmg"]))
				_float_text(end + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), str(int(w["dmg"])), Color(1, 0.45, 0.3))
		_tracer(player.global_position + Vector3(0, 1.4, 0), end)
	if ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if reload_t <= 0.0 and ammo < int(_weapon()["mag"]):
		reload_t = float(_weapon()["reload"])


func _tracer(a: Vector3, b: Vector3) -> void:
	var ln := a.distance_to(b)
	if ln < 0.2:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, ln)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 2.0
	bm.material = mat
	mi.mesh = bm
	add_child(mi)
	mi.position = (a + b) / 2.0
	if (b - a).cross(Vector3.UP).length() > 0.001:
		mi.look_at(b)
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 1.0, 0.08)
	tw.tween_callback(mi.queue_free)


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	l.position = pos
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", pos.y + 1.2, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)


func _equip(id: String) -> void:
	cur_weapon = id
	ammo = int(_weapon()["mag"])
	reload_t = 0.0
	if hand_box:
		hand_box.queue_free()
	hand_box = add_visual_box(player.right_arm, Vector3(0.16, 0.18, 0.8), Vector3(0, -0.75, -0.2), _weapon()["hand"])


func _unhandled_input(event: InputEvent) -> void:
	if player == null or state == State.OVER:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_R:
		_start_reload()
		return
	var slot := -1
	match k.physical_keycode:
		KEY_1: slot = 0
		KEY_2: slot = 1
		KEY_3: slot = 2
		KEY_4: slot = 3
	if slot >= 0 and slot < WEAPONS.size():
		var w: Dictionary = WEAPONS[slot]
		if w.get("free", false) or Game.has_item(str(w["id"])):
			if cur_weapon != w["id"]:
				_equip(str(w["id"]))
				show_toast(str(w["name"]))
		else:
			show_toast("Не куплено - магазин (B)")


# ----- HUD и Game Over -----
var hp_fill: ColorRect
var wave_label: Label
var info_label: Label


func _ready() -> void:
	super()
	_build_hud()


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 11
	add_child(hud)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.45)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bg.offset_left = 16
	hp_bg.offset_top = -56
	hp_bg.offset_right = 222
	hp_bg.offset_bottom = -40
	hud.add_child(hp_bg)

	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.3, 0.85, 0.3)
	hp_fill.position = Vector2(2, 2)
	hp_fill.size = Vector2(202, 12)
	hp_bg.add_child(hp_fill)

	wave_label = Label.new()
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wave_label.offset_top = 8
	wave_label.offset_left = 16
	wave_label.offset_right = -16
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 24)
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.add_theme_constant_override("outline_size", 6)
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(wave_label)

	info_label = Label.new()
	info_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info_label.offset_left = -280
	info_label.offset_top = -66
	info_label.offset_right = -14
	info_label.offset_bottom = -12
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 5)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(info_label)

	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 30)
	cross.add_theme_color_override("font_outline_color", Color.BLACK)
	cross.add_theme_constant_override("outline_size", 6)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)


func _update_hud() -> void:
	var ratio := 0.0 if player.max_hp <= 0.0 else player.hp / player.max_hp
	hp_fill.size = Vector2(202.0 * ratio, 12)
	hp_fill.color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.3), ratio)
	var w := _weapon()
	var wtxt: String = "%s - перезарядка..." % w["name"] if reload_t > 0.0 else "%s %d/%d" % [w["name"], ammo, int(w["mag"])]
	info_label.text = "Убийств: %d\n%s" % [kills, wtxt]
	match state:
		State.INTERMISSION:
			wave_label.text = "Приготовься! Волна %d через %d с" % [wave + 1, int(ceil(countdown))]
		State.WAVE:
			wave_label.text = "Волна %d - осталось %d" % [wave, alive + to_spawn.size()]
		State.OVER:
			wave_label.text = ""


func _on_player_died() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	var best := int(Game.get_place_data("best_wave", 0))
	var new_record := wave > best
	if new_record:
		Game.set_place_data("best_wave", wave)
	var total := int(Game.get_place_data("total_kills", 0))
	Game.set_place_data("total_kills", total + kills)
	board.text = _board_text()
	_show_game_over(new_record)


func _show_game_over(new_record: bool) -> void:
	var ui := CanvasLayer.new()
	ui.layer = 60
	add_child(ui)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.1, 0.95)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var title := Label.new()
	title.text = "ТЫ ПОГИБ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	box.add_child(title)

	var stats := Label.new()
	stats.text = "Волна: %d    Убийств: %d" % [wave, kills]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	var rec := Label.new()
	if new_record:
		rec.text = "НОВЫЙ РЕКОРД!"
		rec.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	else:
		rec.text = "Рекорд: волна %d" % int(Game.get_place_data("best_wave", 0))
		rec.modulate = Color(1, 1, 1, 0.6)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rec)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var again := Button.new()
	again.text = "Заново"
	again.custom_minimum_size = Vector2(150, 44)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	row.add_child(again)

	var menu := Button.new()
	menu.text = "В меню"
	menu.custom_minimum_size = Vector2(150, 44)
	menu.pressed.connect(Game.go_to_menu)
	row.add_child(menu)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ----- зомби -----
class Zombie extends CharacterBody3D:
	signal killed(z)

	var place  # скрипт плейса
	var hp := 50.0
	var speed := 2.6
	var dmg := 8.0
	var reward := 3
	var torso_color := Color(0.42, 0.6, 0.3)
	var is_boss := false
	var dying := false
	var hit_cd := 0.0
	var flash_t := 0.0
	var bob_t := 0.0
	var torso_mat: StandardMaterial3D
	var vis: Node3D

	func _ready() -> void:
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.45
		cap.height = 1.7
		col.shape = cap
		col.position.y = 0.9
		add_child(col)
		vis = Node3D.new()
		add_child(vis)
		var skin := Color(0.47, 0.62, 0.38)
		var torso: MeshInstance3D = place.add_visual_box(vis, Vector3(0.8, 0.9, 0.45), Vector3(0, 1.0, 0), torso_color)
		torso_mat = torso.mesh.surface_get_material(0)
		place.add_visual_box(vis, Vector3(0.45, 0.45, 0.45), Vector3(0, 1.68, 0), skin)
		place.add_visual_box(vis, Vector3(0.09, 0.1, 0.03), Vector3(-0.11, 1.72, -0.235), Color.BLACK)
		place.add_visual_box(vis, Vector3(0.09, 0.1, 0.03), Vector3(0.11, 1.72, -0.235), Color.BLACK)
		place.add_visual_box(vis, Vector3(0.24, 0.24, 0.7), Vector3(-0.52, 1.28, -0.3), skin)
		place.add_visual_box(vis, Vector3(0.24, 0.24, 0.7), Vector3(0.52, 1.28, -0.3), skin)
		place.add_visual_box(vis, Vector3(0.3, 0.62, 0.3), Vector3(-0.2, 0.32, 0), Color(0.25, 0.28, 0.33))
		place.add_visual_box(vis, Vector3(0.3, 0.62, 0.3), Vector3(0.2, 0.32, 0), Color(0.25, 0.28, 0.33))

	func _physics_process(delta: float) -> void:
		if dying:
			return
		bob_t += delta * 6.0
		vis.position.y = absf(sin(bob_t)) * 0.06
		if flash_t > 0.0:
			flash_t -= delta
			if flash_t <= 0.0 and torso_mat:
				torso_mat.emission_enabled = false
		hit_cd = maxf(hit_cd - delta, 0.0)
		if not is_on_floor():
			velocity.y -= 28.0 * delta
		var p = place.player
		if p == null or p.dead or Game.is_ui_blocked():
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() > 1.35:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if hit_cd <= 0.0:
				hit_cd = 1.0
				p.hurt(dmg)
		move_and_slide()

	func take_hit(dmg: float) -> void:
		if dying:
			return
		hp -= dmg
		flash_t = 0.08
		if torso_mat:
			torso_mat.emission_enabled = true
			torso_mat.emission = Color(1, 1, 1)
			torso_mat.emission_energy_multiplier = 0.8
		if hp <= 0.0:
			_die()

	func _die() -> void:
		dying = true
		killed.emit(self)
		for c in get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", true)
		collision_layer = 0
		collision_mask = 0
		var tw := create_tween()
		tw.tween_property(vis, "rotation:x", -PI / 2.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.7)
		tw.tween_callback(queue_free)
