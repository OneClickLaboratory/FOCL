extends PlaceBase
## «Казино "Золотой Фокус"» - арт-деко: изумруд, золото, слоновая кость.
## Рулетка в центре под люстрой, крылья по сторонам с табличками,
## золотые направляющие на полу. Ставки - Focls, рекорды сохраняются.

const UITheme := preload("res://scripts/ui_theme.gd")

const BETS := [10, 50, 100, 500]

const C_EMERALD := Color(0.055, 0.2, 0.15)
const C_EMERALD2 := Color(0.08, 0.27, 0.2)
const C_NAVY := Color(0.06, 0.09, 0.13)
const C_TEAL := Color(0.09, 0.16, 0.18)
const C_GOLD := Color(0.85, 0.67, 0.22)
const C_GOLD_GLOW := Color(1.0, 0.82, 0.32)
const C_CREAM := Color(0.93, 0.88, 0.75)
const C_BURGUNDY := Color(0.42, 0.08, 0.14)
const C_MARBLE := Color(0.09, 0.1, 0.12)

const ROULETTE_SECTORS := ["red", "black", "red", "black", "red", "black", "green", "black", "red", "green", "red", "black"]
const SECTOR_COLORS := {"red": Color(0.78, 0.12, 0.1), "black": Color(0.08, 0.08, 0.1), "green": Color(0.08, 0.45, 0.2)}
const ROULETTE_NAMES := {"red": "КРАСНОЕ", "black": "ЧЁРНОЕ", "green": "ЗЕЛЁНОЕ"}

const FORTUNE_MULTS := [0.0, 1.5, 0.0, 0.0, 2.0, 0.0, 0.0, 1.5, 0.0, 0.0, 5.0, 0.0]

const SLOTS_SYMS := ["🍒", "🍋", "🔔", "⭐", "💎"]
const SLOTS_WEIGHTS := [25, 22, 18, 13, 12]
const SLOTS_PAYOUT := {"🍒": 5, "🍋": 6, "🔔": 8, "⭐": 12, "💎": 20}

var dialog: CanvasLayer
var cur_bet := 10
var spins := 0
var best_win := 0
var stations: Array = []
var board: Label3D

var roulette_wheel: Node3D
var roulette_bet := "red"
var roulette_busy := false
var roulette_result: Label

var fortune_wheel: Node3D
var fortune_busy := false
var fortune_result: Label

var slots_reels: Array = []
var slots_busy := false
var slots_result: Label

var dice_l1: Label
var dice_l2: Label
var dice_bet := 0
var dice_busy := false
var dice_result: Label


# ---------- товары и запуск ----------
func shop_items() -> Array:
	return [{
		"id": "vip",
		"name": "VIP-статус",
		"price": 1000,
		"desc": "Золотая корона над головой. Пусть все завидуют.",
		"color": Color(1.0, 0.82, 0.25),
	}]


func _hint_text() -> String:
	var t := super()
	t += "   E у стола - играть"
	return t


func _on_player_spawned() -> void:
	player.inventory_enabled = true
	player.item_used.connect(_on_item_used)
	if Game.has_item("vip"):
		_crown()


func _crown() -> void:
	add_visual_box(player.model, Vector3(0.62, 0.32, 0.62), Vector3(0, 2.2, 0), C_GOLD)


func on_item_purchased(item: Dictionary) -> void:
	if item["id"] == "vip":
		_crown()


func _on_item_used(id: String) -> void:
	match id:
		"chips":
			Game.add_focls(50)
			show_toast("+50 Focls")
		"drink":
			player.heal(30.0)
			show_toast("+30 HP")


# ---------- мир ----------
func _build_world() -> void:
	spawn_point = Vector3(0, 1.5, 20)
	spins = int(Game.get_place_data("spins", 0))
	best_win = int(Game.get_place_data("biggest_win", 0))

	Game.define_item({"id": "chips", "name": "Стопка фишек", "desc": "Используй (V): +50 Focls.", "color": Color(1.0, 0.82, 0.25)})
	Game.define_item({"id": "drink", "name": "Коктейль «Фортуна»", "desc": "Используй (V): +30 HP.", "color": Color(0.95, 0.4, 0.6)})

	_build_hall()
	_build_center()
	_build_wings()
	_build_entrance_wing()
	_build_lights()


func _glow(parent: Node3D, size: Vector3, pos: Vector3, color: Color, energy := 1.1) -> MeshInstance3D:
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


## Зал: пол-шахматка, стены с пилястрами, потолок с кессонами.
func _build_hall() -> void:
	# Пол: коллизия одним боксом + визуальная шахматка
	add_box(Vector3(0, -0.25, 0), Vector3(70, 0.5, 50), C_MARBLE)
	for i in 14:
		for j in 10:
			var c := C_EMERALD2 if (i + j) % 2 == 0 else C_EMERALD
			add_visual_box(self, Vector3(4.98, 0.04, 4.98), Vector3(i * 5 - 32.5, 0.02, j * 5 - 22.5), c)
	# золотой кант пола
	for e in [Vector3(0, 0.05, -24.7), Vector3(0, 0.05, 24.7)]:
		_glow(self, Vector3(70, 0.06, 0.5), e, C_GOLD, 0.5)
	for e in [Vector3(-34.7, 0.05, 0), Vector3(34.7, 0.05, 0)]:
		_glow(self, Vector3(0.5, 0.06, 50), e, C_GOLD, 0.5)

	# Стены-коллизии
	add_box(Vector3(0, 3, -26), Vector3(72, 6, 2), C_NAVY)
	add_box(Vector3(-20, 3, 26), Vector3(32, 6, 2), C_NAVY)
	add_box(Vector3(20, 3, 26), Vector3(32, 6, 2), C_NAVY)
	add_box(Vector3(-36, 3, 0), Vector3(2, 6, 54), C_NAVY)
	add_box(Vector3(36, 3, 0), Vector3(2, 6, 54), C_NAVY)

	# Декор стен: кремовая панель + золотая линия + пилястры
	var walls := [
		{"p": Vector3(0, 1.0, -24.85), "s": Vector3(70, 2.0, 0.2), "n": Vector3(0, 0, 1), "len": 60.0, "step": Vector3(10, 0, 0), "cnt": 8},
		{"p": Vector3(0, 1.0, 24.85), "s": Vector3(32, 2.0, 0.2), "n": Vector3(0, 0, 1), "len": 26.0, "step": Vector3(10, 0, 0), "cnt": 6},
		{"p": Vector3(-34.85, 1.0, 0), "s": Vector3(0.2, 2.0, 50), "n": Vector3(1, 0, 0), "len": 46.0, "step": Vector3(0, 0, 10), "cnt": 6},
		{"p": Vector3(34.85, 1.0, 0), "s": Vector3(0.2, 2.0, 50), "n": Vector3(1, 0, 0), "len": 46.0, "step": Vector3(0, 0, 10), "cnt": 6},
	]
	for w in walls:
		add_visual_box(self, w["s"], w["p"], C_TEAL)
		var line_pos: Vector3 = w["p"] + Vector3(w["n"].x, 0, w["n"].z) * 0.08 + Vector3(0, 1.1, 0)
		_glow(self, w["s"] + Vector3(w["n"].x, 0, w["n"].z) * 0.06 + Vector3(0, 0.06, 0), line_pos, C_GOLD, 0.6)
		for k in int(w["cnt"]):
			var off: Vector3 = (w["step"] as Vector3) * (k - int(w["cnt"]) / 2.0 + 0.5)
			var pil: Vector3 = w["p"] + off + Vector3(w["n"].x, 0, w["n"].z) * 0.14
			add_visual_box(self, Vector3(0.7, 5.4, 0.7), pil, C_NAVY.lerp(C_TEAL, 0.4))
			add_visual_box(self, Vector3(0.84, 0.14, 0.84), pil + Vector3(0, 2.76, 0), C_GOLD)
			add_visual_box(self, Vector3(0.84, 0.14, 0.84), pil - Vector3(0, 2.76, 0), C_GOLD)

	# Потолок + кессоны
	add_visual_box(self, Vector3(72, 0.4, 52), Vector3(0, 8.9, 0), Color(0.03, 0.045, 0.07))
	for z in [-15.0, -5.0, 5.0, 15.0]:
		add_visual_box(self, Vector3(72, 0.5, 1.4), Vector3(0, 8.35, z), C_TEAL)
		_glow(self, Vector3(72, 0.07, 0.2), Vector3(0, 8.08, z), C_GOLD, 0.4)
	for x in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		add_visual_box(self, Vector3(1.4, 0.5, 52), Vector3(x, 8.35, 0), C_TEAL)

	# Колонны арт-деко
	for p in [Vector3(-12, 0, -8), Vector3(12, 0, -8), Vector3(-12, 0, 8), Vector3(12, 0, 8)]:
		add_box(p + Vector3(0, 0.3, 0), Vector3(1.9, 0.6, 1.9), C_MARBLE)
		add_box(p + Vector3(0, 3.5, 0), Vector3(1.2, 5.8, 1.2), C_TEAL)
		add_box(p + Vector3(0, 2.0, 0), Vector3(1.34, 0.16, 1.34), C_GOLD)
		add_box(p + Vector3(0, 4.6, 0), Vector3(1.34, 0.16, 1.34), C_GOLD)
		add_box(p + Vector3(0, 6.55, 0), Vector3(1.9, 0.6, 1.9), C_MARBLE)


## Центр: ковёр, кольцо, рулетка под большой люстрой.
func _build_center() -> void:
	# Красная дорожка с золотой каймой
	add_visual_box(self, Vector3(7, 0.05, 15), Vector3(0, 0.045, 16.5), C_BURGUNDY)
	_glow(self, Vector3(0.22, 0.07, 15), Vector3(-3.6, 0.06, 16.5), C_GOLD, 0.4)
	_glow(self, Vector3(0.22, 0.07, 15), Vector3(3.6, 0.06, 16.5), C_GOLD, 0.4)

	# Золотое кольцо-плаза вокруг рулетки
	for i in 36:
		var a := TAU * i / 36.0
		var d := Vector3(cos(a), 0, sin(a)) * 7.0
		add_visual_box(self, Vector3(0.44, 0.05, 0.44), d + Vector3(0, 0.05, 0), C_GOLD if i % 3 == 0 else C_CREAM)

	# Направляющие к крыльям
	for g in [
		{"p": Vector3(14, 0.05, -2.25), "s": Vector3(18, 0.05, 0.5)},
		{"p": Vector3(-13, 0.05, 0), "s": Vector3(12, 0.05, 0.5)},
		{"p": Vector3(18, 0.05, -9.5), "s": Vector3(0.5, 0.05, 9)},
		{"p": Vector3(-18, 0.05, -9.5), "s": Vector3(0.5, 0.05, 9)},
	]:
		_glow(self, g["s"], g["p"], C_GOLD, 0.35)

	# Пьедестал и рулетка
	add_box(Vector3(0, 0.5, 0), Vector3(5.6, 1.0, 5.6), C_MARBLE)
	add_box(Vector3(0, 1.05, 0), Vector3(5.7, 0.14, 5.7), C_GOLD)
	var felt := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 3.1
	fm.bottom_radius = 3.1
	fm.height = 0.22
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = C_EMERALD
	fmat.roughness = 0.85
	fm.material = fmat
	felt.mesh = fm
	felt.position = Vector3(0, 1.24, 0)
	add_child(felt)
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 3.35
	rm.bottom_radius = 3.35
	rm.height = 0.3
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = C_GOLD
	rmat.metallic = 0.6
	rmat.roughness = 0.3
	rm.material = rmat
	rim.mesh = rm
	rim.position = Vector3(0, 1.2, 0)
	add_child(rim)

	roulette_wheel = _make_wheel(Vector3(0, 1.62, 0), 2.5, _roulette_colors(), _roulette_labels(), ROULETTE_SECTORS)
	add_box(Vector3(2.3, 2.05, 0), Vector3(0.14, 0.85, 0.34), C_GOLD)
	stations.append({"pos": Vector3(0, 0, 0), "radius": 5.2, "open": _open_roulette})


## Крылья: слоты, колесо фортуны, кости, бар, VIP, касса, доска рекордов.
func _build_wings() -> void:
	# --- слоты (восток) ---
	var machine_colors := [Color(0.15, 0.55, 0.65), Color(0.7, 0.25, 0.45), Color(0.2, 0.5, 0.3), Color(0.75, 0.55, 0.15)]
	for i in 4:
		var z := -9.0 + i * 4.5
		add_box(Vector3(32.6, 1.15, z), Vector3(1.4, 2.3, 1.15), C_NAVY)
		add_visual_box(self, Vector3(1.5, 0.14, 1.25), Vector3(32.6, 2.36, z), C_GOLD)
		add_visual_box(self, Vector3(1.5, 0.14, 1.25), Vector3(32.6, 0.16, z), C_GOLD)
		_glow(self, Vector3(0.1, 0.95, 0.8), Vector3(31.82, 1.55, z), machine_colors[i], 1.4)
		_glow(self, Vector3(0.5, 0.22, 0.3), Vector3(32.6, 2.55, z), C_GOLD_GLOW, 1.6)
	stations.append({"pos": Vector3(30, 0, -2.25), "radius": 5.0, "open": _open_slots})
	_hang_sign("СЛОТЫ", Vector3(29.5, 4.4, -2.25), Vector3(-1, 0, 0.15))

	# --- колесо фортуны (запад) ---
	add_box(Vector3(-20, 0.5, 0), Vector3(5.4, 1.0, 5.4), C_MARBLE)
	add_box(Vector3(-20, 1.05, 0), Vector3(5.5, 0.14, 5.5), C_GOLD)
	fortune_wheel = _make_wheel(Vector3(-20, 1.62, 0), 3.0, _fortune_colors(), _fortune_labels(), [])
	add_box(Vector3(-16.4, 2.1, 0), Vector3(0.14, 0.95, 0.36), C_GOLD)
	stations.append({"pos": Vector3(-20, 0, 0), "radius": 5.4, "open": _open_fortune})
	_hang_sign("КОЛЕСО ФОРТУНЫ", Vector3(-17.5, 4.4, 0), Vector3(1, 0, 0.15))

	# --- кости (северо-восток) ---
	add_box(Vector3(18, 0.55, -14), Vector3(4.6, 1.1, 3.0), C_MARBLE)
	var dfelt := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.9
	dm.bottom_radius = 1.9
	dm.height = 0.14
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = C_EMERALD2
	dmat.roughness = 0.85
	dm.material = dmat
	dfelt.mesh = dm
	dfelt.position = Vector3(18, 1.16, -14)
	add_child(dfelt)
	add_visual_box(self, Vector3(0.44, 0.44, 0.44), Vector3(17.1, 1.4, -14), C_CREAM)
	add_visual_box(self, Vector3(0.44, 0.44, 0.44), Vector3(18.9, 1.4, -14), C_CREAM)
	stations.append({"pos": Vector3(18, 0, -14), "radius": 4.2, "open": _open_dice})
	_hang_sign("КОСТИ", Vector3(18, 4.4, -12.4), Vector3(0, 0, 1))

	# --- бар (северо-запад) ---
	add_box(Vector3(-14, 0.55, -22.8), Vector3(9, 1.1, 1.7), C_MARBLE)
	add_visual_box(self, Vector3(9.1, 0.12, 1.8), Vector3(-14, 1.14, -22.8), C_GOLD)
	add_box(Vector3(-14, 2.0, -24.6), Vector3(9, 2.2, 0.5), C_NAVY)
	var bottle_colors := [Color(0.15, 0.6, 0.35), Color(0.75, 0.25, 0.15), Color(0.15, 0.35, 0.7), Color(0.85, 0.75, 0.2), Color(0.6, 0.15, 0.5), Color(0.2, 0.6, 0.6)]
	for i in 6:
		_glow(self, Vector3(0.3, 0.75, 0.3), Vector3(-17.5 + i * 1.4, 2.35, -24.4), bottle_colors[i], 1.3)
	add_pickup(Vector3(-15.5, 1.25, -22.8), "drink")
	add_pickup(Vector3(-12.5, 1.25, -22.8), "drink")
	for sz in [-19.5, -16.0]:
		add_box(Vector3(-16.5, 0.35, sz), Vector3(0.9, 0.7, 0.9), C_BURGUNDY)
	_hang_sign("БАР", Vector3(-14, 4.4, -21.2), Vector3(0, 0, 1))

	# --- VIP (юго-запад) ---
	add_visual_box(self, Vector3(5, 0.05, 4), Vector3(-18, 0.04, 12), C_BURGUNDY)
	add_box(Vector3(-20.4, 0.45, 12), Vector3(1.1, 0.9, 3.4), C_BURGUNDY)
	add_box(Vector3(-21.1, 1.1, 12), Vector3(0.4, 0.7, 3.4), C_BURGUNDY.lerp(Color.BLACK, 0.25))
	add_box(Vector3(-20.4, 0.75, 13.6), Vector3(1.1, 0.45, 0.3), C_GOLD)
	add_box(Vector3(-20.4, 0.75, 10.4), Vector3(1.1, 0.45, 0.3), C_GOLD)
	add_box(Vector3(-18.4, 0.45, 12), Vector3(1.5, 0.9, 1.5), C_MARBLE)
	add_visual_box(self, Vector3(1.7, 0.1, 1.7), Vector3(-18.4, 0.94, 12), C_GOLD)
	add_pickup(Vector3(-18.4, 1.05, 12), "chips", 2)
	add_pickup(Vector3(-16.2, 0.15, 14.5), "chips")
	for rp in [Vector3(-15.4, 0, 10.4), Vector3(-15.4, 0, 13.6)]:
		add_box(rp + Vector3(0, 0.55, 0), Vector3(0.16, 1.1, 0.16), C_GOLD)
		_glow(self, Vector3(0.2, 0.14, 0.2), rp + Vector3(0, 1.16, 0), C_GOLD_GLOW, 1.2)
	add_box(Vector3(-15.4, 0.95, 12), Vector3(0.07, 0.07, 3.0), C_GOLD)
	_hang_sign("VIP", Vector3(-18, 4.4, 12), Vector3(0, 0, 1))

	# --- касса (юго-восток, у входа) ---
	add_box(Vector3(10, 0.55, 19), Vector3(3, 1.1, 1.4), C_MARBLE)
	add_visual_box(self, Vector3(3.1, 0.12, 1.5), Vector3(10, 1.14, 19), C_GOLD)
	add_pickup(Vector3(9.2, 1.25, 19), "chips", 2)
	add_pickup(Vector3(10.8, 1.25, 19), "chips")
	_hang_sign("КАССА", Vector3(10, 4.4, 19), Vector3(0, 0, 1))

	# --- доска рекордов (юго-запад, у входа) ---
	add_box(Vector3(-10, 0.8, 19), Vector3(0.3, 1.6, 0.3), C_MARBLE)
	add_box(Vector3(-10, 1.9, 19), Vector3(3.4, 2.4, 0.24), C_NAVY)
	for f in [
		{"p": Vector3(-10, 3.16, 19), "s": Vector3(3.6, 0.14, 0.3)},
		{"p": Vector3(-10, 0.76, 19), "s": Vector3(3.6, 0.14, 0.3)},
		{"p": Vector3(-11.76, 1.96, 19), "s": Vector3(0.14, 2.5, 0.3)},
		{"p": Vector3(-8.24, 1.96, 19), "s": Vector3(0.14, 2.5, 0.3)},
	]:
		add_visual_box(self, f["s"], f["p"], C_GOLD)
	board = Label3D.new()
	board.text = _board_text()
	board.position = Vector3(-10, 1.95, 19.14)
	board.font_size = 40
	board.pixel_size = 0.01
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.outline_size = 8
	add_child(board)
	_hang_sign("РЕКОРДЫ", Vector3(-10, 4.4, 19), Vector3(0, 0, 1))


func _build_entrance_wing() -> void:
	# Портал входа: ступенчатые золотые колонны + балка
	for px in [-5.0, 5.0]:
		add_box(Vector3(px, 2.5, 25.2), Vector3(1.3, 5, 1.3), C_TEAL)
		add_box(Vector3(px, 5.3, 25.2), Vector3(1.7, 0.4, 1.7), C_GOLD)
		add_box(Vector3(px, 5.75, 25.2), Vector3(2.1, 0.35, 2.1), C_CREAM)
	add_box(Vector3(0, 5.4, 25.2), Vector3(10, 0.5, 1.2), C_GOLD)
	var main := Label3D.new()
	main.text = "КАЗИНО «ЗОЛОТОЙ ФОКУС»"
	main.position = Vector3(0, 7.0, 24.9)
	main.rotation.y = PI
	main.font_size = 110
	main.pixel_size = 0.02
	main.modulate = C_GOLD_GLOW
	main.outline_size = 16
	add_child(main)
	var back := Label3D.new()
	back.text = "УДАЧИ ТЕБЕ, ИГРОК"
	back.position = Vector3(0, 7.0, -25.6)
	back.font_size = 80
	back.pixel_size = 0.02
	back.modulate = Color(0.9, 0.75, 0.5)
	back.outline_size = 14
	add_child(back)


func _build_lights() -> void:
	# Люстры-солнца
	for c in [Vector3(0, 7.0, 0), Vector3(-20, 7.0, 0), Vector3(26, 7.0, -2.25), Vector3(18, 7.0, -14), Vector3(-14, 7.0, -20), Vector3(-18, 7.0, 12), Vector3(10, 7.0, 17)]:
		var big: bool = c.x == 0 and c.z == 0
		var arm_len := 2.4 if big else 1.7
		_chandelier(c, arm_len)


func _chandelier(c: Vector3, arm_len: float) -> void:
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.08
	sm.bottom_radius = 0.08
	sm.height = 1.4
	var smat := StandardMaterial3D.new()
	smat.albedo_color = C_GOLD
	smat.metallic = 0.5
	sm.material = smat
	stem.mesh = sm
	stem.position = c + Vector3(0, 0.8, 0)
	add_child(stem)
	_glow(self, Vector3(0.85, 0.5, 0.85), c, C_GOLD_GLOW, 1.5)
	for i in 8:
		var pivot := Node3D.new()
		pivot.position = c
		pivot.rotation.y = TAU * i / 8.0
		add_child(pivot)
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(arm_len, 0.07, 0.07)
		var amat := StandardMaterial3D.new()
		amat.albedo_color = C_GOLD
		amat.metallic = 0.5
		am.material = amat
		arm.mesh = am
		arm.position = Vector3(arm_len / 2.0, 0.1, 0)
		pivot.add_child(arm)
		var bulb := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.2, 0.2)
		var bumat := StandardMaterial3D.new()
		bumat.albedo_color = C_CREAM
		bumat.emission_enabled = true
		bumat.emission = Color(1.0, 0.9, 0.7)
		bumat.emission_energy_multiplier = 2.0
		bm.material = bumat
		bulb.mesh = bm
		bulb.position = Vector3(arm_len, 0.2, 0)
		pivot.add_child(bulb)
	var light := OmniLight3D.new()
	light.position = c + Vector3(0, -0.6, 0)
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.6
	light.omni_range = 24.0
	add_child(light)


func _hang_sign(text: String, pos: Vector3, face: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(face.x, face.z)
	add_child(n)
	for rx in [-1.35, 1.35]:
		add_visual_box(n, Vector3(0.08, 2.6, 0.08), Vector3(rx, 2.0, 0), C_GOLD)
	add_visual_box(n, Vector3(3.7, 0.95, 0.14), Vector3(0, 0, 0), C_NAVY)
	add_visual_box(n, Vector3(3.7, 0.08, 0.16), Vector3(0, 0.53, 0), C_GOLD)
	add_visual_box(n, Vector3(3.7, 0.08, 0.16), Vector3(0, -0.53, 0), C_GOLD)
	var l := Label3D.new()
	l.text = text
	l.position = Vector3(0, 0, 0.09)
	l.font_size = int(52.0 / maxf(1.0, text.length() / 9.0))
	l.pixel_size = 0.012
	l.modulate = C_GOLD_GLOW
	l.outline_size = 10
	n.add_child(l)


# ---------- колёса ----------
func _roulette_colors() -> Array:
	var res: Array = []
	for s in ROULETTE_SECTORS:
		res.append(SECTOR_COLORS[s])
	return res


func _roulette_labels() -> Array:
	var res: Array = []
	for s in ROULETTE_SECTORS:
		res.append("x5" if s == "green" else "")
	return res


func _fortune_colors() -> Array:
	var res: Array = []
	for m in FORTUNE_MULTS:
		if m == 0.0:
			res.append(Color(0.13, 0.13, 0.16))
		elif m == 1.5:
			res.append(Color(0.16, 0.36, 0.62))
		elif m == 2.0:
			res.append(Color(0.1, 0.42, 0.28))
		else:
			res.append(C_GOLD)
	return res


func _fortune_labels() -> Array:
	var res: Array = []
	for m in FORTUNE_MULTS:
		res.append(("x%s" % str(m)).trim_suffix(".0") if m > 0.0 else "")
	return res


func _make_wheel(pos: Vector3, radius: float, colors: Array, labels: Array, seps: Array) -> Node3D:
	var wheel := Node3D.new()
	wheel.position = pos
	add_child(wheel)
	var n := colors.size()
	var step := TAU / n
	var arc := radius * step * 0.6
	for i in n:
		var pivot := Node3D.new()
		pivot.rotation.y = i * step
		wheel.add_child(pivot)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 0.86, 0.14, arc)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.roughness = 0.55
		bm.material = mat
		box.mesh = bm
		box.position = Vector3(radius * 0.52, 0, 0)
		pivot.add_child(box)
		if labels.size() > i and str(labels[i]) != "":
			var l := Label3D.new()
			l.text = str(labels[i])
			l.position = Vector3(radius * 0.6, 0.14, 0)
			l.rotation_degrees.x = -90
			l.font_size = 64
			l.pixel_size = 0.01
			l.modulate = C_CREAM
			pivot.add_child(l)
	# золотые сепараторы и обод
	var sep_n := seps.size() if seps.size() > 0 else 0
	if sep_n > 0:
		var sep_arc := radius * step * 0.16
		for i in sep_n:
			var sp := Node3D.new()
			sp.rotation.y = i * step + step / 2.0
			wheel.add_child(sp)
			var sb := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(radius * 0.95, 0.18, sep_arc)
			var sm := StandardMaterial3D.new()
			sm.albedo_color = C_GOLD
			sm.metallic = 0.6
			sm.roughness = 0.3
			sbm.material = sm
			sb.mesh = sbm
			sb.position = Vector3(radius * 0.5, 0, 0)
			sp.add_child(sb)
	var ring_n := 24
	var ring_seg := radius * TAU / ring_n * 1.3
	for i in ring_n:
		var rp := Node3D.new()
		rp.rotation.y = TAU * i / ring_n
		wheel.add_child(rp)
		var rb := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		rbm.size = Vector3(0.5, 0.22, ring_seg)
		var rm2 := StandardMaterial3D.new()
		rm2.albedo_color = C_GOLD
		rm2.metallic = 0.6
		rm2.roughness = 0.3
		rbm.material = rm2
		rb.mesh = rbm
		rb.position = Vector3(radius + 0.1, 0, 0)
		rp.add_child(rb)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.5
	cm.height = 0.34
	var hm := StandardMaterial3D.new()
	hm.albedo_color = C_GOLD
	hm.metallic = 0.6
	hm.roughness = 0.3
	cm.material = hm
	hub.mesh = cm
	wheel.add_child(hub)
	return wheel


func _board_text() -> String:
	return "РЕКОРДЫ\nВыигрыш: %d\nСпинов: %d" % [int(Game.get_place_data("biggest_win", 0)), int(Game.get_place_data("spins", 0))]


# ---------- ввод и станции ----------
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_ESCAPE and Game.dialog_open:
		_close_dialog()
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode != KEY_E:
		return
	if Game.dialog_open:
		_close_dialog()
		get_viewport().set_input_as_handled()
		return
	if player == null or player.dead or Game.is_ui_blocked():
		return
	for st in stations:
		if player.global_position.distance_to(st["pos"]) < st["radius"]:
			(st["open"] as Callable).call()
			get_viewport().set_input_as_handled()
			return


func _close_dialog() -> void:
	if dialog:
		dialog.queue_free()
		dialog = null
	Game.dialog_open = false
	# Обнуляем ссылки на UI, чтобы анимации, докручивающиеся после закрытия,
	# не трогали освобождённые лейблы (проверки is_instance_valid ниже).
	roulette_result = null
	fortune_result = null
	slots_result = null
	slots_reels.clear()
	dice_l1 = null
	dice_l2 = null
	dice_result = null


func _open_dialog(title_text: String) -> VBoxContainer:
	_close_dialog()
	Game.dialog_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialog = CanvasLayer.new()
	dialog.layer = 45
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -400
	panel.offset_right = -24
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.add_theme_stylebox_override("panel", UITheme.panel())
	dialog.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	UITheme.title(title)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Выбери ставку кнопками. E/Esc - выйти."
	hint.modulate = Color(1, 1, 1, 0.45)
	box.add_child(hint)
	return box


func _result_label(box: VBoxContainer) -> Label:
	var l := Label.new()
	l.text = ""
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 46)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	l.add_theme_font_size_override("font_size", 18)
	box.add_child(l)
	return l


func _bet_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for b in BETS:
		var btn := Button.new()
		btn.text = str(b)
		btn.custom_minimum_size = Vector2(74, 40)
		btn.disabled = Game.focls < int(b)
		btn.pressed.connect(_set_bet.bind(int(b)))
		UITheme.dark_button(btn)
		row.add_child(btn)


func _set_bet(v: int) -> void:
	cur_bet = v
	show_toast("Ставка: %d Focls" % v)


# ---------- рулетка ----------
func _open_roulette() -> void:
	var box := _open_dialog("Рулетка - ставка на цвет")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for c in ["red", "black", "green"]:
		var btn := Button.new()
		btn.text = {"red": "Красный x2", "black": "Чёрный x2", "green": "Зелёный x5"}[c]
		btn.custom_minimum_size = Vector2(104, 42)
		btn.pressed.connect(_set_roulette_bet.bind(str(c)))
		UITheme.dark_button(btn)
		row.add_child(btn)
	_bet_row(box)
	roulette_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(220, 48)
	play.pressed.connect(_roulette_spin)
	UITheme.gold_button(play, true)
	box.add_child(play)


func _set_roulette_bet(c: String) -> void:
	roulette_bet = c
	show_toast("Ставка на %s" % ROULETTE_NAMES[c])


func _roulette_spin() -> void:
	if roulette_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	roulette_busy = true
	var idx := randi() % ROULETTE_SECTORS.size()
	var res := roulette_result
	var target_deg := -(idx * 30.0 + randf_range(-10.0, 10.0)) - 1080.0
	if is_instance_valid(res):
		res.text = "Крутится..."
	var tw := create_tween()
	tw.tween_property(roulette_wheel, "rotation:y", deg_to_rad(target_deg), 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_roulette_result.bind(idx, res))


func _roulette_result(idx: int, res) -> void:
	roulette_busy = false
	var sector: String = ROULETTE_SECTORS[idx]
	var payout := 0
	if sector == roulette_bet:
		payout = cur_bet * (5 if sector == "green" else 2)
	_game_result(res, payout, "Выпало %s" % ROULETTE_NAMES[sector])


# ---------- колесо фортуны ----------
func _open_fortune() -> void:
	var box := _open_dialog("Колесо фортуны")
	var legend := Label.new()
	legend.text = "Секторы: x0, x1.5, x2 и один x5!"
	legend.modulate = Color(1, 1, 1, 0.55)
	box.add_child(legend)
	_bet_row(box)
	fortune_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(220, 48)
	play.pressed.connect(_fortune_spin)
	UITheme.gold_button(play, true)
	box.add_child(play)


func _fortune_spin() -> void:
	if fortune_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	fortune_busy = true
	var idx := randi() % FORTUNE_MULTS.size()
	var res := fortune_result
	var target_deg := -(idx * 30.0 + randf_range(-10.0, 10.0)) - 1080.0
	if is_instance_valid(res):
		res.text = "Крутится..."
	var tw := create_tween()
	tw.tween_property(fortune_wheel, "rotation:y", deg_to_rad(target_deg), 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_fortune_result.bind(idx, res))


func _fortune_result(idx: int, res) -> void:
	fortune_busy = false
	var mult: float = FORTUNE_MULTS[idx]
	var payout := int(cur_bet * mult)
	_game_result(res, payout, "Сектор x%s" % str(mult))


# ---------- слоты ----------
func _open_slots() -> void:
	var box := _open_dialog("Слоты «Золотая семёрка»")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	slots_reels.clear()
	for i in 3:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(70, 70)
		p.add_theme_stylebox_override("panel", UITheme.card())
		var l := Label.new()
		l.text = "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 36)
		p.add_child(l)
		row.add_child(p)
		slots_reels.append(l)
	_bet_row(box)
	slots_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(220, 48)
	play.pressed.connect(_slots_spin)
	UITheme.gold_button(play, true)
	box.add_child(play)


func _pick_sym() -> String:
	var roll := randi() % 90
	var acc := 0
	for i in SLOTS_SYMS.size():
		acc += SLOTS_WEIGHTS[i]
		if roll < acc:
			return SLOTS_SYMS[i]
	return SLOTS_SYMS[0]


func _slots_spin() -> void:
	if slots_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	slots_busy = true
	var reels: Array = slots_reels.duplicate()
	var res := slots_result
	if is_instance_valid(res):
		res.text = "Крутится..."
	var final := [_pick_sym(), _pick_sym(), _pick_sym()]
	for step in 14:
		for r in 3:
			var lv = reels[r]
			if is_instance_valid(lv):
				(lv as Label).text = final[r] if step > 8 + r * 2 else SLOTS_SYMS[randi() % SLOTS_SYMS.size()]
		await get_tree().create_timer(0.09).timeout
	_slots_result(final, res)


func _slots_result(reels: Array, res) -> void:
	slots_busy = false
	var payout := 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		payout = cur_bet * int(SLOTS_PAYOUT[reels[0]])
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		payout = cur_bet
	_game_result(res, payout, "%s %s %s" % [reels[0], reels[1], reels[2]])


# ---------- кости ----------
func _open_dice() -> void:
	var box := _open_dialog("Кости - угадай сумму")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for i in 3:
		var btn := Button.new()
		btn.text = ["Меньше 7 (x2.2)", "Ровно 7 (x5)", "Больше 7 (x2.2)"][i]
		btn.custom_minimum_size = Vector2(104, 42)
		btn.pressed.connect(_set_dice.bind(i))
		UITheme.dark_button(btn)
		row.add_child(btn)
	_bet_row(box)
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 14)
	box.add_child(drow)
	for j in 2:
		var lp := PanelContainer.new()
		lp.custom_minimum_size = Vector2(56, 56)
		lp.add_theme_stylebox_override("panel", UITheme.card())
		var l := Label.new()
		l.text = "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30)
		lp.add_child(l)
		drow.add_child(lp)
		if j == 0:
			dice_l1 = l
		else:
			dice_l2 = l
	dice_result = _result_label(box)
	var play := Button.new()
	play.text = "БРОСИТЬ"
	play.custom_minimum_size = Vector2(220, 48)
	play.pressed.connect(_dice_roll)
	UITheme.gold_button(play, true)
	box.add_child(play)


func _set_dice(v: int) -> void:
	dice_bet = v
	show_toast(["Ставка: меньше 7", "Ставка: ровно 7", "Ставка: больше 7"][v])


func _dice_roll() -> void:
	if dice_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	dice_busy = true
	var l1 := dice_l1
	var l2 := dice_l2
	var res := dice_result
	if is_instance_valid(res):
		res.text = "Бросок..."
	for i in 10:
		if is_instance_valid(l1):
			l1.text = str(randi() % 6 + 1)
			l2.text = str(randi() % 6 + 1)
		await get_tree().create_timer(0.08).timeout
	var d1 := randi() % 6 + 1
	var d2 := randi() % 6 + 1
	if is_instance_valid(l1):
		l1.text = str(d1)
		l2.text = str(d2)
	var sum := d1 + d2
	var payout := 0
	if dice_bet == 0 and sum < 7:
		payout = int(cur_bet * 2.2)
	elif dice_bet == 1 and sum == 7:
		payout = cur_bet * 5
	elif dice_bet == 2 and sum > 7:
		payout = int(cur_bet * 2.2)
	_game_result(res, payout, "Кости: %d + %d = %d" % [d1, d2, sum])
	dice_busy = false


# ---------- результат и рекорды ----------
func _game_result(label, payout: int, extra: String) -> void:
	var net := payout - cur_bet
	if payout > 0:
		Game.add_focls(payout)
	spins += 1
	Game.set_place_data("spins", spins)
	if net > best_win:
		best_win = net
		Game.set_place_data("biggest_win", best_win)
		show_toast("Новый рекорд выигрыша!")
	if is_instance_valid(board):
		board.text = _board_text()
	var txt := "-%d Focls" % cur_bet
	if net > 0:
		txt = "Выигрыш +%d Focls!" % net
	elif payout == cur_bet:
		txt = "Возврат ставки"
	if is_instance_valid(label):
		label.text = "%s - %s" % [extra, txt]
