extends Node
## Временный смоук-тест плейса «Зомби» (удаляется после прогона).

func _ready() -> void:
    Game.load_profile("__z_test__", "Тест")
    Game.focls = 1000
    var place = load("res://scenes/places/zombies.tscn").instantiate()
    add_child(place)

    var n_shop: int = place.shop_items().size()

    # Рекорды: place_data
    Game.set_place_data("best_wave", 7)
    var rec := int(Game.get_place_data("best_wave", 0))

    # Покупка апгрейда через API -> хук on_item_purchased -> max_hp вырос
    var ok_armor := Game.buy_item("up_armor")
    var max_hp: float = place.player.max_hp

    # Волна и убийство зомби
    place._start_wave()
    await get_tree().create_timer(1.3).timeout
    var alive_before: int = place.alive
    var z = null
    for c in place.get_children():
        if c.has_method("take_hit"):
            z = c
            break
    var focls_before := Game.focls
    if z:
        z.take_hit(9999.0)
    var kill_ok: bool = place.kills == 1 and Game.focls == focls_before + 3 and place.alive == alive_before - 1
    var data_ok: bool = str(Game.place_data.get("zombies", {}).get("best_wave", 0)) == "7"

    print("RESULT shop=%d rec=%d armor=%s max_hp=%.0f alive_before=%d kill_ok=%s data_ok=%s focls=%d" % [n_shop, rec, ok_armor, max_hp, alive_before, kill_ok, data_ok, Game.focls])
    var all_ok: bool = n_shop == 6 and rec == 7 and ok_armor and max_hp == 150.0 and alive_before > 0 and kill_ok and data_ok
    print("TEST %s" % ("PASS" if all_ok else "FAIL"))
    get_tree().quit(0 if all_ok else 1)
