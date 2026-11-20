extends PlaceBase
## «Зомби-Выживание 2.0»: главное меню, два режима (Классика и База и волны),
## своя валюта (черепки), пассы (перманентные перки за Focls), броня, криты,
## комбо-серии, кровавая луна, элиты, ярость босса, добыча кристаллов,
## постройка базы: стены, турели, дроны, дриллы, мины, аптечки в инвентарь,
## катсцены, тряска камеры и частицы.

const UITheme := preload("res://scripts/ui_theme.gd")

const FIRST_WAVE_DELAY := 4.0
const INTERMISSION := 8.0
const SPAWN_STEP := 0.6
const BASE_HP := 100.0
const ARENA := 60.0
const COMBO_TIME := 4.0
const MEDKIT_CHANCE := 0.10
const BUILD_LIMIT := 24

enum State { MENU, INTERMISSION, WAVE, OVER }

const WEAPONS := [
	{"id": "wpn_pistol", "name": "Пистолет", "dmg": 26.0, "rate": 0.35, "range": 45.0, "mag": 12, "reload": 1.0, "pellets": 1, "spread": 0.0, "hand": Color(0.32, 0.32, 0.36), "free": true},
	{"id": "wpn_smg", "name": "ПП «Оса»", "dmg": 13.0, "rate": 0.09, "range": 38.0, "mag": 30, "reload": 1.6, "pellets": 1, "spread": 0.05, "hand": Color(0.85, 0.55, 0.12), "price": 100},
	{"id": "wpn_shotgun", "name": "Дробовик «Бублик»", "dmg": 20.0, "rate": 0.95, "range": 16.0, "mag": 6, "reload": 2.2, "pellets": 6, "spread": 0.1, "hand": Color(0.72, 0.28, 0.2), "price": 250},
	{"id": "wpn_sniper", "name": "Снайперка «Игла»", "dmg": 160.0, "rate": 1.25, "range": 120.0, "mag": 5, "reload": 2.4, "pellets": 1, "spread": 0.0, "hand": Color(0.22, 0.5, 0.85), "price": 400},
]

const ZOMBIE_TYPES := {
	"normal": {"hp": 50.0, "hp_grow": 6.0, "speed": 2.6, "dmg": 8.0, "reward": 3, "skulls": 1, "color": Color(0.42, 0.6, 0.3)},
	"fast": {"hp": 30.0, "hp_grow": 4.0, "speed": 4.4, "dmg": 6.0, "reward": 4, "skulls": 1, "color": Color(0.78, 0.32, 0.26)},
	"tank": {"hp": 140.0, "hp_grow": 12.0, "speed": 1.7, "dmg": 16.0, "reward": 9, "skulls": 3, "color": Color(0.32, 0.36, 0.48)},
	"boss": {"hp": 600.0, "hp_grow": 80.0, "speed": 2.0, "dmg": 25.0, "reward": 60, "skulls": 25, "color": Color(0.28, 0.16, 0.4)},
}

const BUILDS := [
	{"id": "wall", "name": "Стена", "cost": 20, "desc": "Блокирует зомби"},
	{"id": "turret", "name": "Турель", "cost": 60, "desc": "Стреляет сама"},
	{"id": "drill", "name": "Дрилл", "cost": 40, "desc": "Добывает черепки"},
	{"id": "mine", "name": "Мина", "cost": 15, "desc": "Взрыв при подходе"},
	{"id": "drone", "name": "Дрон", "cost": 80, "desc": "Летает и стреляет"},
]

const MECHANICS := [
	"Камера на Shift - без зажатия ПКМ",
	"Рывок на Q с перезарядкой",
	"Броня поглощает 60% урона",
	"Черепки - своя валюта за убийства",
	"Пассы - перманентные перки в магазине (B)",
	"Криты: 15% шанс утроить урон",
	"Добыча: расстреливай кристаллы",
	"Постройка стен (C в режиме базы)",
	"Турели сами защищают базу",
	"Боевые дроны летают за тобой",
	"Дриллы добывают черепки пассивно",
	"Мины взрываются у зомби",
	"Кровавая луна: каждая 4-я волна",
	"Элитные золотые зомби (x5 черепков)",
	"Босс впадает в ярость на 30% HP",
	"Комбо-серия умножает черепки",
	"Аптечки падают в инвентарь (V - лечит)",
]

const C_GOLD := Color(0.85, 0.67, 0.22)
const C_BLOOD := Color(0.55, 0.06, 0.06)

var state := State.MENU
var run_mode := "classic"
var wave := 0
var countdown := FIRST_WAVE_DELAY
var to_spawn: Array = []
var spawn_timer := 0.0
var alive := 0
var kills := 0
var run_skulls := 0
var blood_moon := false
var spawn_points: Array = []
var board: Label3D

# броня / черепки / комбо / пассы
var armor := 0.0
var armor_max := 100.0
var skulls := 0
var combo_n := 0
var combo_t := 0.0

# постройки
var build_enabled := false
var build_open := false
var build_sel := 0
var structures: Array = []
var zombie_list: Array = []
var drones: Array = []
var crystal_nodes: Array = []

# стрельба
var cur_weapon := "wpn_pistol"
var ammo := 12
var shoot_cd := 0.0
var reload_t := 0.0
var hand_box: MeshInstance3D

# катсцены и эффекты
var cutscene_active := false
var cut_cam: Camera3D
var cut_tween: Tween
var cut_top: ColorRect
var cut_bot: ColorRect
var cut_banner: Label
var shake_t := 0.0

# HUD
var hp_fill: ColorRect
var ar_fill: ColorRect
var wave_label: Label
var mode_label: Label
var skull_label: Label
var combo_label: Label
var info_label: Label
var banner_label: Label
var build_bar: HBoxContainer
var build_buttons: Array = []

var menu_ui: CanvasLayer


# ---------- магазин: оружие, апгрейды и пассы ----------
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
	items.append({"id": "up_x2", "name": "Двойные Focls", "price": 300, "desc": "Двойная награда Focls за зомби.", "color": Color(1.0, 0.82, 0.25)})
	items.append({"id": "pass_damage", "name": "Пасс: Урон +25%", "price": 400, "desc": "Весь урон оружия увеличен на 25%.", "color": Color(0.85, 0.3, 0.25)})
	items.append({"id": "pass_reload", "name": "Пасс: Быстрые руки", "price": 350, "desc": "Перезарядка на 30% быстрее.", "color": Color(0.3, 0.7, 0.7)})
	items.append({"id": "pass_skulls", "name": "Пасс: Черепный магнат", "price": 300, "desc": "+50% черепков со всех источников.", "color": Color(0.75, 0.5, 0.85)})
	items.append({"id": "pass_crit", "name": "Пасс: Смертельный шанс", "price": 450, "desc": "15% шанс крита (x3 урона).", "color": Color(1.0, 0.6, 0.2)})
	items.append({"id": "pass_armor", "name": "Пасс: Экзо-броня", "price": 500, "desc": "Каждый забег начинается со 100 брони.", "color": Color(0.45, 0.55, 0.95)})
	return items


func on_item_purchased(item: Dictionary) -> void:
	match str(item["id"]):
		"up_armor":
			_apply_run_mods()
			player.heal(50.0)
		"pass_armor":
			_apply_run_mods()
			show_toast("Броня активна: 100 ед. за забег")
		_:
			for i in WEAPONS.size():
				if WEAPONS[i]["id"] == item["id"]:
					show_toast("Клавиша %d - %s" % [i + 1, item["name"]])


# ---------- запуск плейса ----------
func _hint_text() -> String:
	var t := super()
	t += "   Shift - камера   Q - рывок"
	if build_enabled:
		t += "   C - постройка"
	return t


func _on_player_spawned() -> void:
	player.respawn_enabled = false
	player.died.connect(_on_player_died)
	player.dash_enabled = true
	player.inventory_enabled = true
	player.item_used.connect(_on_item_used)
	_apply_run_mods()


func _apply_run_mods() -> void:
	player.set_max_hp(BASE_HP + (50.0 if Game.has_item("up_armor") else 0.0))
	armor_max = 100.0 if Game.has_item("pass_armor") else 0.0
	armor = armor_max


func _on_item_used(id: String) -> void:
	if id == "medkit":
		player.heal(40.0)
		show_toast("+40 HP")
		hud_refresh()


func _build_world() -> void:
	spawn_point = Vector3(0, 1.5, 20)
	skulls = int(Game.get_place_data("skulls", 0))
	Game.define_item({"id": "medkit", "name": "Аптечка", "desc": "Используй (V): +40 HP.", "color": Color(0.9, 0.25, 0.25)})

	# Пол и стены (стилизовано: тёмный сланец + золотые канты)
	add_box(Vector3(0, -0.5, 0), Vector3(ARENA, 1, ARENA), Color(0.1, 0.11, 0.1))
	for i in 12:
		for j in 12:
			var c := Color(0.13, 0.14, 0.12) if (i + j) % 2 == 0 else Color(0.11, 0.12, 0.11)
			add_visual_box(self, Vector3(4.98, 0.04, 4.98), Vector3(i * 5 - 27.5, 0.02, j * 5 - 27.5), c)
	add_box(Vector3(0, 3, -26), Vector3(72, 6, 2), Color(0.16, 0.15, 0.14))
	add_box(Vector3(0, 2.2, -25.9), Vector3(70, 0.25, 0.3), C_GOLD)
	add_box(Vector3(-20, 3, 26), Vector3(32, 6, 2), Color(0.16, 0.15, 0.14))
	add_box(Vector3(20, 3, 26), Vector3(32, 6, 2), Color(0.16, 0.15, 0.14))
	add_box(Vector3(-36, 3, 0), Vector3(2, 6, 54), Color(0.16, 0.15, 0.14))
	add_box(Vector3(-35.9, 2.2, 0), Vector3(0.3, 0.25, 52), C_GOLD)
	add_box(Vector3(36, 3, 0), Vector3(2, 6, 54), Color(0.16, 0.15, 0.14))
	add_box(Vector3(35.9, 2.2, 0), Vector3(0.3, 0.25, 52), C_GOLD)

	# Руины-укрытия
	var ruins := [
		[Vector3(-14, 0.9, -10), Vector3(2, 1.8, 2)],
		[Vector3(-12, 0.6, -13), Vector3(1.4, 1.2, 1.4)],
		[Vector3(15, 1.2, -14), Vector3(3, 2.4, 2)],
		[Vector3(-18, 1.0, 12), Vector3(2.4, 2.0, 2.4)],
		[Vector3(12, 0.8, 16), Vector3(2, 1.6, 2)],
		[Vector3(0, 1.0, -20), Vector3(4, 2.0, 1.6)],
		[Vector3(6, 0.7, 12), Vector3(1.6, 1.4, 1.6)],
		[Vector3(-8, 0.9, -6), Vector3(1.8, 1.8, 1.8)],
	]
	for r in ruins:
		add_box(r[0], r[1], Color(0.28, 0.27, 0.25))
		add_visual_box(self, Vector3(r[1].x + 0.2, 0.12, r[1].z + 0.2), Vector3(r[0].x, r[0].y + r[1].y / 2.0 + 0.06, r[0].z), C_GOLD)

	# Точки спавна у стен
	for x in [-26.0, 0.0, 26.0]:
		for z in [-26.0, 26.0]:
			spawn_points.append(Vector3(x, 1.0, z))
	spawn_points.append(Vector3(26, 1.0, 0))
	spawn_points.append(Vector3(-26, 1.0, 0))

	# Лавка пассов и доска рекордов
	_shop_stand(Vector3(10, 0, 16))
	_build_board(Vector3(-10, 0, 16))

	_build_hud()
	_build_cutscene_ui()
	_open_menu()
	Game.dialog_open = true


func _shop_stand(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.55, 0), Vector3(3.6, 1.1, 1.2), Color(0.3, 0.2, 0.14))
	add_visual_box(self, Vector3(3.7, 0.12, 1.3), Vector3(p.x, 1.14, p.z), C_GOLD)
	var i := 0
	for w in WEAPONS:
		_glow_box(self, Vector3(0.16, 0.5, 0.7), p + Vector3(-1.4 + i * 0.9, 1.5, 0), w["hand"], 0.8)
		i += 1
	add_box(p + Vector3(-2.1, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(2.1, 1.9, 0.55), Vector3(0.15, 3.8, 0.15), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 3.85, 0.2), Vector3(4.6, 0.15, 1.7), Color(0.5, 0.08, 0.1))
	add_sign("ПАССЫ (B)", p + Vector3(0, 4.6, 0.2))


func _glow_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, energy := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_board(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.8, 0), Vector3(0.25, 1.6, 0.25), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 1.7, 0), Vector3(3.4, 2.3, 0.2), Color(0.1, 0.1, 0.09))
	for f in [Vector3(0, 2.9, 0), Vector3(0, 0.5, 0), Vector3(-1.75, 1.7, 0), Vector3(1.75, 1.7, 0)]:
		var fs: Vector3 = f
		add_visual_box(self, Vector3(3.6, 0.12, 0.24) if absf(fs.x) < 0.1 else Vector3(0.12, 2.6, 0.24), p + fs, C_GOLD)
	board = Label3D.new()
	board.text = _board_text()
	board.position = p + Vector3(0, 1.7, 0.14)
	board.font_size = 38
	board.pixel_size = 0.01
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.outline_size = 8
	add_child(board)


func _board_text() -> String:
	return "РЕКОРДЫ\nВолна: %d\nУбийств: %d\nЧерепков: %d" % [int(Game.get_place_data("best_wave", 0)), int(Game.get_place_data("total_kills", 0)), int(Game.get_place_data("skulls_earned", 0))]


# ---------- главное меню с режимами ----------
func _open_menu() -> void:
	if menu_ui:
		menu_ui.queue_free()
	menu_ui = CanvasLayer.new()
	menu_ui.layer = 60
	add_child(menu_ui)
	Game.dialog_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_ui.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 0)
	card.add_theme_stylebox_override("panel", UITheme.panel())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := Label.new()
	title.text = "☠ ЗОМБИ-ВЫЖИВАНИЕ 2.0"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Выбери режим и выживай"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.55)
	box.add_child(sub)

	var b1 := Button.new()
	b1.text = "КЛАССИКА - просто волны"
	b1.custom_minimum_size = Vector2(0, 52)
	b1.pressed.connect(_start_run.bind("classic"))
	UITheme.gold_button(b1, true)
	box.add_child(b1)

	var b2 := Button.new()
	b2.text = "БАЗА И ВОЛНЫ - добывай, строй, защищай"
	b2.custom_minimum_size = Vector2(0, 52)
	b2.pressed.connect(_start_run.bind("base"))
	UITheme.gold_button(b2, true)
	box.add_child(b2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var mech := Button.new()
	mech.text = "МЕХАНИКИ (17)"
	mech.custom_minimum_size = Vector2(220, 44)
	mech.pressed.connect(_toggle_mechanics)
	UITheme.dark_button(mech)
	row.add_child(mech)
	var leave := Button.new()
	leave.text = "В ГЛАВНОЕ МЕНЮ"
	leave.custom_minimum_size = Vector2(220, 44)
	leave.pressed.connect(Game.go_to_menu)
	UITheme.dark_button(leave)
	row.add_child(leave)

	_mech_panel(box)


var mech_scroll: ScrollContainer

func _mech_panel(box: VBoxContainer) -> void:
	mech_scroll = ScrollContainer.new()
	mech_scroll.custom_minimum_size = Vector2(0, 170)
	mech_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(mech_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mech_scroll.add_child(list)
	for m in MECHANICS:
		var l := Label.new()
		l.text = "•  " + str(m)
		l.modulate = Color(1, 1, 1, 0.75)
		list.add_child(l)
	mech_scroll.visible = false


func _toggle_mechanics() -> void:
	mech_scroll.visible = not mech_scroll.visible


func _start_run(mode: String) -> void:
	if state != State.MENU:
		return
	run_mode = mode
	build_enabled = mode == "base"
	wave = 0
	kills = 0
	run_skulls = 0
	combo_n = 0
	blood_moon = false
	env.fog_enabled = false
	_apply_run_mods()
	player.heal(9999.0)
	if menu_ui:
		menu_ui.queue_free()
		menu_ui = null
	Game.dialog_open = false
	mode_label.text = "РЕЖИМ: %s" % ("БАЗА И ВОЛНЫ" if build_enabled else "КЛАССИКА")
	if build_enabled:
		_spawn_crystals()
	build_bar.visible = build_enabled
	hud_refresh()
	_run_intro()


func _run_intro() -> void:
	await _mini_cutscene(player.global_position + Vector3(0, 15, 13), player.global_position + Vector3(0, 1, 0), 2.6, "ПРИГОТОВЬСЯ...")
	state = State.INTERMISSION
	countdown = FIRST_WAVE_DELAY
	_banner("Волна 1 скоро", 2.0)


func _spawn_crystals() -> void:
	for i in 20:
		var a := randf() * TAU
		var r := randf_range(9.0, 27.0)
		var pos := Vector3(cos(a) * r, 0.15, sin(a) * r)
		var c := Crystal.new()
		c.place = self
		c.position = pos
		add_child(c)
		crystal_nodes.append(c)


# ---------- катсцены ----------
func _build_cutscene_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 70
	add_child(ui)
	cut_top = ColorRect.new()
	cut_top.color = Color.BLACK
	cut_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cut_top.offset_bottom = 0
	cut_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cut_top)
	cut_bot = ColorRect.new()
	cut_bot.color = Color.BLACK
	cut_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cut_bot.offset_top = 0
	cut_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cut_bot)
	cut_banner = Label.new()
	cut_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cut_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_banner.add_theme_font_size_override("font_size", 44)
	cut_banner.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	cut_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	cut_banner.add_theme_constant_override("outline_size", 8)
	cut_banner.modulate.a = 0.0
	ui.add_child(cut_banner)


func _mini_cutscene(cam_from: Vector3, cam_look: Vector3, dur: float, text: String) -> void:
	if cutscene_active:
		return
	cutscene_active = true
	Game.dialog_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cut_cam = Camera3D.new()
	add_child(cut_cam)
	cut_cam.current = true
	cut_cam.position = cam_from
	cut_cam.look_at(cam_look)
	var to := cam_from.lerp(cam_look, 0.6) + Vector3(0, 2.4, 0)
	cut_tween = create_tween()
	cut_tween.tween_property(cut_cam, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bars_t := create_tween()
	bars_t.set_parallel()
	bars_t.tween_property(cut_top, "offset_bottom", 80.0, 0.4)
	bars_t.tween_property(cut_bot, "offset_top", -80.0, 0.4)
	cut_banner.text = text
	cut_banner.modulate.a = 1.0
	# ждём по таймеру (не по твину), чтобы скип катсцены не ломал последовательность
	await get_tree().create_timer(dur + 0.1).timeout
	_cutscene_end()


func _cutscene_end() -> void:
	if not cutscene_active:
		return
	cutscene_active = false
	Game.dialog_open = false
	if cut_tween:
		cut_tween.kill()
	var bars_t := create_tween()
	bars_t.set_parallel()
	bars_t.tween_property(cut_top, "offset_bottom", 0.0, 0.35)
	bars_t.tween_property(cut_bot, "offset_top", 0.0, 0.35)
	var b_t := create_tween()
	b_t.tween_property(cut_banner, "modulate:a", 0.0, 0.35)
	if cut_cam and is_instance_valid(cut_cam):
		cut_cam.queue_free()
	cut_cam = null
	if player and is_instance_valid(player):
		player.camera.current = true


func _shake(t: float) -> void:
	shake_t = maxf(shake_t, t)


func _burst(pos: Vector3, color: Color, amount := 10, speed := 4.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.14
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	m.material = mat
	p.mesh = m
	add_child(p)
	p.position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _banner(text: String, dur := 2.2, color := UITheme.GOLD_BRIGHT) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.5)


# ---------- урон, броня, комбо, черепки ----------
func _damage_mult() -> float:
	return 1.25 if Game.has_item("pass_damage") else 1.0


func _skull_mult() -> float:
	var m := 1.0
	if Game.has_item("pass_skulls"):
		m *= 1.5
	if blood_moon:
		m *= 2.0
	m *= combo_mult()
	return m


func combo_mult() -> float:
	return minf(1.0 + combo_n * 0.1, 3.0)


func _player_hit(dmg: float) -> void:
	if armor > 0.0:
		var absorbed: float = minf(armor, dmg * 0.6)
		armor -= absorbed
		dmg -= absorbed
	player.hurt(dmg)
	hud_refresh()


func _add_skulls(n: int, pos: Vector3, big := false) -> void:
	var amount := int(round(n * _skull_mult()))
	skulls += amount
	run_skulls += amount
	Game.set_place_data("skulls", skulls)
	Game.set_place_data("skulls_earned", int(Game.get_place_data("skulls_earned", 0)) + amount)
	if is_instance_valid(board):
		board.text = _board_text()
	_float_text(pos + Vector3(0, 1.6, 0), "+%d 💀" % amount, Color(0.75, 0.5, 0.95) if not big else Color(1.0, 0.7, 0.3))
	hud_refresh()


# ---------- волны ----------
func _process(delta: float) -> void:
	if player == null:
		return
	if Game.has_item("up_regen") and state != State.OVER and not Game.is_ui_blocked():
		player.heal(2.0 * delta)
	# тряска камеры
	if shake_t > 0.0:
		shake_t -= delta
		player.camera.v_offset = randf_range(-0.06, 0.06)
		player.camera.h_offset = randf_range(-0.06, 0.06)
	else:
		player.camera.v_offset = 0.0
		player.camera.h_offset = 0.0
	# комбо
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo_n = 0
			hud_refresh()
	_tick_weapons(delta)
	if not Game.is_ui_blocked():
		_tick_waves(delta)
	_tick_buildings(delta)
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
		State.MENU, State.OVER:
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
	if wave % 4 == 3 and wave >= 3:
		blood_moon = true
		env.fog_enabled = true
		env.fog_light_color = C_BLOOD
		env.fog_density = 0.03
		_banner("🌕 КРОВАВАЯ ЛУНА - черепки x2!", 2.6, Color(1.0, 0.4, 0.35))
	elif wave % 5 == 0:
		_banner("БОСС ПРИБЫЛ", 2.2, Color(0.8, 0.35, 0.9))
	else:
		_banner("Волна %d" % wave, 1.8)
	spawn_timer = 0.5
	hud_refresh()


func _wave_cleared() -> void:
	var bonus := (10 + 5 * wave) * (2 if Game.has_item("up_x2") else 1)
	Game.add_focls(bonus)
	player.heal(25.0)
	show_toast("Волна %d пройдена! +%d Focls" % [wave, bonus])
	_add_skulls(5 + wave, player.global_position + Vector3(0, 2, 0))
	blood_moon = false
	env.fog_enabled = false
	state = State.INTERMISSION
	countdown = INTERMISSION


func _spawn_zombie(type: String) -> void:
	var t: Dictionary = ZOMBIE_TYPES[type]
	var z := Zombie.new()
	z.place = self
	z.hp = float(t["hp"]) + float(t["hp_grow"]) * (wave - 1)
	z.max_hp = z.hp
	z.speed = float(t["speed"]) * (1.0 + 0.02 * wave) * randf_range(0.92, 1.08)
	if blood_moon:
		z.speed *= 1.35
	z.dmg = float(t["dmg"])
	z.reward = int(t["reward"])
	z.skull_reward = int(t["skulls"])
	z.torso_color = t["color"]
	if type == "boss":
		z.is_boss = true
		z.scale = Vector3(1.5, 1.5, 1.5)
	elif wave >= 2 and randf() < 0.08:
		z.is_elite = true
		z.hp *= 3.0
		z.skull_reward *= 5
		z.reward *= 2
		z.scale = Vector3(1.12, 1.12, 1.12)
	var sp := (spawn_points.pick_random() as Vector3) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	z.position = sp + Vector3(0, -1.6, 0)
	z.spawn_y = sp.y
	z.killed.connect(_on_zombie_killed)
	add_child(z)
	zombie_list.append(z)
	alive += 1
	_burst(sp + Vector3(0, 0.3, 0), Color(0.4, 0.3, 0.2), 10, 3.0)
	if z.is_boss:
		_mini_cutscene(sp + Vector3(0, 7, 9), sp + Vector3(0, 1.5, 0), 1.6, "☠ БОСС ☠")


func _on_zombie_killed(z) -> void:
	alive -= 1
	zombie_list.erase(z)
	kills += 1
	combo_n += 1
	combo_t = COMBO_TIME
	var reward: int = z.reward * (2 if Game.has_item("up_x2") else 1)
	Game.add_focls(reward)
	_float_text(z.global_position + Vector3(0, 2.1, 0), "+%d" % reward, Color(1.0, 0.82, 0.25))
	_add_skulls(z.skull_reward, z.global_position + Vector3(0, 1.4, 0))
	_burst(z.global_position + Vector3(0, 1, 0), Color(0.6, 0.08, 0.08), 14, 4.5)
	if randf() < MEDKIT_CHANCE and not z.is_boss:
		add_pickup(z.global_position + Vector3(0, 0.2, 0), "medkit")
	if z.is_boss:
		_shake(1.2)
		_burst(z.global_position + Vector3(0, 1.5, 0), Color(0.9, 0.4, 0.1), 30, 7.0)
	hud_refresh()


# ---------- стрельба (с критами и добычей) ----------
func _weapon() -> Dictionary:
	for w in WEAPONS:
		if w["id"] == cur_weapon:
			return w
	return WEAPONS[0]


func _reload_time() -> float:
	return float(_weapon()["reload"]) * (0.7 if Game.has_item("pass_reload") else 1.0)


func _tick_weapons(delta: float) -> void:
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = int(_weapon()["mag"])
		return
	if state != State.OVER and not player.dead and not Game.is_ui_blocked() \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not build_open:
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
			var col = hit["collider"]
			if col is Zombie:
				var crit: bool = Game.has_item("pass_crit") and randf() < 0.15
				var dmg := float(w["dmg"]) * _damage_mult() * (3.0 if crit else 1.0)
				col.take_hit(dmg, crit)
				_float_text(end + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), ("%d!" % int(dmg)) if crit else str(int(dmg)), Color(1.0, 0.6, 0.15) if crit else Color(1, 0.45, 0.3))
			elif col.has_method("mine_hit"):
				col.mine_hit()
			elif col is Structure:
				pass  # свои постройки не страдают от твоих пуль
		_tracer(player.global_position + Vector3(0, 1.4, 0), end)
	if ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if reload_t <= 0.0 and ammo < int(_weapon()["mag"]):
		reload_t = _reload_time()


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
	l.font_size = 38
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
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if cutscene_active:
		_cutscene_end()
		get_viewport().set_input_as_handled()
		return
	if state == State.OVER:
		return
	if k.physical_keycode == KEY_ESCAPE:
		return  # Esc обрабатывают магазин/меню
	if Game.dialog_open or player == null or player.dead or Game.is_ui_blocked():
		return
	if k.physical_keycode == KEY_C and build_enabled:
		_toggle_build(not build_open)
		get_viewport().set_input_as_handled()
		return
	if build_open:
		var slot := -1
		match k.physical_keycode:
			KEY_1: slot = 0
			KEY_2: slot = 1
			KEY_3: slot = 2
			KEY_4: slot = 3
			KEY_5: slot = 4
		if slot >= 0:
			_select_build(slot)
			get_viewport().set_input_as_handled()
			return
	if k.physical_keycode == KEY_R:
		_start_reload()
		return
	var wslot := -1
	match k.physical_keycode:
		KEY_1: wslot = 0
		KEY_2: wslot = 1
		KEY_3: wslot = 2
		KEY_4: wslot = 3
	if wslot >= 0 and wslot < WEAPONS.size() and not build_open:
		var w: Dictionary = WEAPONS[wslot]
		if w.get("free", false) or Game.has_item(str(w["id"])):
			if cur_weapon != w["id"]:
				_equip(str(w["id"]))
				show_toast(str(w["name"]))
		else:
			show_toast("Не куплено - магазин (B)")


# ---------- постройка базы ----------
func _toggle_build(on: bool) -> void:
	if not build_enabled:
		return
	build_open = on
	build_bar.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_build_bar()
	else:
		if player.camera_locked:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud_refresh()


func _select_build(i: int) -> void:
	build_sel = i
	_refresh_build_bar()
	show_toast("%s - %d 💀" % [BUILDS[i]["name"], int(BUILDS[i]["cost"])])


func _refresh_build_bar() -> void:
	for i in build_buttons.size():
		var b: Button = build_buttons[i]
		var d: Dictionary = BUILDS[i]
		b.text = ("%s %s %d💀" % ["▶" if i == build_sel else "", d["name"], int(d["cost"])]).strip_edges()
		b.disabled = skulls < int(d["cost"])


func _place_build() -> void:
	if not build_open or state == State.OVER:
		return
	var d: Dictionary = BUILDS[build_sel]
	if skulls < int(d["cost"]):
		show_toast("Не хватает черепков!")
		return
	if structures.size() >= BUILD_LIMIT:
		show_toast("Слишком много построек!")
		return
	var fwd := -player.model.global_basis.z
	var pos := player.global_position + fwd * 2.6
	pos.y = 0.15
	if d["id"] == "drill":
		var crystal = _nearest_crystal(pos, 3.5)
		if crystal == null:
			show_toast("Дриллу нужен кристалл рядом!")
			return
		pos = crystal.global_position + Vector3(1.3, 0.15, 0)
	if d["id"] == "drone":
		skulls -= int(d["cost"])
		Game.set_place_data("skulls", skulls)
		var dr := Drone.new()
		dr.place = self
		dr.position = player.global_position + Vector3(0, 2.7, 0)
		add_child(dr)
		drones.append(dr)
		_burst(dr.position, Color(0.4, 0.8, 1.0), 10, 3.0)
		show_toast("Дрон развернут!")
		_refresh_build_bar()
		hud_refresh()
		return
	var s := Structure.new()
	s.kind = str(d["id"])
	s.place = self
	s.position = pos
	s.rotation.y = player.yaw if d["id"] == "wall" else 0.0
	if d["id"] == "drill":
		s.crystal = _nearest_crystal(pos, 4.0)
	add_child(s)
	structures.append(s)
	skulls -= int(d["cost"])
	Game.set_place_data("skulls", skulls)
	_burst(pos + Vector3(0, 0.8, 0), C_GOLD, 10, 3.0)
	_refresh_build_bar()
	hud_refresh()


func _nearest_crystal(pos: Vector3, max_d: float):
	var best = null
	var best_d := max_d
	for c in crystal_nodes:
		if not is_instance_valid(c) or c.reserve <= 0:
			continue
		var d: float = c.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func _nearest_zombie(pos: Vector3, max_d: float):
	var best = null
	var best_d := max_d
	for z in zombie_list:
		if not is_instance_valid(z) or z.dying:
			continue
		var d: float = z.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = z
	return best


func nearest_structure(pos: Vector3, max_d: float):
	var best = null
	var best_d := max_d
	for s in structures:
		if not is_instance_valid(s) or s.kind == "mine":
			continue
		var d: float = s.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best


func _structure_died(s) -> void:
	structures.erase(s)
	_burst(s.global_position + Vector3(0, 1, 0), Color(0.8, 0.6, 0.2), 16, 5.0)
	_shake(0.3)


func _tick_buildings(delta: float) -> void:
	if state == State.MENU:
		return
	for d in drones:
		if is_instance_valid(d):
			d.tick(delta)


# ---------- HUD ----------
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 11
	add_child(hud)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bg.offset_left = 16
	hp_bg.offset_top = -80
	hp_bg.offset_right = 242
	hp_bg.offset_bottom = -62
	hud.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.3, 0.85, 0.3)
	hp_fill.position = Vector2(2, 2)
	hp_fill.size = Vector2(222, 14)
	hp_bg.add_child(hp_fill)

	var ar_bg := ColorRect.new()
	ar_bg.color = Color(0, 0, 0, 0.5)
	ar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ar_bg.offset_left = 16
	ar_bg.offset_top = -58
	ar_bg.offset_right = 242
	ar_bg.offset_bottom = -44
	hud.add_child(ar_bg)
	ar_fill = ColorRect.new()
	ar_fill.color = Color(0.4, 0.6, 0.95)
	ar_fill.position = Vector2(2, 2)
	ar_fill.size = Vector2(222, 10)
	ar_bg.add_child(ar_fill)

	skull_label = Label.new()
	skull_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	skull_label.offset_left = 16
	skull_label.offset_top = -108
	skull_label.offset_bottom = -84
	skull_label.add_theme_font_size_override("font_size", 20)
	skull_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.95))
	skull_label.add_theme_color_override("font_outline_color", Color.BLACK)
	skull_label.add_theme_constant_override("outline_size", 5)
	hud.add_child(skull_label)

	combo_label = Label.new()
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	combo_label.offset_left = 16
	combo_label.offset_top = 44
	combo_label.add_theme_font_size_override("font_size", 20)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 5)
	hud.add_child(combo_label)

	mode_label = Label.new()
	mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mode_label.offset_left = 16
	mode_label.offset_top = 12
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mode_label.add_theme_constant_override("outline_size", 5)
	hud.add_child(mode_label)

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

	banner_label = Label.new()
	banner_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner_label.offset_top = 90
	banner_label.offset_bottom = 150
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 36)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.add_theme_constant_override("outline_size", 8)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_label.modulate.a = 0.0
	hud.add_child(banner_label)

	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 30)
	cross.add_theme_color_override("font_outline_color", Color.BLACK)
	cross.add_theme_constant_override("outline_size", 6)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)

	build_bar = HBoxContainer.new()
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_bar.offset_left = -435
	build_bar.offset_right = 435
	build_bar.offset_top = -140
	build_bar.offset_bottom = -92
	build_bar.add_theme_constant_override("separation", 8)
	build_bar.visible = false
	hud.add_child(build_bar)
	for i in BUILDS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 44)
		b.pressed.connect(_select_build.bind(i))
		UITheme.dark_button(b)
		build_bar.add_child(b)
		build_buttons.append(b)

	hud_refresh()


func hud_refresh() -> void:
	if skull_label:
		skull_label.text = "💀 %d   (серия x%.1f)" % [skulls, combo_mult()]
		combo_label.text = "🔥 Серия: %d" % combo_n if combo_n >= 2 else ""


func _update_hud() -> void:
	if player == null or player.max_hp <= 0.0:
		return
	var ratio: float = clampf(player.hp / player.max_hp, 0.0, 1.0)
	hp_fill.size = Vector2(222.0 * ratio, 14)
	hp_fill.color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.3), ratio)
	var ar_ratio: float = 0.0 if armor_max <= 0.0 else clampf(armor / armor_max, 0.0, 1.0)
	ar_fill.size = Vector2(222.0 * ar_ratio, 10)
	ar_fill.color = Color(0.4, 0.6, 0.95)
	var w := _weapon()
	var wtxt: String = "%s - перезарядка..." % w["name"] if reload_t > 0.0 else "%s %d/%d" % [w["name"], ammo, int(w["mag"])]
	info_label.text = "Убийств: %d\n%s" % [kills, wtxt]
	match state:
		State.INTERMISSION:
			wave_label.text = "Волна %d через %d с" % [wave + 1, int(ceil(countdown))]
		State.WAVE:
			wave_label.text = "%sВолна %d - осталось %d" % ["🌕 " if blood_moon else "", wave, alive + to_spawn.size()]
		State.OVER:
			wave_label.text = ""
		State.MENU:
			wave_label.text = ""
	if build_bar.visible:
		_refresh_build_bar()


# ---------- Game Over ----------
func _on_player_died() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	_cutscene_end()
	_toggle_build(false)
	Game.set_place_data("total_kills", int(Game.get_place_data("total_kills", 0)) + kills)
	var best := int(Game.get_place_data("best_wave", 0))
	var new_record := wave > best
	if new_record:
		Game.set_place_data("best_wave", wave)
	if is_instance_valid(board):
		board.text = _board_text()
	_show_game_over(new_record)


func _show_game_over(new_record: bool) -> void:
	var ui := CanvasLayer.new()
	ui.layer = 60
	add_child(ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	card.add_theme_stylebox_override("panel", UITheme.panel())
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
	stats.text = "Волна: %d    Убийств: %d    Черепков за забег: %d" % [wave, kills, run_skulls]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var rec := Label.new()
	if new_record:
		rec.text = "НОВЫЙ РЕКОРД!"
		rec.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
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
	again.custom_minimum_size = Vector2(140, 44)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	UITheme.gold_button(again)
	row.add_child(again)
	var tomenu := Button.new()
	tomenu.text = "В меню игры"
	tomenu.custom_minimum_size = Vector2(160, 44)
	tomenu.pressed.connect(func() -> void:
		get_tree().reload_current_scene())
	UITheme.dark_button(tomenu)
	row.add_child(tomenu)
	var platform := Button.new()
	platform.text = "Выйти из плейса"
	platform.custom_minimum_size = Vector2(180, 44)
	platform.pressed.connect(Game.go_to_menu)
	UITheme.dark_button(platform)
	row.add_child(platform)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------- кристаллы (добыча) ----------
class Crystal extends StaticBody3D:
	var place
	var reserve := 120
	var hp := 30.0
	var flash := false

	func _ready() -> void:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.2, 1.6, 1.2)
		col.shape = sh
		col.position.y = 0.8
		add_child(col)
		var rock := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.3, 0.4, 1.3)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.18, 0.18, 0.2)
		rm.material = rmat
		rock.mesh = rm
		rock.position.y = 0.2
		add_child(rock)
		for i in 3:
			var shard := MeshInstance3D.new()
			var sm := BoxMesh.new()
			var h := randf_range(0.7, 1.3)
			sm.size = Vector3(randf_range(0.3, 0.5), h, randf_range(0.3, 0.5))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.7, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.7, 1.0)
			mat.emission_energy_multiplier = 0.9
			sm.material = mat
			shard.mesh = sm
			shard.position = Vector3(randf_range(-0.3, 0.3), 0.4 + h / 2.0, randf_range(-0.3, 0.3))
			shard.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0, TAU), randf_range(-0.3, 0.3))
			add_child(shard)

	func mine_hit() -> void:
		if reserve <= 0:
			return
		var amount := 2 if Game.has_item("pass_skulls") else 1
		reserve -= 2
		hp -= 2.5
		place._add_skulls(amount, global_position)
		place._burst(global_position + Vector3(0, 1, 0), Color(0.3, 0.8, 1.0), 6, 3.0)
		if hp <= 0:
			place._add_skulls(15, global_position + Vector3(0, 1.5, 0), true)
			place._burst(global_position + Vector3(0, 1, 0), Color(0.4, 0.9, 1.0), 24, 6.0)
			place.crystal_nodes.erase(self)
			queue_free()

	func drill_take() -> void:
		if reserve <= 0:
			return
		reserve -= 2
		var amount := 3 if Game.has_item("pass_skulls") else 2
		place._add_skulls(amount, global_position)


# ---------- постройки ----------
class Structure extends StaticBody3D:
	var kind := "wall"
	var place
	var hp := 120.0
	var max_hp := 120.0
	var head: Node3D
	var bit: MeshInstance3D
	var core_mat: StandardMaterial3D
	var fire_t := 0.0
	var out_t := 0.0
	var arm_t := 1.0
	var crystal
	var flash_t := 0.0

	func _ready() -> void:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(3.2, 2.6, 0.6)
		col.shape = sh
		col.position.y = 1.3
		add_child(col)
		match kind:
			"wall":
				hp = 150.0
				max_hp = 150.0
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(3.2, 2.6, 0.5)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.35, 0.38, 0.36)
				bm.material = mat
				m.mesh = bm
				m.position.y = 1.3
				add_child(m)
				place.add_visual_box(self, Vector3(3.3, 0.14, 0.6), Vector3(0, 2.62, 0), place.C_GOLD)
				core_mat = mat
			"turret":
				hp = 100.0
				max_hp = 100.0
				col.shape.size = Vector3(1.2, 1.8, 1.2)
				var base := MeshInstance3D.new()
				var bmesh := CylinderMesh.new()
				bmesh.top_radius = 0.55
				bmesh.bottom_radius = 0.7
				bmesh.height = 0.6
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.2, 0.22, 0.26)
				bmesh.material = bmat
				base.mesh = bmesh
				base.position.y = 0.3
				add_child(base)
				head = Node3D.new()
				head.position.y = 1.0
				add_child(head)
				var barrel := MeshInstance3D.new()
				var brm := BoxMesh.new()
				brm.size = Vector3(0.22, 0.22, 1.1)
				var brmat := StandardMaterial3D.new()
				brmat.albedo_color = place.C_GOLD
				brm.material = brmat
				barrel.mesh = brm
				barrel.position = Vector3(0, 0.15, -0.5)
				head.add_child(barrel)
				var dome := MeshInstance3D.new()
				var dm := SphereMesh.new()
				dm.radius = 0.35
				dm.height = 0.7
				var dmat := StandardMaterial3D.new()
				dmat.albedo_color = Color(0.55, 0.15, 0.15)
				dm.material = dmat
				dome.mesh = dm
				dome.position.y = 0.1
				head.add_child(dome)
				core_mat = dmat
			"drill":
				hp = 90.0
				max_hp = 90.0
				col.shape.size = Vector3(1.2, 1.6, 1.2)
				var frame := MeshInstance3D.new()
				var fm := BoxMesh.new()
				fm.size = Vector3(1.0, 1.4, 1.0)
				var fmat := StandardMaterial3D.new()
				fmat.albedo_color = Color(0.35, 0.28, 0.18)
				fm.material = fmat
				frame.mesh = fm
				frame.position.y = 0.7
				add_child(frame)
				bit = MeshInstance3D.new()
				var dm2 := CylinderMesh.new()
				dm2.top_radius = 0.05
				dm2.bottom_radius = 0.3
				dm2.height = 1.0
				var dmat2 := StandardMaterial3D.new()
				dmat2.albedo_color = place.C_GOLD
				dm2.material = dmat2
				bit.mesh = dm2
				bit.position.y = 1.4
				add_child(bit)
				core_mat = fmat
			"mine":
				hp = 40.0
				max_hp = 40.0
				col.shape.size = Vector3(0.9, 0.4, 0.9)
				var mm := MeshInstance3D.new()
				var mmsh := CylinderMesh.new()
				mmsh.top_radius = 0.42
				mmsh.bottom_radius = 0.5
				mmsh.height = 0.22
				var mmat := StandardMaterial3D.new()
				mmat.albedo_color = Color(0.5, 0.12, 0.1)
				mmat.emission_enabled = true
				mmat.emission = Color(1.0, 0.2, 0.1)
				mmat.emission_energy_multiplier = 0.8
				mmsh.material = mmat
				mm.mesh = mmsh
				mm.position.y = 0.12
				add_child(mm)
				core_mat = mmat
			_:
				pass

	func take_hit(dmg: float) -> void:
		hp -= dmg
		flash_t = 0.1
		if core_mat:
			core_mat.emission_enabled = true
			core_mat.emission = Color(1, 1, 1)
			core_mat.emission_energy_multiplier = 0.8
		if hp <= 0.0:
			place._structure_died(self)
			queue_free()

	func _process(delta: float) -> void:
		if flash_t > 0.0:
			flash_t -= delta
			if flash_t <= 0.0 and core_mat:
				core_mat.emission_enabled = kind == "mine"
				if kind == "mine":
					core_mat.emission_energy_multiplier = 0.8
		match kind:
			"turret":
				_turret(delta)
			"drill":
				_drill(delta)
			"mine":
				_mine(delta)

	func _turret(delta: float) -> void:
		if head == null:
			return
		var z = place._nearest_zombie(global_position, 15.0)
		if z == null:
			return
		var look: Vector3 = z.global_position + Vector3(0, 1.0, 0)
		var dir: Vector3 = look - (global_position + Vector3(0, 1.15, 0))
		if dir.length() > 0.5:
			head.look_at(look)
		fire_t -= delta
		if fire_t <= 0.0:
			fire_t = 0.45
			var dmg: float = 14.0 * place._damage_mult()
			z.take_hit(dmg)
			place._tracer(global_position + Vector3(0, 1.2, 0), z.global_position + Vector3(0, 1.0, 0))
			place._burst(z.global_position + Vector3(0, 1, 0), Color(1.0, 0.7, 0.2), 4, 2.5)

	func _drill(delta: float) -> void:
		if bit:
			bit.rotate_y(delta * 6.0)
		out_t -= delta
		if out_t <= 0.0:
			out_t = 3.0
			if crystal and is_instance_valid(crystal) and crystal.reserve > 0:
				crystal.drill_take()

	func _mine(delta: float) -> void:
		if arm_t > 0.0:
			arm_t -= delta
			return
		if core_mat:
			core_mat.emission_energy_multiplier = 0.8 + sin(Time.get_ticks_msec() / 150.0) * 0.5
		var z = place._nearest_zombie(global_position, 2.4)
		if z:
			_explode()

	func _explode() -> void:
		place._burst(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.15), 30, 8.0)
		place._shake(0.6)
		for z in place.zombie_list.duplicate():
			if is_instance_valid(z) and not z.dying:
				var d: float = z.global_position.distance_to(global_position)
				if d < 4.5:
					z.take_hit(130.0 * (1.0 - d / 4.5 * 0.6))
		place._structure_died(self)
		queue_free()


# ---------- дрон ----------
class Drone extends Node3D:
	var place
	var fire_t := 0.0
	var t := 0.0
	var body: Node3D

	func _ready() -> void:
		body = Node3D.new()
		add_child(body)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.22, 0.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.24, 0.3)
		bm.material = mat
		b.mesh = bm
		body.add_child(b)
		for c in [Vector2(-0.28, -0.28), Vector2(0.28, -0.28), Vector2(-0.28, 0.28), Vector2(0.28, 0.28)]:
			var rotor := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.3, 0.03, 0.08)
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = place.C_GOLD
			rm.material = rmat
			rotor.mesh = rm
			rotor.position = Vector3(c.x, 0.14, c.y)
			body.add_child(rotor)
		var gun := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.08, 0.08, 0.5)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.1, 0.1, 0.12)
		gm.material = gmat
		gun.mesh = gm
		gun.position = Vector3(0, -0.1, -0.3)
		body.add_child(gun)
		var light := OmniLight3D.new()
		light.light_color = Color(0.4, 0.7, 1.0)
		light.light_energy = 0.7
		light.omni_range = 5.0
		light.position.y = -0.2
		add_child(light)

	func tick(delta: float) -> void:
		t += delta
		var p = place.player
		if p == null or not is_instance_valid(p):
			return
		var behind: Vector3 = p.model.global_basis.z * 1.8
		var target: Vector3 = p.global_position + Vector3(0, 2.7, 0) + behind
		global_position = global_position.lerp(target, minf(delta * 4.0, 1.0))
		body.position.y = sin(t * 3.0) * 0.08
		body.rotate_y(delta * 0.8)
		for child in body.get_children():
			if child is MeshInstance3D and child.position.y > 0.1:
				child.rotate_y(delta * 18.0)
		fire_t -= delta
		if fire_t <= 0.0:
			fire_t = 0.9
			var z = place._nearest_zombie(global_position, 13.0)
			if z:
				var dmg: float = 9.0 * place._damage_mult()
				z.take_hit(dmg)
				place._tracer(global_position, z.global_position + Vector3(0, 1.0, 0))
				place._burst(z.global_position + Vector3(0, 1, 0), Color(0.4, 0.8, 1.0), 4, 2.5)


# ---------- зомби ----------
class Zombie extends CharacterBody3D:
	signal killed(z)

	var place
	var hp := 50.0
	var max_hp := 50.0
	var speed := 2.6
	var dmg := 8.0
	var reward := 3
	var skull_reward := 1
	var torso_color := Color(0.42, 0.6, 0.3)
	var is_boss := false
	var is_elite := false
	var spawn_y := 1.0
	var rising := true
	var dying := false
	var hit_cd := 0.0
	var flash_t := 0.0
	var raged := false
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
		place.add_visual_box(vis, Vector3(0.09, 0.1, 0.03), Vector3(-0.11, 1.72, -0.235), Color(1.0, 0.15, 0.1))
		place.add_visual_box(vis, Vector3(0.09, 0.1, 0.03), Vector3(0.11, 1.72, -0.235), Color(1.0, 0.15, 0.1))
		place.add_visual_box(vis, Vector3(0.24, 0.24, 0.7), Vector3(-0.52, 1.28, -0.3), skin)
		place.add_visual_box(vis, Vector3(0.24, 0.24, 0.7), Vector3(0.52, 1.28, -0.3), skin)
		place.add_visual_box(vis, Vector3(0.3, 0.62, 0.3), Vector3(-0.2, 0.32, 0), Color(0.25, 0.28, 0.33))
		place.add_visual_box(vis, Vector3(0.3, 0.62, 0.3), Vector3(0.2, 0.32, 0), Color(0.25, 0.28, 0.33))
		if is_elite:
			place._glow_box(vis, Vector3(0.5, 0.12, 0.5), Vector3(0, 1.98, 0), Color(1.0, 0.8, 0.2), 1.4)
		# подъем из земли
		collision_layer = 0
		collision_mask = 0
		var tw := create_tween()
		tw.tween_property(self, "position:y", spawn_y, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_rise_done)

	func _rise_done() -> void:
		rising = false
		collision_layer = 1
		collision_mask = 1

	func _physics_process(delta: float) -> void:
		if dying or rising:
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
		# сначала атакуют постройки на пути
		var s = place.nearest_structure(global_position, 1.9)
		if s:
			velocity.x = 0.0
			velocity.z = 0.0
			if hit_cd <= 0.0:
				hit_cd = 0.8
				s.take_hit(dmg)
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
				place._player_hit(dmg)
		move_and_slide()

	func take_hit(dmg: float, crit := false) -> void:
		if dying:
			return
		hp -= dmg
		flash_t = 0.08
		if torso_mat:
			torso_mat.emission_enabled = true
			torso_mat.emission = Color(1, 0.5, 0.2) if crit else Color(1, 1, 1)
			torso_mat.emission_energy_multiplier = 0.8
		# ярость босса
		if is_boss and not raged and hp > 0.0 and hp <= max_hp * 0.3:
			raged = true
			speed *= 1.6
			dmg *= 1.3
			if torso_mat:
				torso_mat.albedo_color = Color(0.55, 0.1, 0.1)
			place._banner("БОСС В ЯРОСТИ!", 2.0, Color(1.0, 0.3, 0.25))
			place._shake(1.5)
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
