extends PlaceBase
## Плейс-пример «Казино "Золотой Фокус"»: рулетка, колесо фортуны, слоты и кости.
## Ставки - Focls, рекорд выигрыша через Game.set_place_data. Демонстрирует
## инвентарь: подбор фишек/коктейлей (E), хотбар (1-8), использование (V), G - выброс.

const BETS := [10, 50, 100, 500]

const ROULETTE_SECTORS := ["red", "black", "red", "black", "red", "black", "green", "black", "red", "green", "red", "black"]
const SECTOR_COLORS := {"red": Color(0.85, 0.15, 0.12), "black": Color(0.13, 0.13, 0.16), "green": Color(0.12, 0.55, 0.22)}
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


# ----- запуск -----
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
	add_visual_box(player.model, Vector3(0.62, 0.32, 0.62), Vector3(0, 2.2, 0), Color(1.0, 0.82, 0.25))


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


# ----- товары плейса -----
func shop_items() -> Array:
	return [{
		"id": "vip",
		"name": "VIP-статус",
		"price": 1000,
		"desc": "Золотая корона над головой. Пусть все завидуют.",
		"color": Color(1.0, 0.82, 0.25),
	}]


# ----- мир -----
func _build_world() -> void:
	spawn_point = Vector3(0, 1.5, 20)
	spins = int(Game.get_place_data("spins", 0))
	best_win = int(Game.get_place_data("biggest_win", 0))

	# Предметы инвентаря (не в магазине - только в каталоге для имён/цветов)
	Game.define_item({"id": "chips", "name": "Стопка фишек", "desc": "Используй (V): +50 Focls.", "color": Color(1.0, 0.82, 0.25)})
	Game.define_item({"id": "drink", "name": "Коктейль «Фортуна»", "desc": "Используй (V): +30 HP.", "color": Color(0.95, 0.4, 0.6)})

	# Пол, ковёр, стены
	add_box(Vector3(0, -0.5, 0), Vector3(70, 1, 50), Color(0.13, 0.1, 0.16))
	add_box(Vector3(0, -0.42, 16), Vector3(6, 0.12, 16), Color(0.45, 0.08, 0.12))
	add_box(Vector3(0, 3, -26), Vector3(72, 6, 2), Color(0.24, 0.18, 0.3))
	add_box(Vector3(-20, 3, 26), Vector3(32, 6, 2), Color(0.24, 0.18, 0.3))
	add_box(Vector3(20, 3, 26), Vector3(32, 6, 2), Color(0.24, 0.18, 0.3))
	add_box(Vector3(-36, 3, 0), Vector3(2, 6, 54), Color(0.24, 0.18, 0.3))
	add_box(Vector3(36, 3, 0), Vector3(2, 6, 54), Color(0.24, 0.18, 0.3))

	# Колонны, балки, люстры
	for px in [-12.0, 12.0]:
		for pz in [-4.0, 6.0]:
			add_box(Vector3(px, 3, pz), Vector3(1.4, 6, 1.4), Color(0.5, 0.4, 0.18))
	add_box(Vector3(0, 7.6, -4), Vector3(72, 0.5, 2.2), Color(0.32, 0.25, 0.14))
	add_box(Vector3(0, 7.6, 6), Vector3(72, 0.5, 2.2), Color(0.32, 0.25, 0.14))
	for c in [Vector3(0, 6.5, -4), Vector3(0, 6.5, 6), Vector3(-15, 6.5, -14)]:
		add_visual_box(self, Vector3(1.8, 0.5, 1.8), c, Color(1.0, 0.85, 0.4))
		var light := OmniLight3D.new()
		light.position = c + Vector3(0, -0.8, 0)
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 1.4
		light.omni_range = 22.0
		add_child(light)

	# Вывеска
	var sign_l := Label3D.new()
	sign_l.text = "КАЗИНО «ЗОЛОТОЙ ФОКУС»"
	sign_l.position = Vector3(0, 8.2, -25.7)
	sign_l.font_size = 130
	sign_l.pixel_size = 0.02
	sign_l.modulate = Color(1.0, 0.82, 0.25)
	sign_l.outline_size = 20
	add_child(sign_l)

	# Ряд слот-машин (восток)
	var machine_colors := [Color(0.2, 0.6, 0.7), Color(0.75, 0.3, 0.5), Color(0.25, 0.55, 0.3), Color(0.7, 0.5, 0.15)]
	for i in 4:
		var z := -9.0 + i * 4.5
		add_box(Vector3(30, 1.1, z), Vector3(1.3, 2.2, 1.1), Color(0.14, 0.13, 0.2))
		add_visual_box(self, Vector3(0.08, 0.9, 0.75), Vector3(29.3, 1.5, z), machine_colors[i])
		add_visual_box(self, Vector3(0.14, 0.1, 0.14), Vector3(30, 2.35, z), Color(1.0, 0.9, 0.4))
	stations.append({"pos": Vector3(28.5, 0, -2.25), "radius": 4.6, "open": _open_slots})

	# Рулетка (западный центр)
	add_box(Vector3(-15, 0.5, 0), Vector3(5.2, 1.0, 5.2), Color(0.4, 0.07, 0.1))
	roulette_wheel = _make_wheel(Vector3(-15, 1.35, 0), 2.2, _roulette_colors(), _roulette_labels())
	add_box(Vector3(-12.85, 1.9, 0), Vector3(0.12, 0.7, 0.3), Color(1.0, 0.82, 0.25))
	stations.append({"pos": Vector3(-15, 0, 0), "radius": 4.6, "open": _open_roulette})

	# Колесо фортуны (северо-запад)
	add_box(Vector3(-15, 0.5, -14), Vector3(6, 1.0, 6), Color(0.1, 0.3, 0.2))
	fortune_wheel = _make_wheel(Vector3(-15, 1.45, -14), 3.0, _fortune_colors(), _fortune_labels())
	add_box(Vector3(-11.6, 2.05, -14), Vector3(0.14, 0.9, 0.34), Color(1.0, 0.82, 0.25))
	stations.append({"pos": Vector3(-15, 0, -14), "radius": 5.0, "open": _open_fortune})

	# Кости (северо-восток)
	add_box(Vector3(15, 0.55, -14), Vector3(4.5, 1.1, 2.8), Color(0.1, 0.42, 0.24))
	add_visual_box(self, Vector3(0.42, 0.42, 0.42), Vector3(14.2, 1.35, -14), Color(0.95, 0.95, 0.95))
	add_visual_box(self, Vector3(0.42, 0.42, 0.42), Vector3(15.8, 1.35, -14), Color(0.95, 0.95, 0.95))
	stations.append({"pos": Vector3(15, 0, -14), "radius": 4.0, "open": _open_dice})

	# Бар (юго-восток)
	add_box(Vector3(15, 0.55, 14), Vector3(7, 1.1, 1.5), Color(0.3, 0.2, 0.14))
	add_box(Vector3(15, 1.9, 17), Vector3(7, 2.4, 0.6), Color(0.24, 0.16, 0.12))
	for i in 5:
		add_visual_box(self, Vector3(0.3, 0.7, 0.3), Vector3(13 + i * 1.0, 2.5, 17), [Color(0.2, 0.7, 0.4), Color(0.8, 0.3, 0.2), Color(0.2, 0.4, 0.8), Color(0.9, 0.8, 0.2), Color(0.7, 0.2, 0.6)][i])
	add_sign("БАР", Vector3(15, 4.2, 17))
	add_pickup(Vector3(13.6, 1.25, 14), "drink")
	add_pickup(Vector3(16.2, 1.25, 14), "drink")

	# VIP-зона (юго-запад)
	add_box(Vector3(-18, 0.35, 13.5), Vector3(2.6, 0.7, 1.3), Color(0.5, 0.12, 0.2))
	add_box(Vector3(-13, 0.35, 13.5), Vector3(2.6, 0.7, 1.3), Color(0.5, 0.12, 0.2))
	add_box(Vector3(-15.5, 0.4, 13.5), Vector3(1.6, 0.8, 1.6), Color(0.35, 0.28, 0.14))
	add_sign("VIP", Vector3(-15.5, 3.2, 13.5))
	add_pickup(Vector3(-15.5, 0.95, 13.5), "chips", 2)
	add_pickup(Vector3(-17.5, 0.15, 15.5), "chips")

	# Фишки у входа и доска рекордов
	add_pickup(Vector3(4.5, 0.15, 18), "chips")
	_build_board(Vector3(-6, 0, 20))


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
			res.append(Color(0.17, 0.17, 0.2))
		elif m == 1.5:
			res.append(Color(0.2, 0.45, 0.8))
		elif m == 2.0:
			res.append(Color(0.2, 0.65, 0.3))
		else:
			res.append(Color(0.95, 0.75, 0.15))
	return res


func _fortune_labels() -> Array:
	var res: Array = []
	for m in FORTUNE_MULTS:
		res.append(("x%s" % str(m)).trim_suffix(".0") if m > 0.0 else "")
	return res


func _make_wheel(pos: Vector3, radius: float, colors: Array, labels: Array) -> Node3D:
	var wheel := Node3D.new()
	wheel.position = pos
	add_child(wheel)
	var step := TAU / colors.size()
	var arc := radius * TAU / colors.size() * 0.62
	for i in colors.size():
		var pivot := Node3D.new()
		pivot.rotation.y = i * step
		wheel.add_child(pivot)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 0.84, 0.14, arc)
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
			l.font_size = 70
			l.pixel_size = 0.01
			pivot.add_child(l)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.45
	cm.height = 0.3
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.82, 0.25)
	hm.roughness = 0.4
	cm.material = hm
	hub.mesh = cm
	wheel.add_child(hub)
	return wheel


func _build_board(p: Vector3) -> void:
	add_box(p + Vector3(0, 0.8, 0), Vector3(0.25, 1.6, 0.25), Color(0.4, 0.27, 0.16))
	add_box(p + Vector3(0, 1.7, 0), Vector3(3.2, 2.2, 0.2), Color(0.1, 0.08, 0.14))
	board = Label3D.new()
	board.text = _board_text()
	board.position = p + Vector3(0, 1.7, 0.15)
	board.font_size = 44
	board.pixel_size = 0.01
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.outline_size = 8
	add_child(board)


func _board_text() -> String:
	return "КАЗИНО\nКрупный выигрыш: %d\nСпинов: %d" % [int(Game.get_place_data("biggest_win", 0)), int(Game.get_place_data("spins", 0))]


# ----- ввод и станции -----
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


func _open_dialog(title_text: String) -> VBoxContainer:
	_close_dialog()
	Game.dialog_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialog = CanvasLayer.new()
	dialog.layer = 45
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -380
	panel.offset_right = -24
	panel.offset_top = -240
	panel.offset_bottom = 240
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.12, 0.93)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1, 0.82, 0.25, 0.4)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	dialog.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Кнопками выбери ставку. E/Esc - выйти."
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)
	return box


func _result_label(box: VBoxContainer) -> Label:
	var l := Label.new()
	l.text = ""
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	box.add_child(l)
	return l


func _bet_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for b in BETS:
		var btn := Button.new()
		btn.text = str(b)
		btn.custom_minimum_size = Vector2(72, 38)
		btn.disabled = Game.focls < int(b)
		btn.pressed.connect(_set_bet.bind(int(b)))
		row.add_child(btn)


func _set_bet(v: int) -> void:
	cur_bet = v
	show_toast("Ставка: %d Focls" % v)


# ----- рулетка -----
func _open_roulette() -> void:
	var box := _open_dialog("Рулетка - ставка на цвет")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for c in ["red", "black", "green"]:
		var btn := Button.new()
		btn.text = {"red": "Красный x2", "black": "Чёрный x2", "green": "Зелёный x5"}[c]
		btn.custom_minimum_size = Vector2(104, 40)
		btn.pressed.connect(_set_roulette_bet.bind(str(c)))
		row.add_child(btn)
	_bet_row(box)
	roulette_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(200, 44)
	play.pressed.connect(_roulette_spin)
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
	var target_deg := -(idx * 30.0 + randf_range(-10.0, 10.0)) - 1080.0
	roulette_result.text = "Крутится..."
	var tw := create_tween()
	tw.tween_property(roulette_wheel, "rotation:y", deg_to_rad(target_deg), 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_roulette_result.bind(idx))


func _roulette_result(idx: int) -> void:
	roulette_busy = false
	var sector: String = ROULETTE_SECTORS[idx]
	var payout := 0
	if sector == roulette_bet:
		payout = cur_bet * (5 if sector == "green" else 2)
	var extra := "Выпало %s" % ROULETTE_NAMES[sector]
	_game_result(roulette_result, payout, extra)


# ----- колесо фортуны -----
func _open_fortune() -> void:
	var box := _open_dialog("Колесо фортуны")
	var legend := Label.new()
	legend.text = "Секторы: x0, x1.5, x2 и один x5!"
	legend.modulate = Color(1, 1, 1, 0.6)
	box.add_child(legend)
	_bet_row(box)
	fortune_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(200, 44)
	play.pressed.connect(_fortune_spin)
	box.add_child(play)


func _fortune_spin() -> void:
	if fortune_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	fortune_busy = true
	var idx := randi() % FORTUNE_MULTS.size()
	var target_deg := -(idx * 30.0 + randf_range(-10.0, 10.0)) - 1080.0
	fortune_result.text = "Крутится..."
	var tw := create_tween()
	tw.tween_property(fortune_wheel, "rotation:y", deg_to_rad(target_deg), 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_fortune_result.bind(idx))


func _fortune_result(idx: int) -> void:
	fortune_busy = false
	var mult: float = FORTUNE_MULTS[idx]
	var payout := int(cur_bet * mult)
	_game_result(fortune_result, payout, "Сектор x%s" % str(mult))


# ----- слоты -----
func _open_slots() -> void:
	var box := _open_dialog("Слоты «Золотая семёрка»")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	slots_reels.clear()
	for i in 3:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(64, 64)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.04, 0.07)
		sb.set_corner_radius_all(8)
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34)
		p.add_child(l)
		row.add_child(p)
		slots_reels.append(l)
	_bet_row(box)
	slots_result = _result_label(box)
	var play := Button.new()
	play.text = "КРУТИТЬ"
	play.custom_minimum_size = Vector2(200, 44)
	play.pressed.connect(_slots_spin)
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
	if is_instance_valid(slots_result):
		slots_result.text = "Крутится..."
	var final := [_pick_sym(), _pick_sym(), _pick_sym()]
	for step in 14:
		for r in 3:
			var l := slots_reels[r] as Label
			if is_instance_valid(l):
				l.text = final[r] if step > 8 + r * 2 else SLOTS_SYMS[randi() % SLOTS_SYMS.size()]
		await get_tree().create_timer(0.09).timeout
	_slots_result(final)


func _slots_result(reels: Array) -> void:
	slots_busy = false
	var payout := 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		payout = cur_bet * int(SLOTS_PAYOUT[reels[0]])
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		payout = cur_bet
	_game_result(slots_result, payout, "%s %s %s" % [reels[0], reels[1], reels[2]])


# ----- кости -----
func _open_dice() -> void:
	var box := _open_dialog("Кости - угадай сумму")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for i in 3:
		var btn := Button.new()
		btn.text = ["Меньше 7 (x2.2)", "Ровно 7 (x5)", "Больше 7 (x2.2)"][i]
		btn.custom_minimum_size = Vector2(104, 40)
		btn.pressed.connect(_set_dice.bind(i))
		row.add_child(btn)
	_bet_row(box)
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 14)
	box.add_child(drow)
	for j in 2:
		var l := Label.new()
		l.text = "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 44)
		if j == 0:
			dice_l1 = l
		else:
			dice_l2 = l
		drow.add_child(l)
	dice_result = _result_label(box)
	var play := Button.new()
	play.text = "БРОСИТЬ"
	play.custom_minimum_size = Vector2(200, 44)
	play.pressed.connect(_dice_roll)
	box.add_child(play)


func _set_dice(v: int) -> void:
	dice_bet = v
	show_toast(["Ставка: меньше 7", "Ставка: ровно 7", "Ставка: больше 7"][v])


func _dice_roll() -> void:
	if dice_busy or cur_bet > Game.focls:
		return
	Game.add_focls(-cur_bet)
	dice_busy = true
	if is_instance_valid(dice_result):
		dice_result.text = "Бросок..."
	for i in 10:
		if is_instance_valid(dice_l1):
			dice_l1.text = str(randi() % 6 + 1)
			dice_l2.text = str(randi() % 6 + 1)
		await get_tree().create_timer(0.08).timeout
	var d1 := randi() % 6 + 1
	var d2 := randi() % 6 + 1
	if is_instance_valid(dice_l1):
		dice_l1.text = str(d1)
		dice_l2.text = str(d2)
	var sum := d1 + d2
	var payout := 0
	if dice_bet == 0 and sum < 7:
		payout = int(cur_bet * 2.2)
	elif dice_bet == 1 and sum == 7:
		payout = cur_bet * 5
	elif dice_bet == 2 and sum > 7:
		payout = int(cur_bet * 2.2)
	_game_result(dice_result, payout, "Кости: %d + %d = %d" % [d1, d2, sum])
	dice_busy = false


# ----- результат и рекорды -----
func _game_result(label: Label, payout: int, extra: String) -> void:
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
