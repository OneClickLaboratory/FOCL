class_name ItemPickup
extends Node3D
## Предмет на земле: парит, крутится, подсвечивается. Нажми E рядом - подберётся
## в инвентарь (если он включён у игрока). Спавни через PlaceBase.add_pickup().

var place  # PlaceBase, который создал подборку
var item_id := ""
var count := 1
var grace_t := 0.0  # сколько секунд нельзя поднимать (для выброшенных)
var player_in := false
var spin_t := 0.0
var mesh_mi: MeshInstance3D


func _ready() -> void:
	var def := Game.item_def(item_id)
	var color: Color = def.get("color", Color(1.0, 0.82, 0.25))
	mesh_mi = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	bm.material = mat
	mesh_mi.mesh = bm
	mesh_mi.position.y = 0.75
	add_child(mesh_mi)

	var base := str(def.get("name", item_id))
	var name_l := Label3D.new()
	name_l.text = (base + " x%d" % count) if count > 1 else base
	name_l.position.y = 1.4
	name_l.font_size = 42
	name_l.pixel_size = 0.01
	name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_l.outline_size = 12
	add_child(name_l)

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.8
	cs.shape = sh
	cs.position.y = 0.8
	area.add_child(cs)
	area.body_entered.connect(_on_body.bind(true))
	area.body_exited.connect(_on_body.bind(false))
	add_child(area)


func _on_body(body: Node3D, inside: bool) -> void:
	if body is Player:
		player_in = inside


func _process(delta: float) -> void:
	spin_t += delta
	if grace_t > 0.0:
		grace_t -= delta
	rotate_y(delta * 1.6)
	mesh_mi.position.y = 0.75 + sin(spin_t * 2.5) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.physical_keycode != KEY_E:
		return
	if not player_in or grace_t > 0.0:
		return
	var p: Player = get_tree().get_first_node_in_group("player")
	if p == null or p.dead or not p.inventory_enabled:
		return
	if p.inventory_add(item_id, count):
		place.show_toast("Подобрано: %s" % str(Game.item_def(item_id).get("name", item_id)))
		get_viewport().set_input_as_handled()
		queue_free()
	else:
		place.show_toast("Инвентарь полон!")
		get_viewport().set_input_as_handled()
