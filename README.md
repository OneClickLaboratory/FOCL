# Roblox Clone (Godot 4.3+)

1. Открой папку в Godot 4.3+ (Import -> project.godot), запусти (F5).
2. Впиши URL и anon key в `supabase_config.cfg` (Supabase -> Project Settings -> API).
   Для регистрации по email проверь Authentication -> Providers -> Email.
   Если включено подтверждение почты - после регистрации подтверди email, потом входи.
3. Без Supabase можно зайти кнопкой "Играть как гость".

Управление: WASD/стрелки - ходьба, Пробел - прыжок, ПКМ - вращать камеру, колесо - зум,
Esc - меню плейса, ` (Ё) или F1 - консоль.

Консоль: help, time set <0-24>, fps_show, reset, focls <n>, give <id>, items, quit.

Новый плейс: сцена с Node3D + скрипт `extends PlaceBase` (переопредели _build_world()),
затем добавь запись в Game.PLACES (scripts/game.gd).

## Магазин и товары (для креаторов плейсов)

Магазин (клавиша B в плейсе) - общая система: покупка за Focls с окном подтверждения,
владение сохраняется в профиле игрока. Чтобы продавать свои товары, в скрипте плейса
объяви их и выдай возможность после покупки (пример - scripts/places/parkour.gd):

```gdscript
extends PlaceBase

func shop_items() -> Array:
    return [{"id": "jetpack", "name": "Джетпак", "price": 200,
             "desc": "Летай по плейсу", "color": Color(0.3, 0.6, 1.0)}]

func on_item_purchased(item: Dictionary) -> void:
    if item["id"] == "jetpack":
        pass  # включи возможность игроку

func _on_player_spawned() -> void:
    player.flying_changed.connect(_on_flying)  # сигналы игрока доступны здесь
```

API в `Game`: `define_item({...})` (регистрация кодом, плейс подставится сам),
`item_def(id)`, `items_for_place(place_id)`, `has_item(id)`, `buy_item(id)`,
сигнал `item_purchased(id)`. Данные твоего плейса (рекорды, прогресс) храни
через `Game.set_place_data(key, value)` / `Game.get_place_data(key, default)` -
сохраняются в профиле. У игрока есть общие возможности: полёт
`player.set_flying(true/false)` (сигнал `flying_changed`), здоровье
`player.hurt/heal/set_max_hp` (сигнал `hp_changed`, `died`) и инвентарь:
включи `player.inventory_enabled = true` в `_on_player_spawned()` - получишь
хотбар на 8 слотов (клавиши 1-8), подбор предметов с земли `add_pickup(pos, id, count)`
(E), использование (V -> сигнал `item_used`) и выброс (G -> `drop_requested`).
Примеры: паркур с ковром (parkour.gd), казино с рулеткой/слотами/костями (casino.gd),
«Зомби-Выживание 2.0» (zombies.gd) - главное меню, два режима (Классика / База и волны),
своя валюта (черепки), пассы-перки, броня, криты, комбо, кровавая луна, элиты, ярость
босса, добыча кристаллов, постройка базы (стены/турели/дроны/дриллы/мины), катсцены.
У игрока также: камера на Shift (без зажатия ПКМ), рывок на Q (`player.dash_enabled = true`).
